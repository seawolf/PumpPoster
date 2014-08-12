require './lib/util/datetime.rb'

require './lib/pump/client.rb'
require './lib/pump/login.rb'
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

    CLIENT_SECRETS  = "CLIENT_SECRETS.TXT"
    LOGIN_SECRETS   = "LOGIN_SECRETS.TXT"

    def initialize(options_hash)
      @activity = options_hash[:activity]

      if secrets_exist?
        client_tokens = JSON.parse(File.read(CLIENT_SECRETS))
        puts "    · Client tokens loaded."

        oauth_tokens = JSON.parse(File.read(LOGIN_SECRETS))
        puts "    · Login tokens loaded."

        site = oauth_tokens["site"]
        user = oauth_tokens["username"]
      else
        site = options_hash[:site]
        user = options_hash[:user]
        pass = options_hash[:pass]

        unless (site && user && pass)
          puts "  * You must supply a site, username and password. Try: #{__FILE__} --help"
          exit 65
        end
      end

      client = Pump::Client.new(site, client_tokens)
      @login = Pump::Login.new(client, site, user, pass, oauth_tokens)

      Pump::Menu.new(self)
    end

    private

    def secrets_exist?
      return File.exist?(CLIENT_SECRETS) && File.exist?(LOGIN_SECRETS)
    end
  end
end

def parse_opts
  options = {}
  OptionParser.new do |opts|
    opts.banner = "  · Usage: #{__FILE__} [options]"

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
