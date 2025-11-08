#===============================================================================
# Tracks raid battle stats.
#===============================================================================
class GameStats
  alias raid_initialize initialize
  def initialize
    raid_initialize
    @raid_battles_won         = 0
	@raid_dens_cleared        = 0
	@online_raid_dens_cleared = 0
	@raid_adventures_cleared  = 0
	@endless_adventure_floors = 0
  end

  def raid_battles_won
    return @raid_battles_won || 0
  end
  
  def raid_battles_won=(value)
    @raid_battles_won = 0 if !@raid_battles_won
    @raid_battles_won = value
  end
  
  def raid_dens_cleared
    return @raid_dens_cleared || 0
  end
  
  def raid_dens_cleared=(value)
    @raid_dens_cleared = 0 if !@raid_dens_cleared
    @raid_dens_cleared = value
  end
  
  def online_raid_dens_cleared
    return @online_raid_dens_cleared || 0
  end
  
  def online_raid_dens_cleared=(value)
    @online_raid_dens_cleared = 0 if !@online_raid_dens_cleared
    @online_raid_dens_cleared = value
  end
  
  def raid_adventures_cleared
    return @raid_adventures_cleared || 0
  end
  
  def raid_adventures_cleared=(value)
    @raid_adventures_cleared = 0 if !@raid_adventures_cleared
	@raid_adventures_cleared = value
  end
  
  def endless_adventure_floors
    return @endless_adventure_floors || 0
  end
  
  def endless_adventure_floors=(value)
    @endless_adventure_floors = 0 if !@endless_adventure_floors
	@endless_adventure_floors = value
  end
end

#===============================================================================
# Battle Rules.
#===============================================================================
class Game_Temp
  alias raid_add_battle_rule add_battle_rule
  def add_battle_rule(rule, var = nil)
    rules = self.battle_rules
    case rule.to_s.downcase
    when "raidbattle"   then rules["raidBattle"]   = var
	when "cheerbattle"  then rules["cheerBattle"]  = true
	when "cheermode"    then rules["cheerMode"]    = var
    else
      raid_add_battle_rule(rule, var)
    end
  end
end

alias raid_additionalRules additionalRules
def additionalRules
  rules = raid_additionalRules
  rules.push("raidbattle", "cheermode")
  return rules
end

#===============================================================================
# Raid battle setup.
#===============================================================================
module BattleCreationHelperMethods
  module_function
  
  BattleCreationHelperMethods.singleton_class.alias_method :raid_prepare_battle, :prepare_battle
  def prepare_battle(battle)
    BattleCreationHelperMethods.raid_prepare_battle(battle)
	battleRules = $game_temp.battle_rules
	battle.cheerMode = 0 if !battleRules["cheerBattle"].nil?
	battle.cheerMode = battleRules["cheerMode"] if !battleRules["cheerMode"].nil?
    prepare_raid(battle)
  end
  
  def prepare_raid(battle)
    return if battle.trainerBattle?
    return if !$game_temp.battle_rules["raidBattle"]
    battleRules = $game_temp.battle_rules
    battle.raidRules = battleRules["raidBattle"]
    battle.wildBattleMode = :raid
	case battle.raidRules[:style]
	when :Ultra then battle.cheerMode = 2
	when :Max   then battle.cheerMode = 3
	when :Tera  then battle.cheerMode = 4
	else             battle.cheerMode = 1
	end
	pkmn = battle.raidRules[:pokemon]
	if battle.raidRules[:style] == :Tera && pkmn.tera_type == :STELLAR
      GameData::Type.each do |t| 
        next if t.pseudo_type
        next if battle.boosted_tera_types[1][0].include?(t.id)
        battle.boosted_tera_types[1][0].push(t.id)
      end
    end
    if (battle.raidRules.is_a?(Hash) && battle.raidRules[:raid_den]) || pbInRaidAdventure?
	  raidType = GameData::RaidType.get(battle.raidRules[:style])
	  if !battle.introText
	    if raidType.id == :Max && (pkmn.gmax? || pkmn.emax?)
		  text = raidType.battle_text.clone
		  form_name = battle.raidRules[:pokemon].species_data.form_name
		  text.gsub!("A Dynamaxed", form_name) if !nil_or_empty?(form_name)
		  battle.introText = text
		else
	      battle.introText = raidType.battle_text
	    end
	  end
      battle.raidStyleCapture = {
        :capture_chance => 100,
        :capture_bgm    => raidType.capture_bgm,
        :flee_msg       => raidType.battle_flee
      }
    end
    battle.raidStyleCapture = true if !battle.raidStyleCapture
  end
