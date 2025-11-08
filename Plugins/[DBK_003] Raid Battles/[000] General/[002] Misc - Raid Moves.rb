#===============================================================================
# Gets all function codes for moves that should be banned from raid battles.
#===============================================================================
def pbRaidBannedMoves(isRental = false)
  functions = [                                       ### Moves banned for all raid battlers. ###
    "PursueSwitchingFoe",                               # Pursuit
	"UserTakesTargetItem",                              # Thief, Covet
    "FlinchTargetFailsIfNotUserFirstTurn",              # Fake Out
    "AttackAndSkipNextTurn",                            # Hyper Beam, Giga Impact, etc.
    "SwitchOutTargetDamagingMove",                      # Circle Throw, Dragon Tail
    "UserFaintsExplosive",                              # Self-Destruct, Explosion
    "UserFaintsPowersUpInMistyTerrainExplosive",        # Misty Explosion
	"UserLosesHalfOfTotalHP",                           # Steel Beam
	"OHKO",                                             # Guillotine, Horn Drill
	"OHKOHitsUndergroundTarget",                        # Fissure
	"OHKOIce",                                          # Sheer Cold
    "LowerUserSpAtk2",                                  # Overheat, Draco Meteor, etc.
    "TwoTurnAttack",                                    # Razor Wind
    "TwoTurnAttackInvulnerableInSky",                   # Fly
    "TwoTurnAttackInvulnerableUnderground",             # Dig
    "TwoTurnAttackInvulnerableUnderwater",              # Dive
    "HealUserByHalfOfDamageDoneIfTargetAsleep",         # Dream Eater
    "TypeDependsOnUserIVs",                             # Hidden Power
    "FailsIfUserHasUnusedMove",                         # Last Resort
    "TwoTurnAttackInvulnerableInSkyTargetCannotAct",    # Sky Drop
    "FlinchTargetFailsIfTargetNotUsingPriorityMove",    # Upper Hand
    "IncreasePowerEachFaintedAlly",                     # Last Respects
    "CategoryDependsOnHigherDamageTera"	                # Tera Blast
  ]
  if isRental
    functions += [                                    ### Moves banned only for rental battlers. ###
      "TwoTurnAttackInvulnerableRemoveProtections",     # Shadow Force, Phantom Force
	  "RemoveTargetItem",                               # Knock Off
      "FailsIfUserNotConsumedBerry"                     # Belch
    ]
  else
    functions += [                                    ### Moves banned only for raid bosses. ###
      "FailsIfNotUserFirstTurn",                        # First Impression
      "HitOncePerUserTeamMember",                       # Beat Up
	  "DoublePowerIfAllyFaintedLastTurn",               # Retaliate
      "MultiTurnAttackConfuseUserAtEnd",                # Trash, Outrage, etc.
      "FailsIfUserDamagedThisTurn",                     # Focus Punch
      "FailsIfTargetHasNoItem",                         # Poltergeist
      "UserLosesHalfOfTotalHPExplosive",                # Mind Blown
      "RemoveTerrain",                                  # Steel Roller
      "RecoilHalfOfTotalHP"                             # Chloroblast
    ]
  end
  return functions
end

