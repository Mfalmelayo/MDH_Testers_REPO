#===============================================================================
# Generic Disguise/Ice Face state
#-------------------------------------------------------------------------------
# Mimikyu/Penny/PENNIES?!/Nickle/Tree Fiddy and Eiscue.
#===============================================================================
class Battle::Battler
  def innate_ability_face_state
    states = @battle.instance_variable_get(:@innateAbilityFaceStates)
    if !states
      states = {}
      @battle.instance_variable_set(:@innateAbilityFaceStates, states)
    end

    key = @pokemon || self
    states[key] ||= {
      :disguise => true,
      :ice_face => true
    }
    return states[key]
  end

  def disguiseFace
    return innate_ability_face_state[:disguise]
  end

  def disguiseFace=(value)
    innate_ability_face_state[:disguise] = !!value
  end

  def iceFace
    return innate_ability_face_state[:ice_face]
  end

  def iceFace=(value)
    innate_ability_face_state[:ice_face] = !!value
  end
end

#===============================================================================
# Allow Disguise and Ice Face to work as innate abilities on other species.
# Native users continue to use their form as the intact/broken state.
#===============================================================================
class Battle::Move
  def pbCheckDamageAbsorption(user, target)
    # Substitute will take the damage.
    if target.effects[PBEffects::Substitute] > 0 && !ignoresSubstitute?(user) &&
       (!user || user.index != target.index)
      target.damageState.substitute = true
      return
    end

    # Ice Face will take physical damage.
    if !@battle.moldBreaker && target.ability == :ICEFACE && physicalMove?
      ice_face_intact = if target.isSpecies?(:EISCUE)
                          target.form == 0
                        else
                          target.iceFace
                        end
      if ice_face_intact
        target.damageState.iceFace = true
        return
      end
    end

    # Disguise will take the damage.
    if !@battle.moldBreaker && target.ability == :DISGUISE
      native_disguise_user = target.isSpecies?(:MIMIKYU) ||
                             target.isSpecies?(:PENNY)
      disguise_intact = if native_disguise_user
                          target.form == 0
                        else
                          target.disguiseFace
                        end
      if disguise_intact
        target.damageState.disguise = true
        return
      end
    end
  end

  #=============================================================================
  # Sturdy's ability splash displayed properly, with generic Disguise/Ice Face
  # handling for species that do not have the native form changes.
  #=============================================================================
  def pbEndureKOMessage(target)
    if target.damageState.disguise
      @battle.pbShowAbilitySplash(target, false, true, :DISGUISE)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("Its disguise served it as a decoy!"))
      else
        @battle.pbDisplay(_INTL("{1}'s disguise served it as a decoy!", target.pbThis))
      end
      @battle.pbHideAbilitySplash(target)

      if target.isSpecies?(:MIMIKYU) || target.isSpecies?(:PENNY)
        target.pbChangeForm(
          1,
          _INTL("{1}'s disguise was busted!", target.pbThis)
        )
      else
        @battle.pbDisplay(
          _INTL("{1}'s disguise was busted!", target.pbThis)
        )
        target.disguiseFace = false
      end

      if Settings::MECHANICS_GENERATION >= 8
        target.pbReduceHP(target.totalhp / 8, false)
      end
    elsif target.damageState.iceFace
      @battle.pbShowAbilitySplash(target)
      if !Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(
          _INTL("{1}'s {2} activated!", target.pbThis, target.abilityName)
        )
      end

      if target.isSpecies?(:EISCUE)
        target.pbChangeForm(
          1,
          _INTL("{1} transformed!", target.pbThis)
        )
      else
        target.iceFace = false
      end
      @battle.pbHideAbilitySplash(target)
    elsif target.damageState.endured
      @battle.pbDisplay(_INTL("{1} endured the hit!", target.pbThis))
    elsif target.damageState.sturdy
      @battle.pbShowAbilitySplash(target, false, true, :STURDY)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1} endured the hit!", target.pbThis))
      else
        @battle.pbDisplay(_INTL("{1} hung on with Sturdy!", target.pbThis))
      end
      @battle.pbHideAbilitySplash(target)
    elsif target.damageState.focusSash
      @battle.pbCommonAnimation("UseItem", target)
      @battle.pbDisplay(
        _INTL("{1} hung on using its Focus Sash!", target.pbThis)
      )
      target.pbConsumeItem
    elsif target.damageState.focusBand
      @battle.pbCommonAnimation("UseItem", target)
      @battle.pbDisplay(
        _INTL("{1} hung on using its Focus Band!", target.pbThis)
      )
    elsif target.damageState.affection_endured
      @battle.pbDisplay(
        _INTL("{1} toughed it out so you wouldn't feel sad!", target.pbThis)
      )
    end
  end
end

