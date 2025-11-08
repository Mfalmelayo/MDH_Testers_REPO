#===============================================================================
# Adds new data class in GameData module for individual Adventure Map tiles.
#===============================================================================
module GameData
  class AdventureTile
    attr_reader :id            # Symbol ID of a map tile.
    attr_reader :real_name     # Display name of a map tile.
    attr_reader :description   # Description of a map tile.
    attr_reader :type          # String used to categorize a map tile into groups. (Landmark, Object, etc.)
    attr_reader :styles        # An array of [:RaidType] ID's that indicate which type of Raid Adventures this map tile may appear in.
    attr_reader :hidden        # Set to true to make these tiles invisible to the player. False by default.
    attr_reader :no_cursor     # When true, the map cursor will not react when highlighting this map tile.
    attr_reader :dark_mode     # 0 = Tile only appears on dark maps. 1 = Tile only appears on lit maps.
    attr_reader :partner       # An array of a trainer ID and name of a partner trainer used for a [:Character] tile.
    attr_reader :gender        # The gender index of a [:Character] tile (0 = Male, 1 = Female, 2 = Genderless).
    attr_reader :required      # The number of tiles of this type that a map requires. Set to -1 to make required in any amount.
    attr_reader :max_number    # The maximum number of tiles of this type that can appear on a map.
    attr_reader :variable      # A number used to randomize certain properties of a map tile.

    DATA = {}

    extend ClassMethodsSymbols
    include InstanceMethods

    def self.load; end
    def self.save; end
      
    def self.each_type(type)
      self.each { |s| yield s if s.type == type }
    end

    def initialize(hash)
      @id            = hash[:id]
      @real_name     = hash[:name]          || "Unnamed"
      @description   = hash[:description]   || "Unknown tile."
      @type          = hash[:type]          || "None"
      @styles        = hash[:styles]        || []
      @hidden        = hash[:hidden]
      @no_cursor     = hash[:no_cursor]
      @dark_mode     = hash[:dark_mode]
      @partner       = hash[:partner]
      @gender        = hash[:gender]
      @required      = hash[:required]
      @max_number    = hash[:max_number]
      @variable      = hash[:variable]
    end

    def name
      return _INTL(@real_name)
    end
    
    def description
      return _INTL(@description)
    end
  end
end

#===============================================================================
# Empty

GameData::AdventureTile.register({
  :id          => :Empty,
  :name        => _INTL("Empty"),
  :required    => -1,
  :no_cursor   => true
})

#===============================================================================
# Landmark

GameData::AdventureTile.register({
  :id          => :Pathway,
  :name        => _INTL("Pathway"),
  :type        => _INTL("Landmark"),
  :no_cursor   => true,
  :required    => -1
})

GameData::AdventureTile.register({
  :id          => :StartPoint,
  :name        => _INTL("Start Point"),
  :description => _INTL("This will always be the first tile you move towards."),
  :type        => _INTL("Landmark"),
  :required    => 1
})

GameData::AdventureTile.register({
  :id          => :Battle,
  :name        => _INTL("Battle"),
  :description => _INTL("Passing over this tile will initiate a raid battle against a wild Pokémon."),
  :type        => _INTL("Landmark"),
  :required    => 11
})

GameData::AdventureTile.register({
  :id          => :Crossroad,
  :name        => _INTL("Crossroad"),
  :description => _INTL("Landing on this tile will allow you to choose a new path to travel in."),
  :type        => _INTL("Landmark")
})

#===============================================================================
# Directional

GameData::AdventureTile.register({
  :id          => :TurnNorth,
  :name        => _INTL("Turn North"),
  :description => _INTL("Passing over this tile will force you to turn north."),
  :type        => _INTL("Directional")
})

GameData::AdventureTile.register({
  :id          => :TurnSouth,
  :name        => _INTL("Turn South"),
  :description => _INTL("Passing over this tile will force you to turn south."),
  :type        => _INTL("Directional")
})

GameData::AdventureTile.register({
  :id          => :TurnWest,
  :name        => _INTL("Turn West"),
  :description => _INTL("Passing over this tile will force you to turn west."),
  :type        => _INTL("Directional")
})

GameData::AdventureTile.register({
  :id          => :TurnEast,
  :name        => _INTL("Turn East"),
  :description => _INTL("Passing over this tile will force you to turn east."),
  :type        => _INTL("Directional")
})

GameData::AdventureTile.register({
  :id          => :RandomTurn,
  :name        => _INTL("Random Turn"),
  :description => _INTL("Passing over this tile may force you to turn in a random direction."),
  :type        => _INTL("Directional")
})

GameData::AdventureTile.register({
  :id          => :ReverseTurn,
  :name        => _INTL("Reverse Turn"),
  :description => _INTL("Landing on this tile will force you to turn in the opposite direction."),
  :type        => _INTL("Directional")
})

#===============================================================================
# Object

GameData::AdventureTile.register({
  :id          => :Door,
  :name        => _INTL("Door"),
  :description => _INTL("Prevents movement on this path unless a key is consumed to unlock it."),
  :type        => _INTL("Object")
})

GameData::AdventureTile.register({
  :id          => :Switch,
  :name        => _INTL("Switch"),
  :description => _INTL("Passing over this tile will flip the switch, which may reveal or hide other tiles."),
  :type        => _INTL("Object")
})

