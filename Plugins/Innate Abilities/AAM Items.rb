#########################################################################
#This is an example of an item that toggles abilityMutation on a Pokemon
=begin
ItemHandlers::UseOnPokemon.add(:EXAMPLEAAM, proc { |item, qty, pokemon, scene, screen, msg|
    scene.pbDisplay(_INTL("After consuming the [placeholder], {1} has awakened its untapped potential!",pokemon.name))
	pokemon.toggleAbilityMutation
})

ItemHandlers::UseOnPokemon.add(:MUTANTGENE, proc { |item, qty, pokemon, scene, screen, msg|
    scene.pbDisplay(_INTL("After consuming the gene, {1} has awakened its untapped potential!",pokemon.name))
	pokemon.toggleAbilityMutation
})

ItemHandlers::UseOnPokemon.add(:INNATESHUFFLER, proc { |item, qty, pokemon, scene, screen, msg|
  # Get available innates
  available_innates = pokemon.getInnateList.map(&:first)
  # Get the maximum number of innates from Settings::INNATE_MAX_AMOUNT
  max_innates = Settings::INNATE_MAX_AMOUNT
  # Ensure max_innates does not exceed the number of available innates
  max_innates = [max_innates, available_innates.size].min
  # Randomly select the innates
  chosen_innates = available_innates.sample(max_innates)
  # Set the chosen innates and mark them as already shuffled
  pokemon.instance_variable_set(:@active_innates, chosen_innates)
  pokemon.instance_variable_set(:@fixed_innates, chosen_innates)
  scene.pbDisplay(_INTL("{1} has shuffled it's innates!", pokemon.name))
})
=end

ItemHandlers::UseOnPokemon.add(:INNATESHUFFLER, proc { |item, qty, pokemon, scene, screen, msg|
  max_innates = Settings::INNATE_MAX_AMOUNT
  pokemon.select_random_innates(max_innates, pokemon.ability_id)
  
  scene.pbDisplay(_INTL("{1} has shuffled its innates!", pokemon.name))
})

ItemHandlers::UseOnPokemon.add(:ABILITYCAPSULE, proc { |item, qty, pkmn, scene|
  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    abil1 = nil
    abil2 = nil
    abils.each do |i|
      abil1 = i[0] if i[1] == 0
      abil2 = i[0] if i[1] == 1
    end
    if abil1.nil? || abil2.nil? || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    newabil = (pkmn.ability_index + 1) % 2
    newabilname = GameData::Ability.get((newabil == 0) ? abil1 : abil2).name
    pkmn.ability_index = newabil
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, newabilname))
	max_innates = Settings::INNATE_MAX_AMOUNT
	pkmn.select_random_innates(max_innates, pkmn.ability_id)
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:ABILITYPATCH, proc { |item, qty, pkmn, scene|
  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    new_ability_id = nil
    abils.each { |a| new_ability_id = a[0] if a[1] == 2 }
    if !new_ability_id || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    new_ability_name = GameData::Ability.get(new_ability_id).name
    pkmn.ability_index = 2
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, new_ability_name))
	max_innates = Settings::INNATE_MAX_AMOUNT
	pkmn.select_random_innates(max_innates, pkmn.ability_id)
    next true
  end
  next false
})