class Battle
  attr_reader   :phoenixDown #For Phoenix Down Ability.
  
  alias rr_initialize initialize
  def initialize(scene, p1, p2, player, opponent)
    rr_initialize(scene, p1, p2, player, opponent)
    @phoenixDown = [Array.new(@party1.length, false), Array.new(@party2.length, false)]
  end
  
def pbEntryHazards(battler)
    battler_side = battler.pbOwnSide
    # Stealth Rock
    if battler_side.effects[PBEffects::StealthRock] && battler.takesIndirectDamage? &&
       GameData::Type.exists?(:ROCK) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS) &&
	   !battler.hasActiveAbility?([:FROZENMIST,:MOUNTAINEER])
      bTypes = battler.pbTypes(true)
      eff = Effectiveness.calculate(:ROCK, *bTypes)
      if !Effectiveness.ineffective?(eff)
        battler.pbReduceHP(battler.totalhp * eff / 8, false)
        pbDisplay(_INTL("Pointed stones dug into {1}!", battler.pbThis))
        battler.pbItemHPHealCheck
      end
    end
    # Spikes
    if battler_side.effects[PBEffects::Spikes] > 0 && battler.takesIndirectDamage? &&
       !battler.airborne? && !battler.hasActiveItem?(:HEAVYDUTYBOOTS) &&
	   !battler.hasActiveAbility?(:FROZENMIST)
      spikesDiv = [8, 6, 4][battler_side.effects[PBEffects::Spikes] - 1]
      battler.pbReduceHP(battler.totalhp / spikesDiv, false)
      pbDisplay(_INTL("{1} is hurt by the spikes!", battler.pbThis))
      battler.pbItemHPHealCheck
    end
    # Toxic Spikes
    if battler_side.effects[PBEffects::ToxicSpikes] > 0 && !battler.fainted? && !battler.airborne? && !battler.hasActiveAbility?(:FROZENMIST)
      if battler.pbHasType?(:POISON)
        battler_side.effects[PBEffects::ToxicSpikes] = 0
        pbDisplay(_INTL("{1} absorbed the poison spikes!", battler.pbThis))
      elsif battler.pbCanPoison?(nil, false) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS)
        if battler_side.effects[PBEffects::ToxicSpikes] == 2
          battler.pbPoison(nil, _INTL("{1} was badly poisoned by the poison spikes!", battler.pbThis), true)
        else
          battler.pbPoison(nil, _INTL("{1} was poisoned by the poison spikes!", battler.pbThis))
        end
      end
    end
    # Sticky Web
    if battler_side.effects[PBEffects::StickyWeb] && !battler.fainted? && !battler.airborne? &&
       !battler.hasActiveItem?(:HEAVYDUTYBOOTS) && !battler.hasActiveAbility?(:FROZENMIST)
      pbDisplay(_INTL("{1} was caught in a sticky web!", battler.pbThis))
      if battler.pbCanLowerStatStage?(:SPEED)
        battler.pbLowerStatStage(:SPEED, 1, nil)
        battler.pbItemStatRestoreCheck
      end
    end
  end
  end

