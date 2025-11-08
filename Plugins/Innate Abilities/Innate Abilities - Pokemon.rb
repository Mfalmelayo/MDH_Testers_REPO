class Pokemon
	attr_accessor :Innates
	attr_accessor :active_innates
	attr_accessor :fixed_innates
	attr_accessor :original_innates
#Adds the innates to a species datta
	def species=(species_id)
		new_species_data = GameData::Species.get(species_id)
		return if @species == new_species_data.species
		@species     = new_species_data.species
		default_form = new_species_data.default_form
		if default_form >= 0
			@form      = default_form
			elsif new_species_data.form > 0
			@form      = new_species_data.form
		end
		@forced_form = nil
		@gender      = nil if singleGendered?
		@level       = nil   # In case growth rate is different for the new species
		@ability     = nil
		@innate      = nil
		calc_stats
		assign_innate_abilities
	end
#=============================================================================
# Stuff related to innate abilities. Basically a copy of Ability
#=============================================================================

  # The index of this Pokémon's ability (0, 1 are natural abilities, 2+ are
  # hidden abilities) as defined for its species/form. An ability may not be
  # defined at this index. Is recalculated (as 0 or 1) if made nil.
  # @return [Integer] the index of this Pokémon's ability
  def innate_index
    @innate_index = (@personalID & 1) if !@innate_index
    return @innate_index
  end

  # @param value [Integer, nil] forced ability index (nil if none is set)
  def innate_index=(value)
    @innate_index = value
    @innate = nil
  end

  # @return [GameData::Ability, nil] an Ability object corresponding to this Pokémon's ability
  def innate
    return GameData::Innate.try_get(innate_id)
  end

  # @return [Symbol, nil] the ability symbol of this Pokémon's ability
  def innate_id
    if !@innate
      sp_data = species_data
      inna_index = innate_index
      #if abil_index >= 2   # Hidden ability
      #  @ability = sp_data.hidden_abilities[abil_index - 2]
      #  abil_index = (@personalID & 1) if !@ability
      #end
      if !@innate   # Natural ability or no hidden ability defined
        @innate = sp_data.innates[inna_index] || sp_data.innates[0]
      end
    end
    return @innate
  end

  # @param value [Symbol, String, GameData::Ability, nil] ability to set
  def innate=(value)
    return if value && !GameData::Innate.exists?(value)
    @innate = (value) ? GameData::Innate.get(value).id : value
  end

  # Returns whether this Pokémon has a particular ability. If no value
  # is given, returns whether this Pokémon has an ability set.
  # @param check_ability [Symbol, String, GameData::Ability, nil] ability ID to check
  # @return [Boolean] whether this Pokémon has a particular ability or
  #   an ability at all
  def hasInnate?(check_innate = nil)
    current_innate = self.innate
    return !current_innate.nil? if check_innate.nil?
    return current_innate == check_innate
  end


  # @return [Array<Array<Symbol,Integer>>] the abilities this Pokémon can have,
  #   where every element is [ability ID, ability index]
=begin
  def getInnateList
    ret = []
    sp_data = species_data
    sp_data.innates.each_with_index { |a, i| ret.push([a, i]) if a }
   # sp_data.hidden_abilities.each_with_index { |a, i| ret.push([a, i + 2]) if a }
    return ret
  end
