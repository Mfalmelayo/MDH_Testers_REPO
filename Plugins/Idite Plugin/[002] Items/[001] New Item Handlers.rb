#=============================================
# GENGAR'S SIGIL
#=============================================
#Gengar Possession
ItemHandlers::UseOnPokemon.add(:GENGARSIGIL, proc { |item, qty, pkmn, scene|
  if !pkmn.isSpecies?(:GENGARp) || !pkmn.fused.nil?
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  elsif pkmn.fainted?
    scene.pbDisplay(_INTL("Gengar cannot possess a Pokémon while fainted."))
    next false
  end
  # Fusing
  chosen = scene.pbChoosePokemon(_INTL("Possess which Pokémon?"))
  next false if chosen < 0
  other_pkmn = $player.party[chosen]
  if pkmn == other_pkmn
    scene.pbDisplay(_INTL("She cannot possess herself."))
    next false
  elsif other_pkmn.egg?
    scene.pbDisplay(_INTL("Gengar will not possess an Egg."))
    next false
  elsif other_pkmn.fainted?
    scene.pbDisplay(_INTL("Gengar will not possess that fainted Pokémon."))
    next false
  elsif !other_pkmn.isSpecies?(:SUICUNE_1) && !other_pkmn.isSpecies?(:ARCANINE_2)
    # && !other_pkmn.isSpecies?(:SPECIES_1) 
    scene.pbDisplay(_INTL("Possession with that Pokémon has not been implemented."))
    next false
  end
  #newForm = 0
  newForm = 1 if other_pkmn.isSpecies?(:SUICUNE_1)
  newForm = 2 if other_pkmn.isSpecies?(:ARCANINE_2)
  #newForm = 3 if other_pkmn.isSpecies?(:)
  pkmn.setForm(newForm) do
    pkmn.fused = other_pkmn
    $player.remove_pokemon_at_index(chosen)
    scene.pbHardRefresh
    scene.pbDisplay(_INTL("{1} possessed her host!", pkmn.name))
  end
  $bag.replace_item(:GENGARSIGIL, :GENGARSIGILUSED)
  next true
})

#================================
# RELEASING HOST
#================================

ItemHandlers::UseOnPokemon.add(:GENGARSIGILUSED, proc { |item, qty, pkmn, scene|
  if !pkmn.isSpecies?(:GENGARp) || pkmn.fused.nil?
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  elsif pkmn.fainted?
    scene.pbDisplay(_INTL("This can't be used on the fainted Pokémon."))
    next false
  elsif $player.party_full?
    scene.pbDisplay(_INTL("You have no room to separate the Pokémon."))
    next false
  end
  # Unfusing
  pkmn.setForm(0) do
    $player.party[$player.party.length] = pkmn.fused
    pkmn.fused = nil
    scene.pbHardRefresh
    scene.pbDisplay(_INTL("{1} released her host!", pkmn.name))
  end
  $bag.replace_item(:GENGARSIGILUSED, :GENGARSIGIL)
  next true
})
#End Gengar Possession


#=================================================
# SECOND ATTEMPT, IN CASE I WANT TO SWITCH IT. CURRENTLY DEFUNCT
#=================================================
=begin
ItemHandlers::UseOnPokemon.add(:NSOLARIZER, proc { |item, qty, pkmn, scene|
  if !pkmn.isSpecies?(:NECROZMA) || !pkmn.fused.nil?
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  elsif pkmn.fainted?
    scene.pbDisplay(_INTL("This can't be used on the fainted Pokémon."))
    next false
  end
  # Fusing
  chosen = scene.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))
  next false if chosen < 0
  other_pkmn = $player.party[chosen]
  if pkmn == other_pkmn
    scene.pbDisplay(_INTL("It cannot be fused with itself."))
    next false
  elsif other_pkmn.egg?
    scene.pbDisplay(_INTL("It cannot be fused with an Egg."))
    next false
  elsif other_pkmn.fainted?
    scene.pbDisplay(_INTL("It cannot be fused with that fainted Pokémon."))
    next false
  elsif !other_pkmn.isSpecies?(:SOLGALEO)
    scene.pbDisplay(_INTL("It cannot be fused with that Pokémon."))
    next false
  end
  pkmn.setForm(1) do
    pkmn.fused = other_pkmn
    $player.remove_pokemon_at_index(chosen)
    scene.pbHardRefresh
    scene.pbDisplay(_INTL("{1} changed Forme!", pkmn.name))
  end
  $bag.replace_item(:NSOLARIZER, :NSOLARIZERUSED)
  next true
})
# Possession Attempt 2
=end