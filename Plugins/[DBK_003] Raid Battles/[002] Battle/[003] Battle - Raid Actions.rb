#===============================================================================
# Battle class additions related to extra raid actions.
#===============================================================================
class Battle
  #-----------------------------------------------------------------------------
  # Utility for triggering various exra raid actions.
  #-----------------------------------------------------------------------------
  def pbRaidExtraActions(battler)
    return if pbAllFainted? || @decision > 0
    return if !battler || battler.fainted? || !battler.isRaidBoss?
	return if !@raidRules[:extra_actions]
	maxCount = @raidRules[:max_turnCount] || 0
    @raidRules[:extra_actions].each do |action|
      case action
      #-------------------------------------------------------------------------
      # Negates the party's raised stats as well as their Abilities.
      when :reset_boosts
	    if battler.hp <= battler.totalhp * 0.4 || (maxCount > 0 && @raidRules[:turn_count] <= (maxCount * 0.4).round)
          pbRaidResetBoosts(battler)
		  @raidRules[:extra_actions].delete(action)
		end
	  #-------------------------------------------------------------------------
      # Negates raid Pokemon's stat drops and cures its status condition.
      when :reset_drops
	    if battler.hp <= battler.totalhp * 0.6 || (maxCount > 0 && @raidRules[:turn_count] <= (maxCount * 0.6).round)
	      pbRaidResetDrops(battler)
		  @raidRules[:extra_actions].delete(action)
		end
      #-------------------------------------------------------------------------
      # Reduces the Cheer level of the player and ally trainers by 1.
      when :drain_cheer
	    if battler.hp <= battler.totalhp * 0.5 || (maxCount > 0 && @raidRules[:turn_count] <= (maxCount * 0.5).round)
	      pbRaidDrainCheer(battler)
		  @raidRules[:extra_actions].delete(action)
		end
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Utilities for specific raid actions.
  #-----------------------------------------------------------------------------
  def pbRaidResetDrops(battler)
    @scene.pbAnimateExtraAction(battler.index)
	pbDisplay(_INTL("{1} removed negative effects from itself!", battler.pbThis))
	PBDebug.log("[Raid mechanics] #{battler.pbThis} (#{battler.index}) triggered an extra action (reset drops)")
	battler.pbCureStatus
	if battler.hasLoweredStatStages?
	  battler.statsRaisedThisRound = true
	end
	GameData::Stat.each_battle do |s|
	  next if battler.stages[s.id] >= 0
	  battler.stages[s.id] = 0
	end
	pbCalculatePriority(false, [battler.index])
  end
  
  def pbRaidResetBoosts(battler)
    @scene.pbAnimateExtraAction(battler.index)
	pbDisplay(_INTL("{1} nullified the stat changes and Abilities affecting your side!", battler.pbThis))
	PBDebug.log("[Raid mechanics] #{battler.pbThis} (#{battler.index}) triggered an extra action (reset boosts)")
	battlers = []
	allOtherSideBattlers(battler).each do |b|
	  if b.hasRaisedStatStages?
	    b.statsLoweredThisRound = true
        b.statsDropped = true
	  end
	  GameData::Stat.each_battle { |s| b.stages[s.id] = 0 if b.stages[s.id] > 0 }
	  b.effects[PBEffects::GastroAcid] = true if !b.hasActiveItem?(:ABILITYSHIELD)
	  battlers.push(b.index)
	end
	pbCalculatePriority(false, battlers)
  end
  
  def pbRaidDrainCheer(battler)
    @scene.pbAnimateExtraAction(battler.index)
	pbDisplay(_INTL("{1} reduced the effectiveness of cheering!", battler.pbThis))
	PBDebug.log("[Raid mechanics] #{battler.pbThis} (#{battler.index}) triggered an extra action (drain cheer)")
	@cheerLevel[0].length.times do |i|
      oldLvl = @cheerLevel[0][i]
	  next if oldLvl <= 0
	  @cheerLevel[0][i] -= 1
	  PBDebug.log("[Cheer level] #{@player[i].name}'s Cheer level changed (#{oldLvl} => #{@cheerLevel[0][i]})")
	end
  end
  
  #-----------------------------------------------------------------------------
  # Utility for triggering the Extra Move action.
  #-----------------------------------------------------------------------------
  def pbRaidUseExtraMove(battler, choice)
    return if choice[0] != :UseMove || pbAllFainted? || @decision > 0
    return if battler.fainted? || !battler.isRaidBoss?
	[:support_moves, :spread_moves].each do |moves|
	  next if !@raidRules[moves] || @raidRules[moves].empty?
	  case moves
	  when :support_moves
		maxCount = @raidRules[:max_turnCount] || 0
		if maxCount > 0
		  next if ![maxCount, (maxCount / 2).floor].include?(@raidRules[:turn_count])
		else
		  next if ![0, 5].include?(@turnCount)
		end
		type = "support move"
	  when :spread_moves
	    next if !battler.hasRaidShield?
	    type = "spread move"
	  end
	  move = @battleAI.pbRaidChooseExtraMove(battler.index, @raidRules[moves])
	  next if move.nil?
	  @scene.pbAnimateExtraAction(battler.index)
	  PBDebug.log("[Raid mechanics] #{battler.pbThis} (#{battler.index}) triggered an extra move (#{type})")
	  PBDebug.logonerr{ battler.pbUseMoveSimple(move, -1, -1, false) }
	  pbJudge
	end
  end