=end

  def getInnateList
  innate_set = GameData::InnateSet.get(species)
  return [] unless innate_set

  # Use the form if it's greater than 0
  if @form && @form > 0
    innate_set = GameData::InnateSet.get_species_form(species, @form)
	return [] unless innate_set
  end
  
  # Select a random set of innates if there are multiple sets
  selected_innates = innate_set.innates.sample

  # Ensure this returns an array of innate symbols
  #return innate_set ? innate_set.innates : []
  return selected_innates || []
  end
  
  
  def getInnateListName
    ret = []
    sp_data = species_data
    sp_data.innates.each_with_index { |a, i| ret.push(a) if a }
   # sp_data.hidden_abilities.each_with_index { |a, i| ret.push([a, i + 2]) if a }
    return ret
  end
  
  
  
  #Add one single innate
  def add_innate(innate)
    #return unless innate && GameData::Innate.exists?(innate)
    innate_symbol = innate.to_sym
    @Innates << innate_symbol unless @Innates.include?(innate_symbol)
  end

  # Optional: Clears all innates
  def clear_innates
    @Innates.clear
	puts "Innates cleared"
  end
  
  def empty_innates
    @Innates = nil
    puts "Innates set to nil"
  end

  # Optional: Add multiple innates at once
  def add_innates(*innates)
    innates.each { |innate| add_innate(innate) }
  end
  
  # For all of the innate randomizer stuff EXCEPT in battle
  def select_random_innates(max_innates, primary_ability)
    # Load all innate abilities into "Available Innates"
    available_innates = getInnateList#.map(&:first)

    # Remove the primary ability from the available innates
    available_innates.reject! { |ability| ability == primary_ability }
	
	# If shuffling is disabled and the number of available innates is <= max_innates, return the innates as is
	if !Settings::ALWAYS_SHUFFLE_RANDOMS && available_innates.size <= max_innates
		return available_innates.take(max_innates)
	end

    # Ensure max_innates does not exceed the number of available innates
    chosen_innates = []
    max_innates.times do
      chosen_innate = available_innates.sample
      break if chosen_innate.nil?
      chosen_innates.push(chosen_innate)
      available_innates.delete(chosen_innate)  # Remove the chosen innate to prevent duplicates
    end

    # Set the instance variables
    #self.active_innates = available_innates
    #self.fixed_innates = self.active_innates
	
	puts "Possible Innates Randomized"

    return chosen_innates
  end
  
  #Moved the code here for consistency sake
  def assign_innate_abilities
	if @Innates && !(@Innates.empty? || @Innates.nil?)
		# Use the custom Innate Abilities if set
		self.active_innates = @Innates
		puts "Using customly given Innates..."
	else
		# Load all innate abilities into "Available Innates"
		available_innates = getInnateList#.map(&:first)

		# Remove the regular/hidden ability from the list of available innates
		available_innates.reject! { |innate| innate == self.ability_id }

		# Initialize the "Active Innates" array
		self.active_innates = []

		# Check if INNATE_RANDOMIZER is enabled and loads the randomizer
		if Settings::INNATE_RANDOMIZER == true
			self.active_innates = select_random_innates(Settings::INNATE_MAX_AMOUNT, @ability_id)
			puts "Using possible randomized innates..."
		else
			# If randomizer is not enabled, use all available innates
			self.active_innates = available_innates
			puts "Using innates straight from the pbs..."
		end
	end

	# Store the fixed innates with the Pokémon
	self.fixed_innates = self.active_innates
	puts "#{self.name}'s Innates set!"
  end
  
  #WIP
  def save_original_innates
	if self.original_innates.empty?
		self.original_innates = self.active_innates.clone
		puts "Original Innate saved!"
	else
		puts "The innates were already salved"
	end
  end
  
  def restore_original_innates
	if self.original_innates.empty?
		puts "There was nothing to restore here"
	else
		self.active_innates = self.original_innates.clone
		self.original_innates.clear
		puts "Innates Restored"
	end
  end
  
  
#===========================================================
  #Migrated the code from pbInitPokemon to here for more consistency
  def set_innate_limits
    speciesAbilities = [self.ability_id].flatten.compact#[@ability_id].compact
    active_innates = self.active_innates

    if self.hasAbilityMutation?
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
        levels_to_unlock = Settings::LEVELS_TO_UNLOCK.find { |entry| entry.first == self.species }&.drop(1) || Settings::LEVELS_TO_UNLOCK.last
        levels_to_unlock.each_with_index do |min_level, index|
          if self.level >= min_level && active_innates.size > index
            speciesAbilities.push(active_innates[index])
          end
        end
      else
        active_innates.each { |ability| speciesAbilities.push(ability) }
      end
    end

    speciesAbilities.push(:NOABILITY) if speciesAbilities.empty?

    return speciesAbilities
  end
#===========================================================
  
#===========================================================
  # Alias the original initialize method
  alias_method :original_initialize, :initialize
  # Define the new initialize method to add the Innates
  def initialize(species, level, owner = $player, withMoves = true, recheck_form = true)
    # Call the original initialize method
    original_initialize(species, level, owner, withMoves, recheck_form)
    
    # Initialize the new attribute
    @Innates = []
	@active_innates = []
    @fixed_innates = []
	@original_innates = []
  end
#===========================================================
end