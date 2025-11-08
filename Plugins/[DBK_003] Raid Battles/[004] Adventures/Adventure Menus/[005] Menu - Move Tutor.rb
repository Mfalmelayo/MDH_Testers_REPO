#===============================================================================
# Draws move databoxes in Adventure menus.
#===============================================================================
class AdventureMovebox < Sprite
  attr_reader :move, :index
  
  #-----------------------------------------------------------------------------
  # Constants that set the various text colors.
  #-----------------------------------------------------------------------------
  DARK_BASE_COLOR    = Color.new(72, 72, 72)
  DARK_SHADOW_COLOR  = Color.new(184, 184, 184)
  LIGHT_BASE_COLOR   = Color.new(248, 248, 248)
  LIGHT_SHADOW_COLOR = Color.new(64, 64, 64)
  
  SLOT_BASE_X      = 166
  SLOT_BASE_Y      = 38
  SLOT_BASE_WIDTH  = 342
  SLOT_BASE_HEIGHT = 90
  
  #-----------------------------------------------------------------------------
  # Sets up a move databox.
  #-----------------------------------------------------------------------------
  def initialize(move, index, viewport = nil)
    super(viewport)
    @path       = Settings::RAID_GRAPHICS_PATH + "Adventures/Menus/"
    @move       = GameData::Move.try_get(move)
    @index      = index
    @selected   = false
    @contents   = Bitmap.new(SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT)
    self.bitmap = @contents
    self.x      = SLOT_BASE_X
    self.y      = @index * (SLOT_BASE_HEIGHT - 6) + SLOT_BASE_Y
    self.z      = 99999
    pbSetSmallFont(self.bitmap)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Changes the move assigned to a move databox and refreshes it.
  #-----------------------------------------------------------------------------
  def move=(value)
    @move = GameData::Move.try_get(value)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Determines how much a move databox is shifted while highlighted.
  #-----------------------------------------------------------------------------
  SELECTION_OFFSET = 4
  
  #-----------------------------------------------------------------------------
  # Toggles whether a move databox is being selected in the menu.
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
  
  #-----------------------------------------------------------------------------
  # Refreshes and draws the entire move databox.
  #-----------------------------------------------------------------------------
  def refresh
    self.bitmap.clear
    return if !@move
    #---------------------------------------------------------------------------
    # Draws all images
    box_y = (@selected) ? SLOT_BASE_HEIGHT * 2 : SLOT_BASE_HEIGHT
    icon_type = GameData::Type.get(@move.type).icon_position
    imagepos = [
      [@path + "move_slot", 0, 0, 0, box_y, SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT],
      [_INTL("Graphics/UI/types"), 16, 48, 0, icon_type * 28, 64, 28],
      [_INTL("Graphics/UI/category"), 82, 48, 0, @move.category * 28, 64, 28]
    ]
    imagepos.push([@path + "move_slot", 0, 0, 0, 0, SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT]) if @selected
    pbDrawImagePositions(self.bitmap, imagepos)
    #---------------------------------------------------------------------------
    # Draws all text.
    base   = (@selected) ? LIGHT_BASE_COLOR   : DARK_BASE_COLOR
    shadow = (@selected) ? LIGHT_SHADOW_COLOR : DARK_SHADOW_COLOR
    outline = (@selected) ? :outline : nil
    accuracy = (@move.accuracy == 0) ? "---" : @move.accuracy
    case @move.power
    when 0 then power = "---"
    when 1 then power = "???"
    else        power = @move.power
    end
    textpos = [
      [@move.name, 22, 22, :left, base, shadow, outline],
      [_INTL("PP: {1}", @move.total_pp), 264, 22, :left, DARK_BASE_COLOR, DARK_SHADOW_COLOR],
      [_INTL("Power: {1}", power), 154, 54, :left, base, shadow],
      [_INTL("Acc: {1}", accuracy), 254, 54, :left, base, shadow]
    ]
    pbDrawTextPositions(self.bitmap, textpos)
  end
end

