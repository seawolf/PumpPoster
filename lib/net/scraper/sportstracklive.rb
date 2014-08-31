require 'net/https'
require 'uri'
require 'date'

require './lib/net/communicator.rb'

module Scraper
  class Sportstracklive
    attr_reader :username, :pump_login, :results

    FEED_LIMIT = 10
    FEED_CACHE = 30 * 60 # minutes
    BASE_URI = "http://www.sportstracklive.com"

    def initialize(username, pump_login=nil)
      @username = username
      @pump_login = pump_login
      @results = []
      epoch = last_fetch_timestamp
      go(epoch) unless epoch > Time.now - FEED_CACHE
    end

    def go(epoch)
      page = download_page
      return nil if page.nil?

      parse_page(page).each do |track|
        if track[:datetime].strftime("%s").to_i > epoch.to_i
          @results << track
        end
      end
    end

    private

    def profile_url
      "#{BASE_URI}/search?what=user:#{username}&find=track&order=finish"
    end

    def download_page
      page = Communicator.get(profile_url, 80)
      if page.code.to_i == 200
        update_last_fetch_timestamp
        return Hpricot(page.body)
      end
      return nil
    end

    def parse_page(page_string)
      tracks = []
      (page_string/"table.searchresult tr")[1..-1].each_with_index do |e, i|
        next unless (i % 3 == 0)
        puts

        link      = find_track_link(e)
        distance  = find_track_text(e)
        datetime  = find_track_datetime(e)

        tracks << {
          link:     link,
          datetime: datetime,
          message:  generate_content(link, distance)
        }
      end
      return tracks
    end

    def find_track_link(element)
      return element.search("a[@title='Info']").collect {|ele|
        link = (ele).attributes["href"]
        link =~ /\/track\/detail\// ? "#{BASE_URI}#{link}" : ""
      }.reject(&:empty?).first
    end

    def find_track_text(element)
      return (element/"div")[-9].inner_html.strip
    end

    def find_track_datetime(element)
      data = (element/"div")[0..-2]

      date = data[-1].inner_html.strip
      time = (data[-2]/"a").first.inner_html.strip
      dt   = "#{date} #{time}"

      return Pump::Util::DateTime.to_utc(dt)
    end

    def generate_content(track_url, distance)
      prefix = "ben"
      prefix = "<a href=\"#{@pump_login.url}\">#{@pump_login.nickname}</a>" unless @pump_login.nil?
      return "#{prefix} cycled <a href=\"#{track_url}\">#{distance}</a>"
    end

    def update_last_fetch_timestamp
      t = Time.now
      File.open('STL_FETCHED.TXT', 'w') {|f| f.write( t.strftime("%s")) }
      puts "  · SportsTrackLive feed updated: #{t}"
    end

    def last_fetch_timestamp
      begin
        content = File.read('STL_FETCHED.TXT')
        timestamp = Time.at(content.to_i)
        puts "  · SportsTrackLive feed last fetched: #{timestamp}"
        return timestamp
      rescue Errno::ENOENT
        return Time.at(0)
      end
    end
  end
end
