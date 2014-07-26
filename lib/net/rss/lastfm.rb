require 'net/https'
require 'uri'
require 'simple-rss'
require 'date'

require './lib/net/communicator.rb'

module RSS
  class LastFm
    attr_reader :username, :pump_login, :results, :limit

    FEED_LIMIT = 200
    FEED_CACHE = 5 * 60 # minutes

    def initialize(username, pump_login=nil)
      @username = username
      @pump_login = pump_login
      @results = []
      go unless last_fetch_timestamp > Time.now - FEED_CACHE
    end

    def go
      rss = SimpleRSS.parse ::Communicator.get("http://ws.audioscrobbler.com/1.0/user/#{@username}/recenttracks.rss?limit=#{FEED_LIMIT}", 80).body
      update_last_fetch_timestamp
      rss.items.each do |item|
        result = {
          song:     {},
          artist:   {},
          datetime: nil,
          message:  ""
        }
        # {
        #   :title        => "John Legend \xE2\x80\x93 Do What I Gotta Do",
        #   :link         => "http://www.last.fm/music/John+Legend/_/Do+What+I+Gotta+Do",
        #   :description  => "http://www.last.fm/music/John+Legend",
        #   :pubDate      => 2014-07-23 23:34:14 +0100,
        #   :guid         => "http://www.last.fm/user/iamseawolf#1406154854"
        # }

        result[:song][:link] = item[:link]
        result[:song][:name] = URI.decode_www_form_component( item[:title] )
        result[:artist][:link] = item[:description]
        result[:artist][:name] = URI.decode_www_form_component( result[:artist][:link].sub(/^http\:\/\/www.last.fm\/music\//, '') )

        result[:datetime] = item[:pubDate]

        result[:message] = generate_content(
          result[:song][:name],   result[:song][:link],
          result[:artist][:name], result[:artist][:link],
        )

        @results << result
        # Pump::Activities::Listen.new(... , content)
      end
    end

    private

    def generate_content(song_name, song_link, artist_name, artist_link)
      prefix = "ben"
      prefix = "<a href=\"#{@pump_login.url}\">#{@pump_login.nickname}</a>" unless @pump_login.nil?
      return "#{prefix} listened to <a href=\"#{song_link}\">#{song_name}</a> by <a href=\"#{artist_link}\">#{artist_name}</a>"
    end

    def update_last_fetch_timestamp
      t = Time.now
      File.open('LASTFM_FETCHED.TXT', 'w') {|f| f.write( t.strftime("%s")) }
      puts "    · Last.FM feed last fetched: #{t}"
    end

    def last_fetch_timestamp
      begin
        content = File.read('LASTFM_FETCHED.TXT')
        timestamp = Time.at(content.to_i)
        puts "    · Last.FM feed last fetched: #{timestamp}"
        return timestamp
      rescue Errno::ENOENT
        return Time.at(0)
      end
    end
  end
end
