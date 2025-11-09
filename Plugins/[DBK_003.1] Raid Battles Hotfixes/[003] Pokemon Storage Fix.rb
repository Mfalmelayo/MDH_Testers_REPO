#===============================================================================
# Pokemon Storage Parameter Fix
# Fixes the missing parameter bug in the Raid Battles plugin's pbStorePokemon
# The original plugin calls raid_pbStorePokemon without the pkmn parameter,
# causing caught Pokemon to not be stored properly.
#===============================================================================

module Battle::CatchAndStoreMixin
  # Override the entire pbStorePokemon method to fix the missing parameter bug
  # This is defined AFTER the raid plugin, so it takes precedence
  def pbStorePokemon(pkmn)
    # Debug outputs
    echoln "=== POKEMON STORAGE DEBUG ==="
    echoln "Pokemon: #{pkmn.name} (#{pkmn.species})"
    echoln "Has immunities: #{pkmn.immunities.inspect}"
    echoln "Has RAIDBOSS immunity: #{pkmn.immunities&.include?(:RAIDBOSS)}"
    echoln "@raidStyleCapture: #{@raidStyleCapture.inspect}"
    echoln "@caughtPokemon empty: #{@caughtPokemon.empty?}"
    echoln "@raidRules: #{@raidRules.inspect}" if defined?(@raidRules)
    echoln "respond_to raid_pbStorePokemon: #{respond_to?(:raid_pbStorePokemon)}"
    echoln "============================="
    
    if pkmn.immunities&.include?(:RAIDBOSS) && @raidStyleCapture && !@caughtPokemon.empty?
      echoln ">>> Taking RAID BOSS path <<<"
      pkmn.makeUnmega
      pkmn.makeUnprimal
      pkmn.makeUnUltra if pkmn.ultra?
      pkmn.dynamax       = false if pkmn.dynamax?
      pkmn.terastallized = false if pkmn.tera?
      pkmn.hp_level = 0
      pkmn.immunities = nil
      pkmn.name = nil if pkmn.nicknamed?
      pkmn.level = 75 if pkmn.level > 75
      pkmn.resetLegacyData if defined?(pkmn.legacy_data)
      case @raidRules[:style]
      when :Ultra
        pkmn.form_simple = 0 if pkmn.isSpecies?(:NECROZMA)
        if pkmn.item && GameData::Item.get(pkmn.item_id).is_zcrystal?
          pkmn.item = nil if !pbInRaidAdventure?
        end
      when :Max
        pkmn.dynamax_lvl = @raidRules[:rank] + rand(3)
      when :Tera
        pkmn.forced_form = nil if pkmn.isSpecies?(:OGERPON)
      end
      if pbInRaidAdventure?
        if pbRaidAdventureState.endlessMode? || !pbRaidAdventureState.boss_battled
          ev_stats = [nil, :DEFENSE, :SPECIAL_DEFENSE]
          ev_stats.push(:ATTACK) if pkmn.moves.any? { |m| m.physical_move? }
          ev_stats.push(:SPECIAL_ATTACK) if pkmn.moves.any? { |m| m.special_move? }
          ev_stats.push(:SPEED) if pkmn.baseStats[:SPEED] > 60
          stat = ev_stats.sample
          pkmn.ev[:HP] = Pokemon::EV_STAT_LIMIT
          if GameData::Stat.exists?(stat)
            pkmn.ev[stat] = Pokemon::EV_STAT_LIMIT
          else
            GameData::Stat.each_main_battle do |s|
              pkmn.ev[s.id] = (Pokemon::EV_STAT_LIMIT / 5).floor
            end
          end
        end
        pkmn.heal
        pkmn.calc_stats
        pbRaidAdventureState.captures.push(pkmn)
        pbDisplay(_INTL("Caught {1}!", pkmn.name))
      else
        pkmn.heal
        pkmn.reset_moves
        pkmn.calc_stats
        stored_box = $PokemonStorage.pbStoreCaught(pkmn)
        box_name = @peer.pbBoxName(stored_box)
        pbDisplayPaused(_INTL("{1} has been sent to Box \"{2}\"!", pkmn.name, box_name))
      end
    else
      echoln ">>> Taking ELSE path (calling raid_pbStorePokemon) <<<"
      # FIXED: Call raid_pbStorePokemon WITH the pkmn parameter
      # The original plugin was missing this parameter, causing the bug
      if respond_to?(:raid_pbStorePokemon)
        echoln ">>> Calling raid_pbStorePokemon(pkmn) <<<"
        raid_pbStorePokemon(pkmn)
      else
        echoln ">>> ERROR: raid_pbStorePokemon doesn't exist! <<<"
        echoln ">>> Attempting to call base pbStorePokemon manually <<<"
        # Fallback: try to call the original base game method
        if pbPlayer.party_full?
          stored_box = $PokemonStorage.pbStoreCaught(pkmn)
          box_name = @peer.pbBoxName(stored_box)
          pbDisplayPaused(_INTL("{1} has been sent to Box \"{2}\"!", pkmn.name, box_name))
        else
          pbPlayer.party[pbPlayer.party.length] = pkmn
          pbDisplayPaused(_INTL("{1} has been added to your party.", pkmn.name))
        end
      end
    end
  end
  
  # Also add debug for pbRecordAndStoreCaughtPokemon
  alias hotfix_pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon
  def pbRecordAndStoreCaughtPokemon
    echoln "=== pbRecordAndStoreCaughtPokemon DEBUG ==="
    echoln "@caughtPokemon count: #{@caughtPokemon.length}"
    echoln "pbInRaidAdventure?: #{pbInRaidAdventure?}" if respond_to?(:pbInRaidAdventure?)
    @caughtPokemon.each_with_index do |pkmn, i|
      echoln "  [#{i}] #{pkmn.name} - immunities: #{pkmn.immunities.inspect}"
    end
    echoln "==========================================="
    
    hotfix_pbRecordAndStoreCaughtPokemon
    
    echoln "=== AFTER pbRecordAndStoreCaughtPokemon ==="
    echoln "@caughtPokemon count: #{@caughtPokemon.length}"
    echoln "Player party count: #{pbPlayer.party.length}"
    echoln "==========================================="
  end
end