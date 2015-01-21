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

        unless data.is_a?(Hash)
          data = ask_for_data
          while data.nil? do
            print "  ! There was a problem fetching journey data. Try again? "; answer = gets.chomp.upcase
            if answer == "Y"
              data = ask_for_data
            else
              return nil
            end
          end
        end

        @journey = Journey.new(data, @login) unless data.nil? || data.keys.empty?
      end

      def submit!
        return nil if @journey.nil?
        puts "Press Enter to post." ; gets
        puts "  · Posting journey..."
        activity = Pump::Activity.new(@login, "travel", decorate, false).json
        puts activity
        # posted = post!(activity)
        # check(posted)
        # delete!(posted)
      end

      def ask_for_data
        uid = ""
        while uid.length == 0
          print "  > UID: "; uid = gets.chomp.upcase
        end

        begin
          print "  > Date (YYYY-MM-DD; blank for today): " ; raw_date = gets.chomp
          date = raw_date.empty? ? Date.today : Date.parse(raw_date)
        rescue ArgumentError
          retry
        end

        schedule = ::Api::TrainTimes::Schedule.new(uid, date).results
        return nil if schedule.empty?

        headcode = schedule['trainIdentity']

        calling_points = schedule['locations']

        schedule_origin_cors = calling_points.first['crs']
        schedule_origin_name = calling_points.first['description']
        schedule_origin_date = date_for_calling_point(date, calling_points.first['gbttBookedDepartureNextDay'])
        schedule_origin_time = calling_points.first['gbttBookedDeparture']

        schedule_terminus_cors = calling_points.last['crs']
        schedule_terminus_name = calling_points.last['description']
        schedule_terminus_date = date_for_calling_point(date, calling_points.last['gbttBookedArrivalNextDay'])
        schedule_terminus_time = calling_points.last['gbttBookedArrival']

        puts "    · Found schedule for #{headcode} #{schedule_origin_name} (#{schedule_origin_cors}) to #{schedule_terminus_name} (#{schedule_terminus_cors})"

        print '  > Origin code: '
        origin_cors = gets.chomp.upcase
        origin = calling_points.select { |c| c['crs'] == origin_cors }.first
        origin_name = origin['description']
        origin_date = date_for_calling_point(date, origin['gbttBookedDepartureNextDay'])
        origin_time = origin['gbttBookedDeparture']
        puts "    · Calling at #{origin_name} on #{origin_date} at #{origin_time}"

        print '  > Terminus code: '
        terminus_cors = gets.chomp.upcase
        terminus = calling_points.select { |c| c['crs'] == terminus_cors }.last
        terminus_name = terminus['description']
        terminus_date = date_for_calling_point(date, terminus['gbttBookedArrivalNextDay'])
        terminus_time = terminus['gbttBookedArrival']
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

        return r
      end

      private

      def date_for_calling_point(date, bool=false)
        date = Date.parse(date) if date.is_a?(String)
        date = date.next_day if bool == true
        return date.strftime("%Y-%m-%d")
      end

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
        return {
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
          # "published" => @journey.terminus.datetime.strftime("%Y-%m-%dT%H:%M:%SZ")
          "published" => Pump::Util::DateTime.json_datetime(@journey.terminus.datetime)
        }
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
