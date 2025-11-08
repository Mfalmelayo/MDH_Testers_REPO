#===============================================================================
# Adventure Map core.
#===============================================================================
class AdventureMapScene
  attr_reader   :ui_sprites, :map_sprites, :start_tile, :boss_tile
  attr_accessor :raid_battles, :player, :player_tile
  
  #-----------------------------------------------------------------------------
  # Draws and processes the entire Adventure map.
  #-----------------------------------------------------------------------------
  def pbStartScene
    #---------------------------------------------------------------------------
    # Sets up viewports.
    @viewport     = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z   = 99999
    @viewport2    = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport2.z  = 99999
    @map_sprites  = {}
    @ui_sprites   = {}
    #---------------------------------------------------------------------------
    # Sets up important variables.
    @path         = Settings::RAID_GRAPHICS_PATH + "Adventures/"
    @heartbitmap  = AnimatedBitmap.new(@path + "hearts")
    @keybitmap    = AnimatedBitmap.new(@path + "key_count")
    @adventure    = pbRaidAdventureState
    @raid_battles = []    # An array containing all battle rules and Pokemon for each battle in the lair.
    @player       = nil   # The player's icon sprite on the map.
    @player_tile  = nil   # Tile data for the specific tile the player's icon currently occupies.
    @start_tile   = nil   # Tile data for the specific tile containing the lair's Start Point.
    @cursor_tile  = nil   # Tile data for the specific tile the cursor is currently highlighting.
    @boss_tile    = nil   # Tile data for the specific tile containing the lair's boss Pokemon.
    @boss_type    = nil   # The displayed type of the boss Pokemon within the lair.
    @darkness     = nil   # The darkness overlay used in Dark Lairs.
    #---------------------------------------------------------------------------
    # Sets up various sprites and features for the map.
    pbSetupBattles
    pbSetupMap
    pbUpdateHearts
    pbUpdateKeys
    pbUpdateFloor
    pbUpdateDarkness
    #---------------------------------------------------------------------------
    # Sets up general UI sprites.
    @ui_sprites["map_arrow_0"] = AnimatedSprite.new("Graphics/UI/up_arrow", 8, 28, 40, 2, @viewport2)
    @ui_sprites["map_arrow_0"].x = (Graphics.width / 2) - 14
    @ui_sprites["map_arrow_0"].y = 0
    @ui_sprites["map_arrow_1"] = AnimatedSprite.new("Graphics/UI/down_arrow", 8, 28, 40, 2, @viewport2)
    @ui_sprites["map_arrow_1"].x = (Graphics.width / 2) - 14
    @ui_sprites["map_arrow_1"].y = Graphics.height - 44
    @ui_sprites["map_arrow_2"] = AnimatedSprite.new("Graphics/UI/left_arrow", 8, 40, 28, 2, @viewport2)
    @ui_sprites["map_arrow_2"].x = 0
    @ui_sprites["map_arrow_2"].y = (Graphics.height / 2) - 14
    @ui_sprites["map_arrow_3"] = AnimatedSprite.new("Graphics/UI/right_arrow", 8, 40, 28, 2, @viewport2)
    @ui_sprites["map_arrow_3"].x = Graphics.width - 44
    @ui_sprites["map_arrow_3"].y = (Graphics.height / 2) - 14
    4.times do |i|
      @ui_sprites["map_arrow_#{i}"].play
      @ui_sprites["route_arrow_#{i}"] = IconSprite.new(0, 0, @viewport2)
      @ui_sprites["route_arrow_#{i}"].bitmap = Bitmap.new(@path + "route_arrows")
      @ui_sprites["route_arrow_#{i}"].src_rect.set(16 * i, 0, 16, 16)
    end
    @ui_sprites["cursor"] = IconSprite.new(0, 0, @viewport2)
    @ui_sprites["cursor"].setBitmap(@path + "cursor")
    @ui_sprites["cursor"].src_rect.set(0, 0, 64, 64)
    @cursor = @ui_sprites["cursor"]
    @ui_sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport2)
    pbSetSystemFont(@ui_sprites["overlay"].bitmap)
    @ui_sprites["controls"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport2)
    pbSetSmallFont(@ui_sprites["controls"].bitmap)
    #---------------------------------------------------------------------------
    # Begins map processing.
	pbSetupTitle
    pbHideUI
    pbAutoPosition(@player_tile, 0)
    if @adventure.playtesting
      pbUpdateControls(:moving)
    else
      track = GameData::RaidType.get(@adventure.style).lair_bgm
      pbBGMPlay(track)
      pbMapIntro
    end
    pbMovePlayer(@start_tile)
  end
  
  #-----------------------------------------------------------------------------
  # Sets up the intro title for the lair.
  #-----------------------------------------------------------------------------
  def pbSetupTitle
    return if @adventure.playtesting
	@ui_sprites["title"] = IconSprite.new(Graphics.width / 2, 8, @viewport2)
    @ui_sprites["title"].setBitmap(@path + "header")
	bitmap = @ui_sprites["title"].bitmap
	@ui_sprites["title"].ox = bitmap.width / 2
	pbSetSmallFont(bitmap)
	adventure_name = GameData::RaidType.get(@adventure.style).lair_name
	pbDrawTextPositions(bitmap, [[adventure_name, bitmap.width / 2, 12, :center, Color.white, Color.black]])
	pbSetSystemFont(bitmap)
	pbDrawTextPositions(bitmap, [[@adventure.map.name, bitmap.width / 2, 66, :center, Color.white, Color.black, :outline]])
	@ui_sprites["title"].visible = false
  end
  
  #-----------------------------------------------------------------------------
  # Sets up the data for each battle within the lair.
  #-----------------------------------------------------------------------------
  def pbSetupBattles
    return if @adventure.playtesting
    base_rules = {
      :size       => 3,                 # The number of Pokemon the player sends out.
      :style      => @adventure.style,  # The style of the raid battle.
      :ko_count   => @adventure.hearts, # The number of hearts the player has remaining.
      :turn_count => 10,                # The max number of turns for each raid battle.
      :shield_hp  => 5,                 # The number of bars the raid Pokemon's shield will have.
      :battled    => false              # Whether or not this raid Pokemon has been challenged.
    }
    @raid_battles.clear
    @adventure.raid_species.each do |rank, ids|
      ids.each do |sp|
	    rules = base_rules.clone
        rules[:rank] = rank
        species = pbDefaultRaidProperty(sp, :species, rules)
		level = [($player.badge_count + 1) * 10, 70].min
		level += 5 if rank == 6
        pkmn = Pokemon.new(species, level)
        pkmn.setRaidBossAttributes(rules)
		pkmn.dynamax_able = false if defined?(pkmn.dynamax_able) && @adventure.style != :Max
		pkmn.terastal_able = false if defined?(pkmn.terastal_able) && @adventure.style != :Tera
        pkmn.obtain_text = _INTL("{1}.", @adventure.map.name)
        rules[:pokemon] = pkmn
        @raid_battles.push(rules)
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Draws all of the sprites used to display a lair map.
  #-----------------------------------------------------------------------------
  def pbSetupMap
    #---------------------------------------------------------------------------
    # Draws the map background, tiles, and grid.
    @map_sprites["map"] = IconSprite.new(0, 0, @viewport)
    @map_sprites["map"].bitmap = Bitmap.new(@path + "Maps/#{@adventure.map.filename}")
    width, height = *@adventure.map.dimensions
    maxBattle = GameData::AdventureTile.get(:Battle).required - 1
    width.times do |x|
      height.times do |y|
        tile_data = @adventure.map.get_tile(x, y)
        setPlayer = tile_data[:id] == :Player
        tile_data[:id] = :Pathway if setPlayer
        @map_sprites["tile_#{x}_#{y}"] = AdventureTileSprite.new(
          x, y, tile_data, @adventure.style, @adventure.darknessMode?, @viewport)
        tile = @map_sprites["tile_#{x}_#{y}"]
        @player_tile = tile if setPlayer
        @start_tile  = tile if tile_data[:id] == :StartPoint
        @boss_tile   = tile if tile_data[:id] == :Battle && tile.battle_id == maxBattle
      end
    end
    @map_sprites["grid"] = IconSprite.new(0, 0, @viewport)
    @map_sprites["grid"].setBitmap(@path + "map_grid")
    @map_sprites["grid"].visible = false
    #---------------------------------------------------------------------------
    # Draws the Pokemon silhouettes and icons.
    @raid_battles.each_with_index do |raid, i|
      battle_tile = nil
      @map_sprites.each_value do |sprite|
        next if !sprite.is_a?(AdventureTileSprite)
        next if !sprite.isTile?(:Battle) || sprite.battle_id != i
        battle_tile = sprite
      end
      @map_sprites["pokemon_#{i}"] = PokemonSprite.new(@viewport)
	  pkmn = raid[:pokemon]
	  sprite = @map_sprites["pokemon_#{i}"]
	  sprite.setPokemonBitmap(pkmn)
	  sprite.setOffset(PictureOrigin::BOTTOM)
	  sprite.x = battle_tile.x + 16
      sprite.y = battle_tile.y + ((sprite.bitmap.height - (findBottom(sprite.bitmap) + 1)) / 2) + 8
	  sprite.zoom_x = 0.5
      sprite.zoom_y = 0.5
      sprite.color.alpha = 255
	  sprite.pattern = nil
      case @adventure.style
      when :Ultra  # Draws the Z-Crystal held by the Pokemon.
        @map_sprites["pkmntype_#{i}"] = ItemIconSprite.new(battle_tile.x + 16, battle_tile.y + 20, pkmn.item_id, @viewport2)
        type = GameData::Item.get(pkmn.item_id).zmove_type
      when :Tera   # Draws the Tera Type of the Pokemon.
        @map_sprites["pkmntype_#{i}"] = IconSprite.new(battle_tile.x, battle_tile.y, @viewport2)
        type = pkmn.tera_type
        icon_pos = GameData::Type.get(type).icon_position
        @map_sprites["pkmntype_#{i}"].bitmap = Bitmap.new(Settings::TERASTAL_GRAPHICS_PATH + "tera_types")
        @map_sprites["pkmntype_#{i}"].src_rect.set(0, icon_pos * 32, 32, 32)
      else         # Draws one of the Pokemon's types.
        @map_sprites["pkmntype_#{i}"] = IconSprite.new(battle_tile.x - 16, battle_tile.y + 4, @viewport2)
        type = pkmn.types.sample
        icon_pos = GameData::Type.get(type).icon_position
        @map_sprites["pkmntype_#{i}"].bitmap = Bitmap.new(_INTL("Graphics/UI/types"))
        @map_sprites["pkmntype_#{i}"].src_rect.set(0, icon_pos * 28, 64, 28)
      end
      @boss_type = type if i == maxBattle
    end
    #---------------------------------------------------------------------------
    # Draws the player icon and darkness overlay.
    player_icon = GameData::TrainerType.player_map_icon_filename($player.trainer_type)
    @map_sprites["player"] = IconSprite.new(@player_tile.x, @player_tile.y, @viewport2)
    @map_sprites["player"].setBitmap(player_icon)
    @player = @map_sprites["player"]
    @darkness = LairDarknessSprite.new(@player, @viewport) if @adventure.darknessMode?
  end
  
  #-----------------------------------------------------------------------------
  # Updates all of the sprites used in the lair.
  #-----------------------------------------------------------------------------
  def pbUpdate(moving = false)
    pbUpdateSpriteHash(@map_sprites)
    pbUpdateSpriteHash(@ui_sprites)
    pbUpdateDarkness if moving
  end
  
  #-----------------------------------------------------------------------------
  # Hides the visibility of various map UI's.
  #-----------------------------------------------------------------------------
  def pbHideUI(allsprites = false)
    if allsprites
      @ui_sprites.each_value { |s| s.visible = false }
    else
      @ui_sprites["cursor"].visible = false
      @ui_sprites["controls"].visible = false
      @ui_sprites["overlay"].visible = false
      4.times do |i|
        @ui_sprites["map_arrow_#{i}"].visible = false
        @ui_sprites["route_arrow_#{i}"].visible = false
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Restores the visibility of certain map UI's.
  #-----------------------------------------------------------------------------
  def pbRestoreUI
    @ui_sprites["overlay"].visible = true
    @ui_sprites["controls"].visible = true
    @ui_sprites["hearts"].visible = true
    @ui_sprites["keys"].visible = @adventure.keys > 0
    @ui_sprites["floor"].visible = true if @ui_sprites.has_key?("floor")
  end
  
  #-----------------------------------------------------------------------------
  # Pauses all actions on the map for a number of seconds.
  #-----------------------------------------------------------------------------
  def pbPauseScene(seconds = 1.0)
    timer_start = System.uptime
    until System.uptime - timer_start >= seconds
      Graphics.update
      Input.update
      pbUpdate
    end
  end
  
  #-----------------------------------------------------------------------------
  # Views the party Summary while on the lair map.
  #-----------------------------------------------------------------------------
  def pbSummary
    pbHideUI(true)
    oldsprites = pbFadeOutAndHide(@map_sprites) { pbUpdate }
    scene  = PokemonSummary_Scene.new
    screen = PokemonSummaryScreen.new(scene, true)
    party = $player.party
    party += $PokemonGlobal.partner[3] if $PokemonGlobal.partner
    screen.pbStartScreen(party, 0)
    yield if block_given?
    pbFadeInAndShow(@map_sprites, oldsprites) { pbUpdate }
    pbRestoreUI
  end
  
  #-----------------------------------------------------------------------------
  # Updates and draws the player's heart count.
  #-----------------------------------------------------------------------------
  def pbUpdateHearts(value = nil, addToMax = nil)
    if value
      if addToMax
        @adventure.hearts += value
        @adventure.max_hearts += value
      else
        @adventure.hearts = value
        @adventure.max_hearts = value if @adventure.max_hearts < value
      end
    end
    if !@ui_sprites["hearts"]
      @ui_sprites["hearts"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport2)
    end
    @ui_sprites["hearts"].bitmap.clear
    width = @heartbitmap.bitmap.width / 2
    @adventure.max_hearts.times do |i|
      x = (@adventure.hearts > i) ? 0 : width
      rect = Rect.new(x, 0, width, @heartbitmap.bitmap.height)
      @ui_sprites["hearts"].bitmap.blt(34 * i + 4, 4, @heartbitmap.bitmap, rect)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Updates and draws the player's key count.
  #-----------------------------------------------------------------------------
  def pbUpdateKeys(value = nil)
    @adventure.keys += value if value
    if !@ui_sprites["keys"]
      @ui_sprites["keys"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport2)
      pbSetSmallFont(@ui_sprites["keys"].bitmap)
    end
    @ui_sprites["keys"].bitmap.clear
    w, h = @keybitmap.bitmap.width, @keybitmap.bitmap.height
    count = [[@adventure.keys.to_s, 54, 48, :left, Color.white, Color.black, :outline]]
    @ui_sprites["keys"].bitmap.blt(0, 38, @keybitmap.bitmap, Rect.new(0, 0, w, h))
    pbDrawTextPositions(@ui_sprites["keys"].bitmap, count)
    if @adventure.keys > 0
      @ui_sprites["keys"].visible = true
    else
      @ui_sprites["keys"].visible = false
    end
  end
  
  #-----------------------------------------------------------------------------
  # Updates and draws the current floor the player is on in Endless Mode.
  #-----------------------------------------------------------------------------
  def pbUpdateFloor
    return if !@adventure.endlessMode?
    text = sprintf("B%dF", @adventure.floor)
    if !@ui_sprites["floor"]
      @ui_sprites["floor"] = Window_AdvancedTextPokemon.new(text)
      @ui_sprites["floor"].setSkin("Graphics/Windowskins/goldskin")
      @ui_sprites["floor"].resizeToFit(@ui_sprites["floor"].text, Graphics.width)
      @ui_sprites["floor"].viewport = @viewport2
      @ui_sprites["floor"].x = Graphics.width - (@ui_sprites["floor"].width + 4)
      @ui_sprites["floor"].y = 4
    else
      @ui_sprites["floor"].setTextToFit(text)
      @ui_sprites["floor"].x = Graphics.width - (@ui_sprites["floor"].width + 4)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Updates the radius of the darkness circle around the player in Dark Lairs.
  #-----------------------------------------------------------------------------
  def pbUpdateDarkness(increase = false)
    return if !@darkness
    @darkness.increase_radius if increase
    @darkness.refresh
  end
  
  #-----------------------------------------------------------------------------
  # Updates the visibility of Pokemon silhouettes on the map.
  #-----------------------------------------------------------------------------
  def pbUpdatePokemon(fade = false)
    return if @adventure.playtesting
    @raid_battles.each_with_index do |raid, i|
      @map_sprites["pokemon_#{i}"].opacity = (fade) ? 100 : 255
      @map_sprites["pkmntype_#{i}"].opacity = (fade) ? 0 : 255
      if raid[:battled]
        @map_sprites["pkmntype_#{i}"].visible = false
        @map_sprites["pokemon_#{i}"].visible = false
        @map_sprites["pokemon_#{i}"].color.alpha = 0
      else
        @map_sprites["pkmntype_#{i}"].visible = true
        @map_sprites["pokemon_#{i}"].visible = true
        @map_sprites["pokemon_#{i}"].color.alpha = 255
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Updates the route selection arrows.
  #-----------------------------------------------------------------------------
  def pbUpdateRouteArrows(dir, dirs)
    @ui_sprites["route_arrow_0"].x = @player.x + 8
    @ui_sprites["route_arrow_0"].y = @player.y - 16
    @ui_sprites["route_arrow_1"].x = @player.x + 8
    @ui_sprites["route_arrow_1"].y = @player.y + 32
    @ui_sprites["route_arrow_2"].x = @player.x - 16
    @ui_sprites["route_arrow_2"].y = @player.y + 10
    @ui_sprites["route_arrow_3"].x = @player.x + 32
    @ui_sprites["route_arrow_3"].y = @player.y + 10
    4.times do |i|
      color = (i == dir) ? Color.new(255, 0, 0, 200) : Color.new(0, 0, 0, 0)
      @ui_sprites["route_arrow_#{i}"].color = color
      @ui_sprites["route_arrow_#{i}"].visible = dirs.include?(i)
    end
    @ui_sprites["overlay"].visible = true
    overlay = @ui_sprites["overlay"].bitmap
    overlay.clear
    pbDrawImagePositions(overlay, [[@path + "selection", 0, Graphics.height - 74]])
    pbDrawTextPositions(overlay, [
      [_INTL("Choose your path!"), Graphics.width / 2, Graphics.height - 60, :center, Color.white, Color.black, :outline]
    ])
    pbUpdateControls(:selecting)
  end
  
  #-----------------------------------------------------------------------------
  # Updates the controls displayed on screen for all situations in a lair.
  #-----------------------------------------------------------------------------
  def pbUpdateControls(mode)
    return if @adventure.outcome > 0
    @ui_sprites["controls"].visible = true
    @ui_sprites["controls"].opacity = 255
    overlay = @ui_sprites["controls"].bitmap
    overlay.clear
    case mode
    when :teleporting  # Controls for Teleporter selection.
      controls = [[_INTL("[USE] Select Tile"), 4,  8, :left, Color.white, Color.black, :outline]]
    when :moving       # Controls for player movement.
      images = [[@path + "fast_travel", 0, Graphics.height - 32, 0, 0, 176, 32]]
      controls = [[_INTL("ACTION: Fast Travel"), 4, Graphics.height - 22, :left, Color.white, Color.black]]
      if $DEBUG
        images.push([@path + "fast_travel", Graphics.width - 176, Graphics.height - 32, 0, 32, 176, 32])
        controls.push([_INTL("CTRL: Forced Exit"), Graphics.width - 8, Graphics.height - 22, :right, Color.white, Color.black])
      end
      pbDrawImagePositions(overlay, images)
    when :selecting    # Controls for route selection.
      colors = [Color.white, Color.new(64, 64, 64)]
      controls = [
        [_INTL("ARROWS: Select"),  4,                  Graphics.height - 22, :left,   *colors],
        [_INTL("USE: Confirm"),    Graphics.width / 2, Graphics.height - 22, :center, *colors],
        [_INTL("ACTION: Options"), Graphics.width - 4, Graphics.height - 22, :right,  *colors]
      ]
    when :viewing      # Controls for map scrolling.
      text_display = [:left, Color.white, Color.black, :outline]
      if @adventure.playtesting
        controls = [
          [_INTL("[ACTION]"),        4,  8, *text_display],
          [_INTL("[JUMP]"),          4, 28, *text_display],
          [_INTL("[BACK]"),          4, 48, *text_display],
          [_INTL("Toggle Grid"),    82,  8, *text_display],
          [_INTL("Cycle Cursor"),   82, 28, *text_display],
          [_INTL("Return"),         82, 48, *text_display]
        ]
      else
        controls = [
          [_INTL("[USE]"),           4,  8, *text_display],
          [_INTL("[ACTION]"),        4, 28, *text_display],
          [_INTL("[JUMP]"),          4, 48, *text_display],
          [_INTL("[BACK]"),          4, 68, *text_display],
          [_INTL("Toggle Pokémon"), 82,  8, *text_display],
          [_INTL("Toggle Grid"),    82, 28, *text_display],
          [_INTL("Cycle Cursor"),   82, 48, *text_display],
          [_INTL("Return"),         82, 68, *text_display]
        ]
        if $DEBUG
          controls.push(
            [_INTL("[CTRL]"),        4, 88, *text_display],
            [_INTL("Move Player"),  82, 88, *text_display]
          )
        end
      end
    end
    pbDrawTextPositions(overlay, controls)
  end
  
  #-----------------------------------------------------------------------------
  # Updates the cursor while freely scrolling the map.
  #-----------------------------------------------------------------------------
  def pbUpdateCursor(snapToTile = false)
    if snapToTile
      @ui_sprites["cursor"].x = @cursor_tile.x - 16
      @ui_sprites["cursor"].y = @cursor_tile.y - 16
    else
      checkX = @ui_sprites["cursor"].x + 16
      checkY = @ui_sprites["cursor"].y + 16
      @map_sprites.each_value do |sprite|
        next if !sprite.is_a?(AdventureTileSprite)
        next if !(sprite.x - 20..sprite.x + 20).include?(checkX)
        next if !(sprite.y - 20..sprite.y + 20).include?(checkY)
        @cursor_tile = sprite
        break
      end
    end
    cursor_react = pbCursorReact?
    # The cursor changes color when overlapping an interactable tile.
    if @cursor_tile.active? && cursor_react
      @ui_sprites["cursor"].src_rect.x = 64
    else
      @ui_sprites["cursor"].src_rect.x = 0
    end
    # Hides controls display when overlapping the cursor.
    if @ui_sprites["cursor"].x <= 192 && @ui_sprites["cursor"].y <= 96
      @ui_sprites["controls"].opacity = 0
    else
      @ui_sprites["controls"].opacity = 200
    end
    # Draws tile information.
    overlay = @ui_sprites["overlay"].bitmap
    overlay.clear
    tile_bg = [[@path + "tile_bg", Graphics.width - 192, 0]]
    tile_bg.push([@path + "info_bg", 10, 310]) if cursor_react
    pbDrawImagePositions(overlay, tile_bg)
    x, y = *@cursor_tile.coords
    tile_text = [["#{x}, #{y}", Graphics.width - 8, 8, :right, Color.white, Color.black, :outline]]
    if cursor_react
      tile_name = @cursor_tile.tile.name
      case @cursor_tile.tile_id
      when :Battle
        if @adventure.playtesting
          id, bossID = @cursor_tile.battle_id, GameData::AdventureTile.get(:Battle).required - 1
          (id == bossID) ? tile_name += " (Boss)" : tile_name += sprintf(" (#%d)", id)
        else
          rank = @raid_battles[@cursor_tile.battle_id][:rank]
          (rank == 6) ? tile_name += " (Boss)" : tile_name += " (Rank #{rank})"
        end
      when :Warp
        coords = @cursor_tile.warp_point
        tile_name += sprintf(" to %d, %d", *coords)
      when :Switch
        (@cursor_tile.switch_on?) ? tile_name += " (ON)" : tile_name += " (OFF)"
      end
      tile_text.push([_INTL(tile_name), Graphics.width - 8, 40, :right, Color.white, Color.black, :outline])
      if @cursor_tile.toggled?
        desc = @cursor_tile.tile.description
      else
        switch = GameData::AdventureTile.get(:Switch).name
        desc = _INTL("This tile is currently disabled. Enable it by flipping a {1} tile to the 'ON' position.", switch)
      end
      drawTextEx(overlay, 18, 318, 476, 2, desc, Color.white, Color.black)
    end
    pbDrawTextPositions(overlay, tile_text)
  end
  
  #-----------------------------------------------------------------------------
  # Returns whether the cursor should react when hovering over a tile.
  #-----------------------------------------------------------------------------
  def pbCursorReact?
    return false if !@cursor_tile.cursor_react?
    if @adventure.darknessMode? && !@cursor_tile.isTile?(:Battle)
      tiles = []
      px, py = *@player_tile.coords
      radius = (@darkness.radius - 16) / 32
      rangeX = *(px - radius..px + radius)
      rangeY = *(py - radius..py + radius)
      rangeX.each_with_index do |x, i|
        rangeY.each_with_index do |y, j|
          next if i < radius - 1 && j < radius - 1 - i
          next if i > radius + 1 && j < radius - (i - rangeX.length).abs
          next if i < radius - 1 && j > radius + 1 + i
          next if i > radius + 1 && j > radius + (i - rangeX.length).abs
          tiles.push([x, y])
        end
      end
      return tiles.include?(@cursor_tile.coords)
    end
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Plays the introduction sequence upon entering a lair.
  #-----------------------------------------------------------------------------
  def pbMapIntro(showTitle = true)
    return if $DEBUG && Input.press?(Input::CTRL)
    typeName = GameData::Type.get(@boss_type).name
    cryFile = GameData::Species.cry_filename_from_pokemon(@raid_battles[-1][:pokemon])
    pbPauseScene
	if showTitle
	  @ui_sprites["title"].visible = true
	  pbSEPlay("Vs flash")
	  pbSEPlay("Vs sword")
	  pbPauseScene(0.5)
	end
    pbAutoPosition(@boss_tile, 2)
    pbPauseScene
	@ui_sprites["title"].visible = false
    pbMessage(_INTL("\\se[{1}]There's a strong {2}-type reaction coming from within the lair!\\wtnp[30]", cryFile, typeName)) { pbUpdate }
    pbAutoPosition(@player_tile, 6)
  end
  
  #-----------------------------------------------------------------------------
  # Resets the lair and enters a new floor in Endless Mode.
  #-----------------------------------------------------------------------------
  def pbResetLair
    player = @adventure.map.player
    x, y = player[0..1].to_i, player[2..3].to_i
    @player_tile = @map_sprites["tile_#{x}_#{y}"]
    @adventure.boss_battled = false
    pbPauseScene(0.5)
    pbMessage(_INTL("You found a passageway that leads even deeper into the lair!")) { pbUpdate }
    if !pbConfirmMessage(_INTL("Would you like to continue onwards to the next floor?")) { pbUpdate }
      @adventure.outcome = 1
      return
    end
    pbFadeOutIn {
      pbSEPlay("Door enter")
      pbAutoPosition(@player_tile, 0)
      @player.x = @player_tile.x
      @player.y = @player_tile.y
      @darkness.reset_radius if @darkness
      @adventure.raid_species = RaidAdventure.generate_raid_species(nil, @adventure.style)
      @ui_sprites["controls"].visible = false
      pbSetupBattles
      @raid_battles.each_with_index do |raid, i|
	    battle_tile = nil
        @map_sprites.each_value do |sprite|
          next if !sprite.is_a?(AdventureTileSprite)
          next if !sprite.isTile?(:Battle) || sprite.battle_id != i
          battle_tile = sprite
        end
        pkmn = raid[:pokemon]
		sprite = @map_sprites["pokemon_#{i}"]
        sprite.setPokemonBitmap(pkmn)
        sprite.setOffset(PictureOrigin::BOTTOM)
		sprite.x = battle_tile.x + 16
        sprite.y = battle_tile.y + ((sprite.bitmap.height - (findBottom(sprite.bitmap) + 1)) / 2) + 8
        sprite.zoom_x = 0.5
        sprite.zoom_y = 0.5
        sprite.color.alpha = 255
	    sprite.pattern = nil
        case @adventure.style
        when :Ultra
          type = GameData::Item.get(pkmn.item_id).zmove_type
          @map_sprites["pkmntype_#{i}"].item = pkmn.item_id
        when :Tera
          type = pkmn.tera_type
          icon_pos = GameData::Type.get(type).icon_position
          @map_sprites["pkmntype_#{i}"].src_rect.set(0, icon_pos * 32, 32, 32)
        else
          type = pkmn.types.sample
          icon_pos = GameData::Type.get(type).icon_position
          @map_sprites["pkmntype_#{i}"].src_rect.set(0, icon_pos * 28, 64, 28)
        end
        @boss_type = type if i == @raid_battles.length - 1
      end
      @map_sprites.each_value do |sprite|
        next if !sprite.is_a?(AdventureTileSprite)
        sprite.resetTile
      end
      pbUpdatePokemon
      pbUpdateFloor
      pbUpdate(true)
    }
    pbMapIntro(false)
    if    @start_tile.x > @player_tile.x then return 3 # East
    elsif @start_tile.x < @player_tile.x then return 2 # West
    elsif @start_tile.y > @player_tile.y then return 1 # South
    else                                      return 0 # North
    end
  end
  
  #-----------------------------------------------------------------------------
  # Ends the Adventure and fades out the map scene.
  #-----------------------------------------------------------------------------
  def pbEndScene
    return if @adventure.outcome == 0
    pbHideUI(true)
    if !@adventure.playtesting && (@adventure.endlessMode? || @adventure.outcome != 1)
      adventure_name = GameData::RaidType.get(@adventure.style).lair_name
      pbMessage(_INTL("Your {1} is over!", adventure_name)) { pbUpdate }
    end
    pbPauseScene(0.5)
    pbFadeOutAndHide(@map_sprites) { pbUpdate }
    pbDisposeSpriteHash(@map_sprites)
    pbDisposeSpriteHash(@ui_sprites)
    @heartbitmap.dispose
    @keybitmap.dispose
    @darkness.dispose if @darkness
    @viewport.dispose
    @viewport2.dispose
	if !@adventure.playtesting
	  if @adventure.outcome == 1 && !(@adventure.captures.empty? || @adventure.loot.empty?)
	    pbFadeOutIn(99999, true) { 
		  pbAdventureMenuReward
		  @adventure.finalize_loot
		  pbFadeOutIn { pbAdventureMenuSpoils } if !@adventure.loot.empty?
		}
	  end
      pbBGMFade(1.0)
	end
    pbSEPlay("Door exit")
  end