#===============================================================================
# Gets all function codes for approved status moves for raid battles.
# Any status moves that do not appear here are considered banned.
#===============================================================================
def pbRaidApprovedStatusMoves(category = nil, isRental = false)
  functions = [                                       ### Moves approved for all battlers. ### 
    "RaiseUserAtkSpAtk1",                               # Work Up
    "RaiseUserAtkSpAtk1Or2InSun",                       # Growth
    "LowerTargetAtkDef1",                               # Tickle
    "LowerTargetAtkSpAtk1",                             # Noble Roar, Tearful Look
	"RaiseUserDefense2",                                # Barrier, Iron Defense
    "RaiseUserDefense3",                                # Cotton Guard
    "RaiseUserSpDef2",                                  # Amnesia
    "RaiseUserDefSpDef1",                               # Defend Order, Cosmic Power
    "LowerTargetSpeed2",                                # String Shot, Scary Face
    "LowerTargetSpeed1MakeTargetWeakerToFire",          # Tar Shot
    "TrapTargetInBattleLowerTargetDefSpDef1EachTurn",   # Octolock
	"ResetAllBattlersStatStages",                       # Haze
    "InvertTargetStatStages",                           # Topsy-Turvy
    "SleepTarget",                                      # Sleep Powder, Spore
    "SleepTargetNextTurn",                              # Yawn
    "ParalyzeTarget",                                   # Glare, Stun Spore
    "ParalyzeTargetIfNotTypeImmune",                    # Thunder Wave
    "BurnTarget",                                       # Will-O-Wisp
    "DisableTargetStatusMoves",                         # Taunt
    "StartLeechSeedTarget"                              # Leech Seed
  ]
  if [nil, 0].include?(category)
    functions += [                                    ### Moves approved for battlers that prefer physical moves. ### 
      "RaiseUserAtkDef1",                               # Bulk Up
      "RaiseUserAtkSpd1",                               # Dragon Dance
      "RaiseUserAtkSpd1RemoveHazardsSubstitutes",       # Tidy Up
      "RaiseUserAtk1Spd2",                              # Shift Gear
      "RaiseUserAtkDefAcc1",                            # Coil
      "RaiseUserAtkDefSpd1"                             # Victory Dance
    ]
  end
  if [nil, 1].include?(category)
    functions += [                                    ### Moves approved for battlers that prefer special moves. ### 
      "RaiseUserSpAtkSpDef1",                           # Calm Mind
      "RaiseUserSpAtkSpDef1CureStatus",                 # Take Heart
      "RaiseUserSpAtkSpDefSpd1",                        # Quiver Dance
    ]
  end
  if isRental
    functions += [                                   ### Moves approved only for rental battlers. ### 
      "LowerUserDefSpDef1RaiseUserAtkSpAtkSpd2",        # Shell Smash
      "RaiseUserAtkSpAtkSpeed2LoseHalfOfTotalHP",       # Fillet Away
	  "TwoTurnAttackRaiseUserSpAtkSpDefSpd2",           # Geomancy
	  "RaiseUserEvasion2MinimizeUser",                  # Minimize
	  "UserSwapBaseAtkDef",                             # Power Trick
	  "RaiseUserMainStats1TrapUserInBattle",            # No Retreat
      "RaiseUserMainStats1LoseThirdOfTotalHP",          # Clangorous Soul
      "RaiseTargetAtkSpAtk2",                           # Decorate
      "RaiseUserAndAlliesAtkDef1",                      # Coaching
      "LowerTargetAttack2",                             # Feather Dance
      "LowerTargetDefense2",                            # Screech
      "LowerTargetSpDef2",                              # Fake Tears
	  "HealUserByTargetAttackLowerTargetAttack1",       # Strength Sap
	  "HealTargetHalfOfTotalHP",                        # Heal Pulse
      "HealUserAndAlliesQuarterOfTotalHP",              # Life Dew
	  "PowerUpAllyMove",                                # Helping Hand
	  "StartWeakenPhysicalDamageAgainstUserSide",       # Reflect
	  "StartWeakenSpecialDamageAgainstUserSide",        # Light Screen
      "StartUserSideImmunityToStatStageLowering",       # Mist
	  "StartUserSideDoubleSpeed",                       # Tailwind
      "StartPreventCriticalHitsAgainstUserSide",        # Lucky Chant
      "RaiseAlliesCriticalHitRate1DragonTypes2",        # Dragon Cheer
	  "EnsureNextCriticalHit",                          # Laser Focus
	  "StartHealUserEachTurn",                          # Aqua Ring
      "StartHealUserEachTurnTrapUserInBattle",          # Ingrain
      "StartUserAirborne",                              # Magnet Rise
	  "NegateTargetAbility",                            # Gastro Acid
      "SetTargetAbilityToInsomnia",                     # Worry Seed
      "SetUserAbilityToTargetAbility",                  # Role Play
      "SetUserAlliesAbilityToTargetAbility",            # Doodle
      "UseLastMoveUsed",                                # Copycat
      "TargetUsesItsLastUsedMoveAgain",                 # Instruct
      "RedirectAllMovesToTarget",                       # Spotlight
	  "RedirectAllMovesToUser",                         # Follow Me, Rage Powder
      "ProtectUser",                                    # Protect, Detect
      "ProtectUserFromTargetingMovesSpikyShield",       # Spiky Shield
      "ProtectUserBanefulBunker",                       # Baneful Bunker
      "ProtectUserBurningBulwark",                      # Burning Bulwark
      "ProtectUserFromDamagingMovesKingsShield",        # King's Shield
      "ProtectUserFromDamagingMovesObstruct",           # Obstruct
      "ProtectUserFromDamagingMovesSilkTrap",           # Silk Trap
      "ProtectUserSideFromMultiTargetDamagingMoves",    # Wide Guard
      "ProtectUserSideFromDamagingMovesIfUserFirstTurn" # Mat Block
    ]
    if [nil, 0].include?(category)
      functions += [                                  ### Moves approved only for rental battlers that prefer physical moves. ### 
        "RaiseUserAttack2",                             # Swords Dance
        "MaxUserAttackLoseHalfOfTotalHP"                # Belly Drum
      ]
    end
    if [nil, 1].include?(category)
      functions += [                                  ### Moves approved only for rental battlers that prefer special moves. ### 
        "RaiseUserSpAtk2",                              # Nasty Plot
        "RaiseUserSpAtk3"                               # Tail Glow
      ]
    end
  else
    functions += [                                    ### Moves approved only for raid bosses. ### 
      "PoisonTarget",                                   # Poison Gas
      "PoisonTargetLowerTargetSpeed1",                  # Toxic Thread
      "BadPoisonTarget",                                # Toxic
      "DisableTargetLastMoveUsed",                      # Disable
      "DisableTargetUsingDifferentMove",                # Encore
      "DisableTargetUsingSameMoveConsecutively",        # Torment
      "AddSpikesToFoeSide",                             # Spikes
      "AddToxicSpikesToFoeSide"                         # Toxic Spikes
    ]
  end
  return functions
