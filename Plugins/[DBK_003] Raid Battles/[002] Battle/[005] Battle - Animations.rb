#===============================================================================
# Additions to the Battle::Scene class.
#===============================================================================
class Battle::Scene
  #-----------------------------------------------------------------------------
  # Calls the flee animation on the player's side when kicked out of a raid.
  #-----------------------------------------------------------------------------
  def pbAnimateFleeFromRaid
    anims = []
    @battle.allSameSideBattlers.each do |b|
	  b.lastMoveUsed          = nil
      b.lastMoveUsedType      = nil
      b.lastRegularMoveUsed   = nil
      b.lastRegularMoveTarget = -1
	  b.lastRoundMoved        = @battle.turnCount
	  b.pbCancelMoves(true)
	  b.effects[PBEffects::BeakBlast]   = false
      b.effects[PBEffects::Charge]      = 0
      b.effects[PBEffects::GemConsumed] = nil
      b.effects[PBEffects::ShellTrap]   = false
	  fleeAnim = Animation::BattlerFlee.new(@sprites, @viewport, b.index, @battle)
      dataBoxAnim = Animation::DataBoxDisappear.new(@sprites, @viewport, b.index)
	  anims.push(fleeAnim, dataBoxAnim)
      pbAnimateSubstitute(b, :broken)
	end
	if anims.empty?
	  pbSEPlay("Battle flee")
	  return
	end
	allDone = false
	loop do
	  anims.each { |a| a.update }
      pbUpdate
	  anims.each do |a| 
	    break if !a.animDone?
		allDone = true
	  end
      break if allDone
    end
	anims.each { |a| a.dispose }
  end
  
  #-----------------------------------------------------------------------------
  # Calls the raid shield animations.
  #-----------------------------------------------------------------------------
  def pbAnimateRaidShield(battler, oldHP = 0)
    return if !battler.opposes? || (battler.shieldHP <= 0 && oldHP == 0)
    shieldAnim = Animation::RaidShield.new(@sprites, @viewport, battler, oldHP)
    loop do
      shieldAnim.update
      pbUpdate
      break if shieldAnim.animDone?
    end
    shieldAnim.dispose
  end
  
  #-----------------------------------------------------------------------------
  # Calls the extra raid action animation.
  #-----------------------------------------------------------------------------
  def pbAnimateExtraAction(idxBattler)
    extraAnim = Animation::RaidExtraAction.new(@sprites, @viewport, idxBattler)
    loop do
      extraAnim.update
      pbUpdate
      break if extraAnim.animDone?
    end
    extraAnim.dispose
  end
end

