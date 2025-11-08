module Compiler
  module_function


  def validate_compiled_pokemon_form(hash)
    # Split species and form into their own values, generate compound ID from them
    hash[:species] = hash[:id][0]
    hash[:form] = hash[:id][1]
    hash[:id] = sprintf("%s_%d", hash[:species].to_s, hash[:form]).to_sym
    if !GameData::Species.exists?(hash[:species])
      raise _INTL("Undefined species ID '{1}'.\n{3}", hash[:species], FileLineData.linereport)
    elsif GameData::Species.exists?(hash[:id])
      raise _INTL("Form {1} for species ID {2} is defined twice.\n{3}", hash[:form], hash[:species], FileLineData.linereport)
    end
    # Perform the same validations on this form as for a regular species
    validate_compiled_pokemon(hash)
    # Inherit undefined properties from base species
    base_data = GameData::Species.get(hash[:species])
    [:real_name, :real_category, :real_pokedex_entry, :base_exp, :growth_rate,
     :gender_ratio, :catch_rate, :happiness, :hatch_steps, :incense, :height,
     :weight, :color, :shape, :habitat, :generation].each do |property|
      hash[property] = base_data.send(property) if hash[property].nil?
    end
    [:types, :base_stats, :evs, :tutor_moves, :egg_moves, :abilities,
     :hidden_abilities, :egg_groups, :offspring, :flags].each do |property|
      hash[property] = base_data.send(property).clone if hash[property].nil?
    end
    if !hash[:moves].is_a?(Array) || hash[:moves].length == 0
      hash[:moves] ||= []
      base_data.moves.each { |m| hash[:moves].push(m.clone) }
    end
    if !hash[:evolutions].is_a?(Array) || hash[:evolutions].length == 0
      hash[:evolutions] ||= []
      base_data.evolutions.each { |e| hash[:evolutions].push(e.clone) }
    end
    if hash[:wild_item_common].nil? && hash[:wild_item_uncommon].nil? &&
       hash[:wild_item_rare].nil?
      hash[:wild_item_common] = base_data.wild_item_common.clone
      hash[:wild_item_uncommon] = base_data.wild_item_uncommon.clone
      hash[:wild_item_rare] = base_data.wild_item_rare.clone
    end
  end

	class << self
    alias innate_abilities_validate_compiled_trainer validate_compiled_trainer
    def validate_compiled_trainer(hash)
      innate_abilities_validate_compiled_trainer(hash)
      hash[:pokemon].each do |pkmn|
        if pkmn[:Innates]
          innate_abilities = pkmn[:Innates]
		  puts "Validating Innates: #{innate_abilities.inspect}"
          # Ensure innate_abilities is an array, even if a single ability is provided
          innate_abilities = [innate_abilities] unless innate_abilities.is_a?(Array)
		  puts "Innates as Array: #{innate_abilities.inspect}"  # Debug output
          # Validate each innate ability
          #if !innate_abilities.all? { |a| GameData::Ability.exists?(a) }
          #  raise _INTL("One or more specified innate abilities are not defined.\n{1}", FileLineData.linereport)
          #end
        end
      end
    end
  end
  
 #-----------------------------------------------------------------------------
  # Innate Sets compilation functionality
  #-----------------------------------------------------------------------------
  class << self
    alias __innate_sets__compile_pbs_files compile_pbs_files unless method_defined?(:__innate_sets__compile_pbs_files)
    alias __innate_sets__write_all write_all unless method_defined?(:__innate_sets__write_all)
  end

  #-----------------------------------------------------------------------------
  # Innate Sets compilation functionality
  #-----------------------------------------------------------------------------
  def compile_innate_sets(*paths)
    compile_PBS_file_generic(GameData::InnateSet, *paths) do |final_validate, hash|
      (final_validate) ? validate_all_compiled_innate_sets : validate_compiled_innate_set(hash)
    end
  end

  def validate_compiled_innate_set(hash)
    # Here you can add any validation logic for individual innate sets
  end

  def validate_all_compiled_innate_sets
    # Here you can add any final validation logic after all innate sets are compiled
  end

  def compile_pbs_files(*args)
    __innate_sets__compile_pbs_files(*args)
    compile_innate_sets("PBS/innate_sets.txt")
  end

  #-----------------------------------------------------------------------------
  # Innate Sets PBS writing functionality
  #-----------------------------------------------------------------------------
  def write_innate_sets
    write_PBS_file_generic(GameData::InnateSet)
  end

  def write_all
    __innate_sets__write_all
    write_innate_sets
  end
end