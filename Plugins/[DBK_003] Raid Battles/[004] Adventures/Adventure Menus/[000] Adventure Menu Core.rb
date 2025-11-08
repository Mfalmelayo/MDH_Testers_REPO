#===============================================================================
# The core databox class for drawing Pokemon databoxes in Adventure menus.
#===============================================================================
class AdventureDataboxCore < Sprite
  attr_reader :pokemon, :index
  attr_reader :style, :statIcon
  attr_reader :spriteX, :spriteY
  
  #-----------------------------------------------------------------------------
  # Constants that set the various text colors.
  #-----------------------------------------------------------------------------
  DARK_BASE_COLOR    = Color.new(72, 72, 72)
  DARK_SHADOW_COLOR  = Color.new(184, 184, 184)
  LIGHT_BASE_COLOR   = Color.new(248, 248, 248)
  LIGHT_SHADOW_COLOR = Color.new(64, 64, 64)
  MALE_BASE_COLOR    = Color.new(48, 96, 216)
  FEMALE_BASE_COLOR  = Color.new(248, 88, 40)
  
  #-----------------------------------------------------------------------------
  # Sets up a Pokemon databox.
  #-----------------------------------------------------------------------------
  def initialize(pokemon, style, index, viewport = nil)
    super(viewport)
    @path     = Settings::RAID_GRAPHICS_PATH + "Adventures/Menus/"
    @pokemon  = pokemon
    @style    = style
    @index    = index
    @selected = false
    @spriteX  = 0
    @spriteY  = 0
    @statIcon = -1
	if @pokemon
      GameData::Stat.each_main_battle do |stat|
        next if @pokemon.ev[stat.id] == 0
        @statIcon = (@pokemon.ev[stat.id] == Pokemon::EV_STAT_LIMIT) ? stat.pbs_order : 0
        break
      end
	end
    @sprites  = {}
    @sprites["bg"] = IconSprite.new(0, 0, viewport)
    if @pokemon && @style == :Ultra
      @sprites["item"] = ItemIconSprite.new(0, 0, @pokemon.item_id, viewport)
      @sprites["item"].setOffset(PictureOrigin::TOP_LEFT)
      @sprites["item"].blankzero = true
      @itemOffset = [0, 0]
    end
    @sprites["icon"] = PokemonIconSprite.new(@pokemon, viewport)
    @iconOffset = [0, 0]
    if @pokemon && @style != :Ultra
      @sprites["held"] = HeldItemIconSprite.new(0, 0, @pokemon, viewport)
      @heldOffset = [0, 0]
    end
  end
  
  #-----------------------------------------------------------------------------
  # Changes the Pokemon assigned to a rental databox and refreshes it.
  #-----------------------------------------------------------------------------
  def pokemon=(pkmn)
    @pokemon = pkmn
    @sprites["icon"].pokemon = @pokemon
    @sprites["held"].pokemon = @pokemon if @sprites["held"]
    @sprites["item"].item = @pokemon.item_id if @sprites["item"]
    GameData::Stat.each_main_battle do |stat|
      next if @pokemon.ev[stat.id] == 0
      @statIcon = (@pokemon.ev[stat.id] == Pokemon::EV_STAT_LIMIT) ? stat.pbs_order : 0
      break
    end
  end
  
  def refreshItem
    return if !@sprites["item"]
    @sprites["item"].item = @pokemon.item_id
  end
  
  #-----------------------------------------------------------------------------
  # General utilities.
  #-----------------------------------------------------------------------------
  def dispose
    pbDisposeSpriteHash(@sprites)
    @contents.dispose
    super
  end
  
  def x=(value)
    super
    @spriteX = value
    @sprites["bg"].x   = @spriteX if @sprites["bg"]
    @sprites["icon"].x = @spriteX + @iconOffset[0] if @sprites["icon"]
    @sprites["item"].x = @spriteX + @itemOffset[0] if @sprites["item"]
    @sprites["held"].x = @spriteX + @heldOffset[0] if @sprites["held"]
  end
  
  def y=(value)
    super
    @spriteY = value
    @sprites["bg"].y   = @spriteY if @sprites["bg"]
    @sprites["icon"].y = @spriteY + @iconOffset[1] if @sprites["icon"]
    @sprites["item"].y = @spriteY + @itemOffset[1] if @sprites["item"]
    @sprites["held"].y = @spriteY + @heldOffset[1] if @sprites["held"]
  end
  
  def opacity=(value)
    super
    @sprites.each do |i|
      i[1].opacity = value if !i[1].disposed?
    end
  end

  def visible=(value)
    super
    @sprites.each do |i|
      i[1].visible = value if !i[1].disposed?
    end
  end

  def color=(value)
    super
    @sprites.each do |i|
      i[1].color = value if !i[1].disposed?
    end
  end
  
  def update
    super
    pbUpdateSpriteHash(@sprites)
  end
