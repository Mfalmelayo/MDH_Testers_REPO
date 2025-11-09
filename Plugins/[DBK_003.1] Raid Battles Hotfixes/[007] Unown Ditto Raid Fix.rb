#===============================================================================
# Fix for Unown in Raid Battles
#===============================================================================
# Bug: Unown doesn't trigger shield and gives no rewards
# Root Cause: Unown only learns Hidden Power, which is banned from raids
#             This results in an empty moveset, causing various issues
# Fix Approach: Ban Unown from appearing in raids entirely
#===============================================================================

#===============================================================================
# Ban Unown from raid species lists
#===============================================================================
module GameData
  class Species
    alias unown_raid_raid_species? raid_species?
    
    def raid_species?(style)
      # Ban Unown from all raids since it only learns Hidden Power (banned move)
      return false if @species == :UNOWN
      return unown_raid_raid_species?(style)
    end
  end
end