end


#===============================================================================
# Midbattle script for raid battles.
#===============================================================================
MidbattleHandlers.add(:midbattle_global, :raid_battle,
  proc { |battle, idxBattler, idxTarget, trigger|
    next if !battle.raidBattle?
    next if battle.wildBattleMode != :raid
    foe = battle.battlers[1]
	style = battle.raidRules[:style]
    case trigger
	#---------------------------------------------------------------------
	# Sets initial raid battle properties on the first turn.
    when "RoundStartCommand_1_foe"
      if foe.isRaidBoss?
        battle.canRun           = false
        battle.expGain          = false
        battle.moneyGain        = false
        battle.sendToBoxes      = 1
        battle.disablePokeBalls = true
        battle.sosBattle        = false if defined?(battle.sosBattle)
        battle.totemBattle      = nil   if defined?(battle.totemBattle)
        foe.damageThreshold     = 50
		PBDebug.log("[Midbattle Global] Raid battle properties initiated")
      else
        battle.wildBattleMode = nil
      end
	#---------------------------------------------------------------------
	# Change over to using Max Moves in a Max Raid starting on the fifth turn. 
	when "RoundStartCommand_5_foe"
	  next if style != :Max
	  foe.display_dynamax_moves
	#---------------------------------------------------------------------
	# Checks for various additional raid actions to trigger each turn.
	when "RoundStartAttack_foe"
	  battle.pbRaidExtraActions(foe)
	  next if style != :Ultra
	  if foe.turnCount % 2 == 0 && battle.zMove[1][0] == -2
		battle.scene.pbAnimateExtraAction(foe.index)
		battle.pbDisplay(_INTL("{1} replenished its Z-Power with a surge of energy!", foe.pbThis))
		battle.zMove[1][0] = -1
      end
	#---------------------------------------------------------------------
	# Revives party members and reduces raid timer each round.
	when "RoundEnd_player", "RoundEnd_ally"
	  next if battle.turnCount == battle.raidRules[:raid_turnCount]
	  battle.pbParty(0).each do |pkmn|
	    next if !pkmn.fainted?
		pkmn.heal
		pbSEPlay("Anim/Lucky Chant")
        battle.pbDisplayPaused(_INTL("{1} recovered from fainting!\nIt will be sent back out next turn!", pkmn.name))
	  end
	  battle.pbRaidChangeTurnCount(foe, -1)
    #---------------------------------------------------------------------
	# Reduces raid KO counter each time an ally Pokemon faints.
    when "BattlerFainted_player", "BattlerFainted_ally"
	  done_fainting = true
      battle.battlers.each do |b|
        next if !b || !b.opposes?(foe) || b.hp > 0 || b.fainted
        done_fainting = false
      end
	  battle.pbRaidChangeKOCount(foe, -1, done_fainting)
	#---------------------------------------------------------------------
	# Begin raid shield when damage cap is reached.
    when "BattlerReachedHPCap_foe"
	  foe.startRaidShield
	#---------------------------------------------------------------------
	# Reduces raid shield HP when damage is dealt.
	when "TargetTookDamage_foe"
	  user = battle.battlers[battle.lastMoveUser]
	  foe.setRaidShieldHP(-1, user)
	#---------------------------------------------------------------------
	# Add to win counters after completing the raid battle.
    when "BattleEndWin"
      if battle.wildBattleMode == :raid
        $stats.raid_battles_won += 1
      end
    end
  }
)

