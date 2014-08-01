module Pump
  class Menu
    attr_reader :app

    def initialize(app)
      @app = app
      while true
        show_menu
        last_cmd = ask_for_input
        break if last_cmd == :quit
      end
    end

    def show_menu
      puts <<EOM

  · What have you done?
      [c]ycled a route
      [d]rank a beer
      [l]istened to a music track
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
          puts "  · SportsTracker support coming soon!\n"
        when command.match(/^d/) then
          puts "  · Untappd/PerfectPint support coming soon!\n"
        when command.match(/^l/) then
          puts "  · LastFM selected.\n"
          Pump::Activities::Listen.new(app.login,
            RSS::LastFm.new("iamseawolf", app.login)
          ).submit!
      end
    end
  end
end
