#===============================================================================
# Game data for raid types.
#===============================================================================
module GameData
  class RaidType
    attr_reader :id
    attr_reader :real_name
	attr_reader :den_name
	attr_reader :den_sprite
	attr_reader :den_size
	attr_reader :lair_name
	attr_reader :lair_bgm
	attr_reader :battle_bg
	attr_reader :battle_base
	attr_reader :battle_environ
	attr_reader :battle_text
	attr_reader :battle_flee
	attr_reader :battle_bgm
	attr_reader :capture_bgm
	attr_reader :available
	
	RAID_DEN_SUFFIX = "RaidDen"

    DATA = {}

    extend ClassMethodsSymbols
    include InstanceMethods

    def self.load; end
    def self.save; end
	
	def self.each_available
      self.each { |s| yield s if s.available }
    end

    def initialize(hash)
      @id             = hash[:id]
      @real_name      = hash[:name]           || "Unnamed"
	  @den_name       = hash[:den_name]       || "Unnamed"
	  @den_sprite     = hash[:den_sprite]     || "Unnamed"
	  @den_size       = hash[:den_size]       || 1
	  @lair_name      = hash[:lair_name]      || "Unnamed"
	  @lair_bgm       = hash[:lair_bgm]
	  @battle_environ = hash[:battle_environ] || :Cave
	  @battle_bg      = hash[:battle_bg]
	  @battle_base    = hash[:battle_base]
	  @battle_text    = hash[:battle_text]    || "{1} appeared!"
	  @battle_flee    = hash[:battle_flee]    || "{1} fled!"
	  @battle_bgm     = hash[:battle_bgm]     || []
	  @capture_bgm    = hash[:capture_bgm]
	  @available      = hash[:available]
    end
	
	def name
      return _INTL(@real_name)
    end

    def event_name
      return _INTL("{1}{2}", @real_name, RAID_DEN_SUFFIX)
    end
  end
end

#===============================================================================

GameData::RaidType.register({
  :id             => :Online,
  :name           => _INTL("Online"),
  :available      => false
})

GameData::RaidType.register({
  :id             => :Basic,
  :name           => "Basic",
  :den_name       => _INTL("Raid Den"),
  :den_sprite     => "Object den (Basic)",
  :den_size       => 3,
  :lair_name      => _INTL("Raid Adventure"),
  :lair_bgm       => "Raid (Basic) adventure",
  :battle_bg      => "cave3",
  :battle_base    => "cave3",
  :battle_text    => _INTL("{1} emerged from within the den!"),
  :battle_flee    => _INTL("{1} disappeared somewhere into the den..."),
  :battle_bgm     => ["Raid (Basic) battle v1", "Raid (Basic) battle v2"],
  :capture_bgm    => "Raid (Basic) capture",
  :available      => true
})

GameData::RaidType.register({
  :id             => :Ultra,
  :name           => "Ultra",
  :den_name       => _INTL("Ultra Raid Wormhole"),
  :den_sprite     => "Object den (Ultra)",
  :den_size       => 3,
  :lair_name      => _INTL("Ultra Adventure"),
  :lair_bgm       => "Raid (Ultra) adventure",
  :battle_bg      => "raid_ultra",
  :battle_base    => "raid_ultra",
  :battle_environ => :UltraSpace,
  :battle_text    => _INTL("{1} emerged from the wormhole!"),
  :battle_flee    => _INTL("{1} disappeared through the wormhole..."),
  :battle_bgm     => ["Raid (Ultra) battle v1", "Raid (Ultra) battle v2", "Raid (Ultra) battle v3"],
  :capture_bgm    => "Raid (Ultra) capture",
  :available      => PluginManager.installed?("[DBK] Z-Power")
})

GameData::RaidType.register({
  :id             => :Max,
  :name        	  => "Max",
  :den_name    	  => _INTL("Max Raid Den"),
  :den_sprite     => "Object den (Max)",
  :den_size       => 2,
  :lair_name      => _INTL("Dynamax Adventure"),
  :lair_bgm       => "Raid (Max) adventure",
  :battle_bg      => "raid_max",
  :battle_base    => "raid_max",
  :battle_text    => _INTL("A Dynamaxed {1} emerged from within the den!"),
  :battle_flee    => _INTL("{1} disappeared somewhere into the den..."),
  :battle_bgm     => ["Raid (Max) battle v1", "Raid (Max) battle v2", "Raid (Max) battle v3"],
  :capture_bgm    => "Raid (Max) capture",
  :available      => PluginManager.installed?("[DBK] Dynamax")
})

GameData::RaidType.register({
  :id             => :Tera,
  :name           => "Tera",
  :den_name       => _INTL("Tera Raid Den"),
  :den_sprite     => "Object den (Tera)",
  :den_size       => 2,
  :lair_name      => _INTL("Terastal Adventure"),
  :lair_bgm       => "Raid (Tera) adventure",
  :battle_bg      => "raid_tera",
  :battle_base    => "raid_tera",
  :battle_text    => _INTL("A Terastallized {1} emerged from within the den!"),
  :battle_flee    => _INTL("{1} disappeared somewhere into the den..."),
  :battle_bgm     => ["Raid (Tera) battle v1", "Raid (Tera) battle v2", "Raid (Tera) battle v3"],
  :capture_bgm    => "Raid (Tera) capture",
  :available      => PluginManager.installed?("[DBK] Terastallization")
})