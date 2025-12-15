ItemHandlers::UseOnPokemon.add(:SHINYBERRY, proc { |item, qty, pkmn, scene|
  if pkmn.egg?
    scene.pbDisplay(_INTL("It has no effect on an Egg."))
    next false
  end
  if pkmn.shiny?
    scene.pbDisplay(_INTL("{1} is already shiny!", pkmn.name))
    next false
  end
  if !pbConfirmMessage(_INTL("Feed the Shiny Berry to {1}? This will make it shiny.", pkmn.name))
    next false
  end

  pkmn.shiny = true
  pkmn.super_shiny = false if pkmn.respond_to?(:super_shiny=)

  pbSEPlay("Shiny sparkle") rescue nil
  scene.pbDisplay(_INTL("{1} sparkled brilliantly! It's now shiny!", pkmn.name))
  next true
})
