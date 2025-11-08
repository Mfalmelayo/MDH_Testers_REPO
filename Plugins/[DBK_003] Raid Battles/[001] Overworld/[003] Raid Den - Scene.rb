#===============================================================================
# Raid Den scene.
#===============================================================================
class RaidScene
  BASE   = Color.new(248, 248, 248)
  SHADOW = Color.new(0, 0, 0)
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
   
  def pbEndScene
    pbUpdate
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    $game_temp.clear_battle_rules
	$game_temp.transition_animation_data = nil
  end
  
  #-----------------------------------------------------------------------------
  # Saves the game and sets a new Raid Pokemon for this event.
  #-----------------------------------------------------------------------------
  def pbSavingPrompt(pkmn, rules)
	save_game = false
    @interp = pbMapInterpreter
	this_event = @interp.get_self
    raid_pkmn = @interp.getVariable
	den_name = GameData::RaidType.get(rules[:style]).den_name
    # Holding CTRL in Debug mode skips the saving prompt.
    if $DEBUG && Input.press?(Input::CTRL)
      @interp.setVariable(nil)
	  this_event.turn_up
      pbMessage(_INTL("You peered into the {1} before you...", den_name))
      return true
    end
    if !raid_pkmn
      if pbConfirmMessage(_INTL("You must save the game before entering a new raid. Is this ok?"))
        save_game = true
        if SaveData.exists? && $game_temp.begun_new_game
          pbMessage(_INTL("WARNING!"))
          pbMessage(_INTL("There is a different game file that is already saved."))
          pbMessage(_INTL("If you save now, the other file's adventure, including items and Pokémon, will be entirely lost."))
          if !pbConfirmMessageSerious(_INTL("Are you sure you want to save now and overwrite the other save file?"))
            pbSEPlay("GUI save choice")
            save_game = false
          end
        end
      else
        pbSEPlay("GUI save choice")
      end
      if save_game
        $game_temp.begun_new_game = false
        pbSEPlay("GUI save choice")
		@interp.setVariable([pkmn, rules])
        if Game.save
          pbMessage(_INTL("\\se[]{1} saved the game.\\me[GUI save game]\\wtnp[30]", $player.name))
        else
          pbMessage(_INTL("\\se[]Save failed.\\wtnp[30]"))
          @interp.setVariable(nil)
		  this_event.turn_up
          save_game = false
        end
      end
      return save_game
    else
      pbMessage(_INTL("You peered into the {1} before you...", den_name))
      return true
    end
  end
  
  #-----------------------------------------------------------------------------
  # Initializes the raid den.
  #-----------------------------------------------------------------------------
  def pbStartScene(pkmn, rules)
    @sprites    = {}
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    $PokemonGlobal.nextBattleBGM = nil
    return false if !pbSavingPrompt(pkmn, rules)
	@pkmn = (@interp.getVariable.is_a?(Array)) ? @interp.getVariable[0] : pkmn
	@pkmn.heal
	rules[:pokemon] = @pkmn
    @rules = rules
    @path = Settings::RAID_GRAPHICS_PATH + "Raid Dens/"
    #---------------------------------------------------------------------------
    # General sprites
    #---------------------------------------------------------------------------
    @sprites["raidentry"] = IconSprite.new(0, 0)
    @sprites["raidentry"].setBitmap(@path + "#{@rules[:style]}/bg")
    @sprites["raidentry"].z = @viewport.z - 1
    @sprites["pokeicon"] = PokemonIconSprite.new(@pkmn, @viewport)
    @sprites["pokeicon"].x = 95
    @sprites["pokeicon"].y = 140
    @sprites["pokeicon"].zoom_x = 1.5
    @sprites["pokeicon"].zoom_y = 1.5
    @sprites["pokeicon"].color.alpha = 255
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @overlay = @sprites["overlay"].bitmap
    pbSetSmallFont(@overlay)
	@sprites["cursor"] = IconSprite.new(290, 132)
    @sprites["cursor"].setBitmap(@path + "cursor")
    @sprites["cursor"].z = @viewport.z + 1
    imagePos = [[@path + "bg_entry", 0, 0]]
    @rules[:rank].times { |i| imagePos.push([@path + "icon_star", 24 + i * 38, 68]) }
    #---------------------------------------------------------------------------
    # Type icons
    #---------------------------------------------------------------------------
    typepath = "Graphics/UI/Pokedex/icon_types"
	@pkmn.types.each_with_index do |type, i|
      type_number = GameData::Type.get(type).icon_position
      type_x = (i == 0) ? 24 : 124
      imagePos.push([typepath, type_x, 104, 0, type_number * 32, 96, 32])
    end
    #---------------------------------------------------------------------------
    # Additional icons
    #---------------------------------------------------------------------------
    xpos = 428
	case @rules[:style]
	when :Ultra  # Z-Crystal icon
	  if @pkmn.hasItem? && GameData::Item.get(@pkmn.item_id).is_zcrystal?
	    imagePos.push(["Graphics/Items/#{@pkmn.item_id}", xpos, 72])
        xpos -= 54
	  end
	when :Max    # G-Max icon
	  if @pkmn.gmax?
	    imagePos.push([Settings::DYNAMAX_GRAPHICS_PATH + "gmax_factor", xpos + 20, 84])
        xpos -= 34
	  end
	when :Tera   # Tera type icon
	  type_number = GameData::Type.get(@pkmn.tera_type).icon_position
      imagePos.push([Settings::TERASTAL_GRAPHICS_PATH + "tera_types", xpos + 20, 80, 0, type_number * 32, 32, 32])
	  xpos -= 34
	end
    if @rules[:loot] # Bonus loot icon
      imagePos.push([@path + "icon_loot", xpos, 72])
	  xpos -= 52
	end
	imagePos.push([@path + "icon_online", xpos, 72]) if @rules[:online]
    #---------------------------------------------------------------------------
    # Battlefield conditions
    #---------------------------------------------------------------------------
    battleRules = $game_temp.battle_rules
	if battleRules["defaultWeather"] && battleRules["defaultWeather"] != :None
      @weather = battleRules["defaultWeather"]
    else
      field = GameData::Weather.get($game_screen.weather_type).category
      case field
      when :Storm then @weather = :Rain
      else             @weather = field
      end
    end
    if battleRules["defaultTerrain"] && battleRules["defaultTerrain"] != :None
      @terrain = battleRules["defaultTerrain"]
    else
      @terrain = :None
      if Settings::OVERWORLD_WEATHER_SETS_BATTLE_TERRAIN
        field = $game_screen.weather_type
        case field
        when :Storm then @terrain = :Electric
        when :Fog   then @terrain = :Misty
        end
      end
    end
	baseEnviron = GameData::RaidType.get(@rules[:style]).battle_environ
    battleRules["environment"] = baseEnviron if battleRules["environment"].nil?
    @environ = battleRules["environment"] || pbGetEnvironment
    conds = [@weather, @terrain, @environ]
    #---------------------------------------------------------------------------
    # Battlefield icons
    #---------------------------------------------------------------------------
    if conds != [:None, :None, baseEnviron]
      imagePos.push([@path + "field", 340, 2])
      conds.each_with_index do |cond, i|
        case i
        when 0 then type = "weather_"
        when 1 then type = "terrain_"
        when 2 then type = "environ_"
        end
        imagePos.push([@path + "Field Icons/" + type + cond.to_s, 387 + (44 * i), 16])
      end
    end
	#---------------------------------------------------------------------------
    # Party icons
    #---------------------------------------------------------------------------
	pbSetRaidProperties(@rules)
    @raid_party = []
	if @rules[:partner]
	  party_x = 324
	  offset = 102
	  [$player, $PokemonGlobal.partner].each_with_index do |tr, i|
	    trainer_type = (i == 0) ? tr.trainer_type : tr[0]
		trainer_sprite = _INTL("Graphics/Characters/trainer_#{trainer_type}")
		imagePos.push([trainer_sprite, party_x - 36 + (offset * i), 252, 0, 0, 32, 48],
		              [@path + "#{@rules[:style]}/icon_party", party_x + (offset * i), 248])
		pkmn = (i == 0) ? tr.party.first : tr[3].first
		@raid_party.push(pkmn) if i == 0
		@sprites["partyicon_#{i}"] = PokemonIconSprite.new(pkmn, @viewport)
        @sprites["partyicon_#{i}"].setOffset(PictureOrigin::CENTER)
        @sprites["partyicon_#{i}"].x = party_x + (offset * i) + 26
        @sprites["partyicon_#{i}"].y = 276
	  end
	else
	  party_x = 363 - (18 * @rules[:size])
      @rules[:size].times { |i| imagePos.push([@path + "#{@rules[:style]}/icon_party", party_x + (56 * i), 248]) }
	  $player.able_party.each_with_index do |pkmn, i|
        break if i >= @rules[:size]
        @raid_party.push(pkmn)
        @sprites["partyicon_#{i}"] = PokemonIconSprite.new(pkmn, @viewport)
        @sprites["partyicon_#{i}"].setOffset(PictureOrigin::CENTER)
        @sprites["partyicon_#{i}"].x = party_x + (56 * i) + 26
        @sprites["partyicon_#{i}"].y = 276
      end
	end
    #---------------------------------------------------------------------------
    # Text displays
    #---------------------------------------------------------------------------
    raid_name = GameData::RaidType.get(@rules[:style]).den_name
    party_config = (@rules[:size] > 1) ? _INTL("Change Party") : _INTL("Change Pokémon")
    textPos = [
      [raid_name.upcase,     97,  24, :center, BASE, SHADOW, :outline],
      [_INTL("Begin Raid"), 391, 140, :center, BASE, SHADOW, :outline],
      [_INTL("Leave Raid"), 391, 174, :center, BASE, SHADOW, :outline],
      [party_config,        391, 208, :center, BASE, SHADOW, :outline]
    ]
	showTurns = @rules[:turn_count] && @rules[:turn_count] > 0
	showKOs = @rules[:ko_count] && @rules[:ko_count] > 0
	ko_text = (@rules[:ko_count] == 1) ? "knock out" : "knock outs"
	if showTurns
	  if showKOs
	    battleText = "Battle ends in #{@rules[:turn_count]} turns or after #{@rules[:ko_count]} #{ko_text}."
	  else
	    battleText = "Battle ends after #{@rules[:turn_count]} turns."
	  end
	elsif showKOs
	  battleText = "Battle ends after #{@rules[:ko_count]} #{ko_text}."
	else
	  battleText = "Defeat the Pokémon dwelling inside!"
	end
    #---------------------------------------------------------------------------
    pbDrawImagePositions(@overlay, imagePos)
    pbDrawTextPositions(@overlay, textPos)
	drawTextEx(@overlay, 40, 250, 226, 2, _INTL(battleText), BASE, SHADOW)
    pbSEPlay("GUI trainer card open")
    return pbRaidEntry
  end
  
  #-----------------------------------------------------------------------------
  # Command options while the den entry screen is displayed.
  #-----------------------------------------------------------------------------
  def pbRaidEntry
    outcome = 0
    ruleset = PokemonRuleSet.new
    ruleset.setNumber(@rules[:size])
    ruleset.addPokemonRule(AblePokemonRestriction.new)
    index = 0
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::UP)
        index -= 1
        index = 2 if index < 0
        pbPlayCursorSE
        @sprites["cursor"].y = 132 + 34 * index
      elsif Input.trigger?(Input::DOWN)
        index += 1
        index = 0 if index > 2
        pbPlayCursorSE
        @sprites["cursor"].y = 132 + 34 * index
      elsif Input.trigger?(Input::BACK)
	    @sprites["cursor"].visible = false
        if pbConfirmMessage(_INTL("Would you like to leave the raid?"))
          pbSEPlay("GUI menu close")
          break
        end
		@sprites["cursor"].visible = true
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        case index
        when 0 # Begin Raid
          @sprites["cursor"].visible = false
		  party_display = (@rules[:size] > 1) ? "party" : "Pokémon"
          if pbConfirmMessage(_INTL("Enter the raid with the displayed {1}?", party_display))
			@raid_party.each { |pkmn| pkmn.heal }
			setBattleRule("tempParty", @raid_party)
            pbFadeOutIn {
              pbSEPlay("Door enter")
              pbDisposeSpriteHash(@sprites)
              @viewport.dispose
              outcome = WildBattle.start_core(@pkmn)
              pbWait(0.5)
              pbSEPlay("Door exit")
            }
			@pkmn.heal
            if [1, 4].include?(outcome)
              $stats.raid_dens_cleared += 1
			  $stats.online_raid_dens_cleared += 1 if @rules[:online]
              @interp.setVariable(0)
            end
            pbRaidRewardsScreen(outcome)
            break
          end
		  @sprites["cursor"].visible = true
        when 1 # Leave Raid
		  @sprites["cursor"].visible = false
          if pbConfirmMessage(_INTL("Would you like to leave the raid?"))
            pbSEPlay("GUI menu close")
            break
          end
		  @sprites["cursor"].visible = true
        when 2 # Change Party
          @sprites["cursor"].visible = false
		  pbFadeOutIn {
            scene = PokemonParty_Scene.new
            screen = PokemonPartyScreen.new(scene, $player.party)
            ret = screen.pbPokemonMultipleEntryScreenEx(ruleset)
            @raid_party = ret if ret
			@sprites["cursor"].visible = true
          }
          @raid_party.each_with_index { |pkmn, i| @sprites["partyicon_#{i}"].pokemon = pkmn }
        end
      end
    end
    return outcome
  end
  
  #-----------------------------------------------------------------------------
  # Initializes the raid rewards screen.
  #-----------------------------------------------------------------------------
  def pbRaidRewardsScreen(outcome)
    @sprites    = {}
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites["rewardscreen"] = IconSprite.new(0, 0)
    @sprites["rewardscreen"].setBitmap(@path + "#{@rules[:style]}/bg")
	@sprites["rewardscreen"].z = @viewport.z - 1
    @sprites["pokemon"] = PokemonSprite.new(@viewport)
    @sprites["pokemon"].setOffset(PictureOrigin::CENTER)
    @sprites["pokemon"].x = 120
    @sprites["pokemon"].y = 190
    @sprites["pokemon"].setPokemonBitmap(@pkmn)
    @sprites["pokemon"].clear_dynamax_pattern if @pkmn.dynamax?
	if PluginManager.installed?("[DBK] Animated Pokémon System")
      @sprites["pokemon"].pbSetDisplay([120, 190, 222, 182])
	end
	@sprites["itemwindow"] = Window_CommandPokemon.newWithSize([], 236, 94, 258, 196, @viewport)
    @sprites["itemwindow"].index = 0
    @sprites["itemwindow"].baseColor   = BASE
    @sprites["itemwindow"].shadowColor = SHADOW
    @sprites["itemwindow"].windowskin  = nil
	@sprites["itemwindow"].setWhiteArrow
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @overlay = @sprites["overlay"].bitmap
    pbSetSmallFont(@overlay)
	@sprites["itembox"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
	@sprites["itemicon"] = ItemIconSprite.new(48, 338, nil, @viewport)
	@sprites["itemicon"].visible = false
	@sprites["itemtext"] = Window_UnformattedTextPokemon.newWithSize(
      "", 72, 272, Graphics.width - 72 - 24, 128, @viewport
    )
	@sprites["itemtext"].baseColor   = BASE
    @sprites["itemtext"].shadowColor = SHADOW
    @sprites["itemtext"].visible     = false
    @sprites["itemtext"].windowskin  = nil
    textPos = []
    imagePos = [
	  [@path + "bg_rewards", 0, 0],
	  [@path + "buttons", 380, 284, 0, 28, 92, 28]
	]
	@rules[:rank].times { |i| imagePos.push([@path + "icon_star", Graphics.width - 58 - i * 38, 68]) }
	#---------------------------------------------------------------------------
    # Additional icons
    #---------------------------------------------------------------------------
	if @pkmn.shiny?
	  imagePos.push(["Graphics/UI/shiny", 120, 76])
	end
	if @rules[:style] == :Max && @pkmn.gmax_factor?
      imagePos.push([Settings::DYNAMAX_GRAPHICS_PATH + "gmax_factor", 152, 72])
    end
	if @rules[:style] == :Tera
	  type = GameData::Type.get(@pkmn.tera_type).icon_position
      imagePos.push([Settings::TERASTAL_GRAPHICS_PATH + "tera_types", 152, 70, 0, type * 32, 32, 32])
	end
    #---------------------------------------------------------------------------
    # Rewards display
    #---------------------------------------------------------------------------
    if [1, 4].include?(outcome)
	  items = []
	  rewards = pbGenerateRaidRewards(@pkmn, @rules[:style], @rules[:rank], @rules[:loot], @weather, @terrain, @environ).to_a
      rewards.each do |reward|
        item = GameData::Item.get(reward[0])
        name = (item.is_machine?) ? _INTL("{1} {2}", item.name, GameData::Move.get(item.move).name) : item.name
        items.push(_INTL("{1}  x{2}", name, reward[1]))
        $bag.add(item.id, reward[1])
      end
	  if !items.empty?
        @sprites["itemwindow"].commands = items
	    @sprites["itemicon"].item = rewards[0][0]
	    @sprites["itemtext"].text = GameData::Item.get(rewards[0][0]).description
		imagePos.push([@path + "buttons", 258, 284, 0, 0, 92, 28])
		textPos.push([_INTL("View"), 316, 290, :center, BASE, SHADOW, :outline])
	  end
    end
	pbDrawImagePositions(@overlay, imagePos)
    #---------------------------------------------------------------------------
    # Other text displays
    #---------------------------------------------------------------------------
    level   = _INTL("Lv. ???")
    ability = _INTL("Abil: ???")
    case outcome
    when 1
      result  = _INTL("You defeated {1}!", @pkmn.name)
    when 4
      result  = _INTL("You caught {1}!", @pkmn.name)
	  level   = _INTL("Lv. {1}", @pkmn.level)
      ability = _INTL("Abil: {1}", GameData::Ability.get(@pkmn.ability_id).name)
      if @pkmn.male?
        textPos.push(["♂", 96, 78, :left, Color.new(48, 96, 216), SHADOW, :outline])
      elsif @pkmn.female?
        textPos.push(["♀", 96, 78, :left, Color.new(248, 88, 40), SHADOW, :outline])
      end
    else
      result = _INTL("You lost to {1}!", @pkmn.name)
      textPos.push([_INTL("No Rewards Earned."), 367, 180, :center, BASE, SHADOW])
    end
    textPos.push(
      [result,        377,  24, :center, BASE, SHADOW, :outline],
      [level,          32,  78, :left,   BASE, SHADOW, :outline],
      [ability,        32, 290, :left,   BASE, SHADOW, :outline],
	  [_INTL("Next"), 438, 290, :center, BASE, SHADOW, :outline]
    )
    pbDrawTextPositions(@overlay, textPos)
    #---------------------------------------------------------------------------
    # Screen controls
    #---------------------------------------------------------------------------
	itembg = [[@path + "itembox", 0, 282]]
	loop do
      Graphics.update
      Input.update
      pbUpdate
	  if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN) ||
	     Input.repeat?(Input::JUMPUP) || Input.repeat?(Input::JUMPDOWN)
		next if @sprites["itemwindow"].commands.empty?
	    itemidx = @sprites["itemwindow"].index
		itemdesc = GameData::Item.get(rewards[itemidx][0]).description
		@sprites["itemtext"].text = itemdesc
		@sprites["itemicon"].item = rewards[itemidx][0]
	  elsif Input.trigger?(Input::USE)
	    next if @sprites["itemwindow"].commands.empty?
		pbSEPlay("GUI party switch")
	    if @sprites["itemtext"].visible
		  @sprites["itemtext"].visible = false
		  @sprites["itemicon"].visible = false
		  @sprites["itembox"].bitmap.clear
		else
		  @sprites["itemtext"].visible = true
		  @sprites["itemicon"].visible = true
		  pbDrawImagePositions(@sprites["itembox"].bitmap, itembg)
		end
      elsif Input.trigger?(Input::BACK)
        pbSEPlay("GUI menu close")
        Input.update
        break
      end
    end
  end
