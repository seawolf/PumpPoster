require './lib/net/rss/lastfm.rb'
require './lib/pump/activities/listen.rb'
require './lib/pump/activities/train_journey.rb'

module Pump
  class Menu
    attr_reader :app

    def initialize(app)
      @app = app
      if @app.activity.nil?
        while true
          show_menu
          last_cmd = ask_for_input
          break if last_cmd == :quit
        end
      else
        run_activity(@app.activity)
      end
    end

    private

    def show_menu
      puts <<EOM

  · What have you done?
      [c]ycled a route
      [d]rank a beer
      [l]istened to a music track
      [t]ravelled by train
    or you can
      [q]uit
EOM
    end

    def ask_for_input
      print "=>  "
      command = gets
      case
        when command.match(/^q/) then
          puts "Bye!"
          return :quit
        when command.match(/^c/) then
          run_activity("cycle")
        when command.match(/^d/) then
          run_activity("drink")
        when command.match(/^l/) then
          run_activity("listen")
        when command.match(/^t/) then
          run_activity("train")
      end
    end

    def run_activity(cmd)
      case cmd
        when "cycle"
          puts "  · SportsTracker support coming soon!\n"
        when "drink"
          puts "  · Untappd/PerfectPint support coming soon!\n"
        when "listen"
          puts "  · LastFM selected.\n"
          Pump::Activities::Listen.new(@app.login,
            RSS::LastFm.new("iamseawolf", @app.login)
          ).submit!
        when "train"
          puts "  · RealTimeTrains selected.\n"
          Pump::Activities::TrainJourney.new(@app.login).submit!
      end
    end
  end
end
