require './lib/net/communicator.rb'

require 'json'

module Pump
  class Client
    attr_reader :site, :host, :id, :secret, :expires_in, :oauth

    def initialize(site, secrets_json=nil)
      @site = site

      if secrets_json.nil?
        response = Communicator.post("#{@site}/api/client/register", 443, {
          type:             "client_associate",
          application_type: "native",
          application_name: Pump::Poster::NAME,
          contacts:         Pump::Poster::MAINTAINER,
          redirect_uris:    Pump::Poster::WEBSITE
        })
        secrets_json = JSON.parse(response.body)
        write_secrets(response.body)
      end

      set_from_json(secrets_json)
      set_host_from_site!
    end

    private

    def set_from_json(json)
      json.each do |key, value|
        key = key[7..-1] if (key[0..6] == "client_")
        instance_variable_set("@#{key.to_sym}", value)
      end
    end

    def set_host_from_site!
      @host = URI.parse(@site).host
    end

    def write_secrets(s)
      File.open('CLIENT_SECRETS.TXT', 'w') {|f| f.write(s) }
      puts "  · Secrets written."
    end
  end
end
