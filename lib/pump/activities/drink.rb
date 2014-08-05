require './lib/net/communicator.rb'

require 'json'

module Pump
  module Activities
    class Drink
      attr_reader :login, :drinks, :count

      def initialize(login, data=nil)
        @login = login
        @drinks = data.results || []
        @count = @drinks.count
      end

      def submit!
        puts "  · Submitting #{@count} drinks..."
        return nil if @count == 0
        pp decorate_drinks(@drinks.first) if @count > 0
        # posted = post!( decorate_drinks(@drinks.first) )
        # check(posted)
        # delete!(posted)
      end

      private

      def post!(decorated_data)
        uri = URI.parse("#{@login.site}/api/user/#{@login.username}/feed")
        puts "  · Posting to: #{uri}"
        auth_hash = {
          consumer: @login.oauth,
          site: @login.site, request_uri: uri.to_s,
          key: @login.secret, token: OAuth::Token.new(@login.token, @login.secret)
        }
        response = Communicator.post(uri.to_s, 443, decorated_data, nil, auth_hash)
        if response.code.to_i == 200
          puts "  · Successful!"
          puts "    -> #{JSON.parse(response.body)["id"]}"
        else
          puts "  ! Unsuccessful: #{response.code}"
          puts response.body
        end
        return response
      end

      def check(response)
        activity = JSON.parse(response.body)
        object_type = activity['object']['objectType']
        object_id = activity['id']

        uri = URI.parse(object_id)
        auth_hash = {
          consumer: @login.oauth,
          site: @login.site, request_uri: uri.to_s,
          key: @login.secret, token: OAuth::Token.new(@login.token, @login.secret)
        }
        response = Communicator.get(uri.to_s, 443, nil, auth_hash)
        if response.code.to_i == 200
          puts "  · Successful!"
        else
          puts "  ! Unsuccessful: #{response.code}"
          puts response.body
        end
        return response
      end

      def delete!(response)
        activity = JSON.parse(response.body)
        object_type = activity['object']['objectType']
        object_id = activity['id']

        uri = URI.parse(object_id)
        puts "  · Deleting #{object_type} at: #{object_id}"

        auth_hash = {
          consumer: @login.oauth,
          site: @login.site, request_uri: uri.to_s,
          key: @login.secret, token: OAuth::Token.new(@login.token, @login.secret)
        }
        response = Communicator.delete(uri.to_s, 443, nil, auth_hash)
        if [200, 202, 204].include?(response.code.to_i)
          puts "  · Successful! (#{response.code})"
        else
          puts "  ! Unsuccessful: #{response.code}"
          puts response.body
        end
        return response
      end

      def decorate_drinks(drinks)
        data = {
          "actor" => {
            "objectType" => "person",
            "displayName" => @login.nickname,
            "url" => "#{@login.username}@#{@login.host}",
            "id" => "acct:#{@login.username}@#{@login.host}"
          },
          "verb" => "consume",

          # for multiple drinks, their objects should be wrapped in a
          # collection, with some metadata:
          #
          # "collection" => {
          #   "totalItems" => drinks.count,
          #   "items" => drinks.collect do |drink|
          #     decorate_drink(drink)
          #   end
          # },

          # for a single drink, the Object can be simply added in:
          "object" => decorate_drink(drinks)["object"],

          "to" => [
            {
              "objectType" => "collection",
              "id" => "http://activityschema.org/collection/public"
            }
          ],
          "cc" => [
            {
              "objectType" => "collection",
              "id" => @login.followers_url
            }
          ]
        }

        # TODO: how to handle a message for multiple drinks?
        data["content"] = drinks[:message] if drinks.is_a?(Hash)

        json = JSON.generate(data)
        return json
      end

      def decorate_drink(drink)
        data = {
          "object" => {
            "objectType" => "product",
            "displayName" => drink[:beer],
            "actor" => {
              "objectType" => "organization",
              "displayName" => drink[:brewery]
            }
          }
        }

        data["published"] = drink[:datetime].strftime("%Y-%m-%dT%H:%M:%S.%LZ") unless drink[:datetime].nil?

        return data
      end
    end
  end
end
