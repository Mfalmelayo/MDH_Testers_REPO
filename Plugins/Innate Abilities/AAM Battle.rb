class Battle

  alias aam_pbCanSwitch? pbCanSwitch?
  def pbCanSwitch?(idxBattler, idxParty = -1, partyScene = nil)
    $aam_trapping=false

    aam_switch =  aam_pbCanSwitch?(idxBattler, idxParty, partyScene)

    $aam_trapping=true
    battler = @battlers[idxBattler]
    # Trapping abilities for All Abilities Mutation
    allOtherSideBattlers(idxBattler).each do |b|
      next if !b.abilityActive?
      if Battle::AbilityEffects.triggerTrappingByTarget(b.ability, battler, b, self)
		$aamName = b.abilityName
        partyScene&.pbDisplay(_INTL("{1}'s {2} prevents switching!",
                                    b.pbThis, $aamName))
        return false
      end
    end
    return aam_switch
  end

  alias aam_pbCanRun? pbCanRun?
  def pbCanRun?(idxBattler)
    $aam_trapping=true
    return aam_pbCanRun?(idxBattler)
  end  
  
  alias_method :original_pbShowAbilitySplash, :pbShowAbilitySplash
  def pbShowAbilitySplash(battler, delay = false, logTrigger = true)
  puts "[pbShowAbilitySplash] Battler ability: #{battler.abilityName}"
  if battler.ability
    puts "[pbShowAbilitySplash] Setting $aamName to #{battler.abilityName}"
    $aamName = battler.abilityName
  end
  puts "[pbShowAbilitySplash] $aamName is now: #{$aamName}, $aamName2 is: #{$aamName2}"

  original_pbShowAbilitySplash(battler, delay, logTrigger)
  puts "[pbShowAbilitySplash] After original call: $aamName is: #{$aamName}, $aamName2 is: #{$aamName2}"
  end
  
  #Code for once per use abilities by penelope=================================================
  attr_accessor :abils_triggered

  alias fix_initialize initialize
  def initialize(scene, p1, p2, player, opponent)
    fix_initialize(scene, p1, p2, player, opponent)
    @abils_triggered  = [Array.new(@party1.length) { [] }, Array.new(@party2.length) { [] }]
  end

  def pbAbilityTriggered?(battler, check_ability)
    return @abils_triggered[battler.index & 1][battler.pokemonIndex].include?(check_ability)
  end

  def pbSetAbilityTrigger(battler, check_ability)
    @abils_triggered[battler.index & 1][battler.pokemonIndex].push(check_ability)
  end

  def switch_limit_ability_trigger?(battler, check_ability)
    if battler.effects[PBEffects::OneUseAbility].include?(check_ability)
      return true
    elsif switch_limit_ability(battler).include?(check_ability)
      battler.effects[PBEffects::OneUseAbility].push(check_ability)
      return false
    end
  end

  def battle_limit_ability_trigger?(battler, check_ability)
    if pbAbilityTriggered?(battler, check_ability)
      return true
    elsif battle_limit_ability(battler).include?(check_ability)
      pbSetAbilityTrigger(battler, check_ability)
      return false
    end
  end

  def switch_limit_ability(battler) # add once per switch ability here
    ret = [:EMBODYASPECT, :EMBODYASPECT_1, :EMBODYASPECT_2, :EMBODYASPECT_3,
           :INTIMIDATE,
           :SCARE]
    #ret = [] if !battler.pbOwnedByPlayer?
    return ret
  end

  def battle_limit_ability(battler) # add once per battle ability here
    ret = [:EMBODYASPECT, :EMBODYASPECT_1, :EMBODYASPECT_2, :EMBODYASPECT_3,
           :INTIMIDATE,
           :SCARE]
    #ret = [] if !battler.pbOwnedByPlayer?
    return ret
  end
  #===============================================================
  
end  