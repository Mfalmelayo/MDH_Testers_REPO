#===============================================================================
# NPCMon System v21.1
#   - Allows static NPC Pokémon to join and leave the party
#   - Pokémon is stored persistently in $PokemonGlobal.npcMons
#   - Supports forms, shinies, ribbons, markings, Poké Balls, etc.
#   - Player chooses Poké Ball ONLY on first recruit
#   - NPC Pokémon cannot be stored in the PC
#===============================================================================

class PokemonGlobalMetadata
  attr_accessor :npcMons
end

module NPCMon
  #---------------------------------------------------------------------------
  # Global persistent storage
  #---------------------------------------------------------------------------
  def self.store
    $PokemonGlobal.npcMons ||= {}
    return $PokemonGlobal.npcMons
  end

  #---------------------------------------------------------------------------
  # Register NPC Pokémon template (only run ONCE per NPC)
  #---------------------------------------------------------------------------
  def self.register(symbol, species, level, owner = nil, data = {})
    return if store[symbol]   # Already created once

    poke = Pokemon.new(species, level)

    #-------------------------
    # Correct Owner Handling (v21.1)
    #-------------------------
    if owner && owner.is_a?(Trainer)
		poke.owner = Pokemon::Owner.new_from_trainer(owner_data)
	else
		poke.owner = Pokemon::Owner.new_from_trainer($player)
	end

    #-------------------------
    # Standard fields
    #-------------------------
    poke.nature     = data[:nature] if data[:nature]
    poke.gender     = data[:gender] if data[:gender]
    poke.form       = data[:form] if data[:form]
    poke.shiny      = data[:shiny] if !data[:shiny].nil?
    poke.item       = data[:item] if data[:item]
    poke.ability    = data[:ability] if data[:ability]
    poke.iv         = data[:iv] if data[:iv].is_a?(Integer)
    poke.ev         = data[:ev] if data[:ev].is_a?(Array)
    poke.markings   = data[:markings] if data[:markings]
    poke.ribbon_ids = data[:ribbons] if data[:ribbons]

    #-------------------------
    # Innates Support
    #-------------------------
    if data[:Innates]
      if poke.respond_to?(:innates)
        poke.innates = data[:Innates].clone
      elsif $DEBUG
        echoln "[NPCMon] Warning: Innates not supported by this build."
      end
    end

    #-------------------------
    # Moves
    #-------------------------
    if data[:moves]
      poke.reset_moves
      data[:moves].each { |m| poke.learn_move(m) }
    end

    #-------------------------
    # Player chooses Ball (first time only)
    #-------------------------
	pbMessage("Select the pokeball you want to use for #{poke.name}")
    ball = self.choose_ball_ui
    poke.poke_ball = ball if ball

    # Save TEMPLATE
    store[symbol] = poke
  end
  
  def self.update(id, data = {})
	mon = self.store[id]
	return if !mon

	data.each do |key, value|
		if mon.respond_to?("#{key}=")
			mon.send("#{key}=", value)
		else
			echoln("[NPCMon] Unknown attribute '#{key}' for #{id}.")
		end
	end
  end



  #---------------------------------------------------------------------------
  # Add NPC Pokémon to player's party
  #---------------------------------------------------------------------------
  def self.add(symbol, switch_id)
    base = store[symbol]
    return false unless base

    if $player.party_full?
      pbMessage("Your party is full!")
      return false
    end

    # Clone so original always remains preserved
    new_poke = base.clone

    # Mark as NPC Pokémon
    new_poke.npc_mon = true
	new_poke.cannot_store = true
	new_poke.cannot_release = true

    pbAddToPartySilent(new_poke)
    pbMessage("#{new_poke.name} joined your party!")

    # Turn overworld switch ON (remove NPC event)
    if switch_id
      $game_switches[switch_id] = true
    end

    # --- FORCE MAP UPDATE ---
    $game_map.need_refresh = true

    return true
  end

  #---------------------------------------------------------------------------
  # Return an NPC Pokémon and update stored version
  #---------------------------------------------------------------------------
  def self.return(symbol, switch_id = nil)
    poke = $player.party.find { |p| p&.npc_mon }

    unless poke
      pbMessage("You don't have that Pokémon with you.")
      return false
    end

    # Update saved version with current state
    store[symbol] = poke.clone

    # Remove from party
    $player.party.delete(poke)
    pbMessage("#{poke.name} returned to its place.")

    # Turn switch OFF to make NPC reappear
    if switch_id
      $game_switches[switch_id] = false
    end

    # --- FORCE MAP UPDATE ---
    $game_map.need_refresh = true

    return true
  end

  # Opens the Bag filtered to Poké Balls only
  def self.choose_ball_ui
	loop do
		item = pbChooseItem
		return nil if !item # Cancelled
		# Check if item is a Poké Ball
		if GameData::Item.get(item).is_poke_ball?
			return item
		else
			pbMessage("\\se[GUI sel buzzer]Please choose a Poké Ball.")
		end
	end
  end




end

#===============================================================================
# Prevent NPC Pokémon from being stored in the PC
#===============================================================================
class Pokemon
  attr_accessor :npc_mon, :cannot_store, :cannot_release
end


class PokemonStorage
  alias npcmon_pbStoreCaught pbStoreCaught
  def pbStoreCaught(pokemon)
    if pokemon.cannot_store
      pbMessage(_INTL("{1} refuses to enter a PC box!", pokemon.name))
      return false
    end
    return npcmon_pbStoreCaught(pokemon)
  end

  alias npcmon_pbMoveCaughtToBox pbMoveCaughtToBox
  def pbMoveCaughtToBox(pokemon, box_number)
    if pokemon.cannot_store
      pbMessage(_INTL("{1} refuses to enter a PC box!", pokemon.name))
      return false
    end
    return npcmon_pbMoveCaughtToBox(pokemon, box_number)
  end
end

