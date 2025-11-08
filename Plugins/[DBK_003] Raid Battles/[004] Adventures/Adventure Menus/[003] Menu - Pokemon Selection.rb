#===============================================================================
# Draws item databoxes in Adventure menus.
#===============================================================================
class AdventureRewardbox < AdventureDataboxCore
  #-----------------------------------------------------------------------------
  # Sets the number of items per row in the grid.
  #-----------------------------------------------------------------------------
  GRID_BASE_X   = 180
  GRID_BASE_Y   = 44
  GRID_SQUARE   = 76
  GRID_ROW_SIZE = 4
  
  #-----------------------------------------------------------------------------
  # Sets up an item databox.
  #-----------------------------------------------------------------------------
  def initialize(pokemon, index, viewport = nil)
    super(pokemon, nil, index, viewport)
    @iconOffset = [6, 6]
	@heldOffset = [10, 48]
    @sprites["bg"].setBitmap(@path + "item_slot")
    @sprites["bg"].src_rect.set(GRID_SQUARE, 0, GRID_SQUARE, GRID_SQUARE)
    xpos, ypos = 0, 0
    (@index + 1).times do |i|
      next if i == 0
      if i % GRID_ROW_SIZE == 0
        ypos += GRID_SQUARE + 2
        xpos = 0
      else
        xpos += GRID_SQUARE + 2
      end
    end
    self.x = GRID_BASE_X + xpos
    self.y = GRID_BASE_Y + ypos
    self.z = 99999
    @contents   = Bitmap.new(GRID_SQUARE, GRID_SQUARE)
    self.bitmap = @contents
	refresh
  end
  
  def pokemon=(pkmn)
    @pokemon = pkmn
    @sprites["icon"].pokemon = @pokemon
    @sprites["held"].item = nil if @sprites["held"]
	refresh
  end
  
  #-----------------------------------------------------------------------------
  # Toggles whether a rental databox is being selected in the menu.
  #-----------------------------------------------------------------------------
  def selected=(value)
    return if @selected == value
    @selected = value
    @sprites["icon"].selected = value
    if @selected
      @sprites["bg"].src_rect.x = GRID_SQUARE * 2
	  @sprites["icon"].x -= 4
	  @sprites["icon"].y -= 4
    else
      @sprites["bg"].src_rect.x = GRID_SQUARE
	  @sprites["icon"].x += 4
	  @sprites["icon"].y += 4
    end
	refresh
  end
  
  def refresh
    self.bitmap.clear
    if @pokemon.nil?
	  self.visible = false
	else
	  self.visible = true
	  imagepos = []
	  imagepos.push(["Graphics/UI/Shiny", GRID_SQUARE - 22, GRID_SQUARE - 22]) if @pokemon.shiny?
	  imagepos.push([@path + "item_slot", 0, 0, 0, 0, GRID_SQUARE, GRID_SQUARE]) if @selected
	  pbDrawImagePositions(self.bitmap, imagepos)
	end
  end
end

