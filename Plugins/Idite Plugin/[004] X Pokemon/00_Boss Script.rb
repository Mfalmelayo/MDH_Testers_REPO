# Plugin to create boss Pokémon encounters with custom stats loaded from PBS/boss_stats.txt.

module BossStats
  @@boss_stats = {}

  # Load boss stats from boss_stats.txt in the PBS folder
  def self.load_boss_stats
    boss_data = File.readlines("PBS/boss_stats.txt")
    boss_data.each do |line|
      next if line.strip == "" || line.start_with?("#")  # Skip empty lines and comments
      data = line.strip.split(",")
      next if data.size < 7  # Ensure all fields are present
      species_name = data[0].strip.upcase  # Use uppercase for consistency
      @@boss_stats[species_name] = {
        :HP => data[1].to_i,
        :ATTACK => data[2].to_i,
        :DEFENSE => data[3].to_i,
        :SPATK => data[4].to_i,
        :SPDEF => data[5].to_i,
        :SPEED => data[6].to_i
      }
    end
  end

  # Retrieve boss stats for a specific species
  def self.get_boss_stats(species)
    return @@boss_stats[species.to_s.upcase] || nil  # Convert species to string and uppercase
  end
end

# Ensure stats are loaded at the beginning of the game
BossStats.load_boss_stats

# Extend the Pokemon class to include custom base stats
class Pokemon
  attr_accessor :Innates  # Ensure Innates can be assigned and accessed

  # Apply custom base stats if available
  def apply_boss_stats
    boss_stats = BossStats.get_boss_stats(self.species)
    if boss_stats
      @customBaseStats = boss_stats
    end
  end

  # Debug method to display stats
  def debugStats
    puts "== Boss Pokémon Stats =="
    puts "Species: #{self.species}"
    puts "Level: #{self.level}"
    puts "Custom Base Stats: #{@customBaseStats}" if @customBaseStats
    puts "Innate Abilities: #{@Innates}" if @Innates
    puts "Calculated Final Stats: HP=#{self.totalhp}, Attack=#{self.attack}, Defense=#{self.defense}, Sp. Atk=#{self.spatk}, Sp. Def=#{self.spdef}, Speed=#{self.speed}"
    puts "========================"
  end
end

# Define apply_boss_stats method in Battle::Battler for applying custom stats
class Battle::Battler
  # Apply custom boss stats directly as actual stats
  def apply_boss_stats
    return unless @pokemon && @pokemon.instance_variable_defined?(:@customBaseStats)
    boss_stats = @pokemon.instance_variable_get(:@customBaseStats)
    
    # Directly assign the stats from boss_stats.txt
    @totalhp = boss_stats[:HP]
    @attack  = boss_stats[:ATTACK]
    @defense = boss_stats[:DEFENSE]
    @spatk   = boss_stats[:SPATK]
    @spdef   = boss_stats[:SPDEF]
    @speed   = boss_stats[:SPEED]
    
    # Ensure full HP at the start of the battle
    @hp = @totalhp

    # Debug output to confirm stats and innates are applied
    puts "== Applied Boss Stats to Battler =="
    puts "Species: #{@pokemon.species}"
    puts "Level: #{@pokemon.level}"
    puts "Applied Stats: HP=#{@totalhp}, Attack=#{@attack}, Defense=#{@defense}, Sp. Atk=#{@spatk}, Sp. Def=#{@spdef}, Speed=#{@speed}"
    puts "Innate Abilities: #{@pokemon.Innates}" if @pokemon.Innates
    puts "==================================="
  end

  # Alias the original pbInitPokemon method to redefine it with custom behavior
  alias_method :original_pbInitPokemon, :pbInitPokemon
  
  # Redefine pbInitPokemon to include apply_boss_stats
  def pbInitPokemon(pkmn, idxParty)
    original_pbInitPokemon(pkmn, idxParty)  # Call the original pbInitPokemon method
    apply_boss_stats  # Apply boss stats after initialization
  end
end

# Method to create a boss Pokémon with custom stats and attributes
def pbBossPokemon(species, level, options = {})
  # Create the Pokémon as usual
  pokemon = Pokemon.new(species, level)

  # Apply boss stats if available
  pokemon.apply_boss_stats

  # Apply additional attributes from options hash, if provided
  pokemon.gender = options[:gender] if options.key?(:gender)
  pokemon.ability = options[:ability] if options.key?(:ability)
  pokemon.item = options[:item] if options.key?(:item)
  pokemon.nature = options[:nature] if options.key?(:nature)
  pokemon.moves = options[:moves] if options.key?(:moves)
  pokemon.iv = options[:iv] if options.key?(:iv)
  pokemon.ev = options[:ev] if options.key?(:ev)
  
  # Set Innates if provided in options (integrates with your existing Innates system)
  pokemon.Innates = options[:Innates] if options.key?(:Innates)
  # Handle them DBK Immunities
  pokemon.immunities = options[:immunities] if options.key?(:immunities)
  # Call debugStats to verify
  pokemon.debugStats

  return pokemon
end