end

#===============================================================================
# Gets all function codes for eligible status moves to be used as Support Moves.
# Raid bosses can only uses these moves as Support Moves.
#===============================================================================
def pbRaidSupportMoves
  return [                                            ### Moves eligible to be used as Support Moves. ### 
    "StartSunWeather",                                  # Sunny Day
    "StartRainWeather",                                 # Rain Dance
    "StartHailWeather",                                 # Hail, Snowscape
    "StartSandstormWeather",                            # Sandstorm
    "StartElectricTerrain",                             # Electric Terrain
    "StartGrassyTerrain",                               # Grassy Terrain
    "StartPsychicTerrain",                              # Psychic Terrain
    "StartMistyTerrain",                                # Misty Terrain
    "StartWeakenPhysicalDamageAgainstUserSide",         # Reflect
    "StartWeakenSpecialDamageAgainstUserSide",          # Light Screen
    "StartUserSideImmunityToStatStageLowering",         # Mist
    "StartPreventCriticalHitsAgainstUserSide",          # Lucky Chant
    "StartUserSideDoubleSpeed",                         # Tailwind
    "StartWeakenFireMoves",                             # Water Sport
    "StartWeakenElectricMoves",                         # Mud Sport
    "AddStickyWebToFoeSide",                            # Sticky Web
    "AddStealthRocksToFoeSide",                         # Stealth Rock
    "CorrodeTargetItem",                                # Corrosive Gas
    "StartGravity",                                     # Gravity
    "StartNegateHeldItems",                             # Magic Room
    "StartSlowerBattlersActFirst",                      # Trick Room
    "StartSwapAllBattlersBaseDefensiveStats",           # Wonder Room
    "DisableTargetHealingMoves",                        # Heal Block
    "StartHealUserEachTurn",                            # Aqua Ring
    "StartHealUserEachTurnTrapUserInBattle",            # Ingrain
    "StartUserAirborne",                                # Magnet Rise
    "TwoTurnAttackRaiseUserSpAtkSpDefSpd2",             # Geomancy
    "RaiseUserMainStats1TrapUserInBattle",              # No Retreat
    "UserSwapBaseAtkDef",                               # Power Trick
    "RaiseUserCriticalHitRate2",                        # Focus Energy
    "EnsureNextCriticalHit",                            # Laser Focus
    "TargetActsLast",                                   # Quash
    "UseRandomMove"                                     # Metronome
  ]
