#===============================================================================
# Handles the overworld sprites for Raid Den events.
#===============================================================================
class RaidDenSprite
  def initialize(event, style, _viewport)
    @event     = event
	@style     = GameData::RaidType.get(style)
	@disposed  = false
    set_event_graphic
  end

  def dispose
    @event    = nil
	@style    = nil
    @disposed = true
  end

  def disposed?
    @disposed
  end
 
  def update
    set_event_graphic
  end
  
  #-----------------------------------------------------------------------------
  # Sets the actual graphic for a Max Raid Den event.
  #-----------------------------------------------------------------------------
  def set_event_graphic
    return if !@style
	if pbResolveBitmap(_INTL("Graphics/Characters/") + @style.den_sprite)
	  @event.width = @event.height = @style.den_size
	  @event.character_name = @style.den_sprite.split("/").last
	  pkmn = @event.variable
	  case pkmn
	  when 0
	    @event.turn_down
	  when Array
	    turnRight = false
	    flags = pkmn[0].species_data.flags
	    case @style.id
	    when :Basic then turnRight = flags.include?("Legendary") || flags.include?("Mythical")
	    when :Ultra then turnRight = pkmn[0].ultra? || flags.include?("UltraBeast")
	    when :Max   then turnRight = pkmn[0].isSpecies?(:CALYREX)
	    when :Tera  then turnRight = pkmn[0].tera_form? || flags.include?("Paradox")
	    end
	    (turnRight) ? @event.turn_right : @event.turn_left
	  else
	    @event.turn_up
	  end
    end
  end
end

