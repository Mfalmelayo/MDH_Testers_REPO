#===============================================================================
# Handles all movement of the map and player on an Adventure Map.
#===============================================================================
class AdventureMapScene
  #-----------------------------------------------------------------------------
  # Checks if a valid map tile exists at the entered coordinates.
  #-----------------------------------------------------------------------------
  def pbTileExists?(x, y)
    return false if x < 0 || y < 0
    tile = @map_sprites["tile_#{x}_#{y}"]
    return false if tile.nil? || tile.isTile?(:Empty)
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Updates the valid directions the player can travel in from their current tile.
  #-----------------------------------------------------------------------------
  def pbUpdateDirections
    x, y = *@player_tile.coords
    dirs = []
    dirs.push(0) if pbTileExists?(x, y - 1) # Movement north is possible
    dirs.push(1) if pbTileExists?(x, y + 1) # Movement south is possible
    dirs.push(2) if pbTileExists?(x - 1, y) # Movement west is possible
    dirs.push(3) if pbTileExists?(x + 1, y) # Movement east is possible
    return dirs
  end
  
  #-----------------------------------------------------------------------------
  # Reorients the player's direction if an impassable tile is reached.
  #-----------------------------------------------------------------------------
  def pbRedirectMovement(dir, dirs)
    return dir if dirs.include?(dir)
    case dir
    when 0 then return (dirs.include?(1)) ? 1 : dirs.first # Reverse south
    when 1 then return (dirs.include?(0)) ? 0 : dirs.first # Reverse north
    when 2 then return (dirs.include?(3)) ? 3 : dirs.first # Reverse east
    when 3 then return (dirs.include?(2)) ? 2 : dirs.first # Reverse west
    end
  end
  
  #-----------------------------------------------------------------------------
  # Updates which tile the player is currently standing on.
  #-----------------------------------------------------------------------------
  def pbUpdatePlayerTile
    @map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      next if sprite.x != @player.x
      next if sprite.y != @player.y
      @player_tile = sprite
      break
    end
  end
  
  #-----------------------------------------------------------------------------
  # Processes all events that should take place on the player's current tile.
  #-----------------------------------------------------------------------------
  def pbProcessPlayerTile(dir)
    pbUpdatePlayerTile
    @player_tile.make_visited
	dirs = pbUpdateDirections
    if @player_tile.interactable? && !@player_tile.isTile?(:Pathway)
      dir = AdventureTileEffects.triggerTile(@player_tile.tile, @player_tile, @adventure, self, dir, dirs)
	  dirs = pbUpdateDirections
    end
    dir = AdventureTileEffects.triggerTile(:Pathway, @player_tile, @adventure, self, dir, dirs)
    if !dir || dirs.empty?
      pbMessage(_INTL("No valid paths found!\nYou were forced to abandon the adventure!")) { pbUpdate }
      @adventure.outcome = 4
      pbHideUI(true)
    end
    return dir
  end
  
  #-----------------------------------------------------------------------------
  # Used to move the player around the map. Set [dir] to a desired direction.
  # (0 = North, 1 = South, 2 = West, 3 = East)
  # The player will move instantly if the ACTION key is held.
  #-----------------------------------------------------------------------------
  def pbMovePlayer(dir = 0)
    # Determines a direction if [dir] is a sprite and not an integer.
    if !dir.is_a?(Integer)
      if    dir.x > @player_tile.x then dir = 3 # East
      elsif dir.x < @player_tile.x then dir = 2 # West
      elsif dir.y > @player_tile.y then dir = 1 # South
      else                              dir = 0 # North
      end
    end
    pbUpdatePokemon(true)
	count = 0
    # Movement loop.
    loop do
      Input.update
      instantMovement = @ui_sprites["controls"].visible && Input.press?(Input::ACTION)
      if !instantMovement && count % 2 == 0
        Graphics.update
        pbUpdate(true)
      end
      dir = pbProcessPlayerTile(dir) if count % 32 == 0
      if Input.press?(Input::CTRL) && $DEBUG
        @adventure.outcome = 4 if pbConfirmMessageSerious(_INTL("Would you like to exit the lair?"))
      end
      break if @adventure.outcome > 0
      case dir
      when 0 then @player.y -= 1 # Move north
      when 1 then @player.y += 1 # Move south
      when 2 then @player.x -= 1 # Move west
      when 3 then @player.x += 1 # Move east
      else break
      end
	  if @player.x < 32 || @player.x > Graphics.width - 32 || 
	     @player.y < 32 || @player.y > Graphics.height - 32
        pbAutoPosition(@player_tile, 6)
	  end
      count += 1
    end
    pbUpdatePokemon
    Graphics.update
    Input.update
    pbUpdate(true)
  end
  
  #-----------------------------------------------------------------------------
  # Automatically scrolls the camera to center on a new tile.
  # Set [speed] to the desired camera speed. (Set 0 to move the camera instantly)
  #-----------------------------------------------------------------------------
  def pbAutoPosition(sprite, speed = 1)
    map = @map_sprites["map"]
    centerX = (Graphics.width / 2) - 16
    centerY = (Graphics.height / 2) - 16
    mapX = Graphics.width - (@adventure.map.dimensions[0] * 32)
    mapY = Graphics.height - (@adventure.map.dimensions[1] * 32)
    count = 0
    loop do
      moveX, moveY = false, false
      # Determines if the camera should move on the X-axis.
      if sprite.x > centerX
        shiftX = -1
        moveX = map.x - 1 > mapX
      elsif sprite.x < centerX
        shiftX = 1
        moveX = map.x + 1 < 0
      end
      # Determines if the camera should move on the Y-axis.
      if sprite.y > centerY
        shiftY = -1
        moveY = map.y - 1 > mapY
      elsif sprite.y < centerY
        shiftY = 1
        moveY = map.y + 1 < 0
      end
      # Determines if the map sprites need to be updated.
      if !moveX && !moveY
        Graphics.update
        Input.update
        pbUpdate(true)
        break
      elsif speed > 0 && count % speed == 0
        Graphics.update
        Input.update
        pbUpdate(true)
      end
      # Moves all the map sprites in the required directions.
      @map_sprites.each_value do |s|
        s.x += shiftX if moveX
        s.y += shiftY if moveY
      end
      count += 1
    end	
  end
  
  #-----------------------------------------------------------------------------
  # Handles the logic and controls for player route selection.
  #-----------------------------------------------------------------------------
  def pbSelectRoute(dir, dirs)
    pbAutoPosition(@player_tile, 6)
    pbUpdatePokemon
    pbSEPlay("Exclaim")
    dir = pbRedirectMovement(dir, dirs)
    return nil if !dir
    pbUpdateRouteArrows(dir, dirs)
    old_dir = dir
    loop do
      Graphics.update
      Input.update
      pbUpdate
      #-------------------------------------------------------------------------
      # ARROW KEYS
      #-------------------------------------------------------------------------
      # Route selection.
      if Input.trigger?(Input::UP)
        dir = 0 if dirs.include?(0)
      elsif Input.trigger?(Input::DOWN)
        dir = 1 if dirs.include?(1)
      elsif Input.trigger?(Input::LEFT)
        dir = 2 if dirs.include?(2)
      elsif Input.trigger?(Input::RIGHT)
        dir = 3 if dirs.include?(3)
      end
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Confirm selection.
      if Input.trigger?(Input::USE) && 
         pbConfirmMessage(_INTL("Are you sure you want to follow this path?")) { pbUpdate }
        pbUpdatePokemon(true)
        pbHideUI
        break
      #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      # Reverts to original route selection.
      elsif Input.trigger?(Input::BACK)
        dir = dirs.first
      #-------------------------------------------------------------------------
      # ACTION KEY
      #-------------------------------------------------------------------------
      # Open command menu.
      elsif Input.trigger?(Input::ACTION)
        cmd = 0
        commands = [_INTL("View Map")]
        cmd_ids = [:view]
        if !@adventure.playtesting
          commands.push(_INTL("Check Party"))
          cmd_ids.push(:summary)
        end
        if @adventure.endlessMode?
		  record = $PokemonGlobal.raid_adventure_records(@adventure.style)
		  if record && !record.empty?
            commands.push(_INTL("View Record"))
            cmd_ids.push(:record)
		  end
        end
        commands.push(_INTL("End Adventure"))
        cmd_ids.push(:abandon)
        loop do
          cmd = pbMessage(_INTL("What would you like to do?"), commands, -1, nil, 0) { pbUpdate }
		  if cmd < 0
		    pbPlayCancelSE
			break
		  end
          case cmd_ids[cmd]
          when :view      # View Map
            pbPlayDecisionSE
            pbFreeMapScrolling
            dirs = pbUpdateDirections
            dir = pbRedirectMovement(dir, dirs)
            pbUpdateRouteArrows(dir, dirs)
			break
          when :summary   # Check Party
            pbPlayDecisionSE
            pbSummary
            pbUpdateRouteArrows(dir, dirs)
			break
          when :record    # View Record
		    pbPlayDecisionSE
			pbAdventureRecord(@adventure.style)
          when :abandon   # End Adventure
            if @adventure.playtesting
              msg = _INTL("End your playtesting?")
            else
              adventure_name = GameData::RaidType.get(@adventure.style).lair_name
              msg = _INTL("End your {1}?\nAny captured Pokémon and acquired treasure will be lost.", adventure_name)
            end
            if pbConfirmMessageSerious(msg)
              @adventure.outcome = 4
              pbHideUI(true)
			  break
            end
          end
        end
      end
      break if @adventure.outcome > 0
      #-------------------------------------------------------------------------
      # Updates route arrows.
      if dir != old_dir
        pbPlayCursorSE
        old_dir = dir
        4.times do |i|
          color = (i == dir) ? Color.new(255, 0, 0, 200) : Color.new(0, 0, 0, 0)
          @ui_sprites["route_arrow_#{i}"].color = color
        end
      end
    end
    pbUpdateControls(:moving)
    return dir	
  end
  
  #-----------------------------------------------------------------------------
  # Handles the logic and controls for freely scrolling the map.
  #-----------------------------------------------------------------------------
  def pbFreeMapScrolling(teleporter = false)
    pbHideUI(true)
    map = @map_sprites["map"]
    screenX = Graphics.width - 49
    screenY = Graphics.height - 49
    width, height = *@adventure.map.dimensions
    mapX = Graphics.width - (width * 32) + 1
    mapY = Graphics.height - (height * 32) + 1
    @ui_sprites["cursor"].x = @player_tile.x - 16
    @ui_sprites["cursor"].y = @player_tile.y - 16
    @ui_sprites["cursor"].visible = true
    @ui_sprites["overlay"].visible = true
    @cursor_tile = @player_tile
    pbUpdatePokemon(true) if teleporter
    pbUpdateControls((teleporter ? :teleporting : :viewing))
    pbUpdateCursor
    loop do
      Graphics.update
      Input.update
      pbUpdate(true)
      @ui_sprites["map_arrow_0"].visible = @cursor_tile.map_y > 0
      @ui_sprites["map_arrow_1"].visible = @cursor_tile.map_y < height - 1
      @ui_sprites["map_arrow_2"].visible = @cursor_tile.map_x > 0
      @ui_sprites["map_arrow_3"].visible = @cursor_tile.map_x < width - 1
      #-------------------------------------------------------------------------
      # ARROW KEYS
      #-------------------------------------------------------------------------
      # Directional map controls.
      if Input.press?(Input::UP)
        @map_sprites.each_value { |s| s.y += 2 } if map.y < -1
        @ui_sprites["cursor"].y -= 2 if @ui_sprites["cursor"].y > -16
        pbUpdateCursor
      end
      if Input.press?(Input::DOWN)
        @map_sprites.each_value { |s| s.y -= 2 } if map.y > mapY
        @ui_sprites["cursor"].y += 2 if @ui_sprites["cursor"].y <= screenY
        pbUpdateCursor
      end
      if Input.press?(Input::LEFT)
        @map_sprites.each_value { |s| s.x += 2 } if map.x < -1
        @ui_sprites["cursor"].x -= 2 if @ui_sprites["cursor"].x > -16
        pbUpdateCursor
      end
      if Input.press?(Input::RIGHT)
        @map_sprites.each_value { |s| s.x -= 2 } if map.x > mapX
        @ui_sprites["cursor"].x += 2 if @ui_sprites["cursor"].x <= screenX
        pbUpdateCursor
      end
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::USE)
        # Confirms the selection of a valid tile to teleport to (Teleporter tile).
        if teleporter
          if @cursor_tile.isTile?(:Crossroad) && pbCursorReact?
            if @cursor_tile.visited? && @cursor_tile.coords != @player_tile.coords
              if pbConfirmMessage(_INTL("Teleport to this tile?")) { pbUpdate }
                @player_tile = @cursor_tile
                @player.visible = false
                @player.x = @player_tile.x
                @player.y = @player_tile.y
                pbHideUI
                pbAutoPosition(@player_tile, 6)
                pbRestoreUI
                break
              end
            else
              pbMessage(_INTL("You haven't visited that tile yet!")) { pbUpdate }
            end
          else
            pbPlayBuzzerSE
          end
        # Toggles the visibility of the Pokemon sprites on the map.
        elsif !@adventure.playtesting
          pbPlayDecisionSE
          @raid_battles.each_with_index do |raid, i|
            @map_sprites["pokemon_#{i}"].visible = !@map_sprites["pokemon_#{i}"].visible
            @map_sprites["pkmntype_#{i}"].visible = !@map_sprites["pkmntype_#{i}"].visible
          end
        end
      #-------------------------------------------------------------------------
      # ACTION KEY
      #-------------------------------------------------------------------------
      # Toggles the map grid visibility.
      elsif Input.trigger?(Input::ACTION)
        next if teleporter
        pbPlayDecisionSE
        @map_sprites["grid"].visible = !@map_sprites["grid"].visible
      #-------------------------------------------------------------------------
      # JUMPUP KEY
      #-------------------------------------------------------------------------
      # Cycles the cursor to each Battle tile, in order.
      elsif Input.trigger?(Input::JUMPUP)
        next if teleporter
        id = @cursor_tile.isTile?(:Battle) ? @cursor_tile.battle_id + 1 : 0
        id = 0 if id > @boss_tile.battle_id
        @map_sprites.each_value do |sprite|
          next if !sprite.is_a?(AdventureTileSprite)
          next if !sprite.isTile?(:Battle)
          next if sprite.battle_id != id
          @cursor_tile = sprite
        end
        pbPlayCursorSE
        pbAutoPosition(@cursor_tile, 0)
        pbUpdateCursor(true)
      #-------------------------------------------------------------------------
      # JUMPDOWN KEY
      #-------------------------------------------------------------------------
      # Cycles the cursor to each Battle tile, in reverse order.
      elsif Input.trigger?(Input::JUMPDOWN)
        next if teleporter
        id = @cursor_tile.isTile?(:Battle) ? @cursor_tile.battle_id - 1 : @boss_tile.battle_id
        id = @boss_tile.battle_id if id < 0
        @map_sprites.each_value do |sprite|
          next if !sprite.is_a?(AdventureTileSprite)
          next if !sprite.isTile?(:Battle)
          next if sprite.battle_id != id
          @cursor_tile = sprite
        end
        pbPlayCursorSE
        pbAutoPosition(@cursor_tile, 0)
        pbUpdateCursor(true)
      #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      # Exits the free map scroll mode and returns to route selection.
      elsif Input.trigger?(Input::BACK)
        next if teleporter
        pbPlayCancelSE
        @ui_sprites["cursor"].visible = false
        4.times { |i| @ui_sprites["map_arrow_#{i}"].visible = false }
        pbAutoPosition(@player_tile, 32)
        pbUpdatePokemon
        pbRestoreUI
        break
      #-------------------------------------------------------------------------
      # CTRL KEY (Debug only)
      #-------------------------------------------------------------------------
      # Moves the player to a new crossroad tile.
      elsif Input.trigger?(Input::CTRL) && $DEBUG
        next if teleporter
        next if @adventure.playtesting
        next if @cursor_tile.coords == @player_tile.coords
        next if !pbCursorReact?
        if @cursor_tile.isTile?(:Crossroad)
          if pbConfirmMessage(_INTL("Move to this tile?"))
            @player_tile = @cursor_tile
            @player.x = @player_tile.x
            @player.y = @player_tile.y
            @player_tile.make_visited
            pbSEPlay("Player jump")
          end
        else
          tileName = GameData::AdventureTile.get(:Crossroad).name
          pbMessage(_INTL("The player can only be moved to {1} tiles.", tileName))
        end
      end
    end
  end
end