#===============================================================================
# Battle::Battler additions related to raid shields.
#===============================================================================
class Battle::Battler
  attr_accessor :shieldHP
  
  #-----------------------------------------------------------------------------
  # Aliased to initialize raid shield HP.
  #-----------------------------------------------------------------------------
  alias raid_pbInitEffects pbInitEffects
  def pbInitEffects(batonPass)
    raid_pbInitEffects(batonPass)
	@shieldHP = 0
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to make status moves fail on a raid Pokemon behind a raid shield.
  #-----------------------------------------------------------------------------
  alias raid_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    if target.hasRaidShield? && move.statusMove?
      @battle.pbDisplay(_INTL("The mysterious barrier protected {1}!", target.pbThis(true)))
      return false
    end
    return raid_pbSuccessCheckAgainstTarget(move, user, target, targets)
  end
  
  #-----------------------------------------------------------------------------
  # Returns true if the battler currently has a Raid shield.
  #-----------------------------------------------------------------------------
  def hasRaidShield?
    return false if !opposes? || fainted?
	return @shieldHP && @shieldHP > 0
  end
  
  #-----------------------------------------------------------------------------
  # Utility for starting a new raid shield.
  #-----------------------------------------------------------------------------
  def startRaidShield(shield_hp = 0)
    return if @battle.pbAllFainted? || @battle.decision > 0
    return if hasRaidShield?
	@battle.raidRules[:shield_hp] = shield_hp.clamp(0, 8) if !@battle.raidRules.has_key?(:shield_hp)
	return if !@battle.raidRules[:shield_hp] || @battle.raidRules[:shield_hp] <= 0
	@battle.scene.pbRefreshStyle(:Long) if !@battle.databoxStyle
	@battle.pbDisplay(_INTL("Energy has begun to gather around {1}!", pbThis(true)))
	@battle.pbAnimation(:REFLECT, self, self)
	@shieldHP = @battle.raidRules[:shield_hp]
	PBDebug.log("[Raid mechanics] #{pbThis(true)} #{@index} triggered its raid shield")
	@battle.scene.pbRefreshOne(@index)
	@battle.scene.pbAnimateRaidShield(self)
	@battle.pbDisplay(_INTL("A mysterious barrier appeared in front of {1}!", pbThis(true)))
	pbCureStatus
	@battle.pbDeluxeTriggers(@index, nil, "RaidShieldStart")
  end
  
  #-----------------------------------------------------------------------------
  # Utility for updating a raid shield's HP.
  #-----------------------------------------------------------------------------
  def setRaidShieldHP(amt, user = nil)
    return if !hasRaidShield?
	maxHP = @battle.raidRules[:shield_hp]
	oldShield = @shieldHP
	if $DEBUG && Input.press?(Input::CTRL)
	  amt = (amt > 0) ? maxHP : -maxHP
	elsif user && amt < 0
	  move = GameData::Move.try_get(user.lastMoveUsed)
	  if move && move.damaging?
	    amt -= 1 if user.pbOwnSide.effects[PBEffects::CheerOffense3] > 0
	    case @battle.raidRules[:style]
		#-----------------------------------------------------------------------
		# Basic Raids
		#-----------------------------------------------------------------------
		# Super Effective moves remove 1 extra bar of shield HP.
		when :Basic
		  amt -= 1 if Effectiveness.super_effective?(@damageState.typeMod)
		#-----------------------------------------------------------------------
		# Ultra Raids
		#-----------------------------------------------------------------------
		# Z-Moves remove 2 extra bars of shield HP. Doesn't stack with Ultra Burst.
		# Moves used by a Pokemon in Ultra Burst form remove an extra bar of shield HP.
	    when :Ultra
		  if !user.baseMoves.empty? && user.lastMoveUsedIsZMove && move.zMove?
		    amt -= 2
		  elsif user.ultra?
		    amt -= 1
		  end
		#-----------------------------------------------------------------------
		# Max Raids
		#-----------------------------------------------------------------------
		# Max Moves used by a Pokemon in Dynamax form remove an extra bar of shield HP.
		# G-Max moves used by a Gigantamax Pokemon remove an extra bar of shield HP.
	    when :Max
	      if !user.baseMoves.empty? && user.dynamax? && move.dynamaxMove?
		    amt -= 1
			amt -= 1 if user.gmax? && move.gmaxMove?
		  end
		#-----------------------------------------------------------------------
		# Tera Raids
		#-----------------------------------------------------------------------
		# Moves that match a Terastallized Pokemon's base typing remove an additional bar of shield HP.
		# Moves that match a Terastallized Pokemon's Tera Type remove an additional bar of shield HP.
	    when :Tera
	      if user.tera?
		    amt -= 1 if user.types.include?(user.lastMoveUsedType)
			amt -= 1 if user.typeTeraBoosted?(user.lastMoveUsedType)
		  end
	    end
	  end
	end
	@shieldHP += amt
	@shieldHP = maxHP if @shieldHP > maxHP
	@shieldHP = 0 if @shieldHP < 0
	return if @shieldHP == oldShield
	PBDebug.log("[Raid mechanics] #{pbThis(true)} #{@index}'s raid shield HP changed (#{oldShield} => #{@shieldHP})")
	@battle.scene.pbRefreshOne(@index)
	@battle.scene.pbAnimateRaidShield(self, oldShield)
	@battle.pbDeluxeTriggers(@index, nil, "RaidShieldDamaged") if @shieldHP > 0 && @shieldHP < oldShield
	return if @shieldHP > 0
	return if @battle.pbAllFainted? || @battle.decision > 0
	@battle.pbDisplay(_INTL("The mysterious barrier disappeared!"))
    oldhp = @hp
    @hp -= @totalhp / 8
	@hp = 1 if @hp <= 1
	@battle.scene.pbHPChanged(self, oldhp)
	[:DEFENSE, :SPECIAL_DEFENSE].each do |stat|
	  if pbCanLowerStatStage?(stat, self, nil, true)
		pbLowerStatStage(stat, 2, self, true, false, 0, true)
	  end
	end
	@battle.raidRules.delete(:shield_hp)
	@battle.pbDeluxeTriggers(@index, nil, "RaidShieldBroken")
  end
end

#===============================================================================
# Battle::Move additions related to raid shields.
#===============================================================================
class Battle::Move
  #-----------------------------------------------------------------------------
  # Aliased to reduce move damage on raid Pokemon behind a raid shield.
  #-----------------------------------------------------------------------------
  alias raid_pbCalcDamageMults_Screens pbCalcDamageMults_Screens
  def pbCalcDamageMults_Screens(user, target, numTargets, type, baseDmg, multipliers)
    raid_pbCalcDamageMults_Screens(user, target, numTargets, type, baseDmg, multipliers)
    if target.hasRaidShield?
      multipliers[:final_damage_multiplier] *= 0.05
    end
  end
end