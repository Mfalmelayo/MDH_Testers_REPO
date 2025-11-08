#===============================================================================
# Stat Steal Boss Mechanic (Immediate Trigger)
# Boss Pokémon steals stat boosts immediately when they are raised.
#===============================================================================

module StatStealBossMechanic
    # Toggle for enabling the mechanic in specific battles
    def self.enabled?(battle)
      return $game_switches[526] 
    end
  
    # Handles stealing of stats as they are applied
    def self.steal_stat(battler, stat, increment, battle)
      # Find all unfainted opposing Pokémon using allOpposing
      opposing_battlers = battler.allOpposing
      return if opposing_battlers.empty?
  
      opponent = opposing_battlers.first # Use the first available opposing battler
  
      # Only apply the mechanic to player-controlled Pokémon
      if battler.pbOwnedByPlayer? && increment > 0
        if opponent
          battle.pbDisplay(_INTL("{1} stole {2}'s boosted {3}!", 
                                 opponent.name, battler.name, GameData::Stat.get(stat).name))
          # Apply the stat boost to the opponent
          if opponent.pbCanRaiseStatStage?(stat, opponent, nil)
            opponent.pbRaiseStatStage(stat, increment, opponent)
          end
          # Lower the stat for the player's Pokémon to nullify it
          battler.pbLowerStatStage(stat, increment, battler, true)
          battle.pbDisplay(_INTL("{1}'s {2} boost was nullified!", 
                                 battler.name, GameData::Stat.get(stat).name))
        end
      end
    end
  end
  
  #===============================================================================
  # Hooking into stat stage changes to trigger the mechanic immediately
  #===============================================================================
  class Battle::Battler
    alias original_pbRaiseStatStage pbRaiseStatStage
    def pbRaiseStatStage(stat, increment, user = nil, showAnim = true)
      if @battle && StatStealBossMechanic.enabled?(@battle)
        StatStealBossMechanic.steal_stat(self, stat, increment, @battle)
      end
      original_pbRaiseStatStage(stat, increment, user, showAnim)
    end
  end
  