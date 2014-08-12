require 'net/https'
require 'uri'
require 'date'

require './lib/net/communicator.rb'

module Scraper
  class Untappd
    attr_reader :username, :pump_login, :results

    FEED_LIMIT = 10
    FEED_CACHE = 5 * 60 # minutes
    BASE_URI = "https://untappd.com"

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

      parse_page(page).each do |checkin|
        if checkin[:datetime].strftime("%s").to_i > epoch.to_i
          @results << checkin
        end
      end
    end

    private

    def profile_url
      "#{BASE_URI}/user/#{username}"
    end

    def download_page
      page = Communicator.get(profile_url, 443)
      if page.code.to_i == 200
        update_last_fetch_timestamp
        return Hpricot(page.body)
      end
      return nil
    end

    def parse_page(page_string)
      checkins = []
      (page_string/"div.checkin").each do |e|
        link = find_checkin_link(e)
        user, beer, brewery, venue = find_checkin_text(e)
        datetime = find_checkin_datetime(e)

        checkins << {
          link:     link,
          beer:     beer,
          brewery:  brewery,
          datetime: datetime,
          message:  generate_content(link, beer, brewery)
        }
      end
      return checkins
    end

    def find_checkin_link(element)
      return element.search("div.feedback div.bottom a").collect {|ele|
        link = (ele).attributes["href"]
        link =~ /\/checkin\// ? "#{BASE_URI}#{link}" : ""
      }.reject(&:empty?).first
    end

    def find_checkin_text(element)
      # <a href="/user/seawolf" class="user">ben</a>
      # is drinking a
      # <a href="/b/gold-tatton-brewery/62816">Gold</a>
      # by
      # <a href="/brewery/8395">Tatton Brewery</a>
      # at
      # <a href="/venue/134294">The Lion Tavern</a>
      return (element/"p.text a").collect(&:inner_html).map(&:strip)
    end

    def find_checkin_datetime(element)
      str = (element/"div.feedback a.time").collect(&:inner_html).first
      return Pump::Util::DateTime.from_utc(str)
    end

    def generate_content(checkin_url, beer_name, brewery_name)
      prefix = "ben"
      prefix = "<a href=\"#{@pump_login.url}\">#{@pump_login.nickname}</a>" unless @pump_login.nil?
      return "#{prefix} drank a <a href=\"#{checkin_url}\">#{beer_name}</a> by #{brewery_name}"
    end

    def update_last_fetch_timestamp
      t = Time.now
      File.open('UNTAPPD_FETCHED.TXT', 'w') {|f| f.write( t.strftime("%s")) }
      puts "  · Untappd feed updated: #{t}"
    end

    def last_fetch_timestamp
      begin
        content = File.read('UNTAPPD_FETCHED.TXT')
        timestamp = Time.at(content.to_i)
        puts "  · Untappd feed last fetched: #{timestamp}"
        return timestamp
      rescue Errno::ENOENT
        return Time.at(0)
      end
    end
  end
end

