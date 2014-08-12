require './lib/net/api/traintimes.rb'
require './lib/net/communicator.rb'

require 'date'
require 'json'

module Pump
  module Activities
    class TrainJourney
      attr_reader :login, :journey

      def initialize(login, data=nil)
        @login = login
        data = ask_for_data unless data.is_a?(Hash)
        @journey = Journey.new(data, @login) unless data.nil? || data.keys.empty?
      end

      def submit!
        return nil if @journey.nil?
        puts "Press Enter to post." ; gets
        puts "  · Posting journey..."
        posted = post!( decorate )
        # check(posted)
        # delete!(posted)
      end

      def ask_for_data
        uid = ""
        while uid.length == 0
          print "  > UID: "; uid = gets.chomp.upcase
        end

        begin
          print "  > Date (YYYY-MM-DD): "; date = Date.parse(gets.chomp)
        rescue ArgumentError
          retry
        end

        others = ::Api::TrainTimes::Schedule.new(uid, date).results
        return nil if others.empty?

        headcode = others["trainIdentity"]

        calling_points = others["locations"]

        schedule_origin_cors = calling_points.first["crs"]
        schedule_origin_name = calling_points.first["description"]
        schedule_origin_date = calling_points.first["calldate"]
        schedule_origin_time = calling_points.first["departure_time"]

        schedule_terminus_cors = calling_points.last["crs"]
        schedule_terminus_name = calling_points.last["description"]
        schedule_terminus_date = calling_points.last["calldate"]
        schedule_terminus_time = calling_points.last["arrival_time"]

        puts "    · Found schedule for #{headcode} #{schedule_origin_name} (#{schedule_origin_cors}) to #{schedule_terminus_name} (#{schedule_terminus_cors})"

        print "  > Origin code: "
        origin_cors = gets.chomp.upcase
        origin = calling_points.select { |c| c["crs"] == origin_cors }.first
        origin_name = origin["description"]
        origin_date = origin["calldate"]
        origin_time = origin["departure_time"]
        puts "    · Calling at #{origin_name} on #{origin_date} at #{origin_time}"

        print "  > Terminus code: "
        terminus_cors = gets.chomp.upcase
        terminus = calling_points.select { |c| c["crs"] == terminus_cors }.last
        terminus_name = terminus["description"]
        terminus_date = terminus["calldate"]
        terminus_time = terminus["arrival_time"]
        puts "    · Calling at #{terminus_name} on #{terminus_date} at #{terminus_time}"

        r = {
          schedule: {
            uid: uid,
            headcode: headcode,
            origin: {
              name: schedule_origin_name,
              cors: schedule_origin_cors,
              datetime: Pump::Util::DateTime.to_utc("#{schedule_origin_date}T#{schedule_origin_time}")
            },
            terminus: {
              name: schedule_terminus_name,
              cors: schedule_terminus_cors,
              datetime: Pump::Util::DateTime.to_utc("#{schedule_terminus_date}T#{schedule_terminus_time}")
            }
          },
          journey: {
            origin: {
              name: origin_name,
              cors: origin_cors,
              datetime: Pump::Util::DateTime.to_utc("#{origin_date}T#{origin_time}")
            },
            terminus: {
              name: terminus_name,
              cors: terminus_cors,
              datetime: Pump::Util::DateTime.to_utc("#{terminus_date}T#{terminus_time}")
            }
          }
        }
      end

      private

      def post!(decorated_data)
        uri = URI.parse("#{@login.site}/api/user/#{@login.username}/feed")
        puts "  · Posting to: #{uri}"
        auth_hash = {
          consumer: @login.oauth,
          site: @login.site, request_uri: uri.to_s,
          key: @login.secret, token: OAuth::Token.new(@login.token, @login.secret)
        }
        response = Communicator.post(uri.to_s, 443, decorated_data, nil, auth_hash)
        if response.code.to_i == 200
          puts "  · Successful!"
          puts "    -> #{JSON.parse(response.body)["id"]}"
        else
          puts "  ! Unsuccessful: #{response.code}"
          puts response.body
        end
        return response
      end

      def check(response)
        activity = JSON.parse(response.body)
        object_type = activity['object']['objectType']
        object_id = activity['id']

        uri = URI.parse(object_id)
        auth_hash = {
          consumer: @login.oauth,
          site: @login.site, request_uri: uri.to_s,
          key: @login.secret, token: OAuth::Token.new(@login.token, @login.secret)
        }
        response = Communicator.get(uri.to_s, 443, nil, auth_hash)
        if response.code.to_i == 200
          puts "  · Successful!"
        else
          puts "  ! Unsuccessful: #{response.code}"
          puts response.body
        end
        return response
      end

      def delete!(response)
        activity = JSON.parse(response.body)
        object_type = activity['object']['objectType']
        object_id = activity['id']

        uri = URI.parse(object_id)
        puts "  · Deleting #{object_type} at: #{object_id}"

        auth_hash = {
          consumer: @login.oauth,
          site: @login.site, request_uri: uri.to_s,
          key: @login.secret, token: OAuth::Token.new(@login.token, @login.secret)
        }
        response = Communicator.delete(uri.to_s, 443, nil, auth_hash)
        if [200, 202, 204].include?(response.code.to_i)
          puts "  · Successful! (#{response.code})"
        else
          puts "  ! Unsuccessful: #{response.code}"
          puts response.body
        end
        return response
      end

      def decorate
        data = {
          "actor" => {
            "objectType" => "person",
            "displayName" => @login.nickname,
            "url" => "#{@login.username}@#{@login.host}",
            "id" => "acct:#{@login.username}@#{@login.host}"
          },
          "verb" => "travel",  # TODO: registered verb?
          "object" => {
            "objectType" => "train journey",  # TODO: registered object type?
            "displayName" => @journey.schedule.title,
            "links" => {
              "canonical" => {
                "href" => @journey.rtt_uri
              },
            },
          },
          "content" => @journey.message,
          "to" => [
            {
              "objectType" => "collection",
              "id" => "http://activityschema.org/collection/public"
            }
          ],
          "cc" => [
            {
              "objectType" => "collection",
              "id" => @login.followers_url
            }
          ]
        }

        # data["published"] = @journey.terminus.datetime.strftime("%Y-%m-%dT%H:%M:%SZ")
        data["published"] = Pump::Util::DateTime.json_datetime(@journey.terminus.datetime)

        json = JSON.generate(data)
        return json
      end

      class Journey
        attr_reader :schedule, :origin, :terminus

        def initialize(data, login=nil)
          @login = login
          @origin = Location.new(
            data[:journey][:origin][:name],
            data[:journey][:origin][:cors],
            data[:journey][:origin][:datetime])
          @terminus = Location.new(
            data[:journey][:terminus][:name],
            data[:journey][:terminus][:cors],
            data[:journey][:terminus][:datetime])
          @schedule = Schedule.new(
            data[:schedule][:uid],
            data[:schedule][:headcode],
            data[:schedule][:origin],
            data[:schedule][:terminus])
        end

        def message
          prefix = "ben"
          prefix = "<a href=\"#{@login.url}\">#{@login.nickname}</a>" unless @login.nil?
          return "#{prefix} travelled between #{@origin.name} and #{@terminus.name} on <a href=\"#{rtt_uri}\">#{@schedule.headcode}</a>"
        end

        def rtt_uri
          uid   = @schedule.uid
          date  = @schedule.origin.datetime
          year  = date.year.to_s.rjust(4, "0")
          month = date.month.to_s.rjust(2, "0")
          day   = date.day.to_s.rjust(2, "0")

          return URI.parse("http://www.realtimetrains.co.uk/train/#{uid}/#{year}/#{month}/#{day}")
        end
      end

      class Schedule
        attr_reader :uid, :headcode, :origin, :terminus, :title

        def initialize(uid, headcode, origin_hash, terminus_hash)
          @uid = uid
          @headcode = headcode
          @origin = Location.new(
            origin_hash[:name],
            origin_hash[:cors],
            origin_hash[:datetime])
          @terminus = Location.new(
            terminus_hash[:name],
            terminus_hash[:cors],
            terminus_hash[:datetime])

          @title = "#{@headcode} #{@origin.datetime.strftime("%H%M")} #{@origin.name} (#{@origin.cors}) to #{@terminus.name} (#{@terminus.cors})"
        end
      end

      class Location
        attr_reader :name, :cors, :datetime

        def initialize(name, cors, datetime=nil)
          @name = name
          @cors = cors
          @datetime = datetime
        end
      end
    end
  end
end
