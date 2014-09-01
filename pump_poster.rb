#  PumpPoster  ·  http://code.seawolfsanctuary.com/pumpposter
#
#  Copyright (C) 2014 the seawolfsanctuary
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
    VERSION     = "1.0.0"
    YEAR        = Time.now.year
    MAINTAINER  = "webmaster@seawolfsanctuary.com"
    COMPANY     = "the seawolfsanctuary"
    WEBSITE     = "http://code.seawolfsanctuary.com/pumpposter"

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

        site, user, pass = ensure_credentials(site, user, pass)
      end

      client = Pump::Client.new(site, client_tokens)
      @login = Pump::Login.new(client, site, user, pass, oauth_tokens)

      Pump::Menu.new(self)
    end

    private

    def secrets_exist?
      return File.exist?(CLIENT_SECRETS) && File.exist?(LOGIN_SECRETS)
    end

    def ensure_credentials(site, user, pass)
      while site.to_s.strip.length == 0
        print "    > Enter your Pump.io server URL (e.g. https://mysite.com): "
        site = gets.strip
      end

      while user.to_s.strip.length == 0
        print "    > Enter your username on #{site}: "
        user = gets.strip
      end

      while pass.to_s.strip.length == 0
        print "    > Enter the password for #{user} on #{site}: "
        pass = gets.strip
      end

      unless (site.to_s.length && user.to_s.length && pass.to_s.length)
        puts "  * You must supply a site, username and password. Try: #{__FILE__} --help"
        exit 65
      end

      return [site, user, pass]
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
puts <<LICENSE_NOTICE
    #{Pump::Poster::NAME}  ·  Copyright (C) #{Pump::Poster::YEAR}  ·  #{Pump::Poster::COMPANY}
    This is free software, and you are welcome to redistribute it
    under certain conditions. This software comes with ABSOLUTELY
    NO WARRANTY. See the LICENSE file for details.

LICENSE_NOTICE

app = Pump::Poster.new(parse_opts)