#===============================================================================
# Move related Adventure menus.
#===============================================================================
class AdventureMenuScene
  MOVE_LIST_SIZE = 3
  
  #-----------------------------------------------------------------------------
  # Utility for generating 3 random raid moves for a Pokemon.
  #-----------------------------------------------------------------------------
  def pbGenerateMoveList(pkmn)
    move_hash = pkmn.getRaidMoves(@style, true).clone
    categories = [:primary, :secondary, :other, :status]
	categories.delete(:secondary) if move_hash[:primary] == move_hash[:secondary]
    move_hash.keys.each do |key|
      pkmn.moves.each { |m| move_hash[key].delete(m.id) }
      move_hash.delete(key) if move_hash[key].empty?
    end
    raid_moves = []
	move_hash.each_key do |key|
	  if move_hash.keys.length < Pokemon::MAX_MOVES
	    moves = move_hash[key].sample(2)
        raid_moves.push(*moves)
	  else
	    move = move_hash[key].sample
        raid_moves.push(move)
	  end
    end
    return raid_moves.sample(MOVE_LIST_SIZE)
  end
  
  #-----------------------------------------------------------------------------
  # Move Tutor menu.
  #-----------------------------------------------------------------------------
  def pbMoveTutorMenu
    moves = []
    idxPkmn = 0
    idxMove = 0
    selectionMode = 0
	party_select = (0...PARTY_SIZE).to_a
    PARTY_SIZE.times do |i|
      pkmn = $player.party[i]
      new_moves = pbGenerateMoveList(pkmn)
      moves.push(new_moves)
      @sprites["party_#{i}"] = AdventurePartyDatabox.new(pkmn, @style, i, @viewport)
      @sprites["party_#{i}"].selected = (i == idxPkmn)
    end
	MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"] = AdventureMovebox.new(moves[idxPkmn][i], i, @viewport) }
    @sprites["button"] = IconSprite.new(20, Graphics.height - 32, @viewport)
    @sprites["button"].setBitmap(@path + "buttons")
    @sprites["button"].src_rect.width = 32
    @sprites["descbox"] = IconSprite.new(166, 298, @viewport)
    @sprites["descbox"].setBitmap(@path + "desc_box")
	@sprites["descbox"].src_rect.y = 44
    @sprites["window"] = Window_AdvancedTextPokemon.newWithSize("", 160, 282, 362, 132, @viewport)
    @sprites["window"].windowskin = nil
    @sprites["window"].lineHeight = 28
    @sprites["window"].baseColor = Color.new(248, 248, 248)
    @sprites["window"].shadowColor = Color.new(64, 64, 64)
    pbSetSmallFont(@sprites["window"].contents)
	pkmn = @sprites["party_#{idxPkmn}"].pokemon
	if moves[idxPkmn].empty?
      @sprites["window"].text = _INTL("{1} has no other moves to learn.", pkmn.name)
	else
	  @sprites["window"].text = _INTL("Teach {1} one of the listed moves.", pkmn.name)
	end
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    textpos = [
      [_INTL("RENTAL PARTY"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Select a party member to tutor."), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
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
      # Cycles through party Pokemon or move lists, depending on selectionMode.
      if Input.repeat?(Input::UP)
        case selectionMode
        when 0 # Cycles through party.
          next if party_select.length <= 1
		  pbPlayCursorSE
		  nextIdx = party_select.index(idxPkmn) - 1
          idxPkmn = party_select[nextIdx] || party_select.last
          PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
		  MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].move = moves[idxPkmn][i] }
		  pkmn = @sprites["party_#{idxPkmn}"].pokemon
	      if moves[idxPkmn].empty?
            @sprites["window"].text = _INTL("{1} has no other moves to learn.", pkmn.name)
	      else
	        @sprites["window"].text = _INTL("Teach {1} one of the listed moves.", pkmn.name)
	      end
        when 1 # Cycles through moves.
		  pbPlayCursorSE
          idxMove -= 1
          idxMove = moves[idxPkmn].length - 1 if idxMove < 0
          MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].selected = (i == idxMove) }
          @sprites["window"].text = @sprites["move_#{idxMove}"].move.description
        end
	  #-------------------------------------------------------------------------
      # DOWN KEY
      #-------------------------------------------------------------------------
	  # Cycles through party Pokemon or move lists, depending on selectionMode.
      elsif Input.repeat?(Input::DOWN)
        case selectionMode
        when 0 # Cycles through party.
          next if party_select.length <= 1
		  pbPlayCursorSE
          nextIdx = party_select.index(idxPkmn) + 1
          idxPkmn = party_select[nextIdx] || party_select.first
		  PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
		  MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].move = moves[idxPkmn][i] }
		  pkmn = @sprites["party_#{idxPkmn}"].pokemon
	      if moves[idxPkmn].empty?
            @sprites["window"].text = _INTL("{1} has no other moves to learn.", pkmn.name)
	      else
	        @sprites["window"].text = _INTL("Teach {1} one of the listed moves.", pkmn.name)
	      end
        when 1 # Cycles through moves.
		  pbPlayCursorSE
          idxMove += 1
          idxMove = 0 if idxMove > moves[idxPkmn].length - 1
          MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].selected = (i == idxMove) }
          @sprites["window"].text = @sprites["move_#{idxMove}"].move.description
        end
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
          break if pbConfirmMessage(_INTL("Exit and stop tutoring the party?"))
        when 1 # Returns to party selection.
          pbPlayCancelSE
          overlay.clear
          textpos[1][0] = _INTL("Select a party member to tutor.")
          pbDrawTextPositions(overlay, textpos)
          MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].selected = false }
          @sprites["window"].text = _INTL("Teach {1} one of the listed moves.", pkmn.name)
          selectionMode = 0
          idxMove = 0
        end
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Selects a party Pokemon or a move, depending on selectionMode.
      elsif Input.trigger?(Input::USE)
        case selectionMode
        when 0 # Selects a party Pokemon.
          if moves[idxPkmn].empty?
            pbPlayBuzzerSE
          else
            pbPlayDecisionSE
            overlay.clear
            textpos[1][0] = _INTL("Teach {1} a new move.", pkmn.name)
            pbDrawTextPositions(overlay, textpos)
            MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].selected = (i == idxMove) }
            @sprites["window"].text = @sprites["move_#{idxMove}"].move.description
            selectionMode = 1
          end
        when 1 # Selects a move.
          pbPlayDecisionSE
          moveName = @sprites["move_#{idxMove}"].move.name
          if pbConfirmMessage(_INTL("Teach {1} the move {2}?", pkmn.name, moveName))
            move_index = -1
            if pkmn.numMoves < Pokemon::MAX_MOVES
              move_index = pkmn.numMoves
            else
              move_index = pbForgetMove(pkmn, moves[idxPkmn][idxMove])
            end
            if move_index >= 0
			  old_move = pkmn.moves[move_index]
              pkmn.moves[move_index] = Pokemon::Move.new(moves[idxPkmn][idxMove])
              if old_move
                pbMessage(_INTL("1, 2, and...\\wt[16] ...\\wt[16] ...\\wt[16] Ta-da!") + "\\se[Battle ball drop]\1")
                pbMessage(_INTL("{1} forgot how to use {2}.\\nAnd..." + "\1", pkmn.name, old_move.name))
              end
			  moves[idxPkmn].delete_at(idxMove)
			  idxMove = 0
			  MOVE_LIST_SIZE.times do |i|
				@sprites["move_#{i}"].move = moves[idxPkmn][i]
				@sprites["move_#{i}"].selected = false
			  end
              pbMessage("\\se[]" + _INTL("{1} learned {2}!", pkmn.name, moveName) + "\\se[Pkmn move learnt]")
			  party_select.delete(idxPkmn)
			  idxPkmn = party_select.first
			  PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
			  if party_select.length > 0
			    MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].move = moves[idxPkmn][i] }
			    pkmn = @sprites["party_#{idxPkmn}"].pokemon
			    textpos[1][0] = _INTL("Select a party member to tutor.")
				if moves[idxPkmn].empty?
                  @sprites["window"].text = _INTL("{1} has no other moves to learn.", pkmn.name)
	            else
	              @sprites["window"].text = _INTL("Teach {1} one of the listed moves.", pkmn.name)
	            end
				selectionMode = 0
			  else
			    MOVE_LIST_SIZE.times { |i| @sprites["move_#{i}"].move = nil }
			    textpos = [textpos.first]
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

def pbAdventureMenuTutor
  return if !pbInRaidAdventure?
  style = pbRaidAdventureState.style
  scene = AdventureMenuScene.new
  scene.pbStartScene(style)
  scene.pbMoveTutorMenu
  scene.pbEndScene
end
