class Battle::Move
	
	alias mag_pbCalcTypeModSingle pbCalcTypeModSingle
	def pbCalcTypeModSingle(moveType, defType, user, target)
		ret = mag_pbCalcTypeModSingle(moveType, defType, user, target)
		if Effectiveness.normal_type?(moveType, defType)
			if target.hasActiveAbility?(:CIRCUITPHANTOM) && moveType == :GHOST
				ret = Effectiveness::NOT_VERY_EFFECTIVE_MULTIPLIER
				elsif user.hasActiveAbility?(:CIRCUITPHANTOM) &&  user.pbHasType?(moveType) && defType == :STEEL
				ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
			end
			elsif Effectiveness.not_very_effective_type?(moveType, defType)
			if user.hasActiveAbility?(:CIRCUITPHANTOM) &&  user.pbHasType?(moveType) && defType == :STEEL
				ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
			end
		end
		return ret
	end
end