#===============================================================================
# Draws item databoxes in Adventure menus.
#===============================================================================
class AdventureItembox < Sprite
  attr_reader :item, :index, :quantity
  
  #-----------------------------------------------------------------------------
  # Constants that set the various text colors.
  #-----------------------------------------------------------------------------
  DARK_BASE_COLOR    = Color.new(72, 72, 72)
  DARK_SHADOW_COLOR  = Color.new(184, 184, 184)
  LIGHT_BASE_COLOR   = Color.new(248, 248, 248)
  LIGHT_SHADOW_COLOR = Color.new(64, 64, 64)
  
  #-----------------------------------------------------------------------------
  # Sets the number of items per row in the grid.
  #-----------------------------------------------------------------------------
  GRID_BASE_X   = 180
  GRID_BASE_Y   = 74
  GRID_SQUARE   = 76
  GRID_ROW_SIZE = 4
  
  #-----------------------------------------------------------------------------
  # Sets up an item databox.
  #-----------------------------------------------------------------------------
  def initialize(item, index, quantity = 0, viewport = nil, xpos = GRID_BASE_X, ypos = GRID_BASE_Y, rowSize = GRID_ROW_SIZE)
    super(viewport)
    @path       = Settings::RAID_GRAPHICS_PATH + "Adventures/Menus/"
    @item       = GameData::Item.try_get(item)
	@quantity   = quantity
    @index      = index
    @selected   = false
    @contents   = Bitmap.new(GRID_SQUARE, GRID_SQUARE)
    self.bitmap = @contents
	offsetX, offsetY  = 0, 0
	(@index + 1).times do |i|
	  next if i == 0
	  if i % rowSize == 0
	    offsetY += GRID_SQUARE + 2
		offsetX = 0
	  else
	    offsetX += GRID_SQUARE + 2
	  end
	end
    self.x = xpos + offsetX
    self.y = ypos + offsetY
    self.z = 99999
    pbSetSmallFont(self.bitmap)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Changes the item assigned to an item databox and refreshes it.
  #-----------------------------------------------------------------------------
  def item=(value)
    @item = GameData::Item.try_get(value)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Changes the item and quantity assigned to an item databox and refreshes it.
  #-----------------------------------------------------------------------------
  def setItemValues(item, qty = 0)
    @item = GameData::Item.try_get(item)
	@quantity = qty
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Toggles whether an item databox is being selected in the menu.
  #-----------------------------------------------------------------------------
  def selected=(value)
    return if @selected == value
    @selected = value
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Refreshes and draws the entire item databox.
  #-----------------------------------------------------------------------------
  def refresh
    self.bitmap.clear
    return if !@item
    rectX = (@selected) ? GRID_SQUARE * 2 : GRID_SQUARE
    imagepos = [
      [@path + "item_slot", 0, 0, rectX, 0, GRID_SQUARE, GRID_SQUARE],
      [GameData::Item.icon_filename(@item), 14, 14]
    ]
    imagepos.push([@path + "item_slot", 0, 0, 0, 0, GRID_SQUARE, GRID_SQUARE]) if @selected
    pbDrawImagePositions(self.bitmap, imagepos)
	return if @quantity <= 0
	base = (@selected) ? LIGHT_BASE_COLOR : DARK_BASE_COLOR
    shadow = (@selected) ? LIGHT_SHADOW_COLOR : LIGHT_BASE_COLOR
	x, y = GRID_SQUARE - 6, GRID_SQUARE - 22
	pbDrawTextPositions(self.bitmap, [[sprintf("x%d", @quantity), x, y, :right, base, shadow, :outline]])
  end
end


