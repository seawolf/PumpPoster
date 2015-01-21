require 'date'
require 'yaml'

require './lib/net/communicator.rb'

module Api
  module TrainTimes
    HOST = "https://api.rtt.io/api/v1"
    TYPE = :json

    class Schedule
      attr_reader :results

      def initialize(uid, date)
        @uid = uid

        date = Date.parse(date) unless date.is_a?(Date)
        @date = date
        response = ::Communicator.get("#{HOST}/#{TYPE}/service/#{@uid}/#{pad(@date.year, 4)}/#{pad(@date.month)}/#{pad(@date.day)}", 443, nil, nil, fetch_creds)
        @results = response.code.to_i == 200 ? JSON.parse(response.body) : []

        cleanup! unless @results.empty?
      end

      private

      def cleanup!
        # departure times: 1234 to 12:34
        clean_time(@results['origin'][0]['publicTime'])
        clean_time(@results['destination'][0]['publicTime'])

        @results['locations'].each do |c|
          clean_time(c['gbttBookedArrival'])
          clean_time(c['gbttBookedDeparture'])
        end
      end

      def clean_time(str)
        str.insert(2, ":") if str.is_a?(String) && str.length >= 4
      end

      def pad(obj, length=2)
        return obj.to_s.rjust(length, "0")
      end

      def fetch_creds
        begin
          content = YAML.load( File.read('RTT_CREDS.YML') )
          puts "  · RTT Credentials fetched: #{content}"
          return content
        rescue Errno::ENOENT
          return {}
        end
      end
    end
  end
end