GameData::AdventureTile.register({
  :id          => :Warp,
  :name        => _INTL("Warp"),
  :description => _INTL("Landing on this tile will transport you to another warp tile elsewhere on the map."),
  :type        => _INTL("Object")
})

GameData::AdventureTile.register({
  :id          => :Portal,
  :name        => _INTL("Portal"),
  :description => _INTL("Landing on this tile will teleport you back to the beginning of this map."),
  :type        => _INTL("Object")
})

GameData::AdventureTile.register({
  :id          => :Teleporter,
  :name        => _INTL("Teleporter"),
  :description => _INTL("Stepping on this tile will enable you to return to a previously visited crossroad tile."),
  :type        => _INTL("Object"),
  :dark_mode   => 1
})

GameData::AdventureTile.register({
  :id          => :Roadblock,
  :name        => _INTL("Roadblock"),
  :description => _INTL("An obstacle prevents movement on this path unless you have a Pokémon that can bypass it."),
  :type        => _INTL("Object"),
  :variable    => 12
})

GameData::AdventureTile.register({
  :id          => :HiddenTrap,
  :name        => _INTL("Hidden Trap"),
  :description => _INTL("Passing over this tile may spring a trap that may harm the Pokémon in your party."),
  :type        => _INTL("Object"),
  :hidden      => true
})

#===============================================================================
# Collectable

GameData::AdventureTile.register({
  :id          => :Berries,
  :name        => _INTL("Berries"),
  :description => _INTL("Collecting berries will restore some HP of all Pokémon in the party."),
  :type        => _INTL("Collectable")
})

GameData::AdventureTile.register({
  :id          => :Flare,
  :name        => _INTL("Flare"),
  :description => _INTL("Collecting flares will increase your visibility."),
  :type        => _INTL("Collectable"),
  :dark_mode   => 0
})

GameData::AdventureTile.register({
  :id          => :Key,
  :name        => _INTL("Key"),
  :description => _INTL("Collecting keys may allow you to unlock door and chest tiles on the map."),
  :type        => _INTL("Collectable")
})

GameData::AdventureTile.register({
  :id          => :Chest,
  :name        => _INTL("Chest"),
  :description => _INTL("You may collect the contents hidden in this chest if a key is consumed to unlock it."),
  :type        => _INTL("Collectable")
})

#===============================================================================
# Character

GameData::AdventureTile.register({
  :id          => :Assistant,
  :name        => _INTL("Assistant"),
  :description => _INTL("Offers you new Pokémon in exchange for a current party member."),
  :type        => _INTL("Character"),
  :gender      => 0
})

GameData::AdventureTile.register({
  :id          => :ItemVendor,
  :name        => _INTL("Item Vendor"),
  :description => _INTL("Offers your party Pokémon items that may be given to hold."),
  :type        => _INTL("Character"),
  :styles      => [:Basic, :Max, :Tera],
  :gender      => 0
})

GameData::AdventureTile.register({
  :id          => :StatTrainer,
  :name        => _INTL("Stat Trainer"),
  :description => _INTL("Offers your party Pokémon special training to alter their stats."),
  :type        => _INTL("Character"),
  :gender      => 0
})

GameData::AdventureTile.register({
  :id          => :MoveTutor,
  :name        => _INTL("Move Tutor"),
  :description => _INTL("Offers your party Pokémon tutoring to teach them different moves."),
  :type        => _INTL("Character"),
  :gender      => 1
})

GameData::AdventureTile.register({
  :id          => :Nurse,
  :name        => _INTL("Nurse"),
  :description => _INTL("Fully restores the HP/PP and status of your party Pokémon."),
  :type        => _INTL("Character"),
  :gender      => 1
})

GameData::AdventureTile.register({
  :id          => :Mystic,
  :name        => _INTL("Mystic"),
  :description => _INTL("Cleanses your weary spirit to fully replenish your heart count."),
  :type        => _INTL("Character"),
  :gender      => 1
})

GameData::AdventureTile.register({
  :id          => :MysteryNPC,
  :name        => _INTL("Mystery NPC"),
  :description => _INTL("An unknown person awaits you on this tile. Who could it be?"),
  :type        => _INTL("Character")
})

GameData::AdventureTile.register({
  :id          => :Researcher,
  :name        => _INTL("Researcher"),
  :description => _INTL("Offers to change certain attributes on your party Pokémon depending on the lair style."),
  :type        => _INTL("Character"),
  :styles      => [:Ultra, :Max, :Tera],
  :gender      => 0
})

GameData::AdventureTile.register({
  :id          => :PartnerA,
  :name        => _INTL("Partner Brendan"),
  :description => _INTL("Offers to tag along with you and join forces in battle."),
  :type        => _INTL("Character"),
  :partner     => [:POKEMONTRAINER_Brendan, "Brendan"],
  :max_number  => 1
})

GameData::AdventureTile.register({
  :id          => :PartnerB,
  :name        => _INTL("Partner May"),
  :description => _INTL("Offers to tag along with you and join forces in battle."),
  :type        => _INTL("Character"),
  :partner     => [:POKEMONTRAINER_May, "May"],
  :max_number  => 1
})