end

#===============================================================================
# Utility for drawing the selection arrow on the raid rewards screen.
#===============================================================================
class Window_DrawableCommand < SpriteWindow_SelectableEx
  def setWhiteArrow
    @selarrow.dispose
    @selarrow = AnimatedBitmap.new("Graphics/UI/sel_arrow_white")
    RPG::Cache.retain("Graphics/UI/sel_arrow_white")
  end
end

#===============================================================================
# Item game data for acquiring type-based raid rewards.
#===============================================================================
module GameData
  class Item
    #---------------------------------------------------------------------------
    # Utility for getting TR's based on the inputted types.
    #---------------------------------------------------------------------------
    def self.get_TR_from_type(types)
      trList = []
      self.each do |item|
        next if !item.is_TR?
        move_type = GameData::Move.get(item.move).type
        next if !types.include?(move_type)
        trList.push(item.id)
      end
      return trList.sample
    end
	
	#---------------------------------------------------------------------------
    # Utility for getting a Tera Shard based on the inputted type.
    #---------------------------------------------------------------------------
	def self.get_shard_from_type(type)
	  self.each do |item|
	    next if !item.is_tera_shard?
		next if item.tera_shard_type != type
		return item.id
	  end
	  return nil
	end
  end
end

#===============================================================================
# Calls the raid den scene.
#===============================================================================
class RaidScreen
  def initialize(scene)
    @scene = scene
  end
  
  def pbStartScreen(pkmn, rules)
    outcome = @scene.pbStartScene(pkmn, rules)
    @scene.pbEndScene
	return outcome
  end
end

def pbRaidDenEntry(pkmn, rules)
  scene  = RaidScene.new
  screen = RaidScreen.new(scene)
  return screen.pbStartScreen(pkmn, rules)
end