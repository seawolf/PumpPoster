require './lib/net/communicator.rb'

require 'json'

module Pump
  module Activities
    class Listen
      attr_reader :login, :tracks, :count

      def initialize(login, data=nil)
        @login = login
        @tracks = data.results || []
        @count = @tracks.count
      end

      def submit!
        puts "  · Submitting #{@count} tracks..."
        return nil if @count == 0
        activity = Pump::Activity.new(@login, "listen", decorate_track(@tracks.first), false).json
        puts activity
        # posted = post!(activity)
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

      def decorate_track(track)
        data = {
          "object" => {
            "objectType" => "audio",
            "displayName" => track[:song][:name],
            "links" => {
              "canonical" => {
                "href" => track[:song][:link]
              },
            },
            "actor" => {
              "objectType" => "person",
              "displayName" => track[:artist][:name],
              "links" => {
                "canonical" => {
                  "href" => track[:artist][:link]
                }
              }
            }
          }
        }

        data["content"] = track[:message] if track.is_a?(Hash)
        data["published"] = Pump::Util::DateTime.json_datetime(track[:datetime]) unless track[:datetime].nil?

        return data
      end
    end
  end
end
