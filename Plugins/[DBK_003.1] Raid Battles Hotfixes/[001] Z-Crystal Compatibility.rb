#===============================================================================
# Z-Crystal Compatibility Fix
# Adds hasZCrystal? method when Z-Power plugin is not installed
#===============================================================================

if !PluginManager.installed?("[DBK] Z-Power")
  class Battle::Battler
    def hasZCrystal?
      return false
    end
  end
end