require './lib/net/communicator.rb'

require 'json'

module Pump
  class Activity
    attr_reader :data, :json

    def initialize(login, verb, obj, isCollection=false)
      @data = {
        "actor" => {
          "objectType" => "person",
          "displayName" => login.nickname,
          "url" => "#{login.username}@#{login.host}",
          "id" => "acct:#{login.username}@#{login.host}"
        },
        "verb" => verb,

        "to" => [
          {
            "objectType" => "collection",
            "id" => "http://activityschema.org/collection/public"
          }
        ],
        "cc" => [
          {
            "objectType" => "collection",
            "id" => login.followers_url
          }
        ]
      }
      @data["object"]    = obj["object"]
      @data["published"] = obj["published"] unless obj["published"].nil?

      # TODO: how to handle a message for multiple tracks?
      @data["content"] = obj["content"] if obj.is_a?(Hash)

      @json = JSON.generate(data)
    end
  end
end

