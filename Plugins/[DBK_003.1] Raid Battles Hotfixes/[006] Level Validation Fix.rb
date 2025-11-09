#===============================================================================
# Level Validation Fix  
# Fixes level-related errors and KO display issues
#===============================================================================

class Battle::Battler
  # Fix level validation to prevent nil errors
  alias hotfix_level level
  def level
    base_level = hotfix_level
    return base_level if base_level && base_level > 0
    return 50 # Default fallback level
  end
  
  # Fix KO display issues
  alias hotfix_fainted? fainted?
  def fainted?
    return false if @hp.nil?
    return hotfix_fainted?
  end
end

# Fix databox display for high-level Pokemon
class Battle::Scene
  def pbRefreshDataboxes
    # Add level validation before displaying
    if @sprites["dataBox_0"]&.battler
      level = @sprites["dataBox_0"].battler.level
      @sprites["dataBox_0"].level = level if level && level > 0
    end
    if @sprites["dataBox_1"]&.battler
      level = @sprites["dataBox_1"].battler.level  
      @sprites["dataBox_1"].level = level if level && level > 0
    end
  end
end