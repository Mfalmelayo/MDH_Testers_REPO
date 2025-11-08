#===============================================================================
# Adds new data class in GameData module for Adventure Maps.
#===============================================================================
module GameData
  class AdventureMap
    attr_reader   :id          # Symbol ID of a map.
    attr_accessor :real_name   # Display name of a map.
    attr_accessor :filename    # Filename of the image used for a map's background.
    attr_accessor :description # Description of a map.
    attr_accessor :darkness    # The odds of a map being shrouded in darkness (0-100).
    attr_accessor :dimensions  # An array containing the number of tiles a map has along the X and Y axis.
    attr_accessor :player      # A string of four numbers that act as the coordinates for the player's starting position.
    attr_accessor :pathways    # An array of coordinates for all Pathway tiles on a map.
    attr_accessor :battles     # An array of coordinates for all Battle tiles on a map.
    attr_accessor :tiles       # An array that contains all data for a specific tile [ID, coordinates, toggleable, warp point].
    attr_reader   :flags       # Special flags related to a map (unused).
    attr_reader   :pbs_file_suffix

    DATA = {}
    DATA_FILENAME = "adventure_maps.dat"
    PBS_BASE_FILENAME = "adventure_maps"

    SCHEMA = {
      "SectionName"    => [:id,          "u"],
      "Name"           => [:real_name,   "s"],
      "Filename"       => [:filename,    "s"],
      "Description"    => [:description, "s"],
      "DarknessChance" => [:darkness,    "u"],
      "Dimensions"     => [:dimensions,  "vv"],
      "PlayerStart"    => [:player,      "s"],
      "Pathways"       => [:pathways,    "*s"],
      "Battles"        => [:battles,     "*s"],
      "Tile"           => [:tiles,       "^esBS", :AdventureTile],
      "Flags"          => [:flags,       "*s"]
    }

    extend ClassMethodsIDNumbers
    include InstanceMethods
    
    def get_tile(x, y)
      if @player[0..1].to_i == x && @player[2..3].to_i == y
        return { id: :Player }
      end
      @pathways.each do |c|
        cx, cy = c[0..1].to_i, c[2..3].to_i
        next if !(cx == x && cy == y)
        return { id: :Pathway }
      end
      @battles.each_with_index do |c, i|
        cx, cy = c[0..1].to_i, c[2..3].to_i
        next if !(cx == x && cy == y)
        return { id: :Battle, battle_id: i }
      end
      @tiles.each do |tile|
        c = tile[1]
        cx, cy = c[0..1].to_i, c[2..3].to_i
        next if !(cx == x && cy == y)
        return { id: tile[0], toggle: tile[2], warp_point: tile[3] }
      end
      return { id: :Empty }
    end

    def initialize(hash)
      @id              = hash[:id]
      @real_name       = hash[:real_name]       || "Unnamed"
      @filename        = hash[:filename]        || "small"
      @description     = hash[:description]     || "Unknown."
      @darkness        = hash[:darkness]        || 10
      @dimensions      = hash[:dimensions]      || [1, 1]
      @player          = hash[:player]          || "0000"
      @pathways        = hash[:pathways]        || []
      @battles         = hash[:battles]         || []
      @tiles           = hash[:tiles]           || []
      @flags           = hash[:flags]           || []
      @pbs_file_suffix = hash[:pbs_file_suffix] || ""
    end

    def name
      return _INTL("{1}", @real_name)
    end

    def has_flag?(flag)
      return @flags.any? { |f| f.downcase == flag.downcase }
    end
  end
end

