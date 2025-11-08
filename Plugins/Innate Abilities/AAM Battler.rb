
module PBEffects
  #===========================================================================
  # These effects apply to a battler
  #===========================================================================
  #IMPORTANT: Set Trace to an unused Effect ID in your game.
  ############################################################################
  Trace  = 1000
end   
  

class Battle::Battler
  attr_accessor :abilityMutationList
  
  def hasAbilityMutation?
    return (@pokemon) ? @pokemon.hasAbilityMutation? : false
  end
  
  # Gen 9 Pack Compatibility
  def affectedByMoldBreaker?
    return @battle.moldBreaker && !hasActiveItem?(:ABILITYSHIELD)
  end
  
  def ability=(value)
    new_ability = GameData::Ability.try_get(value)
    @ability_id = (new_ability) ? new_ability.id : nil
    if @ability_id 
      if self.hasAbilityMutation?
        @abilityMutationList.unshift(@ability_id)
        @abilityMutationList = @abilityMutationList|[]
      else  
        @abilityMutationList[0]=@ability_id 
      end  
    end  
  end
=begin
  alias abilityMutations_pbInitPokemon pbInitPokemon
  def pbInitPokemon(pkmn, idxParty)
    abilityMutations_pbInitPokemon(pkmn, idxParty)

    # Assuming @ability_id is already set for the Pokémon
    speciesAbilities = [@ability_id].compact

    # Initialize the innate abilities
    pkmn.assign_innate_abilities if pkmn.active_innates.nil?

    # Get the active innates and process them based on the settings
    active_innates = pkmn.active_innates

    if pkmn.hasAbilityMutation?
      if Settings::INNATE_PROGRESS_WITH_VARIABLE && !Settings::INNATE_PROGRESS_WITH_LEVEL
        push_ability_count = case $game_variables[Settings::INNATE_PROGRESS_VARIABLE]
                             when 1 then 1
                             when 2 then 2
                             when 3 then active_innates.size
                             else 0
                             end
        active_innates.each_with_index do |ability, index|
          speciesAbilities.push(ability)
          break if index + 1 >= push_ability_count
        end
      elsif Settings::INNATE_PROGRESS_WITH_LEVEL && !Settings::INNATE_PROGRESS_WITH_VARIABLE
        levels_to_unlock = Settings::LEVELS_TO_UNLOCK.find { |entry| entry.first == pkmn.species }&.drop(1) || Settings::LEVELS_TO_UNLOCK.last
        levels_to_unlock.each_with_index do |min_level, index|
          if pkmn.level >= min_level && active_innates.size > index
            speciesAbilities.push(active_innates[index])
          end
        end
      else
        active_innates.each { |ability| speciesAbilities.push(ability) }
      end
    end

    # Ensure there's at least one ability
    speciesAbilities.push(:NOABILITY) if speciesAbilities.empty?

    # Assign the list of abilities to the Pokémon's ability mutation list
    @abilityMutationList = speciesAbilities
  end
=end

  alias abilityMutations_pbInitPokemon pbInitPokemon
	def pbInitPokemon(pkmn, idxParty)
		abilityMutations_pbInitPokemon(pkmn, idxParty)

		# Initialize the innate abilities if not already set
		pkmn.assign_innate_abilities if pkmn.active_innates.empty?
		
		# Set the original innates of the pokemon
		pkmn.save_original_innates

		# Set the ability mutation list using the new method
		@abilityMutationList = pkmn.set_innate_limits
	end
  
  alias abilityMutations_pbInitEffects pbInitEffects
  def pbInitEffects(batonPass)
    abilityMutations_pbInitEffects(batonPass)
	  @effects[PBEffects::Trace] = false   #DemICE   AAM edit
  end
  
  #=============================================================================
  # Refreshing a battler's properties
  #=============================================================================
  alias abilityMutations_pbUpdate pbUpdate
  def pbUpdate(fullChange = false)
    return if !@pokemon
    abilityMutations_pbUpdate(fullChange)
    if !@effects[PBEffects::Transform] && fullChange
      if !@abilityMutationList.include?(@ability_id)
        if self.hasAbilityMutation?
          @abilityMutationList.unshift(@ability_id)
          @abilityMutationList=@abilityMutationList|[]
        else
          @abilityMutationList[0]=@ability_id
        end  
        #print @abilityMutationList
      end
    end
  end

  def hasActiveAbility?(check_ability, ignore_fainted = false)
    return false if !abilityActive?(ignore_fainted, check_ability)
    if self.hasAbilityMutation?
=begin
      if check_ability.is_a?(Array)
        for i in check_ability
          $aamName2=GameData::Ability.get(i).name
          return @abilityMutationList.include?(i)	
        end
=end

      if check_ability.is_a?(Array)
	    common_element = (check_ability & @abilityMutationList).first
        $aamName2 = GameData::Ability.get(common_element).name if common_element
		return (check_ability & @abilityMutationList).any?
      else
        $aamName2=GameData::Ability.get(check_ability).name
        return @abilityMutationList.include?(check_ability)	
      end 
    end	
    return check_ability.include?(@ability_id) if check_ability.is_a?(Array)
	  $aamName2=GameData::Ability.get(check_ability).name
    return self.ability == check_ability
	print chek_ability
  end
  alias hasWorkingAbility hasActiveAbility? 


