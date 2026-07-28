#===============================================================================
# Sturdy's ability splash displayed properly
#===============================================================================
class Battle::Move
  def pbEndureKOMessage(target)
    if target.damageState.disguise
      @battle.pbShowAbilitySplash(target, false, true, :DISGUISE)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL(
          "{1}'s disguise served it as a decoy!",
          target.pbThis
        ))
      else
        @battle.pbDisplay(_INTL(
          "{1}'s disguise served it as a decoy!",
          target.pbThis
        ))
      end
      @battle.pbHideAbilitySplash(target)

      if target.isSpecies?(:MIMIKYU)
        target.pbChangeForm(
          1,
          _INTL("{1}'s disguise was busted!", target.pbThis)
        )
      else
        @battle.pbDisplay(_INTL(
          "{1}'s disguise was busted!",
          target.pbThis
        ))
        target.disguiseFace = false
      end

      if Settings::MECHANICS_GENERATION >= 8
        target.pbReduceHP(target.totalhp / 8, false)
      end

    elsif target.damageState.iceFace
      @battle.pbShowAbilitySplash(target, false, true, :ICEFACE)

      if !Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1}'s Ice Face activated!", target.pbThis))
      end

      if target.isSpecies?(:EISCUE)
        target.pbChangeForm(
          1,
          _INTL("{1} transformed!", target.pbThis)
        )
      else
        target.disguiseFace = false
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
      @battle.pbDisplay(_INTL(
        "{1} hung on using its Focus Sash!",
        target.pbThis
      ))
      target.pbConsumeItem

    elsif target.damageState.focusBand
      @battle.pbCommonAnimation("UseItem", target)
      @battle.pbDisplay(_INTL(
        "{1} hung on using its Focus Band!",
        target.pbThis
      ))

    elsif target.damageState.affection_endured
      @battle.pbDisplay(_INTL(
        "{1} toughed it out so you wouldn't feel sad!",
        target.pbThis
      ))
    end
  end
end

# Intercepts the game data to properly handle multiple abilities in checks which
# accidentally receive a MultiAbilityProxy. This MUST unwrap recursively, because
# older versions of this file could accidentally create proxy-inside-proxy values.
module GameData
  class Ability
    class << self
      unless method_defined?(:innates_proxy_original_get)
        alias innates_proxy_original_get get
      end

      unless method_defined?(:innates_proxy_original_try_get)
        alias innates_proxy_original_try_get try_get
      end

      def innate_proxy_unwrap_id(id)
        while defined?(MultiAbilityProxy) && id.is_a?(MultiAbilityProxy)
          id = id.primary
        end
        return id
      end

      def get(id)
        id = innate_proxy_unwrap_id(id)
        return innates_proxy_original_get(id)
      end

      def try_get(id)
        id = innate_proxy_unwrap_id(id)
        return innates_proxy_original_try_get(id)
      end
    end
  end
end

# Proxy to handle multiple abilities for equality-style checks.
# Important: @primary must always be the real main Ability Symbol, not another
# MultiAbilityProxy.
class MultiAbilityProxy
  attr_reader :battler, :primary

  def initialize(battler, primary_ability)
    @battler = battler
    while defined?(MultiAbilityProxy) && primary_ability.is_a?(MultiAbilityProxy)
      primary_ability = primary_ability.primary
    end
    @primary = primary_ability
  end

  def id; @primary; end
  def to_sym; @primary; end
  def to_s; @primary.to_s; end
  def hash; @primary.hash; end
  def eql?(other); self == other; end

  def is_a?(klass)
    return true if klass == Symbol
    super
  end

  def ==(other)
    return false if other.nil?
    target_id = case other
                when Symbol then other
                when GameData::Ability then other.id
                when String then other.to_sym
                when MultiAbilityProxy then other.primary
                else return false
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
  def method_missing(m, *args, &block)
    data = GameData::Ability.try_get(@primary)
    if data && data.respond_to?(m)
      return data.send(m, *args, &block)
    end
    super
  end

  def respond_to_missing?(m, include_private = false)
    data = GameData::Ability.try_get(@primary)
    (data && data.respond_to?(m, include_private)) || super
  end
end

#===============================================================================
# Battler ability proxy
#-------------------------------------------------------------------------------
# The old version called the original Battle::Battler#ability method here.
# In Essentials, that original method calls self.ability_id internally. Since this
# plugin also proxies ability_id, that can feed a MultiAbilityProxy back into
# GameData::Ability.try_get and recurse through validation until stack overflow.
#
# Fix: build the proxy directly from the original ability_id Symbol instead of
# calling the original ability method.
#===============================================================================
class Battle::Battler
  unless method_defined?(:innates_proxy_original_ability_id)
    alias innates_proxy_original_ability_id ability_id
  end

  def innate_proxy_raw_ability_id
    ret = innates_proxy_original_ability_id
    while defined?(MultiAbilityProxy) && ret.is_a?(MultiAbilityProxy)
      ret = ret.primary
    end
    return ret
  end

  def innate_proxy_for(primary_ability, forced = false)
    return nil if primary_ability.nil?
    primary_ability = primary_ability.primary if primary_ability.is_a?(MultiAbilityProxy)
    if forced
      return @__forced_ability_proxy if @__forced_ability_proxy&.primary == primary_ability
      return @__forced_ability_proxy = MultiAbilityProxy.new(self, primary_ability)
    end
    return @__ability_proxy if @__ability_proxy&.primary == primary_ability
    return @__ability_proxy = MultiAbilityProxy.new(self, primary_ability)
  end

  def ability_id
    # During an ability splash, show the forced splash ability if one exists.
    if @forcedSplashAbilityStack && !@forcedSplashAbilityStack.empty?
      return innate_proxy_for(@forcedSplashAbilityStack.last, true)
    end
    return innate_proxy_for(innate_proxy_raw_ability_id)
  end

  def ability
    # Do NOT call the original ability method here. See note above.
    if @forcedSplashAbilityStack && !@forcedSplashAbilityStack.empty?
      return innate_proxy_for(@forcedSplashAbilityStack.last, true)
    end
    return innate_proxy_for(innate_proxy_raw_ability_id)
  end
end

#===============================================================================
# Do NOT proxy Pokemon#ability_id.
# Breaks the shit out of Overworld Abilities
#===============================================================================
class Pokemon
  def innate_aware_ability_ids
    ret = []
    ret.push(self.ability_id) if self.ability_id

    if self.respond_to?(:unlocked_innates)
      ret.concat(self.unlocked_innates || [])
    elsif self.respond_to?(:active_innates)
      ret.concat(self.active_innates || [])
    end

    ret.compact.uniq
  end

  def abilityAble?(ability)
    return false if !ability
    return true if self.hasAbility?(ability)
    return innate_aware_ability_ids.include?(ability)
  end
end

# For Wild Encounters
class PokemonEncounters
  def lead_has_encounter_ability?(pkmn, ability)
    return false if !pkmn
    return true if pkmn.ability_id == ability
    return true if pkmn.respond_to?(:abilityAble?) && pkmn.abilityAble?(ability)
    return false
  end
end