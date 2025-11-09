#===============================================================================
# Cheer Handler Null Reference Fix
# Fixes nil comparison errors in cheer handlers
#===============================================================================

# Fix for cheer effectiveness calculations that cause nil errors
module Battle::BattlerEffects
  alias hotfix_cheer_effectiveness cheer_effectiveness if method_defined?(:cheer_effectiveness)
  def cheer_effectiveness
    result = hotfix_cheer_effectiveness if respond_to?(:hotfix_cheer_effectiveness)
    return result if result && result.is_a?(Numeric)
    return 0 # Safe default
  end
end

# Override problematic cheer handler
EventHandlers.add(:onRaidCheerUsed, :fix_null_reference,
  proc { |battle, cheer_data, effectiveness|
    # Add nil checks to prevent undefined method errors
    next if effectiveness.nil?
    next if cheer_data.nil?
    
    # Ensure proper type checking before comparisons
    if effectiveness.is_a?(Numeric) && effectiveness < 0
      # Handle negative effectiveness safely
      battle.pbDisplay(_INTL("The cheer had no effect..."))
    end
  }
)