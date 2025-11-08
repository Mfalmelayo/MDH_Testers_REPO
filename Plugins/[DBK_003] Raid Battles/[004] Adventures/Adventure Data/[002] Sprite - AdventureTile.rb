#===============================================================================
# Sprite class used for drawing each tile on an Adventure Map.
#===============================================================================
class AdventureTileSprite < Sprite
  attr_reader :map_x      # The grid coordinate of this tile on the X-axis.
  attr_reader :map_y      # The grid coordinate of this tile on the Y-axis.
  attr_reader :variable   # A random number to determine the version of this tile that is encountered.
  attr_reader :toggleable # Determines whether this tile reacts to Switch tiles.
  attr_reader :battle_id  # The ID a Battle tile uses to determine which Pokemon is encountered here.
  attr_reader :warp_point # Coordinates for the tile a Warp tile is linked to.
  
  def initialize(x, y, data, style = nil, dark = false, viewport = nil)
    super(viewport)
    @viewport    = viewport
    @_iconbitmap = nil
    @_tilebitmap = nil
    @_tileSprite = Sprite.new(viewport)
    @map_x       = x
    @map_y       = y
    self.x       = x * 32
    self.y       = y * 32
    @style       = style
    @dark_mode   = dark
    @visited     = false
    @active      = true
    @disabled    = false
    @toggleable  = data[:toggle]
    @switch      = false
    @battle_id   = data[:battle_id]
    @variable    = nil
    setTile(data[:id])
    setWarp(data[:warp_point])
  end
  
  ##############################################################################
  #
  # General tile utilities.
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Returns the GameData::AdventureTile of this tile.
  #-----------------------------------------------------------------------------
  def tile; return @tile; end
  
  #-----------------------------------------------------------------------------
  # Returns the AdventureTile ID of this tile.
  #-----------------------------------------------------------------------------
  def tile_id
    return nil if !@tile
    return @tile.id
  end
  
  #-----------------------------------------------------------------------------
  # Used to check if this tile is of a certain AdventureTile ID.
  #-----------------------------------------------------------------------------
  def isTile?(*args)
    return false if !@tile
    args.each do |tile|
      return true if @tile.id == tile
    end
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Returns an array of the grid coordinates of this tile.
  #-----------------------------------------------------------------------------
  def coords
    return [@map_x, @map_y]
  end
  
  ##############################################################################
  #
  # Utilities for tile interactivity.
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Checks whether or not this is an active tile.
  #-----------------------------------------------------------------------------
  def active?
    return @active
  end
  
  #-----------------------------------------------------------------------------
  # Turns off a tile completely, making it no longer active.
  #-----------------------------------------------------------------------------
  def deactivate
    return if !@active
    @active = false
    refreshTile
  end
  
  #-----------------------------------------------------------------------------
  # Checks if a tile can be interacted with.
  #-----------------------------------------------------------------------------
  def interactable?
    return false if !@tile
    return false if !@active
    return false if @disabled
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Checks if a tile is hidden from view, but still interactable.
  #-----------------------------------------------------------------------------
  def hidden?
    return interactable? && @tile.hidden
  end
  
  #-----------------------------------------------------------------------------
  # Checks if the map cursor should react when highlighting this tile.
  #-----------------------------------------------------------------------------
  def cursor_react?
    return false if !@tile
    return false if hidden? && !$DEBUG
    return false if @tile.no_cursor
    return @active
  end
  
  #-----------------------------------------------------------------------------
  # Checks if the player has stepped on this tile yet.
  #-----------------------------------------------------------------------------
  def visited?
    return @visited
  end
  
  #-----------------------------------------------------------------------------
  # Flags this tile as being stepped on by the player.
  #-----------------------------------------------------------------------------
  def make_visited
    return if !interactable?
    @visited = true
  end
  
  ##############################################################################
  #
  # Specific interactivity related to Switch tiles.
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Checks if a Switch tile is in the ON position or not.
  #-----------------------------------------------------------------------------
  def switch_on?
    return @switch
  end
  
  #-----------------------------------------------------------------------------
  # Flips a Switch tile between the ON and OFF positions.
  #-----------------------------------------------------------------------------
  def flip_switch
    return if !@tile || @tile.id != :Switch
    @switch = !@switch
    refreshTile
  end
  
  #-----------------------------------------------------------------------------
  # Checks if this tile has been toggled on via a Switch tile.
  #-----------------------------------------------------------------------------
  def toggled?
    return true if !@toggleable
    return !@disabled
  end
  
  #-----------------------------------------------------------------------------
  # Toggles a tile on or off if it is affected by Switch tiles.
  #-----------------------------------------------------------------------------
  def toggle
    return if !@toggleable || !@active
    @disabled = !@disabled
    refreshTile
  end
  
  ##############################################################################
  #
  # Utilities for setting tile properties.
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Sets all of the main relevant properties of a tile sprite.
  #-----------------------------------------------------------------------------
  def setTile(tile)
    clearBitmap
    #---------------------------------------------------------------------------
    # Specifically used for drawing the player tile in the map editor.
    if tile == :Player
      @active = true
      @toggleable = false
      @disabled = false
      @battle_id = nil
      @warp_point = nil
      @variable = nil
      player_icon = GameData::TrainerType.player_map_icon_filename($player.trainer_type)
      @_iconbitmap = Bitmap.new(player_icon)
      self.bitmap = @_iconbitmap
    #---------------------------------------------------------------------------
    # Draws all map tiles.
    else
      @tile = GameData::AdventureTile.try_get(tile) || GameData::AdventureTile.get(:Empty)
      if @tile
        @active = true
        if !@tile.dark_mode.nil? && !@dark_mode.nil?
          case @tile.dark_mode
          when 0 then @active = false if !@dark_mode
          when 1 then @active = false if @dark_mode
          end
        end
        if !@style.nil? && !@tile.styles.empty?
          @active = false if !@tile.styles.include?(@style)
        end
        @toggleable = false if @tile.required
        @disabled = @toggleable
        @battle_id = nil if @tile.id != :Battle
        @warp_point = nil if @tile.id != :Warp
        @variable = (@tile.variable) ? rand(@tile.variable) : nil
        path = Settings::RAID_GRAPHICS_PATH + "Adventures/Tiles/"
        clearBitmap
        if pbResolveBitmap(path + @tile.id.to_s)
          @_iconbitmap = Bitmap.new(path + "Pathway")
          self.bitmap = @_iconbitmap
          @_tilebitmap = Bitmap.new(path + @tile.id.to_s)
          @_tileSprite.bitmap = @_tilebitmap
          @_tileSprite.src_rect = Rect.new(0, 0, 32, 32)
          @_tileSprite.x = self.x
          @_tileSprite.y = self.y
          @_tileSprite.visible = self.visible
        end
      end
    end
    refreshTile
  end
  
  #-----------------------------------------------------------------------------
  # Used to set whether this tile interacts with Switch tiles.
  #-----------------------------------------------------------------------------
  def setToggle(value)
    return if !@tile || @tile.required
    @toggleable = value
    @disabled = value
    refreshTile
  end
  
  #-----------------------------------------------------------------------------
  # Used to set the linked coordinates for Warp tiles.
  #-----------------------------------------------------------------------------
  def setWarp(x, y = nil)
    if @tile && @tile.id == :Warp
      case x
      when nil
        @warp_point = nil
      when Array
        @warp_point = x
      when String
        @warp_point = [x[0..1].to_i, x[2..3].to_i]
      else
        @warp_point = [x, y]
      end
    else
      @warp_point = nil
    end
  end
  
  #-----------------------------------------------------------------------------
  # Used to set the battle ID for Battle tiles.
  #-----------------------------------------------------------------------------
  def setBattleID(value)
    if @tile && @tile.id == :Battle
      @battle_id = value
    else
      @battle_id = nil
    end
  end
  
  #-----------------------------------------------------------------------------
  # Resets all of a tile's properties back to their initial values.
  #-----------------------------------------------------------------------------
  def resetTile
    return if !@tile
    @active = true
    @visited = false
    @switch = false
    @disabled = @toggleable
    @variable = (@tile.variable) ? rand(@tile.variable) : nil
    if !@dark_mode.nil? && !@tile.dark_mode.nil?
      case @tile.dark_mode
      when 0 then @active = false if !@dark_mode
      when 1 then @active = false if @dark_mode
      end
    end
    if !@style.nil? && !@tile.styles.empty?
      @active = false if !@tile.styles.include?(@style)
    end
    refreshTile
  end
  
  ##############################################################################
  #
  # Sprite and bitmap properties.
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Ensures sprite values apply to both bitmaps of a tile sprite.
  #-----------------------------------------------------------------------------
  def x=(value)
    super
    return if !@_tilebitmap
    @_tileSprite.x = value
  end
  
  def y=(value)
    super
    return if !@_tilebitmap
    @_tileSprite.y = value
  end
  
  def color=(value)
    super
    return if !@_tilebitmap
    @_tileSprite.color = value
  end
  
  #-----------------------------------------------------------------------------
  # Ensures that sprite bitmaps are properly cleared and/or disposed.
  #-----------------------------------------------------------------------------
  def dispose
    @_iconbitmap&.dispose
    @_iconbitmap = nil
    @_tilebitmap&.dispose
    @_tilebitmap = nil
    self.bitmap = nil if !self.disposed?
    @_tileSprite.bitmap = nil if !self.disposed?
    super
  end

  def clearBitmap
    @_iconbitmap&.dispose
    @_iconbitmap = nil
    @_tilebitmap&.dispose
    @_tilebitmap = nil
    self.bitmap = nil
    @_tileSprite.bitmap = nil
  end
  
  #-----------------------------------------------------------------------------
  # Updates the visibility of the tile sprite based on certain tile properties.
  #-----------------------------------------------------------------------------
  def refreshTile
    return if !@_tileSprite.bitmap
    if @active
      if hidden?
        @_tileSprite.opacity = ($DEBUG) ? 50 : 0
      else
        @_tileSprite.opacity = 255
      end
      @_tileSprite.src_rect.x = (@switch) ? 32 : 0
      @_tileSprite.opacity = (@disabled) ? 50 : 255
    else
      @_tileSprite.opacity = 0
    end
  end
  
  #-----------------------------------------------------------------------------
  # Updates the bitmaps used for a tile sprite.
  #-----------------------------------------------------------------------------
  def update
    super
    if @_iconbitmap
      self.bitmap = @_iconbitmap
    end
    if @_tilebitmap
      @_tileSprite.bitmap = @_tilebitmap
    end
  end
end