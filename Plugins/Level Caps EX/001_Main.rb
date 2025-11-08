#-------------------------------------------------------------------------------
# Hard Level Cap related Additions
#-------------------------------------------------------------------------------
class Pokemon
  def level=(value)
    validate value => Integer
    if value < 1 || value > GameData::GrowthRate.max_level
      max_lvl = GameData::GrowthRate.max_level
      limit = (value < 1)? ["below the minimum  of level 1", "1"] : ["above the maximum of level #{max_lvl}", max_lvl.to_s]
      echoln _INTL("Level {1} for {2} is not a valid level as it goes {3}. The level has been reset to {4}",
                    value, self, limit[0], limit[1])
      value.clamp(1, GameData::GrowthRate.max_level)
    end
    @exp = growth_rate.minimum_exp_for_level(value)
    @level = value
  end

  def crosses_level_cap?
    return LevelCapsEX.soft_cap? && self.level >= LevelCapsEX.level_cap
  end

  def level
    @level = growth_rate.level_from_exp(@exp) if !@level
    self.level = GameData::GrowthRate.max_level if @level > GameData::GrowthRate.max_level
    return @level
  end
end

module GameData
  class GrowthRate
    def self.max_level
      return LevelCapsEX.hard_level_cap
    end
  end
end

#-------------------------------------------------------------------------------
# Soft Level Cap related Additions
#-------------------------------------------------------------------------------
class Battle

  def pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages = true)
    pkmn = pbParty(0)[idxParty]   # The Pokémon gaining Exp from defeatedBattler
    growth_rate = pkmn.growth_rate
    # Don't bother calculating if gainer is already at max Exp
    if pkmn.exp >= growth_rate.maximum_exp
      pkmn.calc_stats   # To ensure new EVs still have an effect
      return
    end
    isPartic    = defeatedBattler.participants.include?(idxParty)
    hasExpShare = expShare.include?(idxParty)
    level = defeatedBattler.level
    # Main Exp calculation
    exp = 0
    a = level * defeatedBattler.pokemon.base_exp
    if expShare.length > 0 && (isPartic || hasExpShare)
      if numPartic == 0   # No participants, all Exp goes to Exp Share holders
        exp = a / (Settings::SPLIT_EXP_BETWEEN_GAINERS ? expShare.length : 1)
      elsif Settings::SPLIT_EXP_BETWEEN_GAINERS   # Gain from participating and/or Exp Share
        exp = a / (2 * numPartic) if isPartic
        exp += a / (2 * expShare.length) if hasExpShare
      else   # Gain from participating and/or Exp Share (Exp not split)
        exp = (isPartic) ? a : a / 2
      end
    elsif isPartic   # Participated in battle, no Exp Shares held by anyone
      exp = a / (Settings::SPLIT_EXP_BETWEEN_GAINERS ? numPartic : 1)
    elsif expAll   # Didn't participate in battle, gaining Exp due to Exp All
      # NOTE: Exp All works like the Exp Share from Gen 6+, not like the Exp All
      #       from Gen 1, i.e. Exp isn't split between all Pokémon gaining it.
      exp = a / 2
    end
    return if exp <= 0
    # Pokémon gain more Exp from trainer battles
    exp = (exp * 1.5).floor if Settings::MORE_EXP_FROM_TRAINER_POKEMON && trainerBattle?
    # Scale the gained Exp based on the gainer's level (or not)
    if Settings::SCALED_EXP_FORMULA
      exp /= 5
      levelAdjust = ((2 * level) + 10.0) / (pkmn.level + level + 10.0)
      levelAdjust **= 5
      levelAdjust = Math.sqrt(levelAdjust)
      exp *= levelAdjust
      exp = exp.floor
      exp += 1 if isPartic || hasExpShare
    else
      exp /= 7
    end
    # Foreign Pokémon gain more Exp
    isOutsider = (pkmn.owner.id != pbPlayer.id ||
                 (pkmn.owner.language != 0 && pkmn.owner.language != pbPlayer.language))
    if isOutsider
      if pkmn.owner.language != 0 && pkmn.owner.language != pbPlayer.language
        exp = (exp * 1.7).floor
      else
        exp = (exp * 1.5).floor
      end
    end
    # Exp. Charm increases Exp gained
    exp = exp * 3 / 2 if $bag.has?(:EXPCHARM)
    # Modify Exp gain based on pkmn's held item
    i = Battle::ItemEffects.triggerExpGainModifier(pkmn.item, pkmn, exp)
    if i < 0
      i = Battle::ItemEffects.triggerExpGainModifier(@initialItems[0][idxParty], pkmn, exp)
    end
    exp = i if i >= 0
    # Boost Exp gained with high affection
    if Settings::AFFECTION_EFFECTS && @internalBattle && pkmn.affection_level >= 4 && !pkmn.mega?
      exp = exp * 6 / 5
      isOutsider = true   # To show the "boosted Exp" message
    end
    # Modify exp gain based on soft level cap
    over_level_cap = false
    if pkmn.crosses_level_cap? && LevelCapsEX.level_cap_mode == 2
      over_level_cap = true
      exp = (exp / 10).to_i
      exp = 1 if exp < 1
    end
    # Make sure Exp doesn't exceed the maximum
    expFinal = growth_rate.add_exp(pkmn.exp, exp)
    expGained = expFinal - pkmn.exp
    return if expGained <= 0
    # "Exp gained" message
    if showMessages
      message = _INTL("{1} got {2} Exp. Points!")
      message = _INTL("{1} got a boosted {2} Exp. Points!") if isOutsider
      message = _INTL("{1} got a reduced {2} Exp. Points!") if over_level_cap
      pbDisplayPaused(_INTL(message, pkmn.name, expGained))
    end
    curLevel = pkmn.level
    newLevel = growth_rate.level_from_exp(expFinal)
    if newLevel < curLevel
      debugInfo = "Levels: #{curLevel}->#{newLevel} | Exp: #{pkmn.exp}->#{expFinal} | gain: #{expGained}"
      raise _INTL("{1}'s new level is less than its current level, which shouldn't happen.", pkmn.name) + "\n[#{debugInfo}]"
    end
    # Give Exp
    if pkmn.shadowPokemon?
      if pkmn.heartStage <= 3
        pkmn.exp += expGained
        $stats.total_exp_gained += expGained
      end
      return
    end
    $stats.total_exp_gained += expGained
    tempExp1 = pkmn.exp
    battler = pbFindBattler(idxParty)
    loop do   # For each level gained in turn...
      # EXP Bar animation
      levelMinExp = growth_rate.minimum_exp_for_level(curLevel)
      levelMaxExp = growth_rate.minimum_exp_for_level(curLevel + 1)
      tempExp2 = (levelMaxExp < expFinal) ? levelMaxExp : expFinal
      pkmn.exp = tempExp2
      @scene.pbEXPBar(battler, levelMinExp, levelMaxExp, tempExp1, tempExp2)
      tempExp1 = tempExp2
      curLevel += 1
      if curLevel > newLevel
        # Gained all the Exp now, end the animation
        pkmn.calc_stats
        battler&.pbUpdate(false)
        @scene.pbRefreshOne(battler.index) if battler
        break
      end
      # Levelled up
      pbCommonAnimation("LevelUp", battler) if battler
      oldTotalHP = pkmn.totalhp
      oldAttack  = pkmn.attack
      oldDefense = pkmn.defense
      oldSpAtk   = pkmn.spatk
      oldSpDef   = pkmn.spdef
      oldSpeed   = pkmn.speed
      battler.pokemon.changeHappiness("levelup") if battler&.pokemon
      pkmn.calc_stats
      battler&.pbUpdate(false)
      @scene.pbRefreshOne(battler.index) if battler
      pbDisplayPaused(_INTL("{1} grew to Lv. {2}!", pkmn.name, curLevel)) { pbSEPlay("Pkmn level up") }
      @scene.pbLevelUp(pkmn, battler, oldTotalHP, oldAttack, oldDefense,
                       oldSpAtk, oldSpDef, oldSpeed)
      # Learn all moves learned at this level
      moveList = pkmn.getMoveList
      moveList.each { |m| pbLearnMove(idxParty, m[1]) if m[0] == curLevel }
    end
  end
end

#-------------------------------------------------------------------------------
# Obedience Related Level Cap Additions
#-------------------------------------------------------------------------------
class Battle::Battler

  alias __level_cap__pbObedienceCheck? pbObedienceCheck? unless method_defined?(:__level_cap__pbObedienceCheck?)
  def pbObedienceCheck?(*args)
    ret = __level_cap__pbObedienceCheck?(*args)
    db = @disobeyed
    @disobeyed = false
    return ret if ret || db
    # Level Cap Disobedience checks
    return true if LevelCapsEX.level_cap_mode != 3
    lv_diff = @level - LevelCapsEX.level_cap
    lv_diff = 5 if lv_diff >= 5
    disobedient = rand(5 - lv_diff) == 0
    return pbDisobey(args[0], (lv_diff * 2)) if lv_diff >= 5 || disobedient
    return true
  end

  alias __level_cap__pbDisobey pbDisobey unless method_defined?(:__level_cap__pbDisobey)
  def pbDisobey(*args)
    ret = __level_cap__pbDisobey(*args)
    @disobeyed = true
    return ret
  end
end