#-------------------------------------------------------------------------------
# Changes a trainer's current cheer level.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_triggers, "setCheerLv",
  proc { |battle, idxBattler, idxTarget, params|
    next if !battle.canCheer?(idxBattler)
	next if !(0..3).include?(params)
	side = idxBattler & 1
	owner = battle.pbGetOwnerIndexFromBattlerIndex(idxBattler)
	oldLvl = battle.cheerLevel[side][owner]
	next if oldLvl == params || battle.pbAbleTeamCounts(side)[owner] == 0
	battle.cheerLevel[side][owner] = params
	PBDebug.log("     'setCheerLv': #{battle.pbGetOwnerName(idxBattler)}'s Cheer level changed (#{oldLvl} => #{params})")
  }
)

#-------------------------------------------------------------------------------
# Forces a trainer to use a particular cheer as their Pokemon's turn.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_triggers, "useCheer",
  proc { |battle, idxBattler, idxTarget, params|
    battler = battle.battlers[idxBattler]
    next if !battler || battler.fainted? || battle.decision > 0
	next if !battle.hasCheer?(idxBattler)
	try_cheer = GameData::Cheer.try_get(params)
	next if !try_cheer
	battle.pbRegisterCheer(idxBattler, try_cheer.command_index)
	PBDebug.log("     'useCheer': #{battler.name} (#{battler.index}) set to use #{try_cheer.name}")
  }
)

#-------------------------------------------------------------------------------
# Changes the value of a raid counter.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_triggers, "raidCounter",
  proc { |battle, idxBattler, idxTarget, params|
	foe = battle.battlers[1]
	next if !battle.raidBattle? || !foe || !params.is_a?(Array)
    case params[0]
	when :turn_count
	  PBDebug.log("     'raidCounter': Turn counter changed")
	  battle.pbRaidChangeTurnCount(foe, params[1])
	when :ko_count
	  done_fainting = true
      battle.battlers.each do |b|
        next if !b || !b.opposes?(foe) || b.hp > 0 || b.fainted
        done_fainting = false
      end
	  PBDebug.log("     'raidCounter': KO counter changed")
	  battle.pbRaidChangeKOCount(foe, params[1], done_fainting)
	end
  }
)

#-------------------------------------------------------------------------------
# Initiates a raid shield, or changes the HP of a current raid shield.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_triggers, "raidShield",
  proc { |battle, idxBattler, idxTarget, params|
	battler = battle.battlers[idxBattler]
	next if !battler || !battler.opposes? || battler.fainted? 
	next if battle.pbAllFainted? || battle.decision > 0
	if battler.shieldHP == 0
	  next if params <= 0
	  battler.startRaidShield(params)
      PBDebug.log("     'raidShield': Initiated raid shield") if battler.shieldHP > 0
	else
	  battler.setRaidShieldHP(params)
      PBDebug.log("     'raidShield': Raid shield HP changed")
	end
  }
)

#-------------------------------------------------------------------------------
# Forces a raid Pokemon to use a certain raid action.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_triggers, "raidAction",
  proc { |battle, idxBattler, idxTarget, params|
    foe = battle.battlers[1]
	next if !battle.raidBattle? || !foe || foe.fainted?
	next if battle.pbAllFainted? || battle.decision > 0
	case params
	when :reset_drops
	  PBDebug.log("     'raidAction': Triggered extra raid action (reset drops)")
	  battle.pbRaidResetDrops(foe)
	when :reset_boosts
	  PBDebug.log("     'raidAction': Triggered extra raid action (reset boosts)")
	  battle.pbRaidResetBoosts(foe)
	when :drain_cheer
	  PBDebug.log("     'raidAction': Triggered extra raid action (drain cheer)")
	  battle.pbRaidDrainCheer(foe)
	end
  }
)