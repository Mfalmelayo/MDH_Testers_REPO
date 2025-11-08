#=================================================
# Bad Company
# Prevents self-lowering stats and recoil damage.
#=================================================
class Battle::Move::RecoilMove < Battle::Move
  def pbEffectAfterAllHits(user, target)
    return if target.damageState.unaffected
    return if !user.takesIndirectDamage?
    return if user.hasActiveAbility?(:ROCKHEAD)
	return if user.hasActiveAbility?(:BADCOMPANY)
    amt = pbRecoilDamage(user, target)
    amt = 1 if amt < 1
    user.stopBoostedHPScaling = true 
    user.pbReduceHP(amt, false)
    @battle.pbDisplay(_INTL("{1} is damaged by recoil!", user.pbThis))
    user.pbItemHPHealCheck
  end
end

class Battle::Move::StatDownMove < Battle::Move
  attr_reader :statDown

  def pbEffectWhenDealingDamage(user, target)
    return if @battle.pbAllFainted?(target.idxOwnSide)
    showAnim = true
    (@statDown.length / 2).times do |i|
      next if !user.pbCanLowerStatStage?(@statDown[i * 2], user, self)
	    next if user.hasActiveAbility?(:BADCOMPANY)
      if user.pbLowerStatStage(@statDown[i * 2], @statDown[(i * 2) + 1], user, showAnim)
        showAnim = false
      end
    end
  end
end
class Battle::Move::UserTargetSwapItems < Battle::Move
  def pbEffectAgainstTarget(user, target)
    oldUserItem = user.item
    oldUserItemName = user.itemName
    oldTargetItem = target.item
    oldTargetItemName = target.itemName
    user.item                             = oldTargetItem
    user.effects[PBEffects::ChoiceBand]   = nil if !user.hasActiveAbility?([:GORILLATACTICS,:SAGEPOWER])
    user.effects[PBEffects::Unburden]     = (!user.item && oldUserItem) if user.hasActiveAbility?(:UNBURDEN)
    target.item                           = oldUserItem
    target.effects[PBEffects::ChoiceBand] = nil if !target.hasActiveAbility?([:GORILLATACTICS,:SAGEPOWER])
    target.effects[PBEffects::Unburden]   = (!target.item && oldTargetItem) if target.hasActiveAbility?(:UNBURDEN)
    # Permanently steal the item from wild Pokémon
    if target.wild? && !user.initialItem && oldTargetItem == target.initialItem
      user.setInitialItem(oldTargetItem)
    end
    @battle.pbDisplay(_INTL("{1} switched items with its opponent!", user.pbThis))
    @battle.pbDisplay(_INTL("{1} obtained {2}.", user.pbThis, oldTargetItemName)) if oldTargetItem
    @battle.pbDisplay(_INTL("{1} obtained {2}.", target.pbThis, oldUserItemName)) if oldUserItem
    user.pbHeldItemTriggerCheck
    target.pbHeldItemTriggerCheck
  end
end
class Battle::Move
#=================================================
# ORAORAORAORA!
# Punch move hit a second time for 50% damage.
#=================================================
def pbNumHits(user, targets)
    if (user.hasActiveAbility?(:PARENTALBOND) && pbDamagingMove? &&
       !chargingTurnMove? && targets.length == 1) || 
       (user.hasActiveAbility?(:ORAORAORAORA) && punchingMove?)
      # Record that Parental Bond applies, to weaken the second attack
      user.effects[PBEffects::ParentalBond] = 3
      return 2
    end
    return 1
  end
def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    args = [user, target, numTargets, type, baseDmg]
    pbCalcDamageMults_Global(*args, multipliers)
    pbCalcDamageMults_Abilities(*args, multipliers)
    pbCalcDamageMults_Items(*args, multipliers)
    if user.effects[PBEffects::ParentalBond] == 1
	  if user.hasActiveAbility?(:PARENTALBOND)
      multipliers[:power_multiplier] /= (Settings::MECHANICS_GENERATION >= 7) ? 4 : 2
	  elsif user.hasActiveAbility?(:ORAORAORAORA)
	  multipliers[:power_multiplier] /= 2
	  end
    end
    pbCalcDamageMults_Other(*args, multipliers)
    pbCalcDamageMults_Field(*args, multipliers)
    pbCalcDamageMults_Badges(*args, multipliers)
    multipliers[:final_damage_multiplier] *= 0.75 if numTargets > 1
    pbCalcDamageMults_Weather(*args, multipliers)
    pbCalcDamageMults_Random(*args, multipliers)
    pbCalcDamageMults_Type(*args, multipliers)
    pbCalcDamageMults_Status(*args, multipliers)
    pbCalcDamageMults_Screens(*args, multipliers)
    if target.effects[PBEffects::Minimize] && tramplesMinimize?
      multipliers[:final_damage_multiplier] *= 2
    end
    if defined?(PBEffects::GlaiveRush) && target.effects[PBEffects::GlaiveRush] > 0
      multipliers[:final_damage_multiplier] *= 2 
    end
    multipliers[:power_multiplier] = pbBaseDamageMultiplier(multipliers[:power_multiplier], user, target)
    multipliers[:final_damage_multiplier] = pbModifyDamage(multipliers[:final_damage_multiplier], user, target)
  end
