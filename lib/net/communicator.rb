require 'net/https'
require 'uri'

class Communicator
  def self.post (raw_uri, port, data, cookie=nil, auth_hash=nil)
    uri = URI.parse(raw_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = http.open_timeout = 10
    http.use_ssl = (port == 443)

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Accept-Language'] = "en-gb,en;q=0.5"
    request['Cookie'] = cookie unless cookie.nil?

    if auth_hash.is_a?(Hash) && !auth_hash.keys.empty?
      request["Authorization"] = OAuth::Client::Helper.new(request, auth_hash).header
    end

    if data.is_a?(Hash)
      request.set_form_data(data)
    elsif data.is_a?(String)  # JSON
      request['Content-Type'] = 'application/json'
      request.body = data
    end

    puts "    > POST to #{uri.request_uri}"
    return http.request(request)
  end

  def self.delete (raw_uri, port, cookie=nil, auth_hash=nil)
    uri = URI.parse(raw_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = http.open_timeout = 10
    http.use_ssl = (port == 443)

    request = Net::HTTP::Delete.new(uri.request_uri)
    request['Accept-Language'] = "en-gb,en;q=0.5"
    request['Cookie'] = cookie unless cookie.nil?

    if auth_hash.is_a?(Hash) && !auth_hash.keys.empty?
      request["Authorization"] = OAuth::Client::Helper.new(request, auth_hash).header
    end

    puts "    > DELETE to #{uri.request_uri}"
    return http.request(request)
  end

  def self.get (raw_uri, port, cookie=nil, auth_hash=nil)
    uri = URI.parse(raw_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = http.open_timeout = 10
    http.use_ssl = (port == 443)

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept-Language'] = "en-gb,en;q=0.5"
    request['Cookie'] = cookie unless cookie.nil?

    if auth_hash.is_a?(Hash) && !auth_hash.keys.empty?
      request["Authorization"] = OAuth::Client::Helper.new(request, auth_hash).header
    end

    puts "    > GET to #{uri.request_uri}#{" with auth hash" unless request['Authorization'].nil?}"
    return http.request(request)
  end
end
