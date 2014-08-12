require 'tzinfo'

module Pump
  module Util
    class DateTime
      STRFTIME_UTC_JS = "%Y-%m-%dT%H:%M:%SZ"

      def self.local_tzinfo
        return TZInfo::Timezone.get('Europe/London')
      end

      def self.to_utc(obj)
        puts "  > (#{obj.class}): #{obj.inspect}"
        obj = ::DateTime.parse(obj) if obj.is_a?(String)
        puts "    > UTC output: #{self.local_tzinfo.local_to_utc(obj)}\n"
        return self.local_tzinfo.local_to_utc(obj)
      end

      def self.json_datetime(datetime)
        return datetime.strftime(STRFTIME_UTC_JS)
      end
    end
  end
end
