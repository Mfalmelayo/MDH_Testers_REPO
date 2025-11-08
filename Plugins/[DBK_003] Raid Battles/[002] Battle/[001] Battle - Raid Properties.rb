#===============================================================================
# General additions to the Battle class.
#===============================================================================
class Battle
  attr_accessor :raidRules
  
  #-----------------------------------------------------------------------------
  # Aliased to initialize new battle properties.
  #-----------------------------------------------------------------------------
  alias raid_initialize initialize
  def initialize(*args)
    raid_initialize(*args)
    @raidRules = {}
  end
  
  #-----------------------------------------------------------------------------
  # Utility for updating the raid turn counter.
  #-----------------------------------------------------------------------------
  def pbRaidChangeTurnCount(battler, amt)
	return if !battler || battler.fainted? || !battler.isRaidBoss?
	return if !@raidRules[:turn_count] || @raidRules[:turn_count] < 0
	oldCount = @raidRules[:turn_count]
	@raidRules[:turn_count] += amt if @raidRules[:turn_count] > 0
	@raidRules[:turn_count] = 0 if @raidRules[:turn_count] < 0
	@raidRules[:raid_turnCount] = @turnCount
	PBDebug.log("[Raid mechanics] Raid turn counter changed (#{oldCount} => #{@raidRules[:turn_count]})")
	@scene.pbRefreshOne(battler.index)
	return if @raidRules[:turn_count] > 0
	return if pbAllFainted? || @decision > 0
	pbDisplayPaused(_INTL("The energy around {1} grew out of control!", battler.pbThis(true)))
    pbDisplay(_INTL("You were blown out of the den!"))
	pbRaidAdventureState.hearts = 0 if pbInRaidAdventure?
    @scene.pbAnimateFleeFromRaid
    @decision = 3
  end
  
  #-----------------------------------------------------------------------------
  # Utility for updating the raid KO counter.
  #-----------------------------------------------------------------------------
  def pbRaidChangeKOCount(battler, amt, done_fainting)
	return if !battler || battler.fainted? || !battler.isRaidBoss?
	return if !@raidRules[:ko_count] || @raidRules[:ko_count] < 0
	oldCount = @raidRules[:ko_count]
	@raidRules[:ko_count] += amt if @raidRules[:ko_count] > 0
	@raidRules[:ko_count] = 0 if @raidRules[:ko_count] < 0
	if pbInRaidAdventure?
	  pbRaidAdventureState.hearts = @raidRules[:ko_count]
	  if pbRaidAdventureState.hearts > pbRaidAdventureState.max_hearts
	    pbRaidAdventureState.max_hearts = @raidRules[:ko_count]
	  end
	end
	PBDebug.log("[Raid mechanics] Raid KO counter changed (#{oldCount} => #{@raidRules[:ko_count]})")
	@scene.pbRefreshOne(battler.index)
	return if amt > 0 || !done_fainting
	case @raidRules[:ko_count]
	when 0 then pbDisplayPaused(_INTL("The energy around {1} grew out of control!", battler.pbThis(true)))
	when 1 then pbDisplay(_INTL("The energy around {1} is growing too strong to withstand!", battler.pbThis(true)))
	else        pbDisplay(_INTL("The energy around {1} is growing stronger!", battler.pbThis(true)))
	end
	return if @raidRules[:ko_count] > 0 || pbAllFainted? || @decision > 0
    pbDisplay(_INTL("You were blown out of the den!"))
	@scene.pbAnimateFleeFromRaid
    @decision = 3
  end
end

#===============================================================================
# Aliases how Raid Pokemon are captured and stored.
#===============================================================================
module Battle::CatchAndStoreMixin
  alias raid_pbStorePokemon pbStorePokemon
  def pbStorePokemon(pkmn)
    if pkmn.immunities.include?(:RAIDBOSS) && @raidStyleCapture && !@caughtPokemon.empty?
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
      raid_pbStorePokemon
    end
  end
  
  alias raid_pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon
  def pbRecordAndStoreCaughtPokemon
	if pbInRaidAdventure?
	  @caughtPokemon.each { |pkmn| pbStorePokemon(pkmn) }
	  @caughtPokemon.clear
	else
      raid_pbRecordAndStoreCaughtPokemon
	end
  end
end