end

#===============================================================================
# GameData::Species utilities for generating raid movesets.
#===============================================================================
module GameData
  class Species
    #---------------------------------------------------------------------------
    # Compiles all eligible raid moves a species may have.
    #---------------------------------------------------------------------------
    def compileRaidMoves(style, isRental = false, category = nil, special = nil)
      if !category
        if @base_stats[:ATTACK] >= @base_stats[:SPECIAL_ATTACK] + 20
          category = 0
        elsif @base_stats[:SPECIAL_ATTACK] >= @base_stats[:ATTACK] + 20
          category = 1
        end
      end
      blacklist = pbRaidBannedMoves(isRental)
      whitelist = pbRaidApprovedStatusMoves(category, isRental)
      raid_moves = Hash.new { |key, value| key[value] = [] }
      sig_move = self.getSignatureMove
      get_family_moves.each do |m|
        next if m == sig_move[1]
        move = GameData::Move.get(m)
        next if blacklist.include?(move.function_code)
        next if (1..60).include?(move.accuracy)
        #-----------------------------------------------------------------------
        # Compiles eligible status moves.
        if move.status?
          if !isRental && pbRaidSupportMoves.include?(move.function_code)
            raid_moves[:support] << move.id
          elsif whitelist.include?(move.function_code)
            raid_moves[:status] << move.id
          end
          next
        end
        #-----------------------------------------------------------------------
        # Checks for eligible move category.
        if ![
            "UseUserDefenseInsteadOfUserAttack",               # Body Press
            "CategoryDependsOnHigherDamagePoisonTarget",       # Shell Side Arm
            "CategoryDependsOnHigherDamageIgnoreTargetAbility" # Photon Geyser
          ].include?(move.function_code)
          case category
          when 0 then next if move.special?
          when 1 then next if move.physical?
          end
        end
        #-----------------------------------------------------------------------
        # Compiles eligible spread moves.
        if [:AllNearFoes, :AllNearOthers].include?(move.target) && !isRental
          raid_moves[:spread] << move.id if move.power >= 50
		  next
        else
          next if move.target == :AllNearOthers
        end
        #-----------------------------------------------------------------------
        # Checks for eligible multi-hit moves.
        if [
            "HitTwoToFiveTimes",                               # Pin Missile, Arm Thrust, etc.
            "HitTwoToFiveTimesRaiseUserSpd1LowerUserDef1",     # Scale Shot
            "HitTwoToFiveTimesOrThreeForAshGreninja",          # Water Shuriken
            "HitThreeTimesPowersUpWithEachHit",                # Triple Kick, Triple Axel
            "HitTenTimes"                                      # Population Bomb
          ].include?(move.function_code)
          next if move.power < 25
        elsif [
            "HitTwoTimes",                                     # Dual Chop, Dual Wingbeat, etc.
            "HitTwoTimesFlinchTarget",                         # Double Iron Bash
            "HitTwoTimesTargetThenTargetAlly",                 # Dragon Darts
          ].include?(move.function_code)
          next if move.power < 35
        elsif [
            "HitThreeTimes",                                   # Triple Dive
            "HitThreeTimesAlwaysCriticalHit"                   # Surging Strikes
          ].include?(move.function_code)
          next if move.power < 25
        #-----------------------------------------------------------------------
        # Checks for eligible priority moves.
        elsif move.priority > 0
          next if move.power < 40
		else
		  next if move.power < 55
        end
        case style
        #-----------------------------------------------------------------------
        # Compiles damaging moves for Ultra Raids.
        when :Ultra
          if special
            if special == move.id
              raid_moves[:primary] << move.id
            elsif @types.include?(move.type)
              raid_moves[:secondary] << move.id
            elsif move.type != :NORMAL || move.priority > 0
              raid_moves[:other] << move.id
            end
          elsif @types.include?(move.type)
            if move.power >= 80
              raid_moves[:primary] << move.id
            else
              raid_moves[:secondary] << move.id
            end
          elsif move.type != :NORMAL || move.priority > 0
            raid_moves[:other] << move.id
          end
        #-----------------------------------------------------------------------
        # Compiles damaging moves for Tera Raids.
        when :Tera
          if special == move.type
            raid_moves[:primary] << move.id
          elsif @types.include?(move.type)
            if move.power >= 80
              raid_moves[:secondary] << move.id
            else
              raid_moves[:other] << move.id
            end
          elsif move.type != :NORMAL || move.priority > 0
            raid_moves[:other] << move.id
          end
        #-----------------------------------------------------------------------
        # Compiles damaging moves for all other raids.
        else
          if @types.include?(move.type)
            if move.power >= 80
              raid_moves[:primary] << move.id
            else
              raid_moves[:secondary] << move.id
            end
          elsif move.type != :NORMAL || move.priority > 0
            raid_moves[:other] << move.id
          end
        end
      end
	  if special && !raid_moves.has_key?(:primary)
	    case style
	    when :Ultra then raid_moves[:primary] = [special]
	    when :Tera  then raid_moves[:primary] = raid_moves[:secondary].clone
	    end
	  end
      if GameData::Move.exists?(sig_move[1])
        if special && sig_move[0] == :primary && raid_moves.has_key?(:primary)
          raid_moves[:secondary] = [sig_move[1]]
        else
          raid_moves[sig_move[0]] = [sig_move[1]]
        end
      end
      return raid_moves
    end
    
    #---------------------------------------------------------------------------
    # Gets signature moves certain species should always have in raids.
    #---------------------------------------------------------------------------
    def getSignatureMove
      case @species
      when :TAUROS     then return [:primary,   :RAGINGBULL]
      when :SLAKING    then return [:primary,   :GIGAIMPACT]
      when :CASTFORM   then return [:primary,   :WEATHERBALL]
      when :DARKRAI    then return [:support,   :DARKVOID]
      when :ARCEUS     then return [:primary,   :JUDGMENT]
      when :KELDEO     then return [:primary,   :SECRETSWORD]
      when :MELOETTA   then return [:spread,    :RELICSONG]
      when :GENESECT   then return [:other,     :TECHNOBLAST]
      when :AEGISLASH  then return [:status,    :KINGSSHIELD]
      when :ORICORIO   then return [:primary,   :REVELATIONDANCE]
      when :SILVALLY   then return [:primary,   :MULTIATTACK]
      when :MELMETAL   then return [:primary,   :DOUBLEIRONBASH]
      when :CRAMORANT  then return [:spread,    :SURF]
      when :MORPEKO    then return [:primary,   :AURAWHEEL]
      when :DRAGAPULT  then return [:secondary, :DRAGONDARTS]
      when :ZACIAN     then return [:primary,   :IRONHEAD]
      when :ZAMAZENTA  then return [:primary,   :IRONHEAD]
      when :ANNIHILAPE then return [:secondary, :RAGEFIST]
      when :OGERPON    then return [:primary,   :IVYCUDGEL]
      when :TERAPAGOS  then return [:primary,   :TERASTARSTORM]
      end
      case @id
      when :MAROWAK    then return [:primary,   :BONEMERANG]
      when :ROTOM_1    then return [:secondary, :OVERHEAT]
      when :ROTOM_2    then return [:secondary, :HYDROPUMP]
      when :ROTOM_3    then return [:secondary, :BLIZZARD]
      when :ROTOM_4    then return [:secondary, :AIRSLASH]
      when :ROTOM_5    then return [:secondary, :LEAFSTORM]
      when :URSHIFU    then return [:primary,   :WICKEDBLOW]
      when :URSHIFU_1  then return [:primary,   :SURGINGSTRIKES]
      end
      return []
    end
  end
end

#===============================================================================
# Utility for getting all eligible raid moves for a specific Pokemon.
#===============================================================================
class Pokemon
  def getRaidMoves(style, isRental = false)
	category = (hasAbility?(:HUGEPOWER) || hasAbility?(:PUREPOWER)) ? 0 : nil
	special = nil
    case style
	when :Ultra
	  GameData::Item.each do |item|
        next if !item.is_zcrystal?
        next if !item.has_zmove_combo?
        species = (item.has_flag?("UsableByAllForms")) ? @species : species_data.id
        next if !item.zmove_species.include?(species)
        special = item.zmove_base_move
        break
      end
	when :Tera
	  special = self.tera_type
	end
    return species_data.compileRaidMoves(style, isRental, category, special)
  end
end