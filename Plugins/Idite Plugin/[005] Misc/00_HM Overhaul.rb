#==========================
# HM Overhaul... Overhaul? 
# Idite, 2.0.0
#==========================

# Define these helper methods outside of any class so they can be used globally.

# Returns the list of potential field moves.
def getFieldMoves
  [:CUT, :FLY, :SURF, :STRENGTH, :FLASH, :ROCKSMASH, :DIVE, :WATERFALL, :DIG, 
   :SOFTBOILED, :MILKDRINK, :HEADBUTT, :TELEPORT, :SWEETSCENT].map { |move_id| GameData::Move.get(move_id) }
end

# Returns the badge requirement for each move, if applicable.
def badge_requirement_for_move(move_id)
  case move_id
  when :CUT
    Settings::BADGE_FOR_CUT
  when :FLY
    Settings::BADGE_FOR_FLY
  when :SURF
    Settings::BADGE_FOR_SURF
  when :STRENGTH
    Settings::BADGE_FOR_STRENGTH
  when :FLASH
    Settings::BADGE_FOR_FLASH
  when :ROCKSMASH
    Settings::BADGE_FOR_ROCKSMASH
  when :DIVE
    Settings::BADGE_FOR_DIVE
  when :WATERFALL
    Settings::BADGE_FOR_WATERFALL
  else
    -1  # No badge requirement
  end
end

# Extends PokemonPartyScreen to add hidden move commands dynamically.
class PokemonPartyScreen
  alias_method :original_pbPokemonScreen, :pbPokemonScreen

  def pbPokemonScreen
    can_access_storage = ($player.has_box_link || $bag.has?(:POKEMONBOXLINK)) &&
                         !$game_switches[Settings::DISABLE_BOX_LINK_SWITCH] &&
                         !$game_map.metadata&.has_flag?("DisableBoxLink")

    @scene.pbStartScene(@party, _INTL("Choose a Pokémon."), nil, false, can_access_storage)

    loop do
      @scene.pbSetHelpText(_INTL("Choose a Pokémon."))
      party_idx = @scene.pbChoosePokemon(false, -1, 1)

      # Handle quick-switching, which may return an array
      if party_idx.is_a?(Array) && party_idx[0] == 1
        @scene.pbSetHelpText(_INTL("Move to where?"))
        old_party_idx = party_idx[1]
        party_idx = @scene.pbChoosePokemon(true, -1, 2)
        pbSwitch(old_party_idx, party_idx) if party_idx >= 0 && party_idx != old_party_idx
        next
      end

      # Proceed if a single party index was chosen
      break if party_idx < 0

      pkmn = @party[party_idx]
      command_list = []
      commands = []

      # Default menu commands
      MenuHandlers.each_available(:party_menu, self, @party, party_idx) do |option, hash, name|
        command_list.push(name)
        commands.push(hash)
      end
      command_list.push(_INTL("Cancel"))

      # Field move commands, shown only if player has required badge
      if !pkmn.egg?
        insert_index = ($DEBUG) ? 2 : 1
        getFieldMoves.each do |move_data|
          move_id = move_data.id
          if HiddenMoveHandlers.hasHandler(move_id) && pkmn.compatible_with_move?(move_id)
            badge_req = badge_requirement_for_move(move_id)
            next unless pbCheckHiddenMoveBadge(badge_req, false)

            # Add move to commands if badge requirement is met
            command_list.insert(insert_index, move_data.name)
            commands.insert(insert_index, move_id)
            insert_index += 1
          end
        end
      end

      choice = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), command_list)
      next if choice < 0 || choice >= commands.length

      case commands[choice]
      when Hash
        commands[choice]["effect"].call(self, @party, party_idx)
      when Symbol
        move_id = commands[choice]
        # Using the existing HiddenMoveHandlers for Fly to avoid duplicating checks and animations
        if HiddenMoveHandlers.triggerCanUseMove(move_id, pkmn, true)
          if HiddenMoveHandlers.triggerConfirmUseMove(move_id, pkmn)
            @scene.pbEndScene  # End scene immediately after Fly is used

            # Perform the Fly action and exit completely without re-triggering
            HiddenMoveHandlers.triggerUseMove(move_id, pkmn)
            return   # Exit the loop and function completely
          end
        else
          pbDisplay(_INTL("Cannot use this move here."))
        end
      end
    end
    @scene.pbEndScene
    return nil
  end
end

# Updated Fly UseMove handler for the plugin
HiddenMoveHandlers::UseMove.add(:FLY, proc { |move, pkmn|
  # Step 1: If there's no Fly destination set, prompt the player to select one
  unless $game_temp.fly_destination
    # Open the region map to choose a Fly destination
    scene = PokemonRegionMap_Scene.new(-1, false)
    screen = PokemonRegionMapScreen.new(scene)
    ret = screen.pbStartFlyScreen

    # If a location was chosen, set the destination; otherwise, cancel the Fly attempt
    if ret
      $game_temp.fly_destination = ret
    else
      pbMessage(_INTL("You can't use that here."))
      next false
    end
  end

  # Step 2: Ensure that a valid Fly destination and Pokémon are available
  if $game_temp.fly_destination
    # Attempt to Fly to the destination directly, bypassing extra checks
    pbFlyToNewLocation(pkmn)
  else
    pbMessage(_INTL("You can't use that here."))
    next false
  end

  # Step 3: Clear the Fly destination to reset for future usage
  $game_temp.fly_destination = nil
  next true
})
