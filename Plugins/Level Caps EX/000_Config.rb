module LevelCapsEX


  # Set this to the Game Variable which controls the value of the
  # level cap
  LEVEL_CAP_VARIABLE      = 498

  # Set this to the Game Variable which controls the mode of the
  # level cap. The 3 modes are:
  #   1 (Hard Cap) - The Pokemon cannot level up/gain experience 
  #   past the level cap.
  #   2 (EXP Cap) - The Pokemon will gain reduced EXP when it
  #   crosses the level cap.
  #   3 (Obedience Cap)  - The Pokemon will gain disobey the player
  #   when it crosses the level cap.
  LEVEL_CAP_MODE_VARIABLE = 499

  # Set this to the default mode of the Level Cap
  DEFAULT_LEVEL_CAP_MODE  = 1

  # Set this to true if any changes to the Level Cap/Level Cap mode
  # should be printed to the console.
  LOG_LEVEL_CAP_CHANGES   = true
end