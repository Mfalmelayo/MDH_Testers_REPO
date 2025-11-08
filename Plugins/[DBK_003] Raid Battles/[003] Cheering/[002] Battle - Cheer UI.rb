#===============================================================================
# Battle::Scene class additions for the cheer window display and controls.
#===============================================================================
class Battle::Scene
  CHEER_BOX = 5
  
  #-----------------------------------------------------------------------------
  # Aliased to add the cheer box as a new window type.
  #-----------------------------------------------------------------------------
  alias cheer_pbShowWindow pbShowWindow
  def pbShowWindow(windowType)
    if @sprites["cheerWindow"]
      @sprites["cheerWindow"].visible = (windowType == CHEER_BOX)
    end
    cheer_pbShowWindow(windowType)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to initialize the cheer window in the battle scene.
  #-----------------------------------------------------------------------------
  alias cheer_pbInitSprites pbInitSprites
  def pbInitSprites
    cheer_pbInitSprites
    if @battle.canCheer?
	  mode = @battle.cheerMode
	  cheerLvl = @battle.cheerLevel[0][0]
      @sprites["cheerWindow"] = CheerMenu.new(@viewport, 200, mode, cheerLvl)
      @sprites["cheerWindow"].visible = false
    end
  end
  
  #-----------------------------------------------------------------------------
  # Controls for navigating the cheer window.
  #-----------------------------------------------------------------------------
  def pbChooseCheer(mode = 0)
    pbShowWindow(CHEER_BOX)
	pbHideUIPrompt if defined?(pbHideUIPrompt)
    cw = @sprites["cheerWindow"]
    cw.index = 0
	cw.mode = mode
	cw.cheerLvl = @battle.cheerLevel[0][0]
	cw.refresh
    ret = -1
    loop do
      oldIndex = cw.index
      pbUpdate(cw)
      if Input.trigger?(Input::LEFT)
        cw.index -= 1 if (cw.index & 1) == 1
      elsif Input.trigger?(Input::RIGHT)
        cw.index += 1 if (cw.index & 1) == 0
      elsif Input.trigger?(Input::UP)
        cw.index -= 2 if (cw.index & 2) == 2
      elsif Input.trigger?(Input::DOWN)
        cw.index += 2 if (cw.index & 2) == 0
      end
      pbPlayCursorSE if cw.index != oldIndex
      if Input.trigger?(Input::USE)
        cheer = @sprites["cheerWindow"].cheers[cw.index]
        next if cheer.id == :None
		pbPlayDecisionSE
		if cw.cheerLvl == 0
		  pbPlayBuzzerSE
		  pbShowWindow(CHEER_BOX)
		else
		  ret = cw.index
		  break
		end
      elsif Input.trigger?(Input::BACK)
        ret = -1
        pbPlayCancelSE
        break
      end
    end
    return ret
  end
end

#===============================================================================
# Cheer menu class used for displaying the cheer menu UI.
#===============================================================================
class Battle::Scene::CheerMenu < Battle::Scene::MenuBase
  attr_reader   :cheers
  attr_accessor :mode, :cheerLvl

  MAX_CHEERS        = 4  # Maximum number of cheers displaying in the UI at one time.
  TEXT_BASE_COLOR   = Color.new(240, 248, 224)
  TEXT_SHADOW_COLOR = Color.new(64, 64, 64)

  def initialize(viewport, z, mode, cheerLvl)
    super(viewport)
    self.x = 0
    self.y = Graphics.height - 142
    @cheers = []
	@mode = mode
	@cheerLvl = cheerLvl
	@cheerBitmap = AnimatedBitmap.new(Settings::RAID_GRAPHICS_PATH + "Battle/cheer_level")
    @buttonBitmap = AnimatedBitmap.new(Settings::RAID_GRAPHICS_PATH + "Battle/cursor_cheer")
	background = IconSprite.new(0, Graphics.height - 142, viewport)
    background.setBitmap(Settings::RAID_GRAPHICS_PATH + "Battle/cheer_bg")
    addSprite("background", background)
	@cheerLvlbg = Sprite.new(viewport)
	@cheerLvlbg.bitmap = @cheerBitmap.bitmap
	@cheerLvlbg.x = self.x + 8
	@cheerLvlbg.y = self.y + 10
	@cheerLvlbg.src_rect.y = 36 * @cheerLvl
	@cheerLvlbg.src_rect.height = 36
	addSprite("cheer_level", @cheerLvlbg)
    @buttons = Array.new(MAX_CHEERS) do |i|
      cheer = GameData::Cheer.get_cheer_for_index(i, @mode)
	  button = Sprite.new(viewport)
      button.bitmap = @buttonBitmap.bitmap
      button.x = self.x + 22
      button.x += (i.even? ? 0 : (@buttonBitmap.width / 2) - 4)
      button.y = self.y + 52
      button.y += (((i / 2) == 0) ? 0 : BUTTON_HEIGHT - 4)
      button.src_rect.y = BUTTON_HEIGHT * cheer.icon_position
	  button.src_rect.width  = @buttonBitmap.width / 2
      button.src_rect.height = BUTTON_HEIGHT
      addSprite("button_#{i}", button)
      next button
    end
    @overlay = BitmapSprite.new(Graphics.width, Graphics.height - self.y, viewport)
    @overlay.x = self.x
    @overlay.y = self.y
    pbSetNarrowFont(@overlay.bitmap)
    addSprite("overlay", @overlay)
    self.z = z
    refresh
  end

  def dispose
    super
    @buttonBitmap&.dispose
  end

  def z=(value)
    super
    @overlay.z += 5 if @overlay
  end

  def refresh
    @cheers.clear
	@cheerLvlbg.src_rect.y = 36 * @cheerLvl
	@buttons.each_with_index do |button, i|
      next if !button
      sel = i == @index
	  cheer = GameData::Cheer.get_cheer_for_index(i, @mode)
	  button.src_rect.y = BUTTON_HEIGHT * cheer.icon_position
      button.src_rect.x = (sel) ? @buttonBitmap.width / 2 : 0
      button.z          = self.z + ((sel) ? 3 : 2)
	  @cheers.push(cheer)
    end
    @overlay.bitmap.clear
	level_text = (@cheerLvl == 3) ? _INTL("Cheer Lv. MAX") : _INTL("Cheer Lv. {1}", @cheerLvl)
    textpos = [
	  [level_text, 74, 20, :center, TEXT_BASE_COLOR, TEXT_SHADOW_COLOR, :outline],
	  [@cheers[@index].description(@cheerLvl), 158, 20, :left, TEXT_BASE_COLOR, TEXT_SHADOW_COLOR]
	]
    @buttons.each_with_index do |button, i|
      next if !button
      x = button.x + 62
      y = button.y - self.y + 14
      textpos.push([@cheers[i].cheer_text, x, y, :left, TEXT_BASE_COLOR, TEXT_SHADOW_COLOR])
    end
    pbDrawTextPositions(@overlay.bitmap, textpos)
  end
end