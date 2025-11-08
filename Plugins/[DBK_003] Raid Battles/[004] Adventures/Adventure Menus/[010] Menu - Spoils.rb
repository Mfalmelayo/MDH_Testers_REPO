#===============================================================================
# Draws item databoxes in Adventure menus.
#===============================================================================
class AdventureSpoilsbox < AdventureItembox
  GRID_BASE_X   = 22
  GRID_BASE_Y   = 36
  GRID_ROW_SIZE = 6
  
  def initialize(item, index, quantity = 0, viewport = nil, xpos = GRID_BASE_X, ypos = GRID_BASE_Y, rowSize = GRID_ROW_SIZE)
    super(item, index, quantity, viewport, xpos, ypos, rowSize)
  end
end

#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  SPOILS_LIST_SIZE = 18
  
  #-----------------------------------------------------------------------------
  # Tresure Chest menu.
  #-----------------------------------------------------------------------------
  def pbSpoilsMenu(pokemon = nil)
	items = ((pokemon) ? pbGenerateRaidRewards(pokemon, @style) : pbRaidAdventureState.loot).to_a
	idxItem = 0
	maxSize = 0
	pageNum = 0
	rowSize = AdventureSpoilsbox::GRID_ROW_SIZE
	maxPage = (items.length / SPOILS_LIST_SIZE.to_f).ceil - 1
	SPOILS_LIST_SIZE.times do |i|
	  if items[i]
	    maxSize += 1
	    itm, qty = *items[i]
		pbRaidAdventureState.add_loot(itm, qty) if pokemon
	  else
	    itm, qty = nil, nil
	  end
	  @sprites["item_#{i}"] = AdventureSpoilsbox.new(itm, i, qty, @viewport)
	end
	maxIndex = maxSize - 1
	@sprites["item_#{idxItem}"].selected = true
    overlay = @sprites["overlay"].bitmap
    overlay.clear
	heading = (pokemon) ? _INTL("Treasure Chest") : _INTL("Adventure Spoils")
    pbDrawTextPositions(overlay, [[heading, Graphics.width / 2, 10, :center, BASE_COLOR, SHADOW_COLOR]])
	@sprites["bg"].setBitmap(sprintf("%s%s/bg_spoils", @path, @style))
	if pokemon.nil?
	  if pbRaidAdventureState.outcome == 3
	    pbMessage(_INTL("You were able to salvage some of the treasure you stashed away during your Adventure..."))
	  end
	else
	  pbSEPlay("GUI menu open")
	end
	if maxPage > 0
	  @sprites["arrowUp"] = IconSprite.new(4, 272, @viewport)
      @sprites["arrowUp"].setBitmap(@path + "page_arrows")
      @sprites["arrowUp"].src_rect.set(0, 0, 76, 32)
	  @sprites["arrowDown"] = IconSprite.new(Graphics.width - 80, 272, @viewport)
      @sprites["arrowDown"].setBitmap(@path + "page_arrows")
      @sprites["arrowDown"].src_rect.set(76, 32, 76, 32)
	end
	@sprites["name"] = Window_AdvancedTextPokemon.newWithSize("", 89, 260, 334, 68, @viewport)
    @sprites["name"].windowskin = nil
    @sprites["name"].baseColor = BASE_COLOR
    @sprites["name"].shadowColor = SHADOW_COLOR
	item = @sprites["item_#{idxItem}"].item
	itemName = (item.is_TR?) ? _INTL("{1} {2}", item.name, GameData::Move.get(item.move).name) : item.name
	@sprites["name"].text = _INTL("<ac>{1}</ac>", itemName)
	@sprites["window"] = Window_AdvancedTextPokemon.newWithSize("", -8, 300, Graphics.width + 16, 94, @viewport)
    @sprites["window"].windowskin = nil
	@sprites["window"].lineHeight = 28
    @sprites["window"].baseColor = BASE_COLOR
    @sprites["window"].shadowColor = SHADOW_COLOR
	pbSetSmallFont(@sprites["window"].contents)
	@sprites["window"].text = @sprites["item_#{idxItem}"].item.description
	needRefresh = false
	needFullRefresh = false
	loop do
      Input.update
      Graphics.update
      pbUpdate
	  #-------------------------------------------------------------------------
      # UP/DOWN KEYS
      #-------------------------------------------------------------------------
      if Input.repeat?(Input::UP)
		next if pageNum == 0 && maxIndex < rowSize
        idxItem -= rowSize
		if idxItem < 0
		  if pageNum > 0
		    pageNum -= 1
			needFullRefresh = true
		  end
		  idxItem += SPOILS_LIST_SIZE
		end
        needRefresh = true
      elsif Input.repeat?(Input::DOWN)
	    next if pageNum == maxPage && maxIndex < rowSize
        idxItem += rowSize
		if idxItem > maxIndex
		  if pageNum < maxPage
		    pageNum += 1
		    needFullRefresh = true
		  end
		  idxItem -= SPOILS_LIST_SIZE
		end
        needRefresh = true
	  #-------------------------------------------------------------------------
      # LEFT/RIGHT KEYS
      #-------------------------------------------------------------------------
	  elsif Input.repeat?(Input::LEFT)
	    next if pageNum == 0 && idxItem == 0
	    idxItem -= 1
		if idxItem < 0
		  if pageNum > 0
		    pageNum -= 1
		    needFullRefresh = true
		  end
		  idxItem = SPOILS_LIST_SIZE - 1
		end
		needRefresh = true
	  elsif Input.repeat?(Input::RIGHT)
	    next if pageNum == maxPage && idxItem == maxIndex
	    idxItem += 1
		if idxItem > maxIndex
		  if pageNum < maxPage
		    pageNum += 1
		    needFullRefresh = true
		  end
		  idxItem = 0
		end
		needRefresh = true
	  #-------------------------------------------------------------------------
      # JUMPUP/JUMPDOWN KEYS
      #-------------------------------------------------------------------------
	  elsif Input.trigger?(Input::JUMPUP)
	    next if pageNum == 0
	    idxItem = 0
		pageNum -= 1
        needFullRefresh = true
	  elsif Input.trigger?(Input::JUMPDOWN)
	    next if pageNum == maxPage
	    idxItem = 0
		pageNum += 1
        needFullRefresh = true
	  #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
	    if pokemon.nil?
	      case pbRaidAdventureState.outcome
		  when 1 then pbMessage(_INTL("All treasure acquired during your Adventure was added to your bag."))
		  when 3 then pbMessage(_INTL("All remaining treasure was added to your bag."))
		  end
		else
		  pbMessage(_INTL("You stashed away the contents of this chest for later."))
	    end
	    pbSEPlay("GUI menu close")
		pbDisposeSpriteHash(@sprites)
		@viewport.dispose
        break
	  end
	  #-------------------------------------------------------------------------
      # Refreshes the scene.
      #-------------------------------------------------------------------------
	  if needFullRefresh
	    maxIndex = [items.length - (maxSize * pageNum), maxSize].min - 1
	    pbSEPlay("GUI party switch")
		@sprites["arrowUp"].src_rect.y = (pageNum == 0) ? 0 : 32
		@sprites["arrowDown"].src_rect.y = (pageNum == maxPage) ? 0 : 32
		SPOILS_LIST_SIZE.times do |i|
		  j = SPOILS_LIST_SIZE * pageNum + i
		  if items[j]
		    @sprites["item_#{i}"].setItemValues(*items[j])
	      else
			@sprites["item_#{i}"].setItemValues(nil, 0)
	      end
		end
		needFullRefresh = false
		needRefresh = true
	  end
	  if needRefresh
	    pbPlayCursorSE
		idxItem = 0 if idxItem < 0
		idxItem = maxIndex if idxItem >= maxIndex
	    maxSize.times { |i| @sprites["item_#{i}"].selected = (i == idxItem) }
		item = @sprites["item_#{idxItem}"].item
		next if !item
	    itemName = (item.is_machine?) ? _INTL("{1} {2}", item.name, GameData::Move.get(item.move).name) : item.name
		@sprites["name"].text = _INTL("<ac>{1}</ac>", itemName)
		@sprites["window"].text = @sprites["item_#{idxItem}"].item.description
		needRefresh = false
	  end
	end
  end
end

def pbAdventureMenuSpoils(pokemon = nil)
  return if !pbInRaidAdventure?
  return if pokemon.nil? && pbRaidAdventureState.loot.empty?
  style = pbRaidAdventureState.style
  scene = AdventureMenuScene.new
  scene.pbStartScene(style)
  scene.pbSpoilsMenu(pokemon)
end