end

#===============================================================================
# Battle::Battler class additions related to processing moves.
#===============================================================================
class Battle::Battler
  #-----------------------------------------------------------------------------
  # Aliased to process all additional attacks a raid Pokemon can use in a turn.
  #-----------------------------------------------------------------------------
  alias raid_pbProcessTurn pbProcessTurn
  def pbProcessTurn(choice, tryFlee = true)
	@battle.pbRaidUseExtraMove(self, choice)
	return false if self.isRaidBoss? && @battle.raidRules[:ko_count] == 0
	ret = raid_pbProcessTurn(choice, tryFlee)
	pbRaidDoubleAttackPhase(choice)
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Utility for processing a raid Pokemon's second attack phase.
  #-----------------------------------------------------------------------------
  def pbRaidDoubleAttackPhase(choice)
    return if choice[0] != :UseMove || @battle.pbAllFainted?
    return if self.fainted? || !self.isRaidBoss?
	return if @battle.decision > 0 || @battle.raidRules[:ko_count] == 0
	maxCount = @battle.raidRules[:max_turnCount] || 0
	if @hp <= @totalhp * 0.4 || (maxCount > 0 && @battle.raidRules[:turn_count] <= (maxCount * 0.4).round)
	  moves = (@baseMoves.empty?) ? @moves.clone : @baseMoves.clone
	  if moves.length > 1
	    moves.length.times { |i| moves[i] = nil if moves[i].id == @lastMoveUsed }
	    moves.compact!
	  end
	  idxRand = rand(moves.length)
	  choice[1] = idxRand
	  choice[2] = moves[idxRand]
	  choice[3] = -1
	  PBDebug.log("[Raid mechanics] #{pbThis} (#{@index}) triggered an extra move (double attack)")
	  PBDebug.log("[Use move] #{pbThis} (#{@index}) used #{choice[2].name}")
	  PBDebug.logonerr { pbUseMove(choice) }
	  @battle.pbJudge
	end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to allow raid Pokemon to use Belch without consuming a berry.
  #-----------------------------------------------------------------------------
  alias raid_belched? belched?
  def belched?
    return true if self.isRaidBoss?
    return raid_belched?
  end
end

