#===============================================================================
# Child class used for drawing rental Pokemon databoxes.
#===============================================================================
class AdventureDynamaxbox < AdventureDataboxCore
  #-----------------------------------------------------------------------------
  # Determines how much a party databox is shifted while highlighted.
  #-----------------------------------------------------------------------------
  SLOT_BASE_X      = 166
  SLOT_BASE_Y      = 44
  SELECTION_OFFSET = 8

  def initialize(pokemon, index, viewport = nil)
    super(pokemon, :Max, index, viewport)
	@increase   = 0
    @iconOffset = [36, 0]
	@heldOffset = [22, 38]
    @sprites["bg"].setBitmap(sprintf("%sMax/dynamax_slot", @path))
	@spriteHeight = @sprites["bg"].bitmap.height / 2
    @sprites["bg"].src_rect.height = @spriteHeight
    @contents = Bitmap.new(@sprites["bg"].bitmap.width, @sprites["bg"].bitmap.height)
	self.bitmap  = @contents
	self.x = SLOT_BASE_X
    self.y = @index * @spriteHeight + SLOT_BASE_Y
    self.z = 99999
    pbSetSmallFont(self.bitmap)
    refresh
  end
  
  def increase=(value)
    return if @increase == value
    @increase = value
  end
  
  #-----------------------------------------------------------------------------
  # Toggles whether a rental databox is being selected in the menu.
  #-----------------------------------------------------------------------------
  def selected=(value)
    return if @selected == value
    @selected = value
    @sprites["icon"].selected = value
    if @selected
      self.x += SELECTION_OFFSET
      @sprites["bg"].src_rect.y = @spriteHeight
    else
      self.x -= SELECTION_OFFSET
      @sprites["bg"].src_rect.y = 0
    end
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Refreshes and draws the entire rental databox.
  #-----------------------------------------------------------------------------
  def refresh
    self.bitmap.clear
    return if !@pokemon
	if @pokemon.gmax_factor?
      pbDrawImagePositions(self.bitmap, [[Settings::DYNAMAX_GRAPHICS_PATH + "gmax_factor", 6, 8]])
	end
	base = (@selected) ? LIGHT_BASE_COLOR : DARK_BASE_COLOR
    shadow = (@selected) ? LIGHT_SHADOW_COLOR : DARK_SHADOW_COLOR
    outline = (@selected) ? :outline : nil
    textpos = [
      [@pokemon.name, 12, 62, :left, base, shadow, outline],
      [_INTL("Dynamax HP"), 235, 46, :center, base, shadow, outline]
    ]
	dynamax_hp = (@pokemon.totalhp * @pokemon.dynamax_calc).round
	if @increase > 0
	  old_hp = (@pokemon.totalhp * (1.5 + ((@pokemon.dynamax_lvl - @increase).to_f * 0.05))).round
	  textpos.push(
	    [sprintf("+%d", @increase), 168, 16, :left, base, shadow, outline],
	    [sprintf("%d -> %d", old_hp, dynamax_hp), 235, 76, :center, base, shadow, outline]
	  )
	else
	  textpos.push([sprintf("%d", dynamax_hp), 235, 76, :center, DARK_BASE_COLOR, DARK_SHADOW_COLOR])
	end
    genderX = self.bitmap.text_size(@pokemon.name).width + 14
    case @pokemon.gender
    when 0 then textpos.push([_INTL("♂"), genderX, 62, :left, MALE_BASE_COLOR, shadow])
    when 1 then textpos.push([_INTL("♀"), genderX, 62, :left, FEMALE_BASE_COLOR, shadow])
    end
    pbDrawTextPositions(self.bitmap, textpos)
  end
end


#===============================================================================
# Pokemon related Adventure menus.
#===============================================================================
class AdventureMenuScene
  #-----------------------------------------------------------------------------
  # Dynamax menu.
  #-----------------------------------------------------------------------------
  def pbDynamaxMenu
    party_select = (0...PARTY_SIZE).to_a
    PARTY_SIZE.times do |i|
      pkmn = $player.party[i]
      @sprites["party_#{i}"] = AdventureDynamaxbox.new(pkmn, i, @viewport)
      xpos, ypos = @sprites["party_#{i}"].x, @sprites["party_#{i}"].y
      @sprites["level_#{i}"] = IconSprite.new(xpos + 204, ypos + 14, @viewport)
      @sprites["level_#{i}"].setBitmap(Settings::DYNAMAX_GRAPHICS_PATH + "dynamax_levels")
      @sprites["level_#{i}"].src_rect.width = pkmn.dynamax_lvl * 12
    end
	overlay = @sprites["overlay"].bitmap
    overlay.clear
	textpos = [[_INTL("Increasing party Dynamax levels..."), 337, 12, :center, BASE_COLOR, SHADOW_COLOR]]
    pbDrawTextPositions(overlay, textpos)
	pbPauseScene(0.5)
    PARTY_SIZE.times do |i|
      Graphics.update
      pbUpdate
      pkmn = $player.party[i]
      next if pkmn.dynamax_lvl == 10
      curlvl = pkmn.dynamax_lvl
      pkmn.dynamax_lvl = [10, curlvl + 2 + rand(3)].min
      increase = pkmn.dynamax_lvl - curlvl
	  @sprites["party_#{i}"].increase = increase
	  @sprites["level_#{i}"].x += AdventureDynamaxbox::SELECTION_OFFSET
	  @sprites["level_#{i - 1}"].x -= AdventureDynamaxbox::SELECTION_OFFSET if i > 0
	  PARTY_SIZE.times { |j| @sprites["party_#{j}"].selected = (j == i) }
	  increase.times do |t|
	    Graphics.update
        pbUpdate
		@sprites["level_#{i}"].src_rect.width += 12
		pbSEPlay("Pkmn exp full")
		pbPauseScene(0.4)
	  end
	  party_select.delete(i)
	  pbPauseScene(0.2)
    end
	@sprites["level_#{PARTY_SIZE - 1}"].x -= AdventureDynamaxbox::SELECTION_OFFSET
	PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = false }
	if party_select.length == PARTY_SIZE
	  pbMessage(_INTL("The party's Dynamax levels cannot be increased any further!"))
	  overlay.clear
	else
	  pbPauseScene(0.5)
	  pbMessage(_INTL("The party's Dynamax levels were increased!"))
	  overlay.clear
	  buttonY = 156
	  imagepos = [
        [@path + "buttons", 20, buttonY, 0, 0, 32, 32],
        [@path + "buttons", 20, buttonY + 40, 32, 0, 32, 32],
      ]
	  pbDrawImagePositions(overlay, imagepos)
	  textpos = [
	    [_INTL("Dynamax levels increased!"), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
		[_INTL("Summary"), 56, buttonY + 12, :left, BASE_COLOR, SHADOW_COLOR, :outline],
		[_INTL("Exit"), 56, buttonY + 52, :left, BASE_COLOR, SHADOW_COLOR, :outline]
	  ]
      pbDrawTextPositions(overlay, textpos)
	  loop do
	    Input.update
        Graphics.update
        pbUpdate
	    if Input.trigger?(Input::ACTION)
	      pbPlayDecisionSE
          pbSummary($player.party[0...PARTY_SIZE])
	    elsif Input.trigger?(Input::BACK)
	      pbPlayCancelSE
		  break
	    end
	  end
	end
  end
end

def pbAdventureMenuDynamax
  return if !pbInRaidAdventure?
  return if pbRaidAdventureState.style != :Max
  scene = AdventureMenuScene.new
  scene.pbStartScene(:Max)
  scene.pbDynamaxMenu
  scene.pbEndScene
end