class Trainer
  def has_pokemon_with_move_data?(hash)
    return false if hash[:type] && !GameData::Type.exists?(hash[:type])
	return false if hash[:category] && ![0, 1, 2].include?(hash[:category])
	return false if hash[:flag] && !hash[:flag].is_a?(String)
	pokemon_party.each do |pkmn|
	  pkmn.moves.each do |move|
	    next if hash[:array] && !hash[:array].include?(move.id)
		next if hash[:type] && move.type != hash[:type]
		next if hash[:category] && move.category != hash[:category]
		next if hash[:flag] && !move.flags.any? { |f| f[/^#{hash[:flag]}$/i] }
		next if move.power == 0 && !hash[:category]
		return true
	  end
	end
	return false
  end
end

class HandlerHashSymbol
  def keys
    return @hash.keys.clone
  end
end

#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  ITEM_LIST_SIZE = 8
  
  #-----------------------------------------------------------------------------
  # Utility for generating the item pool that will be randomly selected from.
  #-----------------------------------------------------------------------------
  def pbGenerateItemPool
    #---------------------------------------------------------------------------
	# Base item pool.
    item_pool = [
	  :SITRUSBERRY, :LEPPABERRY,        # Items that immediately restore HP/PP.
	  :LUMBERRY, :MENTALHERB,           # Items that restore status.
	  :EXPERTBELT, :SCOPELENS,          # Items that boost damage output.
	  :LIFEORB, :ASSAULTVEST,           # Items that boost stats with drawbacks.
	  :SHELLBELL, :LEFTOVERS,           # Items that gradually restore HP.
	  :FOCUSBAND, :FOCUSSASH,           # Items that prevent fainting.
	  :HEAVYDUTYBOOTS, :PROTECTIVEPADS, # Items that prevent effects from triggering.
	  :UTILITYUMBRELLA, :SAFETYGOGGLES, # Items that ignore weather.
	  :ABILITYSHIELD, :COVERTCLOAK      # Items that grant immunities.
	]
	#---------------------------------------------------------------------------
	# Adds stat-boosting berry to the item pool.
	stat_berries = {
	  :HP              => :STARFBERRY,
	  :ATTACK          => :LIECHIBERRY,
	  :DEFENSE         => :GANLONBERRY,
	  :SPECIAL_ATTACK  => :PETAYABERRY,
	  :SPECIAL_DEFENSE => :APICOTBERRY,
	  :SPEED           => :SALACBERRY
	}
	party_stats = []
	$player.party.each do |pkmn|
	  pkmn.ev.keys.reverse.each do |stat|
	    next if pkmn.ev[stat] < Pokemon::EV_STAT_LIMIT
		party_stats.push(stat)
		break
	  end
	end
	item_pool.push(stat_berries[party_stats.sample])
	#---------------------------------------------------------------------------
	# Adds type-boosting items to the item pool.
	type_boosters = {
	  :NORMAL   => [:SILKSCARF, :BLANKPLATE],
	  :FIRE     => [:CHARCOAL, :FLAMEPLATE],
	  :WATER    => [:MYSTICWATER, :SPLASHPLATE, :SEAINCENSE, :WAVEINCENSE],
	  :ELECTRIC => [:MAGNET, :ZAPPLATE],
	  :GRASS    => [:MIRACLESEED, :MEADOWPLATE, :ROSEINCENSE],
	  :ICE      => [:NEVERMELTICE, :ICICLEPLATE],
	  :FIGHTING => [:BLACKBELT, :FISTPLATE],
	  :POISON   => [:POISONBARB, :TOXICPLATE],
	  :GROUND   => [:SOFTSAND, :EARTHPLATE],
	  :FLYING   => [:SHARPBEAK, :SKYPLATE],
	  :PSYCHIC  => [:TWISTEDSPOON, :MINDPLATE, :ODDINCENSE],
	  :BUG      => [:SILVERPOWDER, :INSECTPLATE],
	  :ROCK     => [:HARDSTONE, :STONEPLATE, :ROCKINCENSE],
	  :GHOST    => [:SPELLTAG, :SPOOKYPLATE],
	  :DRAGON   => [:DRAGONFANG, :DRACOPLATE],
	  :DARK     => [:BLACKGLASSES, :DREADPLATE],
	  :STEEL    => [:METALCOAT, :IRONPLATE],
	  :FAIRY    => [:FAIRYFEATHER, :PIXIEPLATE]
	}
	type_boosters.keys.each do |type|
	  next if !$player.has_pokemon_with_move_data?({:type => type})
	  type_boosters[type].each do |item|
	    next if !GameData::Item.exists?(item)
		item_pool.push(item)
		break
	  end
	end
	#---------------------------------------------------------------------------
	# Adds specific items to the item pool based on the player's party.
	item_pool.push(:THICKCLUB)     if $player.has_species?(:MAROWAK)
	item_pool.push(:LIGHTBALL)     if $player.has_species?(:PIKACHU)
	item_pool.push(:BLACKSLUDGE)   if $player.has_pokemon_of_type?(:POISON)
	item_pool.push(:MUSCLEBAND)    if $player.has_pokemon_with_move_data?({:category => 0})
	item_pool.push(:WISEGLASSES)   if $player.has_pokemon_with_move_data?({:category => 1})
	item_pool.push(:THROATSPRAY)   if $player.has_pokemon_with_move_data?({:flag => "Sound"})
	item_pool.push(:PUNCHINGGLOVE) if $player.has_pokemon_with_move_data?({:flag => "Punching"})
	item_pool.push(:LIGHTCLAY)     if $player.has_pokemon_with_move_data?({:array => [:REFLECT, :LIGHTSCREEN, :AURORAVEIL]})
	item_pool.push(:EVIOLITE)      if $player.party.any? { |p| p.species_data.get_evolutions(true).length > 0 }
	#---------------------------------------------------------------------------
	# Adds various battle items to the item pool.
	item_pool.push(Battle::ItemEffects::AccuracyCalcFromUser.keys.sample)
	item_pool.push(Battle::ItemEffects::AccuracyCalcFromTarget.keys.sample)
	item_pool.push(*Battle::ItemEffects::PriorityBracketUse.keys)
	item_pool.push(*Battle::ItemEffects::OnMissingTarget.keys)
	item_pool.push(*Battle::ItemEffects::OnBeingHit.keys)
	item_pool.push(*Battle::ItemEffects::OnBeingHitPositiveBerry.keys)
	item_pool.push(*Battle::ItemEffects::OnEndOfUsingMoveStatRestore.keys)
	item_pool.push(*Battle::ItemEffects::TerrainStatBoost.keys)
	item_pool.push(*Battle::ItemEffects::EndOfRoundEffect.keys)
	if defined?(Battle::ItemEffects::StatLossImmunity)
	  item_pool.push(*Battle::ItemEffects::StatLossImmunity.keys)
	end
	if defined?(Battle::ItemEffects::OnOpposingStatGain)
	  item_pool.push(*Battle::ItemEffects::OnOpposingStatGain.keys)
	end
	#---------------------------------------------------------------------------
	# Validates the final item pool.
	item_pool.uniq!
	item_pool.length.times do |i|
	  item_pool[i] = nil if !GameData::Item.exists?(item_pool[i])
	end
	item_pool.compact!
	return item_pool.shuffle.sample(ITEM_LIST_SIZE)
  end
  
  #-----------------------------------------------------------------------------
  # Item Vendor menu.
  #-----------------------------------------------------------------------------
  def pbItemVendorMenu
    items = pbGenerateItemPool
    idxPkmn = 0
    idxItem = 0
    selectionMode = 0
	rowSize = AdventureItembox::GRID_ROW_SIZE
	party_select = (0...PARTY_SIZE).to_a
    PARTY_SIZE.times do |i|
      @sprites["party_#{i}"] = AdventurePartyDatabox.new($player.party[i], @style, i, @viewport)
      @sprites["party_#{i}"].selected = (i == idxPkmn)
    end
    ITEM_LIST_SIZE.times { |i| @sprites["item_#{i}"] = AdventureItembox.new(items[i], i, 0, @viewport) }
    @sprites["button"] = IconSprite.new(20, Graphics.height - 32, @viewport)
    @sprites["button"].setBitmap(@path + "buttons")
    @sprites["button"].src_rect.width = 32
    @sprites["descbox"] = IconSprite.new(166, 298, @viewport)
    @sprites["descbox"].setBitmap(@path + "desc_box")
	@sprites["descbox"].src_rect.y = 44
	@sprites["name"] = Window_AdvancedTextPokemon.newWithSize("", 170, 242, 334, 68, @viewport)
    @sprites["name"].windowskin = nil
    @sprites["name"].baseColor = BASE_COLOR
    @sprites["name"].shadowColor = SHADOW_COLOR
    itemName = @sprites["item_#{idxItem}"].item.name
    @sprites["window"] = Window_AdvancedTextPokemon.newWithSize("", 160, 282, 364, 112, @viewport)
    @sprites["window"].windowskin = nil
    @sprites["window"].lineHeight = 28
    @sprites["window"].baseColor = BASE_COLOR
    @sprites["window"].shadowColor = SHADOW_COLOR
    pbSetSmallFont(@sprites["window"].contents)
	pkmn = @sprites["party_#{idxPkmn}"].pokemon
    @sprites["window"].text = _INTL("{1} currently holds:\n{2}.", pkmn.name, ((pkmn.hasItem?) ? pkmn.item.name : "No item"))
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    textpos = [
      [_INTL("RENTAL PARTY"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Select a party member to equip."), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
      [_INTL("Summary"), 56, Graphics.height - 20, :left, BASE_COLOR, SHADOW_COLOR, :outline]
    ]
    pbDrawTextPositions(overlay, textpos)
    loop do
      Input.update
      Graphics.update
      pbUpdate
      #-------------------------------------------------------------------------
      # UP KEY
      #-------------------------------------------------------------------------
      # Cycles through party Pokemon or items, depending on selectionMode.
      if Input.repeat?(Input::UP)
        case selectionMode
        when 0 # Cycles through party.
		  next if party_select.length <= 1
		  pbPlayCursorSE
		  nextIdx = party_select.index(idxPkmn) - 1
          idxPkmn = party_select[nextIdx] || party_select.last
          PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
          pkmn = @sprites["party_#{idxPkmn}"].pokemon
		  @sprites["window"].text = _INTL("{1} currently holds:\n{2}.", pkmn.name, ((pkmn.hasItem?) ? pkmn.item.name : "No item"))
        when 1 # Cycles through items.
		  next if items.length <= rowSize
		  pbPlayCursorSE
          idxItem -= rowSize
		  idxItem += ITEM_LIST_SIZE if idxItem < 0
		  idxItem = items.length - 1 if idxItem >= items.length
          ITEM_LIST_SIZE.times { |i| @sprites["item_#{i}"].selected = (i == idxItem) }
		  itemName = @sprites["item_#{idxItem}"].item.name
          @sprites["name"].text = _INTL("<ac>{1}</ac>", itemName)
          @sprites["window"].text = @sprites["item_#{idxItem}"].item.description
        end
	  #-------------------------------------------------------------------------
      # DOWN KEY
      #-------------------------------------------------------------------------
      # Cycles through party Pokemon or items, depending on selectionMode.
      elsif Input.repeat?(Input::DOWN)
        case selectionMode
        when 0 # Cycles through party.
		  next if party_select.length <= 1
		  pbPlayCursorSE
          nextIdx = party_select.index(idxPkmn) + 1
          idxPkmn = party_select[nextIdx] || party_select.first
          PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
          pkmn = @sprites["party_#{idxPkmn}"].pokemon
		  @sprites["window"].text = _INTL("{1} currently holds:\n{2}.", pkmn.name, ((pkmn.hasItem?) ? pkmn.item.name : "No item"))
        when 1 # Cycles through items.
		  next if items.length <= rowSize
		  pbPlayCursorSE
          idxItem += rowSize
		  idxItem -= ITEM_LIST_SIZE if idxItem >= ITEM_LIST_SIZE
		  idxItem = 0 if idxItem >= items.length
          ITEM_LIST_SIZE.times { |i| @sprites["item_#{i}"].selected = (i == idxItem) }
		  itemName = @sprites["item_#{idxItem}"].item.name
          @sprites["name"].text = _INTL("<ac>{1}</ac>", itemName)
          @sprites["window"].text = @sprites["item_#{idxItem}"].item.description
        end
	  #-------------------------------------------------------------------------
      # LEFT/RIGHT KEYS
      #-------------------------------------------------------------------------
      # Navigates through item grid when selectionMode == 1.
	  elsif Input.repeat?(Input::LEFT)
	    next if selectionMode != 1
		pbPlayCursorSE
	    idxItem -= 1
        idxItem = items.length - 1 if idxItem < 0
        ITEM_LIST_SIZE.times { |i| @sprites["item_#{i}"].selected = (i == idxItem) }
		itemName = @sprites["item_#{idxItem}"].item.name
        @sprites["name"].text = _INTL("<ac>{1}</ac>", itemName)
        @sprites["window"].text = @sprites["item_#{idxItem}"].item.description
	  elsif Input.repeat?(Input::RIGHT)
	    next if selectionMode != 1
		pbPlayCursorSE
	    idxItem += 1
        idxItem = 0 if idxItem > items.length - 1 
        ITEM_LIST_SIZE.times { |i| @sprites["item_#{i}"].selected = (i == idxItem) }
		itemName = @sprites["item_#{idxItem}"].item.name
        @sprites["name"].text = _INTL("<ac>{1}</ac>", itemName)
        @sprites["window"].text = @sprites["item_#{idxItem}"].item.description
      #-------------------------------------------------------------------------
      # ACTION KEY
      #-------------------------------------------------------------------------
      # Opens the Summary for the party.
      elsif Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        pbSummary($player.party[0...PARTY_SIZE], idxPkmn)
      #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      # Exits the menu or returns to party selection, depending on selectionMode.
      elsif Input.trigger?(Input::BACK)
        case selectionMode
        when 0 # Exits the menu.
          break if pbConfirmMessage(_INTL("Exit and stop equipping the party?"))
        when 1 # Returns to party selection.
          pbPlayCancelSE
          overlay.clear
          textpos[1][0] = _INTL("Select a party member to equip.")
          pbDrawTextPositions(overlay, textpos)
		  @sprites["descbox"].y += 44
		  @sprites["descbox"].src_rect.y = 44
          ITEM_LIST_SIZE.times { |i| @sprites["item_#{i}"].selected = false }
          idxItem = 0
		  itemName = @sprites["item_#{idxItem}"].item.name
		  @sprites["name"].text = ""
		  @sprites["window"].text = _INTL("{1} currently holds:\n{2}.", pkmn.name, ((pkmn.hasItem?) ? pkmn.item.name : "No item"))
		  selectionMode = 0
        end
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Selects a party Pokemon or an item, depending on selectionMode.
      elsif Input.trigger?(Input::USE)
        case selectionMode
        when 0 # Selects a party Pokemon.
          pbPlayDecisionSE
          overlay.clear
          textpos[1][0] = _INTL("Select an item for {1}.", pkmn.name)
          pbDrawTextPositions(overlay, textpos)
	      @sprites["descbox"].y -= 44
		  @sprites["descbox"].src_rect.y = 0
          ITEM_LIST_SIZE.times { |i| @sprites["item_#{i}"].selected = (i == idxItem) }
		  itemName = @sprites["item_#{idxItem}"].item.name
		  @sprites["name"].text = _INTL("<ac>{1}</ac>", itemName)
          @sprites["window"].text = @sprites["item_#{idxItem}"].item.description
          selectionMode = 1
        when 1 # Selects an item.
		  pbPlayDecisionSE
          itemPortion = @sprites["item_#{idxItem}"].item.portion_name
          if pbConfirmMessage(_INTL("Give {1} the {2} to hold?", pkmn.name, itemPortion))
		    if pkmn.item_id == items[idxItem]
			  pbMessage("\\se[GUI sel buzzer]" + _INTL("{1} is already holding that item!", pkmn.name))
            elsif !pkmn.hasItem? || 
			   pbConfirmMessage(_INTL("{1} is already holding the {2}...\nWould you like to switch items?", pkmn.name, pkmn.item.portion_name))
			  pbMessage("\\se[]" + _INTL("{1} was given the {2} to hold.", pkmn.name, itemPortion) + "\\se[Pkmn move learnt]")
              pkmn.item = items[idxItem]
              items.delete(pkmn.item_id)
			  idxItem = 0
			  party_select.delete(idxPkmn)
			  idxPkmn = party_select.first
			  PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
              ITEM_LIST_SIZE.times do |i| 
                @sprites["item_#{i}"].item = items[i]
                @sprites["item_#{i}"].selected = false
              end
			  if party_select.length > 0
				pkmn = @sprites["party_#{idxPkmn}"].pokemon
				itemName = @sprites["item_#{idxItem}"].item.name
			    textpos[1][0] = _INTL("Select a party member to equip.")
				@sprites["descbox"].y += 44
				@sprites["descbox"].src_rect.y = 44
				@sprites["name"].text = ""
			    @sprites["window"].text = _INTL("{1} currently holds:\n{2}.", pkmn.name, ((pkmn.hasItem?) ? pkmn.item.name : "No item"))
				selectionMode = 0
			  else
			    textpos = [textpos.first]
				@sprites["name"].text = ""
				@sprites["window"].text = ""
				@sprites["button"].visible = false
				@sprites["descbox"].visible = false
			  end
              overlay.clear
			  pbDrawTextPositions(overlay, textpos)
            end
          end
        end  
      end
      break if party_select.empty?
    end
  end
end

def pbAdventureMenuVendor
  return if !pbInRaidAdventure?
  style = pbRaidAdventureState.style
  scene = AdventureMenuScene.new
  scene.pbStartScene(style)
  scene.pbItemVendorMenu
  scene.pbEndScene
end