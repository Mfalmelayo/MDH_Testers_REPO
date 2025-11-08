#===============================================================================
# Battle::AI additions for cheers.
#===============================================================================
class Battle::AI
  #-----------------------------------------------------------------------------
  # Used for AI scoring of the viability of cheers.
  #-----------------------------------------------------------------------------
  CHEER_FAIL_SCORE    = 20
  CHEER_USELESS_SCORE = 60
  CHEER_BASE_SCORE    = 100
  
  #-----------------------------------------------------------------------------
  # Aliased to allow cheer consideration prior to selecting move commands.
  #-----------------------------------------------------------------------------
  alias cheer_pbChooseToUseSpecialCommand pbChooseToUseSpecialCommand
  def pbChooseToUseSpecialCommand
    ret = cheer_pbChooseToUseSpecialCommand
    ret = pbChooseToUseCheer if !ret
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Registers a cheer if one is selected.
  #-----------------------------------------------------------------------------
  def pbChooseToUseCheer
    cheer = nil
    idxCheer = nil
    cheer, idxCheer = choose_cheer_to_use
    return false if !cheer
    @battle.pbRegisterCheer(@user.index, idxCheer)
    PBDebug.log_ai("#{@user.name} will use #{GameData::Cheer.get(cheer).name}")
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Compiles all usable cheers and scores them.
  #-----------------------------------------------------------------------------
  def choose_cheer_to_use
    return nil if !@battle.hasCheer?(@user.index)
    trainer_index = @battle.pbGetOwnerIndexFromBattlerIndex(@user.index)
    cheerLvl = @battle.cheerLevel[@user.side][trainer_index]
	return nil if cheerLvl == 0
	if @battle.raidBattle?
	  case @battle.raidRules[:style]
	  when :Ultra then return nil if @user.battler.ultra?   || @battle.pbCanZMove?(@user.index)
	  when :Max   then return nil if @user.battler.dynamax? || @battle.pbCanDynamax?(@user.index)
	  when :Tera  then return nil if @user.battler.tera?    || @battle.pbCanTerastallize?(@user.index)
	  end
	end
    cheers = []
    Battle::Scene::CheerMenu::MAX_CHEERS.times do |i|
      cheer = GameData::Cheer.get_cheer_for_index(i, @battle.cheerMode)
      next if !cheer || cheer.id == :None
      cheers.push(cheer)
    end
    return nil if cheers.empty?
    # Compile scores for each available cheer.
    choices = []
    cheers.each do |cheer|
      score = CHEER_BASE_SCORE
      PBDebug.log_ai("#{@user.name} is considering using #{cheer.name}...")
      score = Battle::AI::Handlers.cheer_score(cheer.id, score, cheerLvl, self, @battle)
      score = Battle::AI::Handlers.apply_general_cheer_score_modifiers(score, cheer.id, cheer.command_index, cheerLvl, self, @battle)
      choices.push([score, cheer.id])
    end
    # Determines if any cheers are worth using.
    if choices.empty? || !choices.any? { |c| c[0] > CHEER_USELESS_SCORE }
      PBDebug.log_ai("#{@user.name} couldn't find any usable cheers")
      return nil
    end
    max_score = 0
	score_offset = @battle.pbSideSize(@user.index) * 8
    choices.each { |c| max_score = c[0] if max_score < c[0] }
    if @trainer.medium_skill?
      badCheers = false
      if max_score <= CHEER_USELESS_SCORE
        badCheers = true
      elsif max_score < CHEER_BASE_SCORE + score_offset
        badCheers = true if pbAIRandom(100) < 80
      end
      if badCheers
        PBDebug.log_ai("#{@user.name} doesn't want to use any cheers")
        return nil
      end
    end
    # Calculate a minimum score threshold and reduce all cheer scores by it.
    threshold = max_score + score_offset
    choices.each { |c| c[2] = [c[0] - threshold, 0].max }
    total_score = choices.sum { |c| c[2] }
    # Log the available choices.
    if $INTERNAL
      PBDebug.log_ai("Cheer choices for #{@user.name}:")
      choices.each_with_index do |c, i|
	    cheer_data = GameData::Cheer.get(c[1])
        chance = sprintf("%5.1f", (c[2] > 0) ? 100.0 * c[2] / total_score : 0)
        PBDebug.log("   * #{chance}% to use #{cheer_data.name}: score #{c[0]}")
      end
    end
    # Pick a cheer randomly from choices weighted by their scores and log the result.
    randNum = pbAIRandom(total_score)
    choices.each do |c|
      randNum -= c[2]
      next if randNum >= 0
      cheer_data = GameData::Cheer.get(c[1])
      PBDebug.log("   => will use #{cheer_data.name}")
      return c[1], cheer_data.command_index
    end
    return nil
  end
end