=begin
def hasActiveAbility?(check_ability, ignore_fainted = false)
  return false if !abilityActive?(ignore_fainted, check_ability)

  if self.hasAbilityMutation?
    if check_ability.is_a?(Array)
      for i in check_ability
        ability_name = GameData::Ability.get(i).name
        $aamName2 = ability_name
        $aamName = ability_name
        puts "First set of $aamName and $aamName2 to #{ability_name} (Mutation)"
        return true if @abilityMutationList.include?(i)
      end
    else
      ability_name = GameData::Ability.get(check_ability).name
      $aamName2 = ability_name
      $aamName = ability_name
      puts "Else set of $aamName and $aamName2 to #{ability_name} (Mutation)"
      return true if @abilityMutationList.include?(check_ability)
    end
  end

  if check_ability.is_a?(Array)
    return check_ability.include?(@ability_id)
  end

  ability_name = GameData::Ability.get(check_ability).name
  $aamName2 = ability_name
  $aamName = ability_name
  puts "Final set $aamName and $aamName2 to #{ability_name}"
  return self.ability == check_ability
end
alias hasWorkingAbility hasActiveAbility?
=end
  
  # Called when a Pokémon (self) enters battle, at the end of each move used,
  # and at the end of each round.
  def pbContinualAbilityChecks(onSwitchIn = false)
  # Check for end of primordial weather
  @battle.pbEndPrimordialWeather
  # Trace
  if hasActiveAbility?(:TRACE) && (self.effects[PBEffects::Trace] || onSwitchIn)
  # NOTE: In Gen 5 only, Trace only triggers upon the Trace bearer switching
      #       in and not at any later times, even if a traceable ability turns
      #       up later. Essentials ignores this, and allows Trace to trigger
      #       whenever it can even in Gen 5 battle mechanics.
    choices = @battle.allOtherSideBattlers(@index).select { |b|
      next !b.ungainableAbility? &&
           ![:POWEROFALCHEMY, :RECEIVER, :TRACE].include?(b.ability_id) && 
           !self.abilityMutationList.include?(b.ability_id)
    }
    if choices.length == 0
      effects[PBEffects::Trace] = true	  
    else
      choice = choices[@battle.pbRandom(choices.length)]
      $aamName = "Trace"
      @battle.pbShowAbilitySplash(self, true)
      if self.hasAbilityMutation?
        self.abilityMutationList.push(choice.ability.id)							
      else
        self.ability = choice.ability
      end
      $aamName = choice.abilityName
      #puts "Conditional set of $aamName to #{choice.abilityName} due to Trace"
      battle.pbReplaceAbilitySplash(self)
      @battle.pbDisplay(_INTL("{1} traced {2}'s {3}!", pbThis, choice.pbThis(true), choice.abilityName))
      @battle.pbHideAbilitySplash(self)
      if !onSwitchIn && (unstoppableAbility? || abilityActive?)
        Battle::AbilityEffects.triggerOnSwitchIn(self.ability, self, @battle)
      end
      self.effects[PBEffects::Trace] = false
    end
  end
end	

  alias aam_pbCanInflictStatus? pbCanInflictStatus?
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    $aam_StatusImmunityFromAlly=[]
    aam_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end
=begin
  def abilityName # May have problem on some situations, lazy 
    abil = self.ability
	abilitytext = abil.name
	if self.hasAbilityMutation?
      aamNames=[]
      for i in self.abilityMutationList
        aamNames.push(GameData::Ability.get(i).name)
      end
      abilitytext=$aamName if aamNames.include?($aamName)
	  abilitytext=$aamName2 if aamNames.include?($aamName2)
    end
	return abilitytext
  end
=end
  def abilityName
  abil = self.ability
  abilitytext = abil ? abil.name : GameData::Ability.get(:NOABILITY).name
  #puts "[abilityName] Initial ability: #{abil.inspect}, Name: #{abilitytext}"

  if self.hasAbilityMutation?
    aamNames = @abilityMutationList.map { |ability| GameData::Ability.get(ability).name }
    puts "[abilityName] Ability mutation list names: #{aamNames.inspect}"
    #puts "[abilityName] Current $aamName: #{$aamName}, $aamName2: #{$aamName2}"

    if aamNames.include?($aamName2)
      abilitytext = $aamName2
      #puts "[abilityName] Setting abilitytext to $aamName2: #{abilitytext}"
    elsif aamNames.include?($aamName)
      abilitytext = $aamName
      #puts "[abilityName] Setting abilitytext to $aamName: #{abilitytext}"
    end
  end

  #puts "[abilityName] Final abilitytext: #{abilitytext}"
  abilitytext
  end
end

# Safari Zone Fix
class Battle::FakeBattler
  attr_accessor :abilityMutationList
  
  alias aam_initialize initialize
  def initialize(*args)
    aam_initialize(*args)
    @abilityMutationList=[]
  end

  def hasAbilityMutation?
    return (@pokemon) ? @pokemon.hasAbilityMutation? : false
  end
end  
=begin
class Battle::Scene::AbilitySplashBar < Sprite

  def refresh
    self.bitmap.clear
    return if !@battler
    textPos = []
    textX = (@side == 0) ? 10 : self.bitmap.width - 8
    # Draw Pokémon's name
    textPos.push([_INTL("{1}'s", @battler.name), textX, 8, @side == 1,
                  TEXT_BASE_COLOR, TEXT_SHADOW_COLOR, true])
    # Draw Pokémon's ability
    abilitytext=@battler.abilityName
    if @battler.hasAbilityMutation?
      aamNames=[]
      for i in @battler.abilityMutationList
        aamNames.push(GameData::Ability.get(i).name)
      end	
	  #
      abilitytext=$aamName2 if aamNames.include?($aamName2)
      abilitytext=$aamName if aamNames.include?($aamName)
    end	
    textPos.push([abilitytext, textX, 38, @side == 1,
                  TEXT_BASE_COLOR, TEXT_SHADOW_COLOR, true])
    pbDrawTextPositions(self.bitmap, textPos)
  end  

end
=end