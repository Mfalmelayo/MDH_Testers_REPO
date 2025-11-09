#===============================================================================
# Adventure Outcome Logic Fix
# Fixes logic error in adventure completion that prevented proper rewards
#===============================================================================

# Fix for Adventure Map Core outcome logic
class Scene_AdventureMap
  def pbEndAdventure
    return if !@adventure
    if @adventure.outcome == 1 && (!@adventure.captures.empty? || !@adventure.loot.empty?)
      pbMessage(_INTL("Adventure complete!"))
      pbSpoilsMenu(@adventure.captures, @adventure.loot) if @adventure.captures.length > 0 || @adventure.loot.length > 0
    elsif @adventure.outcome == 0
      pbMessage(_INTL("Adventure failed..."))
    end
    @adventure = nil
    @scene.pbCloseScene
    @scene = nil
  end
end