#===============================================================================
# Battle::AI class additions related to selecting an Extra Move action.
#===============================================================================
class Battle::AI
  #-----------------------------------------------------------------------------
  # Scores all possible Extra Moves a raid Pokemon can use.
  #-----------------------------------------------------------------------------
  def pbRaidExtraMoveScores(moves)
    idxMove = -1
    choices = []
	PBDebug.log("[Raid mechanics] #{@user.name} is considering extra move choices...")
    moves.each do |m|
      next if @user.battler.pbHasMove?(m)
	  move = Battle::Move.from_pokemon_move(@battle, Pokemon::Move.new(m))
      set_up_move_check(move)
      if @trainer.has_skill_flag?("PredictMoveFailure") && pbPredictMoveFailure
        PBDebug.log_ai("#{@user.name} is considering using #{move.name}...")
        PBDebug.log_score_change(MOVE_FAIL_SCORE - MOVE_BASE_SCORE, "move will fail")
        choices.push([move, MOVE_FAIL_SCORE, -1])
        next
      end
      target_data = @move.pbTarget(@user.battler)
      if @move.function_code == "CurseTargetOrLowerUserSpd1RaiseUserAtkDef1" &&
         @move.rough_type == :GHOST && @user.has_active_ability?([:LIBERO, :PROTEAN])
        target_data = GameData::Target.get((Settings::MECHANICS_GENERATION >= 8) ? :RandomNearFoe : :NearFoe)
      end
      case target_data.num_targets
      when 0
        PBDebug.log_ai("#{@user.name} is considering using #{move.name}...")
        score = MOVE_BASE_SCORE
        PBDebug.logonerr { score = pbGetMoveScore }
        choices.push([move, score, -1])
      when 1
        redirected_target = get_redirected_target(target_data)
        num_targets = 0
        @battle.allBattlers.each do |b|
          next if redirected_target && b.index != redirected_target
          next if !@battle.pbMoveCanTarget?(@user.battler.index, b.index, target_data)
          next if target_data.targets_foe && !@user.battler.opposes?(b)
          PBDebug.log_ai("#{@user.name} is considering using #{move.name} against #{b.name} (#{b.index})...")
          score = MOVE_BASE_SCORE
          PBDebug.logonerr { score = pbGetMoveScore([b]) }
          choices.push([move, score, b.index])
          num_targets += 1
        end
        PBDebug.log("     no valid targets") if num_targets == 0
      else
        targets = []
        @battle.allBattlers.each do |b|
          next if !@battle.pbMoveCanTarget?(@user.battler.index, b.index, target_data)
          targets.push(b)
        end
        PBDebug.log_ai("#{@user.name} is considering using #{move.name}...")
        score = MOVE_BASE_SCORE
        PBDebug.logonerr { score = pbGetMoveScore(targets) }
        choices.push([move, score, -1])
      end
    end
    @battle.moldBreaker = false
    return choices
  end
  
  #-----------------------------------------------------------------------------
  # Returns the Extra Move the raid Pokemon should use after tallying scores.
  #-----------------------------------------------------------------------------
  def pbRaidChooseExtraMove(idxBattler, moves)
    set_up(idxBattler)
    choice = nil
    choices = pbRaidExtraMoveScores(moves)
    user_battler = @user.battler
    if choices.length == 0
      PBDebug.log_ai("#{@user.name} will not use an extra move")
      return nil
    end
    max_score = 0
    choices.each { |c| max_score = c[1] if max_score < c[1] }
    threshold = (max_score * move_score_threshold.to_f).floor
    choices.each { |c| c[3] = [c[1] - threshold, 0].max }
    total_score = choices.sum { |c| c[3] }
    if $INTERNAL
      PBDebug.log_ai("Extra move choices for #{@user.name}:")
      choices.each_with_index do |c, i|
        chance = sprintf("%5.1f", (c[3] > 0) ? 100.0 * c[3] / total_score : 0)
        log_msg = "   * #{chance}% to use #{c[0].name}"
        log_msg += " (target #{c[2]})" if c[2] >= 0
        log_msg += ": score #{c[1]}"
        PBDebug.log(log_msg)
      end
    end
    randNum = pbAIRandom(total_score)
    choices.each_with_index do |c, i|
      randNum -= c[3]
      next if randNum >= 0
      choice = i
      break
    end
    if choice
      move_name = choices[choice][0].name
      if choices[choice][2] >= 0
        PBDebug.log("   => will use #{move_name} (target #{choices[choice][2]})")
      else
        PBDebug.log("   => will use #{move_name}")
      end
      PBDebug.log("")
      return choices[choice][0].id
    else
      return nil
    end
  end
end