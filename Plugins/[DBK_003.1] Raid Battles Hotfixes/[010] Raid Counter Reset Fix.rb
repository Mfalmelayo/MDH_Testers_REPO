#===============================================================================
# Fix for Raid Counters Persisting Between Battles
#===============================================================================
# Bug: Raid hash persists between battles, causing counters to carry over
# Root Cause: @raidRules hash is not being cleared when raid battle ends
# Impact: Next raid starts with old counters, causing instant failure
# Solution: Completely clear raid hash and all related state on battle end
#===============================================================================

#===============================================================================
# Fix 1: Clear entire raid hash when battle ends
#===============================================================================
class Battle
  alias raid_counter_pbEndOfBattle pbEndOfBattle
  
  def pbEndOfBattle
    # Always clear raid state when any raid battle ends (win or lose)
    if @raidRules && !@raidRules.empty?
      # COMPLETE RESET: Clear the entire hash, not just individual keys
      # This prevents any leftover data from persisting
      @raidRules.clear
      
      # Also clear any instance variables that might be caching values
      @raid_turnCount = nil if defined?(@raid_turnCount)
      @raid_koCount = nil if defined?(@raid_koCount)
      @raidBattle = nil if defined?(@raidBattle)
    end
    
    raid_counter_pbEndOfBattle
  end
end

#===============================================================================
# Fix 2: Safety check - prevent starting raid with existing counters
#===============================================================================
class Battle
  alias raid_counter_pbStartBattle pbStartBattle if method_defined?(:pbStartBattle)
  
  def pbStartBattle
    # Before battle starts, double-check raid state is clean
    if raidBattle? && @raidRules
      # If counters already exist at start, something went wrong - clear them
      if @raidRules[:turn_count] || @raidRules[:ko_count] || 
         @raidRules[:raid_turnCount] || @raidRules[:raid_koCount]
        @raidRules.delete(:turn_count)
        @raidRules.delete(:ko_count)
        @raidRules.delete(:raid_turnCount)
        @raidRules.delete(:raid_koCount)
      end
    end
    
    raid_counter_pbStartBattle if defined?(raid_counter_pbStartBattle)
  end
end