#===============================================================================
# Compiler functions for adventure_maps PBS files.
#===============================================================================
module Compiler
  module_function
  
  Compiler.singleton_class.alias_method :raid_compile_pbs_files, :compile_pbs_files
  def compile_pbs_files
    raid_compile_pbs_files
    text_files = get_all_pbs_files_to_compile
    compile_adventure_maps(*text_files[:AdventureMap][1])
  end
  
  def write_adventure_maps
    write_PBS_file_generic(GameData::AdventureMap)
  end
  
  def compile_adventure_maps(*paths)
    compile_PBS_file_generic(GameData::AdventureMap, *paths) do |final_validate, hash|
      (final_validate) ? validate_all_compiled_adventure_maps : validate_compiled_adventure_map(hash)
    end
  end

  def validate_compiled_adventure_map(hash)
    error = _INTL("Adventure Map {1} '{2}':\n", hash[:id], hash[:name])
    # Dimensions check.
    if hash[:dimensions].any? { |i| i < 1 || i > 32 }
      raise error + _INTL("Map has invalid dimensions. Each value must range from 1-32.\n{3}", 
        name, schema, FileLineData.linereport)
    end
    # Coordinate checks.
    coords = Hash.new { |key, value| key[value] = [] }
    coords["Player Start"] << hash[:player]
    hash[:pathways].each { |c| coords[:Pathway] << c }
    hash[:battles].each  { |c| coords[:Battle]  << c }
    hash[:tiles].each do |tile|
      coords[tile[0]] << tile[1]
      coords["Warp Point"] << tile[3] if tile[3]
    end
    coords.each do |tile, array|
      case tile
      when String
        lineName = _INTL(tile)
      when Symbol
        lineName = GameData::AdventureTile.get(tile).name + " tile"
        coords.each_key do |key|
          next if key == tile
          next if key.is_a?(String)
          coords[key].each do |c|
            next if !array.include?(c)
            raise error + _INTL("Coordinates '{1}' is used twice by two different tiles.\n{3}",
              c, FileLineData.linereport)
          end
        end
      end
      array.each do |c|
        next if c.length == 4
        raise error + _INTL("Coordinates '{1}' for {2} are invalid. Must be 4 characters long.\n{3}",
          c, lineName, FileLineData.linereport)
      end
    end
    # Battle tile checks.
    battleTile = GameData::AdventureTile.get(:Battle)
    if hash[:tiles].any? { |t| t[0] == :Battle }
      raise error + _INTL("A {1} tile is set with 'Tile' instead of '{2}'.\n{3}", 
        name, schema, FileLineData.linereport)
    end
    if hash[:battles].length != battleTile.required
      raise error + _INTL("Invalid number of {1} tiles. Requires {2}.\n{3}", 
        battleTile.name, battleTile.required, FileLineData.linereport)
    end
    # Other required tile checks.
    required = {}
    maximum  = {}
    detected = {}
    GameData::AdventureTile.each do |tile|
      next if tile.id == :Battle
      if tile.required && tile.required > 0
        required[tile.id] = tile.required
        detected[tile.id] = 0
      elsif tile.max_number
        maximum[tile.id]  = tile.max_number
        detected[tile.id] = 0
      end
    end
    hash[:tiles].each do |tile|
      tile = GameData::AdventureTile.get(tile[0])
      if tile.max_number || tile.required && tile.required > 0
        detected[tile.id] += 1
      end
    end
    required.keys.each do |key|
      next if detected[key] == required[key]
      tile = GameData::AdventureTile.get(key)
      raise error + _INTL("Invalid number of {1} tiles. Requires {2}, but only found {3}.\n{4}", 
        tile.name, tile.required, detected[key], FileLineData.linereport)
    end
    maximum.keys.each do |key|
      next if detected[key] <= maximum[key]
      tile = GameData::AdventureTile.get(key)
      raise error + _INTL("Invalid number of {1} tiles. Maximum {2}, but found {3}.\n{4}", 
        tile.name, tile.max_number, detected[key], FileLineData.linereport)
    end
  end

  def validate_all_compiled_adventure_maps
    map_names = []
    map_descriptions = []
    GameData::AdventureMap.each do |map|
      map_names[map.id] = map.real_name
      map_descriptions[map.id] = map.description
    end
    map_names.uniq!
    map_descriptions.uniq!
    MessageTypes.setMessagesAsHash(MessageTypes::ADVENTURE_MAP_NAMES, map_names)
    MessageTypes.setMessagesAsHash(MessageTypes::ADVENTURE_MAP_DESCRIPTIONS, map_descriptions)
  end
end