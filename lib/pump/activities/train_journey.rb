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
        @journey = Journey.new(data, @login)
      end

      def submit!
        pp decorate
        puts "Press Enter to post." ; gets
        puts "  · Posting journey..."
        # posted = post!( decorate )
        # check(posted)
        # delete!(posted)
      end

      def ask_for_data
        print "UID: "; uid = gets.chomp
        print "Headcode: "; headcode = gets.chomp

        print "Schedule Origin code: "; schedule_origin_cors = gets.chomp
        print "Schedule Origin name: "; schedule_origin_name = gets.chomp
        print "Schedule Departure date (YYYY-MM-DD): "; schedule_origin_date = gets.chomp
        print "Schedule Departure time (HH:MM): "; schedule_origin_time = gets.chomp
        print "Schedule Terminus code: "; schedule_terminus_cors = gets.chomp
        print "Schedule Terminus name: "; schedule_terminus_name = gets.chomp
        print "Schedule Arrival date (YYYY-MM-DD): "; schedule_terminus_date = gets.chomp
        print "Schedule Arrival time (HH:MM): "; schedule_terminus_time = gets.chomp

        print "Journey Origin code: "; origin_cors = gets.chomp
        print "Journey Origin name: "; origin_name = gets.chomp
        print "Journey Departure date (YYYY-MM-DD): "; origin_date = gets.chomp
        print "Journey Departure time (HH:MM): "; origin_time = gets.chomp
        print "Journey Terminus code: "; terminus_cors = gets.chomp
        print "Journey Terminus name: "; terminus_name = gets.chomp
        print "Journey Arrival date (YYYY-MM-DD): "; terminus_date = gets.chomp
        print "Journey Arrival time (HH:MM): "; terminus_time = gets.chomp

        return {
          schedule: {
            uid: uid,
            headcode: headcode,
            origin: {
              name: schedule_origin_name,
              cors: schedule_origin_cors,
              datetime: "#{schedule_origin_date}T#{schedule_origin_time}:00+01:00"
            },
            terminus: {
              name: schedule_terminus_name,
              cors: schedule_terminus_cors,
              datetime: "#{schedule_terminus_date}T#{schedule_terminus_time}:00+01:00"
            }
          },
          journey: {
            origin: {
              name: origin_name,
              cors: origin_cors,
              datetime: "#{origin_date}T#{origin_time}:00+01:00"
            },
            terminus: {
              name: terminus_name,
              cors: terminus_cors,
              datetime: "#{terminus_date}T#{terminus_time}:00+01:00"
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
        puts response.body
        puts "  · Successful!" if response.code == 200

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
        puts response.code
        puts response.body

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
        puts "  · Successful!" if [200, 202, 204].include?(response.code)
        puts response.code
        puts response.body

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

        data["published"] = @journey.terminus.datetime.strftime("%Y-%m-%dT%H:%M:%S")

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
          @datetime = DateTime.parse(datetime) unless datetime.nil?
        end
      end
    end
  end
end