end

#===============================================================================
# Child class used for drawing rental party member databoxes.
#===============================================================================
class AdventurePartyDatabox < AdventureDataboxCore
  #-----------------------------------------------------------------------------
  # Determines how much a party databox is shifted while highlighted.
  #-----------------------------------------------------------------------------
  SLOT_BASE_X      = 2
  SLOT_BASE_Y      = 28
  SELECTION_OFFSET = 2
  
  #-----------------------------------------------------------------------------
  # Sets up a party databox.
  #-----------------------------------------------------------------------------
  def initialize(pokemon, style, index, viewport = nil)
    super(pokemon, style, index, viewport)
    @iconOffset = [78, 38]
    @itemOffset = [102, -4]
    @heldOffset = [32, 40]
    self.x = SLOT_BASE_X
    self.y = @index * 110 + SLOT_BASE_Y
    self.z = 99998
    @sprites["bg"].setBitmap(@path + "party_slot")
	@spriteHeight = @sprites["bg"].bitmap.height / 2
    @sprites["bg"].src_rect.height = @spriteHeight
    @sprites["icon"].setOffset
    @contents = Bitmap.new(@sprites["bg"].bitmap.width, @sprites["bg"].bitmap.height)
    self.bitmap = @contents
    pbSetSmallFont(self.bitmap)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Updates the stat training icon displayed on a party databox.
  #-----------------------------------------------------------------------------
  def refreshStat
    oldIcon = @statIcon
    GameData::Stat.each_main_battle do |stat|
      next if @pokemon.ev[stat.id] == 0
      @statIcon = (@pokemon.ev[stat.id] == Pokemon::EV_STAT_LIMIT) ? stat.pbs_order : 0
      break
    end
	refresh if @statIcon != oldIcon
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
  # Refreshes and draws the entire party databox.
  #-----------------------------------------------------------------------------
  def refresh
    self.bitmap.clear
    return if !@pokemon
    #---------------------------------------------------------------------------
    # Draws all images
    imagepos = [[@path + "stat_icons", 6, 6, 28 * @statIcon, 0, 28, 26]]
    case @style
    when :Max
      if @pokemon.gmax_factor?
        icon_path = Settings::DYNAMAX_GRAPHICS_PATH + "gmax_factor"
        imagepos.push([icon_path, 116, 6])
      end
    when :Tera
      icon_path = Settings::TERASTAL_GRAPHICS_PATH + "tera_types"
      icon_pos = GameData::Type.get(@pokemon.tera_type).icon_position
      imagepos.push([icon_path, 116, 6, 0, icon_pos * 32, 32, 32])
    end
    status = -1
    if @pokemon.fainted?
      status = GameData::Status.count - 1
    elsif @pokemon.status != :NONE
      status = GameData::Status.get(@pokemon.status).icon_position
    end
    if status >= 0
      imagepos.push([_INTL("Graphics/UI/statuses"), 108, 46, 0, 16 * status, 44, 16])
    end
    if !@pokemon.fainted?
      w = @pokemon.hp * 96 / @pokemon.totalhp.to_f
      w = 1 if w < 1
      w = ((w / 2).round) * 2
      hpzone = 0
      hpzone = 1 if @pokemon.hp <= (@pokemon.totalhp / 2).floor
      hpzone = 2 if @pokemon.hp <= (@pokemon.totalhp / 4).floor
      imagepos.push([@path + "overlay_hp", 42, 92, 0, hpzone * 6, w, 6])
    end
    pbDrawImagePositions(self.bitmap, imagepos)
    #---------------------------------------------------------------------------
    # Draws all text.
    textpos = [[@pokemon.name, 77, 68, :center, LIGHT_BASE_COLOR, LIGHT_SHADOW_COLOR, :outline]]
    genderX = self.bitmap.text_size(@pokemon.name).width / 2 + 79
    case @pokemon.gender
    when 0 then textpos.push([_INTL("♂"), genderX, 68, :left, MALE_BASE_COLOR, LIGHT_SHADOW_COLOR])
    when 1 then textpos.push([_INTL("♀"), genderX, 68, :left, FEMALE_BASE_COLOR, LIGHT_SHADOW_COLOR])
    end
    pbDrawTextPositions(self.bitmap, textpos)
  end