#=================================================
# Bone Zone 
# Bone moves ignore immunities and resistances.
#=================================================
def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = Effectiveness.calculate(moveType, defType)
    if Effectiveness.ineffective_type?(moveType, defType)
      # Ring Target
      if target.hasActiveItem?(:RINGTARGET)
        ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
	  if user.hasActiveAbility?(:BONEZONE) && self.boneMove?
	    ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
	  end
      # Foresight
      if (user.hasActiveAbility?(:SCRAPPY) || target.effects[PBEffects::Foresight]) &&
         defType == :GHOST
        ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
      # Miracle Eye
      if target.effects[PBEffects::MiracleEye] && defType == :DARK
        ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
    elsif Effectiveness.super_effective_type?(moveType, defType)
      # Delta Stream's weather
      if target.effectiveWeather == :StrongWinds && defType == :FLYING
        ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
	elsif Effectiveness.not_very_effective_type?(moveType, defType)
	  if user.hasActiveAbility?(:BONEZONE) && self.boneMove?
	    ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
	  end
    end
    # Grounded Flying-type Pokémon become susceptible to Ground moves
    if !target.airborne? && defType == :FLYING && moveType == :GROUND
      ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end
    return ret
  end
# New Move Flags for Radical Red abilities.
def poisoningMove?; return false; end
def kickMove?; return @flags.any? { |f| f[/^Kick$/i] };  end
def boneMove?; return @flags.any? { |f| f[/^Bone$/i] };  end
end
=begin
#=================================================
NOW DEFINED IN SCRIPT EDITOR IN-GAME
# Frozen Mist
# Stop additional effects and entry hazard damage.
#=================================================
def pbAdditionalEffectChance(user, target, effectChance = 0)
    return 0 if @battle.pbCheckGlobalAbility(:FROZENMIST)
    return 0 if target.hasActiveAbility?([:SHIELDDUST,:FROZENMIST]) && !@battle.moldBreaker
    ret = (effectChance > 0) ? effectChance : @addlEffect
    return ret if ret > 100
    if (Settings::MECHANICS_GENERATION >= 6 || @function_code != "EffectDependsOnEnvironment") &&
       (user.hasActiveAbility?(:SERENEGRACE) || user.pbOwnSide.effects[PBEffects::Rainbow] > 0)
      ret *= 2
    end
    ret = 100 if $DEBUG && Input.press?(Input::CTRL)
    return ret
  end
def pbFlinchChance(user, target)
    return 0 if flinchingMove?
    return 0 if target.hasActiveAbility?([:SHIELDDUST,:FROZENMIST]) && !@battle.moldBreaker
    ret = 0
    if user.hasActiveAbility?(:STENCH, true) ||
       user.hasActiveItem?([:KINGSROCK, :RAZORFANG], true)
      ret = 10
    end
    ret *= 2 if user.hasActiveAbility?(:SERENEGRACE) ||
                user.pbOwnSide.effects[PBEffects::Rainbow] > 0
    return ret
  end
end
=end
class Battle::Move

#=================================================
# Circuit Phantom Handler
# Electric is super-effective on Steel Types
#=================================================
  alias paldea_pbCalcTypeModSingle pbCalcTypeModSingle
    def pbCalcTypeModSingle(moveType, defType, user, target)
      # Get the initial effectiveness value
      ret = paldea_pbCalcTypeModSingle(moveType, defType, user, target)
      # Check if the user has the Circuit Phantom ability
        if user.hasActiveAbility?(:CIRCUITPHANTOM)
          # Check if the move is Electric-type and the defending type is Steel-type
          if moveType == :ELECTRIC && defType == :STEEL
           # Set the damage multiplier to super-effective
           ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
          end
       end
    return ret
  end

#=================================================
# Water Purification Handler
# Water is super-effective on Poison Types
#=================================================
    def pbCalcTypeModSingle(moveType, defType, user, target)
      ret = paldea_pbCalcTypeModSingle(moveType, defType, user, target)
        if user.hasActiveAbility?(:PURIFY)
          if moveType == :WATER && defType == :POISON
           ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
          end
       end
    return ret
  end

#=================================================
# Molten Slag Handler
# Fire is super-effective on Rock Types
#=================================================
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = paldea_pbCalcTypeModSingle(moveType, defType, user, target)
      if user.hasActiveAbility?(:MOLTENSLAG)
        if moveType == :FIRE && defType == :ROCK
         ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
        end
     end
  return ret
end

#=================================================
# Corrosion Handler
# Fire is super-effective on Rock Types
#=================================================
def pbCalcTypeModSingle(moveType, defType, user, target)
  ret = paldea_pbCalcTypeModSingle(moveType, defType, user, target)
    if user.hasActiveAbility?(:CORROSION)
      if moveType == :POISON && defType == :STEEL
       ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
   end
return ret
end


#=================================================
# Volcanic Wrath Handlers
# Fire is super-effective on Rock & Ground Types
#=================================================
def pbCalcTypeModSingle(moveType, defType, user, target)
  ret = paldea_pbCalcTypeModSingle(moveType, defType, user, target)
    if user.hasActiveAbility?(:VOLCANICWRATH)
      if moveType == :FIRE && defType == :ROCK
       ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
   end
return ret
end
def pbCalcTypeModSingle(moveType, defType, user, target)
  ret = paldea_pbCalcTypeModSingle(moveType, defType, user, target)
    if user.hasActiveAbility?(:VOLCANICWRATH)
      if moveType == :FIRE && defType == :GROUND
       ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
   end
return ret
end


end
