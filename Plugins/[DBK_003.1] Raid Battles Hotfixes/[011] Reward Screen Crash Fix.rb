#===============================================================================
# Raid Battle Reward Screen Crash Fix
#===============================================================================
# BUG: Game crashes after winning/losing a raid battle
# CAUSE: Battle rules (including raidRules) are cleared too early
# FIX: Preserve raid rules until after ALL post-battle processing
#
# CRASH 1: After winning - reward screen needs rules but they're gone
# CRASH 2: After losing - cleanup code needs rules but they're gone
# CRASH 3: Raid Den reward screen - @rules[:rank] is nil
# SOLUTION: Keep rules alive until EVERYTHING is done
#===============================================================================

# Global storage for raid rules during reward screen
$raid_reward_screen_data = nil

# Hook into WildBattle to preserve rules through the whole battle
class WildBattle
  class << self
    alias raid_crash_fix_start_core start_core
    
    def start_core(*args)
      # Check if this is a raid battle by checking battle_rules
      is_raid = $game_temp.battle_rules && $game_temp.battle_rules["raidBattle"]
      
      if is_raid
        # Store ALL battle rules before battle starts
        stored_all_rules = $game_temp.battle_rules.dup
        
        # Run the original battle
        decision = raid_crash_fix_start_core(*args)
        
        # Restore rules AFTER battle but BEFORE reward screen
        # Since battle_rules is read-only, we need to restore each rule individually
        stored_all_rules.each do |key, value|
          $game_temp.instance_variable_get(:@battle_rules)[key] = value
        end
        
        # Store raid data globally for reward screen
        if stored_all_rules["raidBattle"]
          raid_data = stored_all_rules["raidBattle"]
          $raid_reward_screen_data = {
            rules: raid_data.dup,  # Store complete raid rules, not just partial
            pokemon: raid_data[:pokemon]
          }
        end
        
        return decision
      else
        # Not a raid battle - normal processing
        return raid_crash_fix_start_core(*args)
      end
    end
  end
end

# Fix for Raid Den reward screen - @rules[:rank] nil error
class RaidScene
  alias raid_den_hotfix_pbRaidRewardsScreen pbRaidRewardsScreen
  
  def pbRaidRewardsScreen(outcome)
    # If @rules is nil, try to get from global storage
    if !@rules && $raid_reward_screen_data
      @rules = $raid_reward_screen_data[:rules]
      @pkmn = $raid_reward_screen_data[:pokemon]
    end
    
    # If still no rules, try battle_rules
    if !@rules && $game_temp.battle_rules && $game_temp.battle_rules["raidBattle"]
      raid_data = $game_temp.battle_rules["raidBattle"]
      @rules = raid_data.dup  # Use complete raid rules
      @pkmn = raid_data[:pokemon]
    end
    
    # Set path if not set
    if !@path || @path.empty?
      @path = Settings::RAID_GRAPHICS_PATH + "Raid Dens/"
      @path = @path.gsub("//", "/") # Fix double slashes
    end
    
    # Call the original method
    raid_den_hotfix_pbRaidRewardsScreen(outcome)
  end
end

# Also hook into RaidScene to set battle_rules before raid den battle
class RaidScene
  alias raid_den_battle_setup_pbRaidEntry pbRaidEntry
  
  def pbRaidEntry
    # Set battle_rules before battle starts
    if @rules
      $game_temp.battle_rules["raidBattle"] = @rules.dup
      $game_temp.battle_rules["raidBattle"][:pokemon] = @pkmn if @pkmn
    end
    
    # Call original
    raid_den_battle_setup_pbRaidEntry
  end
end

# Override the global function to redirect to instance method
alias original_pbRaidRewardsScreen pbRaidRewardsScreen rescue nil

def pbRaidRewardsScreen(outcome, rules = nil, pkmn = nil)
  echoln "[RAID DEN DEBUG] Global pbRaidRewardsScreen called - looking for RaidScene instance"
  
  # Try to find the current RaidScene instance
  # Check if $scene is a RaidScene
  if $scene && $scene.is_a?(RaidScene)
    echoln "[RAID DEN DEBUG] Found RaidScene instance in $scene"
    return $scene.pbRaidRewardsScreen(outcome)
  end
  
  # If no scene found, try the original global function if it exists
  if defined?(original_pbRaidRewardsScreen)
    echoln "[RAID DEN DEBUG] Calling original global function"
    return original_pbRaidRewardsScreen(outcome, rules, pkmn)
  end
  
  # Last resort: create a temporary scene
  scene = RaidScene.new
  
  # Set data from parameters or global storage
  if rules && pkmn
    scene.instance_variable_set(:@rules, rules)
    scene.instance_variable_set(:@pkmn, pkmn)
  elsif $raid_reward_screen_data
    scene.instance_variable_set(:@rules, $raid_reward_screen_data[:rules])
    scene.instance_variable_set(:@pkmn, $raid_reward_screen_data[:pokemon])
  end
  
  scene.instance_variable_set(:@path, Settings::RAID_GRAPHICS_PATH + "Raid Dens/")
  scene.instance_variable_get(:@path).gsub!("//", "/") # Fix double slashes
  
  scene.pbRaidRewardsScreen(outcome)
end

Console.echo_li("Raid Battles Hotfix: Reward Screen Crash Fix loaded (WIN+LOSE+DEN)")