#===============================================================================
# Raid Den call used to initiate a raid battle.
#===============================================================================
def pbRaidDen(pkmn = {}, rules = {})
  interp = pbMapInterpreter
  event = interp.get_self
  return if !event
  GameData::RaidType.each_available do |r|
    name = r.event_name.downcase
	next if !event.name[/#{name}/i]
	rules[:style] = r.id
	break
  end
  rules[:raid_den] = true
  raid_pkmn = interp.getVariable
  case raid_pkmn
  when 0
    if pbRaidDenReset(interp, event)
	  return RaidBattle.start(pkmn, rules)
	else
	  $game_temp.clear_battle_rules
	  return false
	end
  when Array
    setBattleRule("editWildPokemon", {})
    return RaidBattle.start(*raid_pkmn)
  else
	interp.setVariable(nil)
    return RaidBattle.start(pkmn, rules)
  end
end

#===============================================================================
# Called when the player interacts with an empty den to manually reset it.
#===============================================================================
def pbRaidDenReset(interp, this_event)
  if $DEBUG && Input.press?(Input::CTRL)
    pbMessage(_INTL("A new Pokémon appeared!"))
    interp.setVariable(nil)
	this_event.turn_up
	return true
  else
    item = GameData::Item.get(:RAIDBAIT)
    pbMessage(_INTL("There doesn't seem to be anything here..."))
    if pbConfirmMessage(_INTL("Want to throw in a {1} to lure a Pokémon?", item.portion_name))
      if $bag.has?(item.id)
        pbMessage(_INTL("You tossed in a {1}!", item.portion_name))
        $bag.remove(item.id)
        interp.setVariable(nil)
		this_event.turn_up
		return true
      else
        pbMessage(_INTL("But you don't have any {1}...", item.portion_name_plural))
      end
    end
  end
  return false
end

#===============================================================================
# Utility to empty or reset all Raid Dens on all maps.
#===============================================================================
def pbClearAllRaids(reset = false)
  set = (reset) ? nil : 0
  name = GameData::RaidType::RAID_DEN_SUFFIX.downcase 
  $PokemonGlobal.eventvars = {} if !$PokemonGlobal.eventvars
  GameData::MapMetadata.each do |map_data|
    file = sprintf("Data/Map%03d.rxdata", map_data.id)
	next if !FileTest.exist?(file)
	map = load_data(file)
    for event_id in 1..map.events.length
      event = map.events[event_id]
      next if !event || !event.name[/#{name}/i]
      $PokemonGlobal.eventvars[[map_data.id, event_id]] = set
    end
  end  
  $PokemonGlobal.raid_timer = Time.now
  $game_map.update
end

#===============================================================================
# Defines when the last Raid Den update was to naturally reset dens each day.
#===============================================================================
class PokemonGlobalMetadata
  def raid_timer
    @raid_timer = Time.now if !@raid_timer
	return @raid_timer
  end
  
  def raid_timer=(value)
    @raid_timer = Time.now if !@raid_timer
	@raid_timer = value
  end
end

#-------------------------------------------------------------------------------
# Handler used to automatically reset all Raid Den events after a day has passed.
#-------------------------------------------------------------------------------
EventHandlers.add(:on_frame_update, :raid_den_reset,
  proc {
    next if Time.now.day == $PokemonGlobal.raid_timer.day
    name = GameData::RaidType::RAID_DEN_SUFFIX.downcase 
	$PokemonGlobal.eventvars = {} if !$PokemonGlobal.eventvars
    $PokemonGlobal.eventvars.keys.each do |key|
      map = load_data(sprintf("Data/Map%03d.rxdata", key[0]))
      event = map.events[key[1]]
      next if !event || !event.name[/#{name}/i]
      $PokemonGlobal.eventvars[key] = nil
    end
    $PokemonGlobal.raid_timer = Time.now
    $game_map.update
  }
)

#-------------------------------------------------------------------------------
# Handler used to update the sprites of all Raid Den events on a map.
#-------------------------------------------------------------------------------
EventHandlers.add(:on_new_spriteset_map, :add_raid_den_graphics,
  proc { |spriteset, viewport|
	dens = []
	GameData::RaidType.each_available { |r| dens.push([r.id, r.event_name.downcase]) }
    spriteset.map.events.each do |event|
      char = event[1]
	  dens.each do |den|
	    next if !char.name[/#{den[1]}/i]
		spriteset.addUserSprite(RaidDenSprite.new(char, den[0], viewport))
	  end
    end
  }
)

#===============================================================================
# Stores the schema used to translate a pastebin link into Raid Den data.
#===============================================================================
module LiveRaidEvent
  SCHEMA = {
	"Species"          => [:species,        "e",   :Species],
    "Form"             => [:form,           "v"],
    "Gender"           => [:gender,         "e",   {"M" => 0, "m" => 0, "Male" => 0, "male" => 0, "0" => 0,
                                                    "F" => 1, "f" => 1, "Female" => 1, "female" => 1, "1" => 1}],
    "AbilityIndex"     => [:ability_index,  "u"],
    "Moves"            => [:moves,          "*e",  :Move],
    "Item"             => [:item,           "e",   :Item],
    "Nature"           => [:nature,         "e",   :Nature],
    "IV"               => [:iv,             "uUUUUU"],
    "EV"               => [:ev,             "uUUUUU"],
    "Shiny"            => [:shiny,          "b"],
	"SuperShiny"       => [:super_shiny,    "b"],
    "GmaxFactor"       => [:gmax_factor,    "b"],
    "TeraType"         => [:tera_type,      "e",   :Type],
    "Memento"          => [:memento,        "e",   :Ribbon],
    "Scale"            => [:scale,          "u"],
	"HPLevel"          => [:hp_level,       "v"],
	"Immunities"       => [:immunities,     "*m"],
	"RaidStyle"        => [:style,          "e",   :RaidType],
	"RaidRank"         => [:rank,           "v"],
	"RaidSize"         => [:size,           "v"],
	"RaidPartner"      => [:partner,        "esUB", :TrainerType],
	"RaidTurns"        => [:turn_count,     "i"],
	"RaidKOs"          => [:ko_count,       "i"],
	"RaidShield"       => [:shield_hp,      "i"],
	"RaidActions"      => [:extra_actions,  "*m"],
	"RaidSupportMoves" => [:support_moves,  "*e",  :Move],
	"RaidSpreadMoves"  => [:spread_moves,   "*e",  :Move],
	"RaidLoot"         => [:loot,           "*ev", :Item],
  }
end

#===============================================================================
# Reads a pastebin URL to acquire Raid Den data over the internet.
#===============================================================================
def pbLoadLiveRaidData
  lineno = 1
  species = [nil, 0]
  pkmn_data = {}
  raid_data = {
    :style    => :Basic,
	:online   => true,
	:raid_den => true
  }
  if nil_or_empty?(Settings::LIVE_RAID_EVENT_URL)
    return species, pkmn_data, raid_data
  end
  schema = LiveRaidEvent::SCHEMA
  data = pbDownloadToString(Settings::LIVE_RAID_EVENT_URL)
  data.each_line do |line|
    if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
      line = line[3, line.length - 3]
    end
    line.force_encoding(Encoding::UTF_8)
    line = Compiler.prepline(line)
    FileLineData.setLine(line, lineno) if !line[/^\#/] && !line[/^\s*$/]
    next if !line[/^\s*(\w+)\s*=\s*(.*)$/]
    key = $~[1]
    property_value = Compiler.get_csv_record($~[2], schema[key])
    if ["IV", "EV"].include?(key)
      property_value = property_value.compact!
      property_value = property_value.first if property_value.length < 6
    end
	case key
	when "Species" then species[0] = property_value
	when "Form"    then species[1] = property_value
	else
	  if key.include?("Raid")
	    raid_data[schema[key][0]] = property_value
	  else
	    pkmn_data[schema[key][0]] = property_value
	  end
	end
    lineno += 1
  end
  return species, pkmn_data, raid_data
end