end

#===============================================================================
# Draws attribute databoxes in Adventure menus.
#===============================================================================
class AdventureAttributebox < Sprite
  attr_reader :attribute, :index
  
  #-----------------------------------------------------------------------------
  # Constants that set the various text colors.
  #-----------------------------------------------------------------------------
  DARK_BASE_COLOR    = Color.new(72, 72, 72)
  DARK_SHADOW_COLOR  = Color.new(184, 184, 184)
  LIGHT_BASE_COLOR   = Color.new(248, 248, 248)
  LIGHT_SHADOW_COLOR = Color.new(64, 64, 64)
  
  #-----------------------------------------------------------------------------
  # Determines how much a stat databox is shifted while highlighted.
  #-----------------------------------------------------------------------------
  SLOT_BASE_X      = 186
  SLOT_BASE_Y      = 44
  SLOT_BASE_WIDTH  = 300
  SLOT_BASE_HEIGHT = 56
  SELECTION_OFFSET = 12
  
  #-----------------------------------------------------------------------------
  # Sets up a stat databox.
  #-----------------------------------------------------------------------------
  def initialize(attribute, index, viewport = nil)
    super(viewport)
    @path       = Settings::RAID_GRAPHICS_PATH + "Adventures/Menus/"
    @attribute  = nil
    @index      = index
    @selected   = false
    @contents   = Bitmap.new(SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT)
    self.bitmap = @contents
    self.x = SLOT_BASE_X
    self.y = @index * (SLOT_BASE_HEIGHT - 2) + SLOT_BASE_Y
    self.z = 99999
    pbSetSystemFont(self.bitmap)
  end
  
  #-----------------------------------------------------------------------------
  # Toggles whether a stat databox is being selected in the menu.
  #-----------------------------------------------------------------------------
  def selected=(value)
    return if @selected == value
    @selected = value
	if @selected
      self.x += SELECTION_OFFSET
    else
      self.x -= SELECTION_OFFSET
    end
    refresh
  end
end

#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  BASE_COLOR   = Color.new(248, 248, 248)
  SHADOW_COLOR = Color.new(64, 64, 64)
  
  PARTY_SIZE = 3
  
  def pbStartScene(style = :Basic)
    @style = style
    try_style = GameData::RaidType.try_get(@style)
    @style = :Basic if !try_style || !try_style.available
    @path = Settings::RAID_GRAPHICS_PATH + "Adventures/Menus/"
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @sprites["bg"] = IconSprite.new(0, 0, @viewport)
    @sprites["bg"].setBitmap(sprintf("%s%s/bg", @path, @style))
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSmallFont(@sprites["overlay"].bitmap)
  end
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
  
  def pbPauseScene(seconds = 1.0)
    timer_start = System.uptime
    until System.uptime - timer_start >= seconds
      Graphics.update
      Input.update
      pbUpdate
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def pbShowCommands(commands, index = 0)
    ret = -1
    using(cmdwindow = Window_CommandPokemon.new(commands)) {
     cmdwindow.z = @viewport.z + 1
     cmdwindow.index = index
     pbBottomRight(cmdwindow)
     loop do
       Graphics.update
       Input.update
       cmdwindow.update
       pbUpdate
       if Input.trigger?(Input::BACK)
         pbPlayCancelSE
         ret = -1
         break
       elsif Input.trigger?(Input::USE)
         pbPlayDecisionSE
         ret = cmdwindow.index
         break
       end
     end
    }
    return ret
  end
  
  def pbSummary(party = $player.party, index = 0)
    party = [party] if !party.is_a?(Array)
    oldsprites = pbFadeOutAndHide(@sprites) { pbUpdate }
    scene  = PokemonSummary_Scene.new
    screen = PokemonSummaryScreen.new(scene, true)
    screen.pbStartScreen(party, index)
    yield if block_given?
    pbFadeInAndShow(@sprites, oldsprites) { pbUpdate }
  end
end