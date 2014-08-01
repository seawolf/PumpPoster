require './lib/pump/client.rb'
require './lib/pump/login.rb'
require './lib/net/rss/lastfm.rb'
require './lib/pump/activities/listen.rb'
require './lib/pump/menu.rb'

require 'optparse'
require 'json'

module Pump
  class Poster
    attr_reader :login, :activity

    NAME        = "PumpPoster"
    VERSION     = "0.1"
    MAINTAINER  = "webmaster@seawolfsanctuary.com"
    WEBSITE     = "https://seawolfsanctuary.com/"

    def initialize(options_hash)
      site = options_hash[:site]
      user = options_hash[:user]
      pass = options_hash[:pass]
      @activity = options_hash[:activity]

      begin
        client_tokens = JSON.parse(File.read('CLIENT_SECRETS.TXT'))
        puts "    · Client tokens loaded."
      rescue Errno::ENOENT
      end
      client = Pump::Client.new(site, client_tokens)

      begin
        oauth_tokens = JSON.parse(File.read('LOGIN_SECRETS.TXT'))
        puts "    · Login tokens loaded."
      rescue Errno::ENOENT
      end
      @login = Pump::Login.new(client, site, user, pass, oauth_tokens)
    end
  end
end

def parse_opts
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{__FILE__} [options]"

    opts.on('-s', '--site URL', 'Full URL of the Pump.io site, e.g. https://identi.ca') do |s|
      s.chomp!("/") if s[-1] == "/"
      options[:site] = s
    end

    opts.on('-u', '--user USERNAME', 'Username for your account') do |u|
      options[:user] = u
    end

    opts.on('-p', '--pass PASSWORD', 'Password for your account') do |p|
      options[:pass] = p
    end

    opts.on('-a', '--activity NAME', 'Run an activity') do |a|
      options[:activity] = a
    end

    opts.on('-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end.parse!

  return options
end

puts "  · Loaded PumpPoster v#{Pump::Poster::VERSION}"
app = Pump::Poster.new(parse_opts)

Pump::Menu.new(app)
