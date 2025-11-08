  def pbLowerSpecialAttackStatStageIntimidate(user)
    return false if fainted?
    # NOTE: Substitute intentionally blocks Intimidate even if self has Contrary.
    if @effects[PBEffects::Substitute] > 0
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1} is protected by its substitute!", pbThis))
      else
        @battle.pbDisplay(_INTL("{1}'s substitute protected it from {2}'s {3}!",
                                pbThis, user.pbThis(true), user.abilityName))
      end
      return false
    end
    if Settings::MECHANICS_GENERATION >= 8 && hasActiveAbility?([:OBLIVIOUS, :OWNTEMPO, :INNERFOCUS, :SCRAPPY])
      @battle.pbShowAbilitySplash(self)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1}'s {2} cannot be lowered!", pbThis, GameData::Stat.get(:SPECIAL_ATTACK).name))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} prevents {3} loss!", pbThis, abilityName,
                                GameData::Stat.get(:SPECIAL_ATTACK).name))
      end
      @battle.pbHideAbilitySplash(self)
      return false
    end
    if Battle::Scene::USE_ABILITY_SPLASH
      return pbLowerStatStageByAbility(:SPECIAL_ATTACK, 1, user, false)
    end
    # NOTE: These checks exist to ensure appropriate messages are shown if
    #       Intimidate is blocked somehow (i.e. the messages should mention the
    #       Intimidate ability by name).
    if !hasActiveAbility?(:CONTRARY)
      if pbOwnSide.effects[PBEffects::Mist] > 0
        @battle.pbDisplay(_INTL("{1} is protected from {2}'s {3} by Mist!",
                                pbThis, user.pbThis(true), user.abilityName))
        return false
      end
      if abilityActive? &&
         (Battle::AbilityEffects.triggerStatLossImmunity(self.ability, self, :SPECIAL_ATTACK, @battle, false) ||
          Battle::AbilityEffects.triggerStatLossImmunityNonIgnorable(self.ability, self, :SPECIAL_ATTACK, @battle, false))
        @battle.pbDisplay(_INTL("{1}'s {2} prevented {3}'s {4} from working!",
                                pbThis, abilityName, user.pbThis(true), user.abilityName))
        return false
      end
      allAllies.each do |b|
        next if !b.abilityActive?
        if Battle::AbilityEffects.triggerStatLossImmunityFromAlly(b.ability, b, self, :SPECIAL_ATTACK, @battle, false)
          @battle.pbDisplay(_INTL("{1} is protected from {2}'s {3} by {4}'s {5}!",
                                  pbThis, user.pbThis(true), user.abilityName, b.pbThis(true), b.abilityName))
          return false
        end
      end
    end
    return false if !pbCanLowerStatStage?(:SPECIAL_ATTACK, user)
    return pbLowerStatStageByCause(:SPECIAL_ATTACK, 1, user, user.abilityName)
  end