#===============================================================================
# Intercepts the game data to properly handle multiple abilities in checks for
# ability.id or similar.
#===============================================================================
module GameData
  class Ability
    class << self
      unless method_defined?(:innates_proxy_original_get)
        alias innates_proxy_original_get get
      end

      unless method_defined?(:innates_proxy_original_try_get)
        alias innates_proxy_original_try_get try_get
      end

      def get(id)
        id = id.primary if id.is_a?(MultiAbilityProxy)
        return innates_proxy_original_get(id)
      end

      def try_get(id)
        id = id.primary if id.is_a?(MultiAbilityProxy)
        return innates_proxy_original_try_get(id)
      end
    end
  end
end

#===============================================================================
# Proxy to handle multiple abilities.
#===============================================================================
class MultiAbilityProxy
  attr_reader :battler, :primary

  def initialize(battler, primary_ability)
    @battler = battler
    @primary = primary_ability
  end

  def id; @primary; end
  def to_sym; @primary; end
  def to_s; @primary.to_s; end
  def hash; @primary.hash; end
  def eql?(other); self == other; end

  def is_a?(klass)
    return true if klass == Symbol
    return super
  end

  def ==(other)
    return false if other.nil?

    target_id = case other
                when Symbol
                  other
                when GameData::Ability
                  other.id
                when String
                  other.to_sym
                when MultiAbilityProxy
                  other.primary
                else
                  return false
                end

    return true if @primary == target_id

    if @battler.instance_variable_defined?(:@abilityMutationList)
      list = @battler.instance_variable_get(:@abilityMutationList)
      return true if list&.include?(target_id)
    end

    if @battler.respond_to?(:active_innates)
      list = @battler.active_innates
      return true if list&.include?(target_id)
    end

    return false
  end

  # Forward name/description calls to the primary ability data.
  def method_missing(method_name, *args, &block)
    data = GameData::Ability.try_get(@primary)
    if data && data.respond_to?(method_name)
      return data.send(method_name, *args, &block)
    end
    return super
  end

  def respond_to_missing?(method_name, include_private = false)
    data = GameData::Ability.try_get(@primary)
    return true if data && data.respond_to?(method_name, include_private)
    return super
  end
end

#===============================================================================
# Proxy Battle::Battler#ability_id and #ability, including forced splash
# abilities used by the ability splash system.
#===============================================================================
class Battle::Battler
  unless method_defined?(:innates_proxy_original_ability_id)
    alias innates_proxy_original_ability_id ability_id
  end

  def ability_id
    # During an ability splash, show the forced splash ability if one exists.
    if @forcedSplashAbilityStack && !@forcedSplashAbilityStack.empty?
      forced = @forcedSplashAbilityStack.last
      return nil if forced.nil?
      forced = forced.primary if forced.is_a?(MultiAbilityProxy)
      if @__forced_ability_proxy&.primary == forced
        return @__forced_ability_proxy
      end
      @__forced_ability_proxy = MultiAbilityProxy.new(self, forced)
      return @__forced_ability_proxy
    end

    result = innates_proxy_original_ability_id
    return nil if result.nil?
    result = result.primary if result.is_a?(MultiAbilityProxy)
    return @__ability_proxy if @__ability_proxy&.primary == result
    @__ability_proxy = MultiAbilityProxy.new(self, result)
    return @__ability_proxy
  end

  unless method_defined?(:innates_proxy_original_ability)
    alias innates_proxy_original_ability ability
  end

  def ability
    # During an ability splash, show the forced splash ability if one exists.
    if @forcedSplashAbilityStack && !@forcedSplashAbilityStack.empty?
      forced = @forcedSplashAbilityStack.last
      return nil if forced.nil?
      forced = forced.primary if forced.is_a?(MultiAbilityProxy)
      if @__forced_ability_proxy&.primary == forced
        return @__forced_ability_proxy
      end
      @__forced_ability_proxy = MultiAbilityProxy.new(self, forced)
      return @__forced_ability_proxy
    end

    result = innates_proxy_original_ability
    return nil if result.nil?
    result = result.primary if result.is_a?(MultiAbilityProxy)
    return @__ability_proxy if @__ability_proxy&.primary == result
    @__ability_proxy = MultiAbilityProxy.new(self, result)
    return @__ability_proxy
  end
end

#===============================================================================
# Do NOT proxy Pokemon#ability_id. Doing so breaks Overworld Abilities.
#===============================================================================
class Pokemon
  def innate_aware_ability_ids
    ret = []
    ret.push(self.ability_id) if self.ability_id

    if respond_to?(:unlocked_innates)
      ret.concat(unlocked_innates || [])
    elsif respond_to?(:active_innates)
      ret.concat(active_innates || [])
    end

    return ret.compact.uniq
  end

  def abilityAble?(ability)
    return false if !ability
    return true if hasAbility?(ability)
    return innate_aware_ability_ids.include?(ability)
  end
end

#===============================================================================
# Wild encounters.
#===============================================================================
class PokemonEncounters
  def lead_has_encounter_ability?(pkmn, ability)
    return false if !pkmn
    return true if pkmn.ability_id == ability
    if pkmn.respond_to?(:abilityAble?) && pkmn.abilityAble?(ability)
      return true
    end
    return false
  end
end
