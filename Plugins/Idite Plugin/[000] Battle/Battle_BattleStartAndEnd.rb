#=============================================================================
# End of battle - Money Gain Handling
# This is for Endless Greed
#=============================================================================
def pbGainMoney
    return if !@internalBattle || !@moneyGain
    # Money rewarded from opposing trainers
    if trainerBattle?
      tMoney = 0
      @opponent.each_with_index do |t, i|
        tMoney += pbMaxLevelInTeam(1, i) * t.base_money
      end
      # Double money for specific field effects
      tMoney *= 2 if @field.effects[PBEffects::AmuletCoin]
      tMoney *= 2 if @field.effects[PBEffects::HappyHour]
      # Double money if any battler has Endless Greed
      eachBattler do |battler|
        if battler.hasActiveAbility?(:ENDLESSGREED)
          tMoney *= 2 # This is the money gain multipiler.
          break
        end
      end
      oldMoney = pbPlayer.money
      pbPlayer.money += tMoney
      moneyGained = pbPlayer.money - oldMoney
      if moneyGained > 0
        $stats.battle_money_gained += moneyGained
        pbDisplayPaused(_INTL("You got ${1} for winning!", moneyGained.to_s_formatted))
      end
    end
    # Pick up money scattered by Pay Day
    if @field.effects[PBEffects::PayDay] > 0
      @field.effects[PBEffects::PayDay] *= 2 if @field.effects[PBEffects::AmuletCoin]
      @field.effects[PBEffects::PayDay] *= 2 if @field.effects[PBEffects::HappyHour]
      # Double money from Pay Day if any battler has ENDLESSGREED ability
      # The reason we don't format this like the two above is because we have to
      # parse each battler to check for the ability. 
      eachBattler do |battler|
        if battler.hasActiveAbility?(:ENDLESSGREED)
          @field.effects[PBEffects::PayDay] *= 2
          break
        end
      end
      oldMoney = pbPlayer.money
      pbPlayer.money += @field.effects[PBEffects::PayDay]
      moneyGained = pbPlayer.money - oldMoney
      if moneyGained > 0
        $stats.battle_money_gained += moneyGained
        pbDisplayPaused(_INTL("You picked up ${1}!", moneyGained.to_s_formatted))
      end
    end
  end
  