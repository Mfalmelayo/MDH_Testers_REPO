class Battle
  #attr_reader :ability_usage
  alias multi_ability_initialize initialize
  def initialize(scene, p1, p2, player, opponent)
    multi_ability_initialize(scene, p1, p2, player, opponent)
    @ability_usage = [{}, {}]
    @party1.each_index { |index| @ability_usage[0][index] = Hash.new { |hash, key| hash[key] = [0, -1] } }
    @party2.each_index { |index| @ability_usage[1][index] = Hash.new { |hash, key| hash[key] = [0, -1] } }
  end

  def ability_used_include?(battler, ability_id)
    @ability_usage[battler.index & 1][battler.pokemonIndex].keys.include?(ability_id)
  end

  def record_ability_use(battler, ability_id) # record when an ability triggers
    @ability_usage[battler.index & 1][battler.pokemonIndex][ability_id][0] += 1
  end

  def ability_used_times(battler, ability_id) # amount that an ability already triggered
    @ability_usage[battler.index & 1][battler.pokemonIndex][ability_id][0]
  end

  def ability_available_times(battler, ability_id) # amount that an ability can trigger per battle
    @ability_usage[battler.index & 1][battler.pokemonIndex][ability_id][1]
  end

  def set_ability_available_times(battler, ability_id, available_times = 1) # set amount that an ability can trigger per battle
    return if ability_available_times(battler, ability_id) != -1 # only set when first time calls
    @ability_usage[battler.index & 1][battler.pokemonIndex][ability_id][1] = available_times
  end

  def ability_available?(battler, ability_id)
    return true if ability_available_times(battler, ability_id) == -1
    return true if ability_available_times(battler, ability_id) > ability_used_times(battler, ability_id)
    false
  end

  def ability_limit_set_and_available?(battler, ability_id, available_times = 1)
    set_ability_available_times(battler, ability_id, available_times)
    return false if !ability_available?(battler, ability_id)
    record_ability_use(battler, ability_id)
    true
  end
end

def is_one_battle_ability?(ability_id)
  GameData::Ability.try_get(ability_id).has_flag?("OneBattleAbility")
end

def is_one_switch_ability?(ability_id)
  GameData::Ability.try_get(ability_id).has_flag?("OneSwitchAbility")
end