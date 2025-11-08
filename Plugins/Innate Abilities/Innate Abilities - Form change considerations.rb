#=========================================================
#Evolution checks
#=========================================================
class PokemonEvolutionScene
  # Alias the original pbEvolutionSuccess method
  alias_method :original_pbEvolutionSuccess, :pbEvolutionSuccess

  # Takes care of the evolution stuff
  def pbEvolutionSuccess
    original_pbEvolutionSuccess
	# Clear @Innates to ensure the Pokémon receives a new set of innates
    @pokemon.empty_innates
	@pokemon.assign_innate_abilities

    if @pokemon && @pokemon.species != @newspecies
	  # Loads a new set of innates.
      @pokemon.assign_innate_abilities
    end
  end
end
#=========================================================
#Mega Evolution and Primal Reversion
#==========================================================
class Pokemon
  # Aliasing methods to preserve the originalss
  alias_method :original_makeMega, :makeMega
  alias_method :original_makeUnmega, :makeUnmega
  alias_method :original_makePrimal, :makePrimal
  alias_method :original_makeUnprimal, :makeUnprimal

  # Overridden makeMega method with innates handling
  def makeMega
    # Store original innates
    @original_active_innates = self.active_innates.clone

    # Call the original method
    original_makeMega

    # Assign new innates for Mega form
	self.empty_innates
    self.assign_innate_abilities
  end

  # Overridden makeUnmega method with innates restoration
  def makeUnmega
    # Restore original innates
    if @original_active_innates
      self.active_innates = @original_active_innates
      @original_active_innates = nil  # Clear stored innates
    end

    # Call the original method
    original_makeUnmega
  end

  # Overridden makePrimal method with innates handling
  def makePrimal
    # Store original innates
    @original_active_innates = self.active_innates.clone

    # Call the original method
    original_makePrimal

    # Assign new innates for Primal form
	self.empty_innates
    self.assign_innate_abilities
  end

  # Overridden makeUnprimal method with innates restoration
  def makeUnprimal
    # Restore original innates
    if @original_active_innates
      self.active_innates = @original_active_innates
      @original_active_innates = nil  # Clear stored innates
    end

    # Call the original method
    original_makeUnprimal
  end
end
#=========================================================
#Updated the pbUpdate to handle the modified active_innates
#==========================================================
class Battle::Battler
  alias_method :original_pbUpdate, :pbUpdate

  def pbUpdate(fullChange = false)
    return if !@pokemon
    @pokemon.calc_stats
    @level          = @pokemon.level
    @hp             = @pokemon.hp
    @totalhp        = @pokemon.totalhp
    if !@effects[PBEffects::Transform]
      @attack       = @pokemon.attack
      @defense      = @pokemon.defense
      @spatk        = @pokemon.spatk
      @spdef        = @pokemon.spdef
      @speed        = @pokemon.speed
      if fullChange
        @types      = @pokemon.types
        @ability_id = @pokemon.ability_id
        @active_innates = @pokemon.assign_innate_abilities
		@abilityMutationList = @pokemon.set_innate_limits
      end
    end
  end
end

#=========================================================
#Aliases to modify store and recover the original innates a pokemon had before battle ()WIP()
#==========================================================
class Battle
  #alias_method :original_pbBattleLoop, :pbBattleLoop
  alias_method :original_pbEndOfBattle, :pbEndOfBattle
=begin
  # Redefine pbStartBattle
  def pbBattleLoop
	# Call the original method
    #original_pbStartBattleCore
	
    @battlers.each do |battler|
      next unless battler #&& battler.respond_to?(:save_original_innates)
	  
	  # Get the underlying Pokemon object
      pokemon = battler.pokemon
      pokemon.save_original_innates
    end
    puts "Storing Innates"

    # Call the original method
    original_pbBattleLoop
  end
=end
  # Redefine pbEndOfBattle
  def pbEndOfBattle
=begin
    #@battlers.each do |battler|
    #  next unless battler #&& battler.respond_to?(:original_innates) && battler.respond_to?(:active_innates=)
	  
	  # Get the underlying Pokemon object
      pokemon = battler.pokemon
	  
      pokemon.active_innates = pokemon.original_innates.clone
    end
    puts "Recovering innates"
=end
    pbParty(0).each_with_index do |pkmn, i|
        pkmn.restore_original_innates
	end

    # Call the original method
    original_pbEndOfBattle
  end
end
