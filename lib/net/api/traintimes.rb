require 'date'

require './lib/net/communicator.rb'

module Api
  module TrainTimes
    HOST = "http://api.traintimes.im"

    class Schedule
      attr_reader :results

      def initialize(uid, date)
        @uid = uid

        date = Date.parse(date) unless date.is_a?(Date)
        @date = date

        response = ::Communicator.get("#{HOST}/schedule_full.json?uid=#{@uid}&date=#{@date.strftime("%Y-%m-%d")}", 80)
        @results = response.code.to_i == 200 ? JSON.parse(response.body) : []

        cleanup! unless @results.empty?
      end

      private

      def cleanup!
        # departure times: 1234 to 12:34
        clean_time(@results["origin"]["departure_time"])
        clean_time(@results["destination"]["arrival_time"])

        @results["locations"].each do |c|
          clean_time(c["departure_time"])
          clean_time(c["arrival_time"])
        end
      end

      def clean_time(str)
        str.insert(2, ":") if str.is_a?(String) && str.length >= 4
      end
    end
  end
end
