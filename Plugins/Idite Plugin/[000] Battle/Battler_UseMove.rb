class Battle::Battler
	#mootoo
	alias mag_pbEndTurn pbEndTurn
  def pbEndTurn(_choice)
  @lastRoundMoved = @battle.turnCount   # Done something this round
    if !@effects[PBEffects::ChoiceBand] && hasActiveAbility?(:ASSUREDVICTORY)
      if @lastMoveUsed && pbHasMove?(@lastMoveUsed)
        @effects[PBEffects::ChoiceBand] = @lastMoveUsed
      elsif @lastRegularMoveUsed && pbHasMove?(@lastRegularMoveUsed)
        @effects[PBEffects::ChoiceBand] = @lastRegularMoveUsed
      end
    end
	 return mag_pbEndTurn(_choice)
end
end