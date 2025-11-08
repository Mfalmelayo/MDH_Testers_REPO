#===============================================================================
# Settings
#===============================================================================
module Settings
#-------------------------------------------------------------------------------------------------------------------------------
#For the correct function of the plugin, keep these 3 settings as they are -----------------------------------------------------
  #-----------------------------------------------------------------------------
  # Choose whether you want the mutation icon to be visible (It has no effect since Global mutation icon it's false)
  #-----------------------------------------------------------------------------
  AAM_MUTATION_ICON = true

  #-----------------------------------------------------------------------------
  # Global Mutation
  #-----------------------------------------------------------------------------
  # Enables All Ability Mutation for every Pokemon in the game. 
  #-----------------------------------------------------------------------------
  GLOBAL_MUTATION = true  # Keep it true, since this is what loads the Innate Abilities from the battler

  #-----------------------------------------------------------------------------
  # Choose whether you want the mutation icon to be visible or not when GLOBAL_MUTATION is enabled.
  #-----------------------------------------------------------------------------
  GLOBAL_MUTATION_ICON = false #You can set it to true if you want, but every pokemon will have it so it's kinda redundant.
#-------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------- 
 
#Specific Innate Settings. DO tweak this if you want.
  #-----------------------------------------------------------------------------
  # Set true if you want the Innate Abilities to be unlocked with a Variable rather than having all unlocked by default.
  # If this it's set to true, the INNATE_PROGRESS_WITH_LEVEL setting must be set to false.
  # Having both of them true simply results in all innates being active from the start as if both settings were false... but it messes up the summary Screen.
  # This affects all pokemon. (Set to False by default)
  #-----------------------------------------------------------------------------
  INNATE_PROGRESS_WITH_VARIABLE = false
  
  #-----------------------------------------------------------------------------
  # If you are using the Innate progress with Variable. This defines with game variable to use. This variable defines how many innates a pokemon has.
  # If the variable it's set to:
  # 1 - Only the first innate it's active, and the other 2 are inactive and marked as "Locked" in the summary
  # 2 - Only the first 2 innates are active, and the last one it's inactive and marked as "Locked in the summary"
  # 3 - All innates are unlocked an visible in the summary. Keep it in mind if you are using more than 3 innates
  # Having it at 0 basically doesn't add any Innate and all 3 are marked as "Locked" in the summary, so it can kinda work to de-activate them
  #-----------------------------------------------------------------------------
  INNATE_PROGRESS_VARIABLE = 32
  
  #-----------------------------------------------------------------------------
  # Set to true if you want to unlock Innate abilities depending of a pokemon's current level rather than having all unlocked from the start.
  # If this it's set to true, the INNATE_PROGRESS_WITH_VARIABLE setting must be set to false.
  # Having both of them true simply results in all innates being active from the start as if both settings were false... but it messes up the summary Screen.
  # This affects each pokemon individually.
  #-----------------------------------------------------------------------------
  INNATE_PROGRESS_WITH_LEVEL = false
  
  #-----------------------------------------------------------------------------
  # If you are using the Innate Progress with level Variable, define here at which levels you want to unlock each Innate
  # For example: LEVELS_TO_UNLOCK = [[1, 15, 50]] means:
  # Pokemon with a level equal or greather to 1 (Which usually it's the minimum) have their 1st innate unlocked
  # Pokemon with a level equal or greather to 15 have their 1st and 2nd innate unlocked
  # Pokemon with a level equal or greather to 50 have all of their innates unlocked
  # Locked abilities are displayed as "Locked" in the summary if using the summary add-on
  # Pokemon can be of a lower level than the first value, they will simply not have an Innate available.
  # You can add specific cases for a pokemon in the array by inputting it's ID first, then the 3 levels required to unlock it's proper innate.
  # For example, using "[:MEWTWO, 45, 70, 90]," before the "nameless" array, will make that Mewtwo and ALL OF IT'S FORMS have their Innates 
  # to be unloked at level 45, 70 and 90. You can use as many of these special cases as you want. You can use this to make let pokemon unlock their innates
  # sooner or later than the rest.
  # LEVELS_TO_UNLOCK =  [
  # [:MEWTWO, 45, 70, 90],
  # [:ARCEUS, 80, 90, 100],
  # [:BUTTERFREE, 10, 14, 30], #<- Always remember to end with a "," in arrays prior to the "nameless" one.
  # [1, 15, 45]
  # ]
  #-----------------------------------------------------------------------------
  LEVELS_TO_UNLOCK = [[1, 15, 45]]

  #-----------------------------------------------------------------------------
  #With the following 2 settings you can give pokemon a bigger pool a set of "random" innates.
  #The way it works is, from the available innates a pokemon has, randomly grab an X amount of innates from that list.
  #And use those X innates to be the active innates a pokemon has. 
  #The amount can be defined with the INNATE_MAX_AMOUNT setting.
  #Keep in mind, having this setting off will simply load ALL of the innates defined in each pokemon's "Innates =" section of the PBS.
  #-----------------------------------------------------------------------------
  
  #-----------------------------------------------------------------------------
  #Set to true if you want to enable the "Random Innate Selection"
  #-----------------------------------------------------------------------------
  INNATE_RANDOMIZER = false
  
  #-----------------------------------------------------------------------------
  #Maximunt amount of innates a pokemon can grab from it's innates.
  #-----------------------------------------------------------------------------
  INNATE_MAX_AMOUNT = 3
  
  #-----------------------------------------------------------------------------
  #Set to true if you want to randomize innates even if they are less than the given maximum.
  #Basically having them in a random order. Pair well with the progresss settings for a surprise progress per pokemon.
  #-----------------------------------------------------------------------------
  ALWAYS_SHUFFLE_RANDOMS = false
	
  #Personal setting. I like to use small fonts for my abilities. Ignore this one.
  SMALL_FONT_IN_SUMMARY = true
end  