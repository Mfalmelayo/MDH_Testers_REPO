#===============================================================================
# Adventure Map editor utility.
#===============================================================================
class AdventureMapEditor
  def pbOpen
    @path = Settings::RAID_GRAPHICS_PATH + "Adventures/"
    @ui_sprites  = {}
    @map_sprites = {}
    @viewport    = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z  = 99999
    @viewport2   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport2.z = 99999
    @ui_sprites["copy"] = AdventureTileSprite.new(0, 0, { id: :Empty }, nil, nil, @viewport2)
    @ui_sprites["cursor"] = IconSprite.new(0, 0, @viewport2)
    @ui_sprites["cursor"].setBitmap(@path + "cursor")
    @ui_sprites["cursor"].src_rect.set(0, 0, 64, 64)
    @ui_sprites["cursor"].visible = false
    @ui_sprites["map_arrow_0"] = AnimatedSprite.new("Graphics/UI/up_arrow", 8, 28, 40, 2, @viewport2)
    @ui_sprites["map_arrow_0"].x = (Graphics.width / 2) - 14
    @ui_sprites["map_arrow_0"].y = 0
    @ui_sprites["map_arrow_0"].visible = false
    @ui_sprites["map_arrow_0"].play
    @ui_sprites["map_arrow_1"] = AnimatedSprite.new("Graphics/UI/down_arrow", 8, 28, 40, 2, @viewport2)
    @ui_sprites["map_arrow_1"].x = (Graphics.width / 2) - 14
    @ui_sprites["map_arrow_1"].y = Graphics.height - 44
    @ui_sprites["map_arrow_1"].visible = false
    @ui_sprites["map_arrow_1"].play
    @ui_sprites["map_arrow_2"] = AnimatedSprite.new("Graphics/UI/left_arrow", 8, 40, 28, 2, @viewport2)
    @ui_sprites["map_arrow_2"].x = 0
    @ui_sprites["map_arrow_2"].y = (Graphics.height / 2) - 14
    @ui_sprites["map_arrow_2"].visible = false
    @ui_sprites["map_arrow_2"].play
    @ui_sprites["map_arrow_3"] = AnimatedSprite.new("Graphics/UI/right_arrow", 8, 40, 28, 2, @viewport2)
    @ui_sprites["map_arrow_3"].x = Graphics.width - 44
    @ui_sprites["map_arrow_3"].y = (Graphics.height / 2) - 14
    @ui_sprites["map_arrow_3"].visible = false
    @ui_sprites["map_arrow_3"].play
    @ui_sprites["grid_info"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport2)
    pbSetSystemFont(@ui_sprites["grid_info"].bitmap)
    @ui_sprites["controls"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport2)
    @ui_sprites["controls"].opacity = 150
    pbSetSmallFont(@ui_sprites["controls"].bitmap)
    @helpWindow = Window_UnformattedTextPokemon.new("")
    @helpWindow.viewport = @viewport2
    @helpWindow.visible  = false
    pbBottomLeftLines(@helpWindow, 1)
    pbMenu
  end
  
  def pbClose
    pbFadeOutAndHide(@map_sprites) { update }
    pbDisposeSpriteHash(@map_sprites)
    pbDisposeSpriteHash(@ui_sprites)
    @helpWindow.dispose
    @viewport.dispose
    @viewport2.dispose
  end
  
  ##############################################################################
  #
  # GENERAL UTILITIES
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # General sprite updating.
  #-----------------------------------------------------------------------------
  def update
    pbUpdateSpriteHash(@map_sprites)
    pbUpdateSpriteHash(@ui_sprites)
  end
  
  #-----------------------------------------------------------------------------
  # General command window for editor menus.
  #-----------------------------------------------------------------------------
  def pbShowCommands(text, commands, cmd = 0, top = false)
    ret = -1
    using(cmdwindow = Window_CommandPokemonColor.new(commands)) do
      cmdwindow.z     = @viewport2.z + 1
      cmdwindow.index = cmd
      cmdwindow.x = Graphics.width - cmdwindow.width
      if !nil_or_empty?(text)
        @helpWindow.visible = true
        @helpWindow.resizeHeightToFit(text, Graphics.width - cmdwindow.width)
        @helpWindow.text = text
        @helpWindow.x = 0
      else
        @helpWindow.visible = false
      end
      if top
        cmdwindow.y = 0
        @helpWindow.y = 0
      else
        cmdwindow.y = Graphics.height - cmdwindow.height
        @helpWindow.y = Graphics.height - @helpWindow.height
      end
      loop do
        Graphics.update
        Input.update
        cmdwindow.update
        self.update
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
    end
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Clears all map visuals and redraws the entire map.
  #-----------------------------------------------------------------------------
  def pbRefreshMap(message = false)
    return false if !@mapData
    return false if message && !pbConfirmMessage(_INTL("Are you sure you want to clear all tiles on this map?"))
	if message
	  @mapData.pathways.clear
      @mapData.battles.clear
      @mapData.tiles.clear
      @changedTiles = true
	end
	pbDisposeSpriteHash(@map_sprites)
    @map_sprites["map"] = IconSprite.new(0, 0, @viewport)
    @map_sprites["map"].setBitmap(@path + "Maps/#{@mapData.filename}")
    @width = (@map_sprites["map"].bitmap.width / 32).floor
    @width = 32 if @width > 32
    @height = (@map_sprites["map"].bitmap.height / 32).floor
    @height = 32 if @height > 32
    @mapData.dimensions = [@width, @height]
    player_coords = [0, 0]
    @width.times do |x|
      @height.times do |y|
        tile_data = @mapData.get_tile(x, y)
		setPlayer = tile_data[:id] == :Player
		if setPlayer
		  tile_data[:id] = :Pathway
		  player_coords = [x, y] 
		end
        @map_sprites["tile_#{x}_#{y}"] = AdventureTileSprite.new(x, y, tile_data, nil, nil, @viewport)
      end
    end
    x, y = *player_coords
    @cursor_tile = @map_sprites["tile_#{x}_#{y}"]
    @map_sprites["player"] = IconSprite.new(@cursor_tile.x, @cursor_tile.y, @viewport)
    player_icon = GameData::TrainerType.player_map_icon_filename($player.trainer_type)
    @map_sprites["player"].setBitmap(player_icon)
    @map_sprites["grid"] = IconSprite.new(0, 0, @viewport)
    @map_sprites["grid"].setBitmap(@path + "map_grid")
    pbAutoPosition(x, y)
    pbSetCursor(*@cursor_tile.coords, 1)
    pbUpdateCursor
    self.update
    return true
  end
  
  ##############################################################################
  #
  # SAVING & LOADING DATA
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Saves changes to the current map.
  #-----------------------------------------------------------------------------
  def pbSaveMap
    # Immediately saves if only map properties have been changed.
    if !@changedTiles
      if @changedProperties
        GameData::AdventureMap.save
        Compiler.write_adventure_maps
        pbMessage(_INTL("Map properties saved."))
        @changedProperties = false
      else
        pbMessage(_INTL("No changes detected.\nExiting map."))
      end
	  return true
    end
    # Playtests map before it may be saved.
    pbMessage(_INTL("You must playtest your map first to ensure it's clearable before it can be saved."))
    if pbConfirmMessage(_INTL("Would you like to playtest your map?"))
      if pbPlayTestMap
        pbMessage(_INTL("This map has been cleared!\n\\se[]All changes will now be saved.\\me[GUI save game]\\wtnp[20]"))
        GameData::AdventureMap.save
        Compiler.write_adventure_maps
		return true
      end
    end
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Ensures that the map contains all the required tiles for a functional map.
  #-----------------------------------------------------------------------------
  def pbValidMapTiles?
    required = {}
    maximum  = {}
    detected = {}
    GameData::AdventureTile.each do |tile|
      if tile.required && tile.required > 0
        required[tile.id] = tile.required
        detected[tile.id] = 0
      elsif tile.max_number
        maximum[tile.id] = tile.max_number
        detected[tile.id] = 0
      end
    end
    @map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      tile = sprite.tile
	  if sprite.isTile?(:Warp) && !sprite.warp_point
	    pbMessage(_INTL("A {1} tile is detected that doesn't have any warp coordinates set.", tile.name))
        pbMessage(_INTL("Select 'Properties' on a {1} tile to set its warp coordinates.", tile.name))
	    return false
	  end
      detected[tile.id] += 1 if tile.max_number || tile.required && tile.required > 0
    end
    required.keys.each do |key|
      next if detected[key] == required[key]
      tile = GameData::AdventureTile.get(key)
      pbMessage(_INTL("Invalid number of {1} tiles detected.", tile.name))
      pbMessage(_INTL("The number of {1} tiles required must be exactly {2}.", tile.name, tile.required))
      return false
    end
    maximum.keys.each do |key|
      next if detected[key] <= maximum[key]
      tile = GameData::AdventureTile.get(key)
      pbMessage(_INTL("Invalid number of {1} tiles detected.", tile.name))
      pbMessage(_INTL("The maximum number of {1} tiles per map cannot exceed {1}.", tile.name, tile.max_number))
      return false
    end
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Converts map coordinates into a string that can be saved as map data.
  #-----------------------------------------------------------------------------
  def pbConvertCoords(coords)
    string = ""
    coords.each do |c|
      coord = c.to_s
      coord.insert(0, "0") if coord.length == 1
      string += coord
    end
    return string
  end
  
  #-----------------------------------------------------------------------------
  # Loads the data for a selected map, or creates data for a new one.
  #-----------------------------------------------------------------------------
  def pbLoadMap(id_num)
    if GameData::AdventureMap.exists?(id_num)
      @mapData = GameData::AdventureMap::DATA[id_num]
    else
      bg = nil
      id_num = nil
      loop do
        params = ChooseNumberParams.new
        params.setRange(0, 99999)
        params.setDefaultValue(0)
        id_num = pbMessageChooseNumber(_INTL("Select an ID number for this new map."), params)
        if GameData::AdventureMap.exists?(id_num)
          pbMessage(_INTL("A map with that ID already exists."))
          id_num = nil
        else
          bg = pbBackgroundSelect
          break
        end
      end
      if bg && id_num
        GameData::AdventureMap.register({
          :id       => id_num,
          :filename => bg
        })
        @mapData = GameData::AdventureMap::DATA[id_num]
        @changedProperties = true
        @changedTiles = true
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Playtests the current map to ensure it can function.
  #-----------------------------------------------------------------------------
  def pbPlayTestMap
    return false if !pbValidMapTiles?
    @mapData.pathways.clear
    @mapData.battles.clear
    @mapData.tiles.clear
    tiles = []
    @map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      next if sprite.tile_id == :Empty
      coords = pbConvertCoords(sprite.coords)
      case sprite.tile_id
      when :Pathway
        @mapData.pathways.push(coords)
      when :Battle
        @mapData.battles[sprite.battle_id] = coords
      else
        data = [sprite.tile_id, coords]
        data.push(((sprite.toggleable) ? true : nil))
		data.push(pbConvertCoords(sprite.warp_point)) if sprite.tile_id == :Warp
        tiles.push(data)
      end
    end
    if !tiles.empty?
      tiles.sort_by! { |tile| tile[0].to_s }
      @mapData.tiles = tiles
    end
    $PokemonGlobal.raid_adventure_state = FakeRaidAdventureState.new(@mapData)
    pbFadeOutIn { pbRaidAdventureState.processAdventure }
    ret = pbRaidAdventureState.outcome
    $PokemonGlobal.raid_adventure_state = nil
    return ret == 1
  end
  
  
  ##############################################################################
  #
  # EDITOR MENUS
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Main menu.
  #-----------------------------------------------------------------------------
  def pbMenu
    commands = [
      _INTL("Edit map tiles"),
      _INTL("Clear all tiles"),
      _INTL("Map properties"),
      _INTL("Playtest map"),
      _INTL("Save map")
    ]
    loop do
      pbDisposeSpriteHash(@map_sprites)
	  @ui_sprites.each_value { |s| s.visible = false }
	  @mapData = nil
      @changedTiles = false
      @changedProperties = false
      pbMapSelect
      break if !@mapData
      loop do
        case pbShowCommands(nil, commands)
        when 0 then pbEditMapTiles
        when 1 then pbRefreshMap(true)
        when 2 then pbMapDataEditor
        when 3 then pbPlayTestMap
        when 4 then break if pbSaveMap
        else
          if @changedProperties || @changedTiles
            if pbConfirmMessage(_INTL("Map changes detected.\nExit this map without saving?"))
              GameData::AdventureMap.load
              break
            end
          else
            break
          end
        end
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Map selection menu.
  #-----------------------------------------------------------------------------
  def pbMapSelect
    maps = []
    map_ids = []
    GameData::AdventureMap.each do |m|
      maps.push(_INTL("{1} [{2}]", m.name, m.id))
      map_ids.push(m.id)
    end
    maps.push(_INTL("New map"))
    loop do
      cmd = pbShowCommands(_INTL("Select a map."), maps)
      if cmd >= 0
        pbLoadMap(map_ids[cmd])
        break if @mapData
      elsif pbConfirmMessage(_INTL("Exit map editor?"))
        break
      end
    end
    pbRefreshMap
  end
  
  #-----------------------------------------------------------------------------
  # Background selection menu.
  #-----------------------------------------------------------------------------
  def pbBackgroundSelect
    maps = []
    files = FilenameUpdater.readDirectoryFiles(@path + "Maps/", ["*.png"])
    files.each { |f| maps.push(f.split(".png").first) }
    cmd = pbShowCommands(_INTL("Select a background."), maps)
    @helpWindow.visible = false
    return (cmd < 0) ? nil : maps[cmd]
  end
  
  #-----------------------------------------------------------------------------
  # Tile selection menu.
  #-----------------------------------------------------------------------------
  def pbTileSelect
    tile_id = nil
    tile_hash = Hash.new { |key, value| key[value] = [] }
    # Creates categories of tiles to select from.
    GameData::AdventureTile.each do |tile|
      next if tile.id == :Empty
      tile_hash[tile.type] << tile.id
    end
    tile_types = tile_hash.keys
    # Selects a particular tile within a category.
    typeCmd = 0
    loop do
      typeCmd = pbShowCommands(_INTL("Select a tile type."), tile_types, typeCmd)
      break if typeCmd < 0
      type = tile_types[typeCmd]
      tile_names = []
      tile_hash[type].each do |tile| 
        tile_names.push(GameData::AdventureTile.get(tile).name)
      end
      tileCmd = pbShowCommands(_INTL("Select a tile."), tile_names)
      tile_id = (tileCmd < 0) ? nil : tile_hash[type][tileCmd]
      if pbHaveRequiredTiles?(tile_id)
        tile = GameData::AdventureTile.get(tile_id)
        pbMessage(_INTL("The {1} tile count on this map aready meets the maximum amount. ({2})", 
          tile.name, (tile.required || tile.max_number)))
        tile_id = nil
      end
      break if tile_id
    end
    @helpWindow.visible = false
    return tile_id
  end
  
  #-----------------------------------------------------------------------------
  # Map properties editor menu.
  #-----------------------------------------------------------------------------
  def pbMapDataEditor
    commands = [
      _INTL("Edit map name"),
      _INTL("Edit description"),
      _INTL("Edit background"),
      _INTL("Edit darkness chance")
    ]
    cmd = 0
    loop do
      cmd = pbShowCommands(nil, commands, cmd)
      case cmd
      when 0 # Name
        name = pbMessageFreeText(
          _INTL("Enter a name for this map."), @mapData.name, false, 250, Graphics.width)
        if !nil_or_empty?(name) && name != @mapData.real_name
          @mapData.real_name = name
          @changedProperties = true
        end
      when 1 # Description
        desc = pbMessageFreeText(
          _INTL("Enter a description for this map."), @mapData.description, false, 250, Graphics.width)
        if !nil_or_empty?(desc) && desc != @mapData.description
          @mapData.description = desc
          @changedProperties = true
        end
      when 2 # Background
        old_bg = @mapData.filename
        new_bg = pbBackgroundSelect
        if old_bg != new_bg
          @mapData.filename = new_bg
          pbMessage(_INTL("WARNING!\nChanging the background will erase all current tiles."))
          @mapData.filename = old_bg if !pbRefreshMap(true)
        end
      when 3 # Darkness
        params = ChooseNumberParams.new
        params.setRange(0, 100)
        params.setInitialValue(@mapData.darkness)
        params.setCancelValue(@mapData.darkness)
        dark = pbMessageChooseNumber(_INTL("Enter the odds of this map being played in Darkness Mode."), params)
        if dark != @mapData.darkness
          @mapData.darkness = dark
          @changedProperties = true
        end
      else break
      end
    end
  end
  
  ##############################################################################
  #
  # TILE EDITOR
  #
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # Main tile editor loop.
  #-----------------------------------------------------------------------------
  def pbEditMapTiles
    copied_tile = nil
    player_tile = nil
    moving_tile = false
    linking_tile = false
    paint_mode = false
    erase_mode = false
    screenX = Graphics.width - 49
    screenY = Graphics.height - 49
    map = @map_sprites["map"]
    mapX = Graphics.width - (@width * 32)
    mapY = Graphics.height - (@height * 32)
    @ui_sprites.each_value { |s| s.visible = true }
    @helpWindow.visible = false
    pbUpdateControls
    pbUpdateCursor
    loop do
      Graphics.update
      Input.update
      self.update
      @ui_sprites["map_arrow_0"].visible = @cursor_tile.map_y > 0
      @ui_sprites["map_arrow_1"].visible = @cursor_tile.map_y < @height - 1
      @ui_sprites["map_arrow_2"].visible = @cursor_tile.map_x > 0
      @ui_sprites["map_arrow_3"].visible = @cursor_tile.map_x < @width - 1
      #-------------------------------------------------------------------------
      # ARROW KEYS
      #-------------------------------------------------------------------------
      # Cursor movement.
      #-------------------------------------------------------------------------
      # Paint/Erase mode directional controls.
      if paint_mode || erase_mode
        moved = false
        c = @cursor_tile.coords
        if Input.repeat?(Input::UP) && c[1] > 0
          moved = true
          pbAutoPosition(c[0], c[1] - 1)
        elsif Input.repeat?(Input::DOWN) && c[1] < @height - 1
          moved = true
          pbAutoPosition(c[0], c[1] + 1)
        elsif Input.repeat?(Input::LEFT) && c[0] > 0
          moved = true
          pbAutoPosition(c[0] - 1, c[1])
        elsif Input.repeat?(Input::RIGHT) && c[0] < @width - 1
          moved = true
          pbAutoPosition(c[0] + 1, c[1])
        end
        if moved
          if paint_mode && @cursor_tile.isTile?(:Empty)
            if pbHaveRequiredTiles?(copied_tile.tile_id)
              pbMessage(_INTL("The maximum amount of this tile has already been reached."))
              pbMessage(_INTL("Exiting paint mode."))
              pbSEPlay("GUI storage pick up")
              @ui_sprites["copy"].clearBitmap
              copied_tile = nil
              paint_mode = false
              pbUpdateControls
              pbUpdateCursor
            else
              pbSEPlay("GUI storage put down")
              pbUpdateTile(copied_tile.tile_id)
              @changedTiles = true
            end  
          elsif erase_mode && !@cursor_tile.isTile?(:Empty) && !pbCursorOnPlayer?
            pbSEPlay("GUI storage pick up")
            pbUpdateTile(nil)
            pbUpdateWarpPoints(*@cursor_tile.coords, true)
            @changedTiles = true
          else
            pbPlayCursorSE
          end
        elsif Input.trigger?(Input::USE) ||
              Input.trigger?(Input::BACK) ||		
              Input.trigger?(Input::ACTION)
          pbSEPlay("GUI storage pick up") if paint_mode
          pbSEPlay("GUI storage put down") if erase_mode
          paint_mode = false
          erase_mode = false
          pbUpdateControls((copied_tile.nil? ? 0 : 1))
          pbUpdateCursor
        end
        next
      #-------------------------------------------------------------------------
      # Normal directional controls.
      else
        if Input.press?(Input::UP)
          @map_sprites.each_value { |s| s.y += 2 } if map.y < -1
          pbSetCursor(0, -2) if @ui_sprites["cursor"].y > -16
          pbUpdateCursor
        end
        if Input.press?(Input::DOWN)
          @map_sprites.each_value { |s| s.y -= 2 } if map.y > mapY
          pbSetCursor(0, 2) if @ui_sprites["cursor"].y <= screenY
          pbUpdateCursor
        end
        if Input.press?(Input::LEFT)
          @map_sprites.each_value { |s| s.x += 2 } if map.x < -1
          pbSetCursor(-2, 0) if @ui_sprites["cursor"].x > -16
          pbUpdateCursor
        end
        if Input.press?(Input::RIGHT)
          @map_sprites.each_value { |s| s.x -= 2 } if map.x > mapX
          pbSetCursor(2, 0) if @ui_sprites["cursor"].x <= screenX
          pbUpdateCursor
        end
      end
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Accesses tile menu, or confirms a copy/move/link.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::USE)
        #-----------------------------------------------------------------------
        # USAGE 1: Moves the player starting position to the selected tile.
        #-----------------------------------------------------------------------
        if player_tile
          pbSetCursor(*@cursor_tile.coords, 1)
          if !@cursor_tile.isTile?(:Pathway, :Empty)
            pbMessage(_INTL("The player cannot be placed on an occupied tile."))
          else
            pbSEPlay("GUI storage put down")
            @mapData.player = pbConvertCoords(@cursor_tile.coords)
            @map_sprites["player"].x = @cursor_tile.x
            @map_sprites["player"].y = @cursor_tile.y
            @map_sprites["player"].visible = true
            x, y = *player_tile.coords
            pbUpdateTile(:Empty, @map_sprites["tile_#{x}_#{y}"])
            pbUpdateTile(:Pathway)
            @ui_sprites["copy"].clearBitmap
            player_tile = nil
            moving_tile = false
            pbUpdateControls
            pbUpdateCursor
            @changedTiles = true
          end
        #-----------------------------------------------------------------------
        # USAGE 2: Links a Warp tile with the selected tile.
        #-----------------------------------------------------------------------
        elsif linking_tile
          pbSetCursor(*@cursor_tile.coords, 1)
          if @cursor_tile.isTile?(:Warp) && @cursor_tile.coords != copied_tile.coords
            if pbConfirmMessage(_INTL("Set the warp coordinates to this tile?"))
              pbSEPlay("GUI storage put down")
              c = copied_tile.coords
              @map_sprites["tile_#{c[0]}_#{c[1]}"].setWarp(@cursor_tile.coords)
              @cursor_tile.setWarp(c) if !@cursor_tile.warp_point
              if @cursor_tile.toggleable != copied_tile.toggleable
                @cursor_tile.setToggle(copied_tile.toggleable)
              end
              @ui_sprites["copy"].clearBitmap
              copied_tile = nil
              linking_tile = false
              pbUpdateControls
              @changedTiles = true
            end
          else
            pbMessage(_INTL("You can't set the warp coodinates to that tile."))
          end
        #-----------------------------------------------------------------------
        # USAGE 3: Places a copied tile when selecting an empty tile.
        #-----------------------------------------------------------------------
        elsif copied_tile && @cursor_tile.isTile?(:Empty)
          pbSetCursor(*@cursor_tile.coords, 1)
          if pbHaveRequiredTiles?(copied_tile.tile_id)
            pbMessage(_INTL("The maximum amount of this tile has already been reached."))
          else
            pbSEPlay("GUI storage put down")
            pbUpdateTile(copied_tile.tile_id)
            pbUpdateWarpPoints(*copied_tile.coords)
            @cursor_tile.setWarp(copied_tile.warp_point)
            if moving_tile
              copied_tile = nil
              moving_tile = false
              @ui_sprites["copy"].clearBitmap
              pbUpdateControls
            end
            pbUpdateCursor
            @changedTiles = true
          end
        #-----------------------------------------------------------------------
        # USAGE 4: Opens the tile command menu.
        #-----------------------------------------------------------------------
        elsif !copied_tile || copied_tile.tile_id != @cursor_tile.tile_id
          pbPlayCursorSE
          pbSetCursor(*@cursor_tile.coords, 1)
          @ui_sprites["controls"].visible = false
          topWindow = @ui_sprites["cursor"].y > Graphics.height / 2
          commands = []
          if @cursor_tile.isTile?(:Empty)
            commands.push(_INTL("Set"))
          else
            commands.push(_INTL("Replace"))
            if !copied_tile
              commands.push(_INTL("Move"))
              commands.push(_INTL("Copy"))
              commands.push(_INTL("Clear"))
              commands.push(_INTL("Properties")) if pbTileHasProperties?
            end
          end
          case pbShowCommands(nil, commands, 0, topWindow)
          #---------------------------------------------------------------------
          when 0 # Set/Replace tile
            if pbCursorOnPlayer?
              pbMessage(_INTL("Cannot replace a tile the player is standing on."))
            else
              tile = (copied_tile) ? copied_tile.tile_id : pbTileSelect
              if pbHaveRequiredTiles?(tile)
                pbMessage(_INTL("The maximum amount of this tile has already been reached."))
              else
                pbUpdateTile(tile) if tile
                pbUpdateWarpPoints(*copied_tile.coords) if copied_tile
                if moving_tile
                  copied_tile = nil
                  moving_tile = false
                  @ui_sprites["copy"].clearBitmap
                end
                pbUpdateCursor
                @changedTiles = true
              end
            end
          #---------------------------------------------------------------------
          when 1 # Move tile or player position.
            if pbCursorOnPlayer?
              player_tile = @cursor_tile.clone
              @ui_sprites["copy"].setTile(:Player)
              @ui_sprites["copy"].opacity = 200
              @map_sprites["player"].visible = false
              moving_tile = true
              pbUpdateControls(2)
            else
              copied_tile = @cursor_tile.clone
              @ui_sprites["copy"].setTile(copied_tile.tile_id)
              @ui_sprites["copy"].opacity = 200
              pbUpdateTile(nil)
              moving_tile = true
              pbUpdateCursor
              pbUpdateControls(2)
            end
          #---------------------------------------------------------------------
          when 2 # Copy tile
            if pbHaveRequiredTiles?(@cursor_tile.tile_id)
              pbMessage(_INTL("The maximum amount of this tile has already been reached."))
            else
              copied_tile = @cursor_tile.clone
              @ui_sprites["copy"].setTile(copied_tile.tile_id)
              @ui_sprites["copy"].opacity = 200
              moving_tile = false
              pbUpdateControls(1)
            end
          #---------------------------------------------------------------------
          when 3 # Clear tile
            if pbCursorOnPlayer?
              pbMessage(_INTL("Cannot clear a tile the player is standing on."))
            else
              pbUpdateTile(nil)
              pbUpdateWarpPoints(*@cursor_tile.coords, true)
              pbUpdateCursor
              @changedTiles = true
            end
          #---------------------------------------------------------------------
          when 4 # Properties
            linking_tile = pbSetTileProperties
            if linking_tile
              copied_tile = @cursor_tile.clone 
              @ui_sprites["copy"].setTile(copied_tile.tile_id)
              @ui_sprites["copy"].opacity = 200
              pbUpdateControls(3)
            end
          end
          @ui_sprites["controls"].visible = true
        end
      #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      # Returns to main menu, or cancels a copy/move/link.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        if player_tile
          @ui_sprites["copy"].clearBitmap
          @map_sprites["player"].visible = true
          player_tile = nil
          moving_tile = false
          pbUpdateControls
        elsif copied_tile
          if moving_tile
            x, y = copied_tile.map_x, copied_tile.map_y
            pbUpdateTile(copied_tile.tile_id, @map_sprites["tile_#{x}_#{y}"])
            @map_sprites["tile_#{x}_#{y}"].setWarp(copied_tile.warp_point)
          end
          copied_tile = nil
          moving_tile = false
          linking_tile = false
          @ui_sprites["copy"].clearBitmap
          pbUpdateControls
        else
          @map_sprites["grid"].visible = true
          @ui_sprites.each_value { |s| s.visible = false }
          break
        end
      #-------------------------------------------------------------------------
      # ACTION KEY
      #-------------------------------------------------------------------------
      # Toggles paint/erase modes.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::ACTION) && !moving_tile
        if copied_tile
          if pbHaveRequiredTiles?(copied_tile.tile_id)
            pbMessage(_INTL("The maximum amount of this tile has already been reached."))
            next
          else
            pbSEPlay("GUI storage pick up")
            paint_mode = true
          end
        else
          pbSEPlay("GUI storage put down")
          erase_mode = true
        end
        pbUpdateControls(4)
        pbUpdateCursor(true)
        pbSetCursor(*@cursor_tile.coords, 1)
      #-------------------------------------------------------------------------
      # CTRL KEY
      #-------------------------------------------------------------------------
      # Toggles grid and info displays.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::CTRL)
        pbPlayDecisionSE
        @map_sprites["grid"].visible     = !@map_sprites["grid"].visible
        @ui_sprites["grid_info"].visible = !@ui_sprites["grid_info"].visible
        @ui_sprites["controls"].visible  = !@ui_sprites["controls"].visible
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Used to instantly center the camera on the entered coordinates.
  #-----------------------------------------------------------------------------
  def pbAutoPosition(x, y)
    sprite = @map_sprites["tile_#{x}_#{y}"]
    return if !sprite
    map = @map_sprites["map"]
    centerX = (Graphics.width / 2) - 16
    centerY = (Graphics.height / 2) - 16
    mapX = Graphics.width - (@width * 32)
    mapY = Graphics.height - (@height * 32)
    loop do
      moveX, moveY = false, false
      if sprite.x > centerX
        shiftX = -1
        moveX = map.x - 1 > mapX
      elsif sprite.x < centerX
        shiftX = 1
        moveX = map.x + 1 < 0
      end
      if sprite.y > centerY
        shiftY = -1
        moveY = map.y - 1 > mapY
      elsif sprite.y < centerY
        shiftY = 1
        moveY = map.y + 1 < 0
      end
      break if !moveX && !moveY
      @map_sprites.each_value do |s|
        s.x += shiftX if moveX
        s.y += shiftY if moveY
      end
    end
    pbSetCursor(x, y, 1)
    pbUpdateCursor(true)
  end
  
  #-----------------------------------------------------------------------------
  # Updates a tile with a new tile type.
  #-----------------------------------------------------------------------------
  def pbUpdateTile(id, tile = nil)
    tile = @cursor_tile if !tile
    tile.setTile(id)
    if id == :Battle
      range = (0..(tile.tile.required - 1)).to_a
      @map_sprites.each_value do |sprite|
        next if !sprite.is_a?(AdventureTileSprite)
        next if !sprite.isTile?(:Battle)
        range.delete(sprite.battle_id)
      end
      tile.setBattleID(range.first)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Checks if the maximum or required amount of an alotted tile has been met.
  #-----------------------------------------------------------------------------
  def pbHaveRequiredTiles?(tile)
    tile = GameData::AdventureTile.try_get(tile)
    return false if !tile
    return false if !tile.max_number && !(tile.required && tile.required > 0)
    num_tiles = 0
    @map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      next if sprite.tile_id != tile.id
      num_tiles += 1
    end
    return true if tile.required && num_tiles >= tile.required
    return true if tile.max_number && num_tiles >= tile.max_number
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Utilities related to setting and updating special properties on certain tiles.
  #-----------------------------------------------------------------------------
  def pbSetTileProperties
    case @cursor_tile.tile_id
    # Setting a battle ID for Battle tiles.
    when :Battle
      value  = @cursor_tile.battle_id || 0
      maxVal = @cursor_tile.tile.required - 1
      params = ChooseNumberParams.new
      params.setRange(0, maxVal)
      params.setInitialValue(value)
      params.setCancelValue(value)
      msg = _INTL("Enter the ID number for this Battle tile.\n(Boss = {1})", maxVal)
      idNum = pbMessageChooseNumber(msg, params)
      if idNum != value
        @map_sprites.each_value do |sprite|
          next if !sprite.is_a?(AdventureTileSprite)
          next if !sprite.isTile?(:Battle)
          next if sprite.battle_id != idNum
          sprite.setBattleID(value)
        end
        @cursor_tile.setBattleID(idNum)
        @changedTiles = true
      end
    # Setting warp points and switch toggles for Warp tiles.
    when :Warp
      commands = [_INTL("Set tile to warp to"), _INTL("Set switch toggle")]
      case pbShowCommands(nil, commands)
      when 0 then return true
      when 1
        if pbConfirmMessage(_INTL("Should this tile be disabled until a Switch tile is flipped ON?"))
          pbSEPlay("GUI storage put down")
          pbUpdateToggle(true)
        else
          pbSEPlay("GUI storage pick up")
          pbUpdateToggle(false)
        end
        @changedTiles = true
      end
    # Setting switch toggles for all other eligible tiles.
    else
      if pbConfirmMessage(_INTL("Should this tile be disabled until a Switch tile is flipped ON?"))
        pbSEPlay("GUI storage put down")
        pbUpdateToggle(true)
      else
        pbSEPlay("GUI storage pick up")
        pbUpdateToggle(false)
      end
      @changedTiles = true
    end
    return false
  end
  
  def pbTileHasProperties?
    return false if @cursor_tile.isTile?(:Empty, :Pathway)
    return true if !@cursor_tile.tile.required
    return true if @cursor_tile.isTile?(:Battle)
    return false
  end
  
  def pbUpdateToggle(value)
    @cursor_tile.setToggle(value)
    if @cursor_tile.isTile?(:Warp)
      @map_sprites.each_value do |sprite|
        next if !sprite.is_a?(AdventureTileSprite)
        next if !sprite.warp_point
        next if sprite.warp_point != @cursor_tile.coords
        sprite.setToggle(value)
      end
    end
  end
  
  def pbUpdateWarpPoints(x, y, delete = false)
    coords = [x, y]
    @map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      next if !sprite.warp_point
      next if sprite.warp_point != coords
      if delete
        sprite.setWarp(nil)
      else
        sprite.setWarp(@cursor_tile.coords)
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Utilities related to updating and repositioning the cursor and other map UI's.
  #-----------------------------------------------------------------------------
  def pbSetCursor(x, y, mode = 0)
    case mode
    when 0 # Sets the cursor to the exact pixel coordinates.
      @ui_sprites["cursor"].x += x if x
      @ui_sprites["cursor"].y += y if y
      @ui_sprites["copy"].x   += x if x
      @ui_sprites["copy"].y   += y if y
    when 1 # Sets the cursor to a particular map tile.
      map = @map_sprites["map"]
      ox = (map.x < 0) ? map.x : 0
      oy = (map.y < 0) ? map.y : 0
      @ui_sprites["cursor"].x = x * 32 + ox - 16 if x
      @ui_sprites["cursor"].y = y * 32 + oy - 16 if y
      @ui_sprites["copy"].x   = x * 32 + ox if x
      @ui_sprites["copy"].y   = y * 32 + oy if y
    end
  end
  
  def pbUpdateCursor(paint_mode = false)
    checkX = @ui_sprites["cursor"].x + 16
    checkY = @ui_sprites["cursor"].y + 16
    @map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      next if !(sprite.x - 20..sprite.x + 20).include?(checkX)
      next if !(sprite.y - 20..sprite.y + 20).include?(checkY)
      @cursor_tile = sprite
      break
    end
    # Yellow cursor (Tile highlight)
    if @cursor_tile.active? && @cursor_tile.cursor_react?
      @ui_sprites["cursor"].src_rect.x = 64
    # Blue cursor (Paint/Erase mode)
    elsif paint_mode
      @ui_sprites["cursor"].src_rect.x = 128
    # Red cursor (Normal)
    else
      @ui_sprites["cursor"].src_rect.x = 0
    end
    # Hides controls display when overlapping the cursor.
    if @ui_sprites["cursor"].x <= 192 && @ui_sprites["cursor"].y <= 96
      @ui_sprites["controls"].opacity = 0
    else
      @ui_sprites["controls"].opacity = 200
    end
    # Draws tile info.
    overlay = @ui_sprites["grid_info"].bitmap
    overlay.clear
    tile_bg = [[@path + "tile_bg", Graphics.width - 192, 0]]
    if !paint_mode && @cursor_tile.cursor_react?
      tile_bg.push([@path + "info_bg", 10, 310])
    end
    pbDrawImagePositions(overlay, tile_bg)
    x, y = *@cursor_tile.coords
    text_display = [:right, Color.white, Color.black, :outline]
    tile_text = [["#{x}, #{y}", Graphics.width - 8, 8, *text_display]]
    if !paint_mode && @cursor_tile.cursor_react?
      tile_name = @cursor_tile.tile.name
      if @cursor_tile.toggleable
        tile_name += " (Disabled)"
      else
        case @cursor_tile.tile_id
        when :Battle
          if @cursor_tile.battle_id
            tile_name += sprintf(" (#%d)", @cursor_tile.battle_id)
          end
        when :Warp
          coords = @cursor_tile.warp_point
          tile_name += sprintf(" to %d, %d", *coords) if coords
        end
      end
      tile_text.push([_INTL(tile_name), Graphics.width - 8, 40, *text_display])
      drawTextEx(overlay, 18, 318, 476, 2, @cursor_tile.tile.description, Color.white, Color.black)
    end
    pbDrawTextPositions(overlay, tile_text)
  end
  
  def pbCursorOnPlayer?
    cx = @cursor_tile.x
    cy = @cursor_tile.y
    px = @map_sprites["player"].x
    py = @map_sprites["player"].y
    return cx == px && cy == py
  end
  
  def pbUpdateControls(mode = 0)
    overlay = @ui_sprites["controls"].bitmap
    overlay.clear
    text_display = [:left, Color.white, Color.black, :outline]
    case mode
    when 0 # Normal controls
	  controls = [
	    [_INTL("[USE]"),     4,  8, *text_display],
      [_INTL("[ACTION]"),  4, 28, *text_display],
      [_INTL("[BACK]"),    4, 48, *text_display],
      [_INTL("[CTRL]"),    4, 68, *text_display],
      [_INTL("Select"),   82,  8, *text_display],
      [_INTL("Eraser"),   82, 28, *text_display],
      [_INTL("Return"),   82, 48, *text_display],
      [_INTL("Hide"),     82, 68, *text_display]
	  ]
    when 1 # Copy controls
	  controls = [
	    [_INTL("[USE]"),     4,  8, *text_display],
      [_INTL("[ACTION]"),  4, 28, *text_display],
      [_INTL("[BACK]"),    4, 48, *text_display],
      [_INTL("[CTRL]"),    4, 68, *text_display],
      [_INTL("Paste"),    82,  8, *text_display],
      [_INTL("Paint"),    82, 28, *text_display],
      [_INTL("Return"),   82, 48, *text_display],
      [_INTL("Hide"),     82, 68, *text_display]
	  ]
    when 2 # Move controls
	  controls = [
	    [_INTL("[USE]"),     4,  8, *text_display],
      [_INTL("[BACK]"),    4, 28, *text_display],
      [_INTL("[CTRL]"),    4, 48, *text_display],
      [_INTL("Place"),    82,  8, *text_display],
      [_INTL("Return"),   82, 28, *text_display],
      [_INTL("Hide"),     82, 48, *text_display]
	  ]
    when 3 # Link controls
      controls = [
	    [_INTL("[USE]"),     4,  8, *text_display],
      [_INTL("[BACK]"),    4, 28, *text_display],
      [_INTL("[CTRL]"),    4, 48, *text_display],
      [_INTL("Link"),     62,  8, *text_display],
      [_INTL("Return"),   62, 28, *text_display],
      [_INTL("Hide"),     62, 48, *text_display]
	  ]
	when 4 # Paint/Erase controls
	  controls = [
      [_INTL("[BACK]"),    4,  8, *text_display],
      [_INTL("Return"),   62,  8, *text_display]
	  ]
    end
    pbDrawTextPositions(overlay, controls)
  end
end

#===============================================================================
# Calls the Adventure Map editor.
#===============================================================================
class AdventureMapEditorScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStart
    @scene.pbOpen
    @scene.pbClose
  end
end