end

#===============================================================================
# The LairDarknessSprite object used to create the black overlay in Dark Lairs.
#===============================================================================
class LairDarknessSprite < DarknessSprite
  def initialize(player, viewport = nil)
    @player = player
    super(viewport)
    self.z = 99999
  end
  
  def radiusMin; return 80;  end
  def radiusMax; return 240; end
  
  def reset_radius
    self.radius = radiusMin
  end
  
  def increase_radius
    return if @radius >= radiusMax
    radiusNow = @radius
    pbSEPlay("Vs flash")
    pbWait(0.7) do |delta_t|
      self.radius = lerp(radiusNow, radiusNow + 32, 0.7, delta_t)
    end
  end

  def refresh
    @darkness.fill_rect(0, 0, Graphics.width, Graphics.height, Color.black)
    px = @player.x + 16
    py = @player.y + 16
    cradius = @radius
    numfades = 5
    (1..numfades).each do |i|
      (px - cradius..px + cradius).each do |j|
        diff2 = (cradius * cradius) - ((j - px) * (j - px))
        diff = Math.sqrt(diff2)
        @darkness.fill_rect(j, py - diff, 1, diff * 2, Color.new(0, 0, 0, 255.0 * (numfades - i) / numfades))
      end
      cradius = (cradius * 0.9).floor
    end
  end
end