#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  REWARD_LIST_SIZE = 16
  
  def drawPokemonName(pkmn, overlay)
	overlay.clear
    textpos = [[pkmn.name, 75, 2, :center, BASE_COLOR, SHADOW_COLOR, :outline]]
    genderX = overlay.text_size(pkmn.name).width / 2 + 79
    case pkmn.gender
    when 0 then textpos.push([_INTL("♂"), genderX, 2, :left, Color.new(48, 96, 216), SHADOW_COLOR])
    when 1 then textpos.push([_INTL("♀"), genderX, 2, :left, Color.new(248, 88, 40), SHADOW_COLOR])
    end
    pbDrawTextPositions(overlay, textpos)
  end
  
  def pbGenerateRewards
    pokemon = pbRaidAdventureState.captures
	pokemon.each do |pkmn|
	  pkmn.item = nil
	  pkmn.reset_moves
	  pkmn.ev.each_key { |s| pkmn.ev[s] = 0 }
	  pkmn.resetLegacyData if defined?(pkmn.legacy_data)
	  pkmn.dynamax_able = nil if defined?(pkmn.dynamax_able)
	  pkmn.terastal_able = nil if defined?(pkmn.terastal_able)
	  case @style
	  when :Max  then pkmn.dynamax_lvl = 5
	  when :Tera then pkmn.tera_type = nil
	  end
	  shiny_chance = ($bag.has?(:SHINYCHARM)) ? rand(50) : rand(150)
	  case shiny_chance
	  when 0 then pkmn.shiny = true
	  when 1 then pkmn.super_shiny = true
	  end
	  pkmn.calc_stats
	  pkmn.heal
	end
	return pokemon.reverse
  end
  
  def pbRewardMenu
    idxReward = 0
    pokemon = pbGenerateRewards
    rowSize = AdventureRewardbox::GRID_ROW_SIZE
    @sprites["pokemon"] = PokemonSprite.new(@viewport)
    @sprites["pokemon"].setOffset(PictureOrigin::CENTER)
	if defined?(@sprites["pokemon"].display_values)
	  @sprites["pokemon"].display_values = [80, Graphics.height / 2 - 32]
	else
	  @sprites["pokemon"].x = 80
      @sprites["pokemon"].y = Graphics.height / 2 - 32
	end
	@sprites["pokemon"].setPokemonBitmap(pokemon[idxReward])
    @sprites["namebox"] = IconSprite.new(0, 252, @viewport)
    @sprites["namebox"].setBitmap(@path + "desc_box")
    @sprites["namebox"].src_rect.set(160, 0, 160, 40)
    @sprites["name"] = BitmapSprite.new(160, 28, @viewport)
    @sprites["name"].y = @sprites["namebox"].y + 8
    name_overlay = @sprites["name"].bitmap
    pbSetSystemFont(name_overlay)
    drawPokemonName(pokemon[idxReward], name_overlay)
    REWARD_LIST_SIZE.times do |i| 
      @sprites["reward_#{i}"] = AdventureRewardbox.new(pokemon[i], i, @viewport)
      @sprites["reward_#{i}"].selected = (i == idxReward)
    end
    @sprites["button"] = IconSprite.new(20, Graphics.height - 32, @viewport)
    @sprites["button"].setBitmap(@path + "buttons")
    @sprites["button"].src_rect.width = 32
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    textpos = [
      [_INTL("CAPTURED POKéMON"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Select a Pokémon to keep."), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
      [_INTL("Summary"), 56, Graphics.height - 20, :left, BASE_COLOR, SHADOW_COLOR, :outline]
    ]
    pbDrawTextPositions(overlay, textpos)
    loop do
      Input.update
      Graphics.update
      pbUpdate
      #-------------------------------------------------------------------------
      # UP/DOWN KEYS
      #-------------------------------------------------------------------------
      if Input.press?(Input::UP)
        next if pokemon.length <= rowSize
        pbPlayCursorSE
        idxReward -= rowSize
        idxReward += REWARD_LIST_SIZE if idxReward < 0
        idxReward = pokemon.length - 1 if idxReward >= pokemon.length
        REWARD_LIST_SIZE.times { |i| @sprites["reward_#{i}"].selected = (i == idxReward) }
        @sprites["pokemon"].setPokemonBitmap(pokemon[idxReward])
        drawPokemonName(pokemon[idxReward], name_overlay)
        pbPauseScene(0.2)
      elsif Input.press?(Input::DOWN)
        next if pokemon.length <= rowSize
        pbPlayCursorSE
        idxReward += rowSize
        idxReward -= REWARD_LIST_SIZE if idxReward >= REWARD_LIST_SIZE
        idxReward = 0 if idxReward >= pokemon.length
        REWARD_LIST_SIZE.times { |i| @sprites["reward_#{i}"].selected = (i == idxReward) }
        @sprites["pokemon"].setPokemonBitmap(pokemon[idxReward])
        drawPokemonName(pokemon[idxReward], name_overlay)
        pbPauseScene(0.2)
      #-------------------------------------------------------------------------
      # LEFT/RIGHT KEYS
      #-------------------------------------------------------------------------
      elsif Input.press?(Input::LEFT)
        next if pokemon.length <= 1
        pbPlayCursorSE
        idxReward -= 1
        idxReward = pokemon.length - 1 if idxReward < 0
        REWARD_LIST_SIZE.times { |i| @sprites["reward_#{i}"].selected = (i == idxReward) }
        @sprites["pokemon"].setPokemonBitmap(pokemon[idxReward])
        drawPokemonName(pokemon[idxReward], name_overlay)
        pbPauseScene(0.2)
      elsif Input.press?(Input::RIGHT)
        next if pokemon.length <= 1
        pbPlayCursorSE
        idxReward += 1
        idxReward = 0 if idxReward > pokemon.length - 1 
        REWARD_LIST_SIZE.times { |i| @sprites["reward_#{i}"].selected = (i == idxReward) }
        @sprites["pokemon"].setPokemonBitmap(pokemon[idxReward])
        drawPokemonName(pokemon[idxReward], name_overlay)
        pbPauseScene(0.2)
      #-------------------------------------------------------------------------
      # ACTION KEY
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        pbSummary(pokemon, idxReward)
      #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::BACK)
        break if pbConfirmMessage(_INTL("Exit without claiming any of the captured Pokémon?"))
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        pkmn = pokemon[idxReward]
        if pbConfirmMessage(_INTL("Would you like to claim {1} and take it with you?", pkmn.name)) { pbUpdate }
          textpos = [textpos.first]
          if pbBoxesFull?
            pbMessage(_INTL("There's no more room for Pokémon!") + "\1")
            pbMessage(_INTL("The Pokémon Boxes are full and can't accept any more!"))
            overlay.clear
            pbDrawTextPositions(overlay, textpos)
            @sprites["button"].visible = false
			REWARD_LIST_SIZE.times { |i| @sprites["reward_#{i}"].selected = false }
          else
            pokemon.delete_at(idxReward)
            should_show_pokedex = $player.has_pokedex && !$player.owned?(pkmn.species) && Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN
            $player.pokedex.register(pkmn)
            $player.pokedex.register_last_seen(pkmn)
            $player.pokedex.set_seen(pkmn.species)
            $player.pokedex.set_owned(pkmn.species)
			pkmn.record_first_moves
            if should_show_pokedex
              pbMessage(_INTL("{1}'s data was added to the Pokédex.", pkmn.speciesName)) { pbUpdate }
              pbFadeOutIn {
                scene = PokemonPokedexInfo_Scene.new
                screen = PokemonPokedexInfoScreen.new(scene)
                screen.pbDexEntry(pkmn.species)
                overlay.clear
                pbDrawTextPositions(overlay, textpos)
                @sprites["button"].visible = false
                REWARD_LIST_SIZE.times do |i| 
				  @sprites["reward_#{i}"].pokemon = pokemon[i]
				  @sprites["reward_#{i}"].selected = false
				end
              }
            else
              pkmn.play_cry
              pbPauseScene(0.5)
              overlay.clear
              pbDrawTextPositions(overlay, textpos)
              @sprites["button"].visible = false
              REWARD_LIST_SIZE.times do |i| 
				@sprites["reward_#{i}"].pokemon = pokemon[i]
			    @sprites["reward_#{i}"].selected = false
			  end
            end
            if $PokemonSystem.givenicknames == 0
              species_name = pkmn.speciesName
              if pbConfirmMessage(_INTL("Would you like to give a nickname to {1}?", species_name)) { pbUpdate }
                pkmn.name = pbEnterPokemonName(_INTL("{1}'s nickname?", species_name), 0, Pokemon::MAX_NAME_SIZE, "", pkmn)
              end
            end
            @sprites["pokemon"].visible = false
            @sprites["namebox"].visible = false
            name_overlay.clear
			overlay.clear
            stored_box = $PokemonStorage.pbStoreCaught(pkmn)
            box_name   = $PokemonStorage[stored_box].name
            pbMessage(_INTL("{1} has been sent to Box \"{2}\"!", pkmn.name, box_name)) { pbUpdate }
            pbMessage(_INTL("You returned any remaining captured Pokémon and your rental party.")) { pbUpdate }
          end
          break
        end
      end
    end
  end
end

def pbAdventureMenuReward
  return if !pbInRaidAdventure?
  return if pbRaidAdventureState.captures.empty?
  style = pbRaidAdventureState.style
  scene = AdventureMenuScene.new
  scene.pbStartScene(style)
  scene.pbRewardMenu
  scene.pbEndScene
end