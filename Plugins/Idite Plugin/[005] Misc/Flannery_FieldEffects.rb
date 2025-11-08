#===============================================================================
# Inferno Field Effect - Weakens Water moves, Boosts Fire moves
# Toasty Field Effect, Hot Field Effect
#===============================================================================

#-------------------------------------------------------------------------------
# Helper method to dynamically assign the next available ID in PBEffects.
#-------------------------------------------------------------------------------
def next_available_effect_id
  PBEffects.constants.map { |sym| PBEffects.const_get(sym) }.max + 1
end

#-------------------------------------------------------------------------------
# Dynamically assign IDs for the new field effects.
#-------------------------------------------------------------------------------
module PBEffects
  ToastyField  = next_available_effect_id
  HotField     = next_available_effect_id
  InfernoField = next_available_effect_id
end

module Battle::DebugVariables
  FIELD_EFFECTS[PBEffects::ToastyField]        = {name: "Toasty Field Active",  default: 0}
  FIELD_EFFECTS[PBEffects::HotField]           = {name: "Hot Field Active",     default: 0}
  FIELD_EFFECTS[PBEffects::InfernoField]       = {name: "Inferno Field Active", default: 0}
end

#-------------------------------------------------------------------------------
class Battle::ActiveField
  alias inferno_initialize initialize
  def initialize
    inferno_initialize

    max_effect_id = [PBEffects::ToastyField, PBEffects::HotField, PBEffects::InfernoField].max
    @effects[max_effect_id] ||= 0

    @effects[PBEffects::ToastyField]  = 0  # Toasty Field
    @effects[PBEffects::HotField]     = 0  # Hot Field
    @effects[PBEffects::InfernoField] = 0  # Inferno Field
  end
end



#-------------------------------------------------------------------------------
# Move Effects: Toasty Field, Hot Field, Inferno Field
#-------------------------------------------------------------------------------
class Battle::Move::ToastyField < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if damagingMove?
    if @battle.field.effects[PBEffects::ToastyField] > 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return true if pbMoveFailedLastInRound?(user)
    return false
  end

  def pbEffectGeneral(user)
    return if @battle.field.effects[PBEffects::ToastyField] > 0
    @battle.field.effects[PBEffects::ToastyField] = 5  # Lasts for 5 turns
    @battle.pbDisplay(_INTL("The battlefield is getting warm! Fire-type moves are strengthened, and Water-type moves are weakened!"))
  end
end

class Battle::Move::HotField < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if damagingMove?
    if @battle.field.effects[PBEffects::HotField] > 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return true if pbMoveFailedLastInRound?(user)
    return false
  end

  def pbEffectGeneral(user)
    return if @battle.field.effects[PBEffects::HotField] > 0
    @battle.field.effects[PBEffects::HotField] = 5  # Lasts for 5 turns
    @battle.pbDisplay(_INTL("The battlefield is hot! Fire-type moves are greatly strengthened, and Water-type moves are almost useless!"))
  end
end

class Battle::Move::InfernoField < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if damagingMove?
    if @battle.field.effects[PBEffects::InfernoField] > 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return true if pbMoveFailedLastInRound?(user)
    return false
  end

  def pbEffectGeneral(user)
    return if @battle.field.effects[PBEffects::InfernoField] > 0
    @battle.field.effects[PBEffects::InfernoField] = 5  # Lasts for 5 turns
    @battle.pbDisplay(_INTL("The battlefield is covered in an inferno! Fire-type moves are unstoppable, and Water-type moves will evaporate!"))
  end
end

#-------------------------------------------------------------------------------
# Modify move power calculation to account for the new Fields.
#-------------------------------------------------------------------------------
class Battle::Move
  alias original_pbCalcDamageMultipliers pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    original_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    # Toasty Field
    if @battle.field.effects[PBEffects::ToastyField] > 0
      if type == :FIRE
        multipliers[:power_multiplier] *= 1.2
        @battle.pbDisplay(_INTL("{1}'s Fire-type move is powered up by the Toasty Field!", user.pbThis))
      elsif type == :WATER
        multipliers[:power_multiplier] *= 0.75
        @battle.pbDisplay(_INTL("{1}'s Water-type move is weakened by the Toasty Field!", user.pbThis))
      end
    end

    # Hot Field
    if @battle.field.effects[PBEffects::HotField] > 0
      if type == :FIRE
        multipliers[:power_multiplier] *= 1.5
        @battle.pbDisplay(_INTL("{1}'s Fire-type move is greatly powered up by the Hot Field!", user.pbThis))
      elsif type == :WATER
        multipliers[:power_multiplier] *= 0.33
        @battle.pbDisplay(_INTL("{1}'s Water-type move is severely weakened by the Hot Field!", user.pbThis))
      end
    end

    # Inferno Field
    if @battle.field.effects[PBEffects::InfernoField] > 0
      if type == :FIRE
        multipliers[:power_multiplier] *= 2.0
        @battle.pbDisplay(_INTL("{1}'s Fire-type move is empowered to the max by the Inferno Field!", user.pbThis))
      elsif type == :WATER
        multipliers[:power_multiplier] = 0.01
        @battle.pbDisplay(_INTL("{1}'s Water-type move evaporates in the Inferno Field!", user.pbThis))
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Handle Field Effect durations during the End of Round Phase.
#-------------------------------------------------------------------------------
def pbEORCountDownFieldEffect(effect, msg)
  return if @field.effects[effect] <= 0
  @field.effects[effect] -= 1
  return if @field.effects[effect] > 0
  pbDisplay(msg)
end

def pbEOREndFieldEffects(priority)
  # Trick Room
  pbEORCountDownFieldEffect(PBEffects::TrickRoom,
                            _INTL("The twisted dimensions returned to normal!"))
  # Gravity
  pbEORCountDownFieldEffect(PBEffects::Gravity,
                            _INTL("Gravity returned to normal!"))
  # Water Sport
  pbEORCountDownFieldEffect(PBEffects::WaterSportField,
                            _INTL("The effects of Water Sport have faded."))
  # Mud Sport
  pbEORCountDownFieldEffect(PBEffects::MudSportField,
                            _INTL("The effects of Mud Sport have faded."))
  # Wonder Room
  pbEORCountDownFieldEffect(PBEffects::WonderRoom,
                            _INTL("Wonder Room wore off, and Defense and Sp. Def stats returned to normal!"))
  # Magic Room
  pbEORCountDownFieldEffect(PBEffects::MagicRoom,
                            _INTL("Magic Room wore off, and held items' effects returned to normal!"))
  # Toasty Field Effect Duration
  pbEORCountDownFieldEffect(PBEffects::ToastyField,
                            _INTL("The battlefield cooled off!"))
  # Hot Field Effect Duration
  pbEORCountDownFieldEffect(PBEffects::HotField,
                            _INTL("The heat blew over! The battlefield returned to normal!"))
  # Inferno Field Effect Duration
  pbEORCountDownFieldEffect(PBEffects::InfernoField,
                            _INTL("The inferno covering the battlefield subsided!"))
end

=begin
#-------------------------------------------------------------------------------
# Ensure that field effects decrement at the end of each round
#-------------------------------------------------------------------------------
class Battle
  alias original_pbEndOfRoundPhase pbEndOfRoundPhase

  def pbEndOfRoundPhase
    original_pbEndOfRoundPhase  # Call the original method to handle the usual end of round events

    # Now handle the end of round for the custom field effects
    pbEOREndFieldEffects(nil)
  end
end
=end