#===============================================================================
# Animations for raid shields.
#===============================================================================
class Battle::Scene::Animation::RaidShield < Battle::Scene::Animation
  def initialize(sprites, viewport, battler, oldHP)
    @battler = battler
	@oldHP = oldHP || 0
    super(sprites, viewport)
  end

  def createProcesses
    box = @sprites["dataBox_#{@battler.index}"]
	return if !box.style
	delay = 0
	t = 0.5
	hp = @battler.shieldHP
	totalhp = @battler.battle.raidRules[:shield_hp]
	path = Settings::DELUXE_GRAPHICS_PATH + "Databoxes/#{box.style.id}"
    bgX = box.spriteX + box.shieldXY[0]
	bgY = box.spriteY + box.shieldXY[1]
	bg = addNewSprite(bgX, bgY, path + "/shield_bg")
	bgOffset = @pictureSprites[@pictureEx.length - 1].bitmap.width / 2
	bg.setOrigin(delay, PictureOrigin::TOP)
	bg.setXY(delay, bgX + bgOffset, bgY)
	bg.setZ(delay, 999)
	barX = bgX + box.shieldOffset[0] + (box.shieldWH[0] / 2 - (totalhp * box.shieldHPWidth / 2))
    barY = bgY + box.shieldOffset[1]
    bar = addNewSprite(barX, barY, path + "/raid_shield")
    bar.setSrcSize(delay, totalhp * box.shieldHPWidth, box.shieldWH[1])
	barOffset = @pictureSprites[@pictureEx.length - 1].bitmap.width / 2
	bar.setOrigin(delay, PictureOrigin::TOP)
	bar.setXY(delay, barX + barOffset, barY)
    bar.setZ(delay, 999)
	#---------------------------------------------------------------------------
    # Animation for creating shield.
    #---------------------------------------------------------------------------
	if hp > @oldHP
	  if @oldHP > 0
	    oldHP = addNewSprite(barX, barY, path + "/raid_shield")
		oldHP.setSrc(delay, 0, box.shieldWH[1])
        oldHP.setSrcSize(delay, @oldHP * box.shieldHPWidth, box.shieldWH[1])
	    oldHP.setZ(delay, 999)
	  end
      hp.times do |i|
	    offsetX = i * box.shieldHPWidth
        p = addNewSprite(barX + offsetX, barY, path + "/raid_shield")
        p.setSrc(0, offsetX, box.shieldWH[1])
		p.setSrcSize(0, box.shieldHPWidth, box.shieldWH[1])
		p.setTone(0, Tone.new(255, 255, 255, 255))
		p.setOpacity(0, 0)
		p.setZoom(0, 300)
		p.setZ(0, 999)
		next if @oldHP >= i + 1
		p.setSE(delay, "Vs sword")
        p.moveOpacity(delay, 6, 255)
		p.moveZoom(delay, 8, 100)
		p.moveTone(delay, 10, Tone.new(0, 0, 0, 0))
		delay += 2
      end
	#---------------------------------------------------------------------------
    # Animation for reducing shield.
    #---------------------------------------------------------------------------
	else
	  pictureHP = []
	  @oldHP.times do |i|
		offsetX = i * box.shieldHPWidth
        p = addNewSprite(barX + offsetX, barY, path + "/raid_shield")
        p.setSrc(0, offsetX, box.shieldWH[1])
		p.setSrcSize(0, box.shieldHPWidth, box.shieldWH[1])
		p.setOpacity(0, 255)
		p.setZ(0, 999)
		next if i < hp
		pictureHP.push(p)
      end
	  pictureHP.reverse.each do |p|
	    p.moveDelta(delay, 2, 0, -2)
		delay = p.totalDuration
		p.moveDelta(delay, 4, 0, 8)
		p.moveOpacity(delay, 6, 0)
		p.moveTone(delay, 6, Tone.new(-255, -255, -255, -255))
		delay += 2
	  end
	  delay = pictureHP.first.totalDuration
	  if hp == 0
	    baseBgX = bgX + bgOffset
		baseBarX = barX + barOffset
        16.times do |i|
          bg.moveXY(delay, t, baseBgX + 2, bgY)
		  bar.moveXY(delay, t, baseBarX + 2, barY)
		  bg.moveXY(delay + t, t, baseBgX - 2, bgY)
          bar.moveXY(delay + t, t, baseBarX - 2, barY)
          delay = bar.totalDuration
        end
        bg.setXY(delay, baseBgX, bgY)
	    bar.setXY(delay, baseBarX, barY)
	    bg.moveOpacity(delay, 6, 0)
		bg.moveZoomXY(delay, 6, 400, 100)
	    bar.moveOpacity(delay, 6, 0)
		bar.moveZoomXY(delay, 6, 400, 100)
        bar.setSE(delay + 1, "Anim/Crash")
		bar.moveTone(delay - 8, 10, Tone.new(255, 255, 255, 255))
	  end
    end
  end
end

#===============================================================================
# Animation for extra raid actions.
#===============================================================================
class Battle::Scene::Animation::RaidExtraAction < Battle::Scene::Animation
  def initialize(sprites, viewport, idxBattler)
    @index = idxBattler
    super(sprites, viewport)
  end

  def createProcesses
    return if !@sprites["pokemon_#{@index}"]
    delay = 0
    xpos  = @sprites["pokemon_#{@index}"].x
    ypos  = @sprites["pokemon_#{@index}"].y
    zpos  = @sprites["pokemon_#{@index}"].z
    color = @sprites["pokemon_#{@index}"].color
    battler = addSprite(@sprites["pokemon_#{@index}"], PictureOrigin::BOTTOM)
    wave = addNewSprite(xpos, ypos - 60, Settings::DELUXE_GRAPHICS_PATH + "pulse", PictureOrigin::CENTER)
    wave.setZoom(delay, 0)
    wave.setZ(delay, zpos)
    t = 0.5
    8.times do |i|
      battler.moveXY(delay, t, xpos + 4, ypos)
      battler.moveXY(delay + t, t, xpos - 4, ypos)
      battler.setSE(delay + t, "Anim/fog2") if i == 0
      delay = battler.totalDuration
    end
    wave.moveZoom(delay, 5, 800)
    battler.moveColor(1, delay, Color.new(255, 255, 255, 248))
    battler.setXY(delay, xpos, ypos)
    battler.moveColor(delay, 4, color)
  end
end