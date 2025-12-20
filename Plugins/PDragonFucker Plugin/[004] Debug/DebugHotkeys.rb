#===============================================================================
# * Debug Hotkeys Plugin (Essentials v21.1 - RGSS)
#   F5 = Heal party (plays SE)
#   F6 = Set eggs to 1 step (plays SE or bump if no eggs)
#===============================================================================

module DebugHotkeys
  KEY_HEAL = 25  # Q key
  KEY_EGGS = 26  # W key
  SE_SUCCESS = "Voltorb Flip point"
  SE_FAIL    = "Player bump"

  def self.quick_heal
    $player.heal_party
    pbSEPlay(SE_SUCCESS)
  end

  def self.quick_hatch
    eggs_found = false
    $player.party.each do |pkmn|
      next unless pkmn.egg?
      pkmn.steps_to_hatch = 1
      eggs_found = true
    end
    pbSEPlay(eggs_found ? SE_SUCCESS : SE_FAIL)
  end
end

class Scene_Map
  alias debug_hotkeys_update update
  def update
    debug_hotkeys_update
    return unless $DEBUG

    # F5 → Heal party
    if Input.trigger?(DebugHotkeys::KEY_HEAL)
      DebugHotkeys.quick_heal
    end

    # F6 → Egg step reset
    if Input.trigger?(DebugHotkeys::KEY_EGGS)
      DebugHotkeys.quick_hatch
    end
  end
end
