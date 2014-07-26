require './lib/net/communicator.rb'
require './lib/pump/client.rb'

require 'hpricot'
require 'oauth'
require 'oauth/request_proxy/net_http'
require 'json'

module Pump
  class Login
    attr_reader :client, :username, :password, :site, :host, :token, :secret, :oauth, :nickname, :url, :followers_url

    def initialize(client, site, username, password, secrets_json=nil)
      @client = client
      @username = username
      @password = password
      @site = site
      set_host_from_site!

      if secrets_json.nil?
        fetch_secrets
        fetch_user_details

        write_secrets(JSON.generate({
          username: @username, site: @site,
          token: @token, secret: @secret,
          nickname: @nickname, url: @url, followers_url: @followers_url
        }))
      else
        set_from_json(secrets_json)
      end
    end

    private

    def set_host_from_site!
      @host = URI.parse(@site).host
    end

    def set_oauth_consumer
      @oauth = OAuth::Consumer.new( @client.id, @client.secret, { site: @site } )
    end

    def set_from_json(json)
      json.each do |key, value|
        instance_variable_set("@#{key.to_sym}", value)
      end
      set_host_from_site!
      set_oauth_consumer
    end

    def fetch_secrets
      set_oauth_consumer

      puts "  · Fetching request token..."
      request_token = @oauth.get_request_token
      puts "  · Obtaining authorisation verifier..."
      response = Communicator.get(request_token.authorize_url, 443)
      cookie_from_response(response)

      response = login_to_site(response) if login_required?(response)
      response = authorise_client_by_user(response) if authorisation_required?(response)

      verify_client_authorisation(response, request_token)
    end

    def login_required?(response)
      doc = Hpricot(response.body)
      login_form = (doc/"form#oauth-authentication").inner_html
      return login_form.length > 0
    end

    def login_to_site(response)
      puts "  · Logging in to #{@site} as #{@username}..."
      doc = Hpricot(response.body)
      form = (doc/"form#oauth-authentication")
      oauth_element = (form/"input").first
      params = {
        "oauth_token" => oauth_element['value'],
        "username" => @username,
        "password" => @password,
        "authenticate" => "Login"
      }
      response = Communicator.post("#{@site}/oauth/authorize", 443, params, "connect.sic=#{@session_id}")
      cookie_from_response(response)
      return response
    end

    def authorisation_required?(response)
      doc = Hpricot(response.body)
      auth_form = (doc/"form#authorize")
      return auth_form.length > 0
    end

    def authorise_client_by_user(response)
      puts "  · Logged in to #{@site} as #{@username}, authorising application..."
      doc = Hpricot(response.body)
      form = (doc/"form#authorize")

      oauth_token = (form/"input#oauth_token").first
      verifier_element = (form/"input#verifier").first
      authorize_element = (form/"input#authorize").first
      params = {
        "oauth_token" => oauth_token['value'],
        "verifier" =>  verifier_element['value'],
        "authorize" => authorize_element['value']
      }
      response = Communicator.post("#{@site}/oauth/authorize", 443, params, "connect.sic=#{@session_id}")
      cookie_from_response(response)
      return response
    end

    def verify_client_authorisation(response, request_token)
      puts "  · Application authorised for #{@username} at #{@site}, fetching keys..."
      doc = Hpricot(response.body)
      verifier = (doc/"td#verifier").inner_html
      raise ArgumentError.new("Unable to obtain verifier token") unless verifier.length > 0
      puts "    · Request (authoriser) token found"

      access_token = request_token.get_access_token(oauth_verifier: verifier)
      @token = access_token.token
      @secret = access_token.secret
      puts "    · Obtained Oauth tokens, success!"
      return true
    end

    def write_secrets(s)
      File.open('LOGIN_SECRETS.TXT', 'w') {|f| f.write(s) }
      puts "  ·  OAuth tokens stored."
    end

    def cookie_from_response(r)
      cookie = r.header['Set-Cookie']
      return nil unless cookie
      if cookie_sid = cookie.match(/connect.sid=([^;]*);/)
        if sid_found = cookie_sid[1]
          @session_id = sid_found
          puts "    · HTTP Session set."
        else
          puts "    ! Unable to set HTTP Session!"
        end
      end
    end

    def fetch_user_details
      uri = URI.parse("https://#{@host}/api/whoami")
      auth_hash = {
        consumer: @oauth,
        site: @site, request_uri: uri.to_s,
        key: @secret, token: OAuth::Token.new(@token, @secret)
      }
      whoami = Communicator.get(uri.to_s, 443, nil, auth_hash)
      puts "  · initialisation and self-check for #{@username}@#{@host} complete." if redirected_to_own_profile?(whoami)

      uri = URI.parse(whoami.header['Location'])
      auth_hash = {
        consumer: @oauth,
        site: @site, request_uri: uri.to_s,
        key: @secret, token: OAuth::Token.new(@token, @secret)
      }
      profile = Communicator.get(uri.to_s, 443, nil, auth_hash)
      parse_user_details(profile.body)
    end

    def redirected_to_own_profile?(http_resp)
      http_resp.header['Location'] == "#{@site}/api/user/#{@username}/profile"
    end

    def parse_user_details(j)
      profile = JSON.parse(j)
      @nickname = profile["displayName"]
      @url = profile["url"]
      @followers_url = profile["followers"]["url"]
    end
  end
end
