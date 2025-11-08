class Battle::Battler
  def reborn?
    return @battle.phoenixDown[@index & 1][@pokemonIndex]
  end
  def setReborn
    @battle.phoenixDown[@index & 1][@pokemonIndex] = true
  end
  
  def pbRemoveItem(permanent = true)
    @effects[PBEffects::ChoiceBand] = nil if !hasActiveAbility?([:GORILLATACTICS,:SAGEPOWER])
    @effects[PBEffects::Unburden]   = true if self.item && hasActiveAbility?(:UNBURDEN)
    setInitialItem(nil) if permanent && self.item == self.initialItem
    self.item = nil
  end
  
  def pbEndTurn(_choice)
    @lastRoundMoved = @battle.turnCount   # Done something this round
    if !@effects[PBEffects::ChoiceBand] &&
       (hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF]) ||
       hasActiveAbility?([:GORILLATACTICS,:SAGEPOWER]))
      if @lastMoveUsed && pbHasMove?(@lastMoveUsed)
        @effects[PBEffects::ChoiceBand] = @lastMoveUsed
      elsif @lastRegularMoveUsed && pbHasMove?(@lastRegularMoveUsed)
        @effects[PBEffects::ChoiceBand] = @lastRegularMoveUsed
      end
    end
    @effects[PBEffects::BeakBlast]   = false
    @effects[PBEffects::Charge]      = 0 if @effects[PBEffects::Charge] == 1
    @effects[PBEffects::GemConsumed] = nil
    @effects[PBEffects::ShellTrap]   = false
    @battle.allBattlers.each { |b| b.pbContinualAbilityChecks }   # Trace, end primordial weathers
  end

  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    # Disable
    if @effects[PBEffects::DisableMove] == move.id && !specialUsage
      if showMessages
        msg = _INTL("{1}'s {2} is disabled!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Heal Block
    if @effects[PBEffects::HealBlock] > 0 && move.healingMove?
      if showMessages
        msg = _INTL("{1} can't use {2} because of Heal Block!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Gravity
    if @battle.field.effects[PBEffects::Gravity] > 0 && move.unusableInGravity?
      if showMessages
        msg = _INTL("{1} can't use {2} because of gravity!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Throat Chop
    if @effects[PBEffects::ThroatChop] > 0 && move.soundMove?
      if showMessages
        msg = _INTL("{1} can't use {2} because of Throat Chop!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Choice Band/Gorilla Tactics
    @effects[PBEffects::ChoiceBand] = nil if !pbHasMove?(@effects[PBEffects::ChoiceBand])
    if @effects[PBEffects::ChoiceBand] && move.id != @effects[PBEffects::ChoiceBand]
      choiced_move = GameData::Move.try_get(@effects[PBEffects::ChoiceBand])
      if choiced_move
        if hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF])
          if showMessages
            msg = _INTL("The {1} only allows the use of {2}!", itemName, choiced_move.name)
            (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
          end
          return false
        elsif hasActiveAbility?([:GORILLATACTICS,:SAGEPOWER,:ASSUREDVICTORY])
          if showMessages
            msg = _INTL("{1} can only use {2}!", pbThis, choiced_move.name)
            (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
          end
          return false
        end
      end
    end
    # Taunt
    if @effects[PBEffects::Taunt] > 0 && move.statusMove? && !specialUsage
      if showMessages
        msg = _INTL("{1} can't use {2} after the taunt!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Torment
    if @effects[PBEffects::Torment] && !@effects[PBEffects::Instructed] && !specialUsage &&
       @lastMoveUsed && move.id == @lastMoveUsed && move.id != @battle.struggle.id
      if showMessages
        msg = _INTL("{1} can't use the same move twice in a row due to the torment!", pbThis)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Imprison
    if @battle.allOtherSideBattlers(@index).any? { |b| b.effects[PBEffects::Imprison] && b.pbHasMove?(move.id) }
      if showMessages
        msg = _INTL("{1} can't use its sealed {2}!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Assault Vest (prevents choosing status moves but doesn't prevent
    # executing them)
    if hasActiveItem?(:ASSAULTVEST) && move.statusMove? && move.function_code != "UseMoveTargetIsAboutToUse" && commandPhase
      if showMessages
        msg = _INTL("The effects of the {1} prevent status moves from being used!", itemName)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Belch
    return false if !move.pbCanChooseMove?(self, commandPhase, showMessages)
    return true
  end

end