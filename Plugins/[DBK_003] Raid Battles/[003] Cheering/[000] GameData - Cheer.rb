#===============================================================================
# Game data for cheers.
#===============================================================================
module GameData
  class Cheer
    attr_reader :id
    attr_reader :real_name
	attr_reader :icon_position
    attr_reader :command_index
    attr_reader :mode
    attr_reader :cheer_text
	attr_reader :description

    DATA = {}
    
    extend ClassMethodsSymbols
    include InstanceMethods

    def self.load; end
    def self.save; end

    def initialize(hash)
      @id            = hash[:id]
      @real_name     = hash[:name]          || "Unnamed"
	  @icon_position = hash[:icon_position] || 0
	  @command_index = hash[:command_index] || -1
      @mode          = hash[:mode]          || 0
      @cheer_text    = hash[:cheer_text]    || ""
	  @description   = hash[:description]
    end

    def name;        return _INTL(@real_name);   end
    def cheer_text;  return _INTL(@cheer_text);  end
	
	def description(level)
	  return _INTL("") if !@description
	  return @description[level]
	end
    
    def self.get_cheer_for_index(index, mode = 0)
      cheer = self.get(:None)
	  self.each do |c|
        next if c.command_index != index
        cheer = c if c.mode == 0
		if c.mode == mode
		  cheer = c
		  break
		end
      end
      return cheer
    end
  end
end

#===============================================================================

GameData::Cheer.register({
  :id            => :None,
  :name          => _INTL("None")
})

GameData::Cheer.register({
  :id            => :Offense,
  :name          => _INTL("Offense Cheer"),
  :icon_position => 1,
  :command_index => 0,
  :cheer_text    => _INTL("Go all-out!"),
  :description   => [_INTL("Requires Cheer Lv.1 or higher."),
                     _INTL("The team deals more damage with moves."),
					 _INTL("Increases potency of the team's moves."),
					 _INTL("The team's moves may pierce protections.")]
})

GameData::Cheer.register({
  :id            => :Defense,
  :name          => _INTL("Defense Cheer"),
  :icon_position => 2,
  :command_index => 1,
  :cheer_text    => _INTL("Hang tough!"),
  :description   => [_INTL("Requires Cheer Lv.1 or higher."),
                     _INTL("The team takes less damage from moves."),
					 _INTL("The team is immune to move effects."),
					 _INTL("The team endures damage from moves.")]
})

GameData::Cheer.register({
  :id            => :Healing,
  :name          => _INTL("Healing Cheer"),
  :icon_position => 3,
  :command_index => 2,
  :cheer_text    => _INTL("Heal up!"),
  :description   => [_INTL("Requires Cheer Lv.1 or higher."),
                     _INTL("Heals some of the team's HP."),
					 _INTL("Heals the team's HP & cures status."),
					 _INTL("Grants the team a wish & fully heals.")]
})

GameData::Cheer.register({
  :id            => :Counter,
  :name          => _INTL("Counter Cheer"),
  :icon_position => 4,
  :command_index => 3,
  :cheer_text    => _INTL("Turn the tables!"),
  :description   => [_INTL("Requires Cheer Lv.1 or higher."),
                     _INTL("Reverses stat changes of both teams."),
					 _INTL("Swaps the field effects on both sides."),
					 _INTL("Removes and applies Heal Block to teams.")]
})

GameData::Cheer.register({
  :id            => :BasicRaid,
  :name          => _INTL("Basic Raid Cheer"),
  :icon_position => 5,
  :command_index => 3,
  :mode          => 1,
  :cheer_text    => _INTL("Keep it going!"),
  :description   => [_INTL("Requires Cheer Lv.2 or higher."),
                     _INTL("Requires Cheer Lv.2 or higher."),
					 _INTL("Extends the raid turn counter."),
					 _INTL("Extends the raid turn & KO counters.")]
})

GameData::Cheer.register({
  :id            => :UltraRaid,
  :name          => _INTL("Ultra Raid Cheer"),
  :icon_position => 6,
  :command_index => 3,
  :mode          => 2,
  :cheer_text    => _INTL("Let's use Z-Power!"),
  :description   => [_INTL("Requires Cheer Lv.MAX."),
                     _INTL("Requires Cheer Lv.MAX."),
					 _INTL("Requires Cheer Lv.MAX."),
					 _INTL("Allows you to use a Z-Move.")]
})

GameData::Cheer.register({
  :id            => :MaxRaid,
  :name          => _INTL("Max Raid Cheer"),
  :icon_position => 7,
  :command_index => 3,
  :mode          => 3,
  :cheer_text    => _INTL("Let's Dynamax!"),
  :description   => [_INTL("Requires Cheer Lv.MAX."),
                     _INTL("Requires Cheer Lv.MAX."),
					 _INTL("Requires Cheer Lv.MAX."),
					 _INTL("Allows you to use Dynamax.")]
})

GameData::Cheer.register({
  :id            => :TeraRaid,
  :name          => _INTL("Tera Raid Cheer"),
  :icon_position => 8,
  :command_index => 3,
  :mode          => 4,
  :cheer_text    => _INTL("Let's Terastallize!"),
  :description   => [_INTL("Requires Cheer Lv.MAX."),
                     _INTL("Requires Cheer Lv.MAX."),
					 _INTL("Requires Cheer Lv.MAX."),
					 _INTL("Allows you to use Terastallization.")]
})