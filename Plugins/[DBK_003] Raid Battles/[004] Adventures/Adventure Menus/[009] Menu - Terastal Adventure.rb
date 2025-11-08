#===============================================================================
# Draws Tera type databoxes in Adventure menus.
#===============================================================================
class AdventureTeraTypebox < AdventureAttributebox
  #-----------------------------------------------------------------------------
  # Sets up a Tera type databox.
  #-----------------------------------------------------------------------------
  def initialize(type, index, viewport = nil)
    super(type, index, viewport)
    @attribute = GameData::Type.try_get(type)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Returns the type data assigned to a Tera type databox.
  #-----------------------------------------------------------------------------
  def type
    return @attribute
  end
  
  #-----------------------------------------------------------------------------
  # Changes the type assigned to a Tera type databox and refreshes it.
  #-----------------------------------------------------------------------------
  def type=(value)
    @attribute = GameData::Type.try_get(value)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Refreshes and draws the entire Tera type databox.
  #-----------------------------------------------------------------------------
  def refresh
    self.bitmap.clear
    return if !@attribute
    rectY = (@selected) ? SLOT_BASE_HEIGHT * 2 : SLOT_BASE_HEIGHT
	icon_path = Settings::TERASTAL_GRAPHICS_PATH + "tera_types"
    imagepos = [
      [@path + "text_slot", 0, 0, 0, rectY, SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT],
      [icon_path, 28, 12, 0, @attribute.icon_position * 32, 32, 32]
    ]
    imagepos.push([@path + "text_slot", 0, 0, 0, 0, SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT]) if @selected
    pbDrawImagePositions(self.bitmap, imagepos)
    base   = (@selected) ? LIGHT_BASE_COLOR   : DARK_BASE_COLOR
    shadow = (@selected) ? LIGHT_SHADOW_COLOR : DARK_SHADOW_COLOR
    outline = (@selected) ? :outline : nil
    pbDrawTextPositions(self.bitmap, [[_INTL("Tera {1}", @attribute.name), 156, 20, :center, base, shadow, outline]])
  end
end

#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  TYPE_LIST_SIZE = 6

  #-----------------------------------------------------------------------------
  # Utility for generating the list of Tera types Pokemon can be given.
  #-----------------------------------------------------------------------------
  def pbGenerateTypeList
    type_list = []
    GameData::Type.each do |type| 
      next if type.pseudo_type
      next if [:QMARKS, :SHADOW].include?(type.id)
      type_list.push(type.id)
    end
    return type_list.sample(TYPE_LIST_SIZE)
  end
  
  #-----------------------------------------------------------------------------
  # Tera type menu.
  #-----------------------------------------------------------------------------
  def pbTeraTypeMenu
    types = pbGenerateTypeList
    idxPkmn = 0
    idxType = 0
    selectionMode = 0
    party_select = (0...PARTY_SIZE).to_a
    PARTY_SIZE.times do |i|
      @sprites["party_#{i}"] = AdventurePartyDatabox.new($player.party[i], @style, i, @viewport)
      @sprites["party_#{i}"].selected = (i == idxPkmn)
    end
    TYPE_LIST_SIZE.times { |i| @sprites["type_#{i}"] = AdventureTeraTypebox.new(types[i], i, @viewport) }
    @sprites["button"] = IconSprite.new(20, Graphics.height - 32, @viewport)
    @sprites["button"].setBitmap(@path + "buttons")
    @sprites["button"].src_rect.width = 32
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    textpos = [
      [_INTL("RENTAL PARTY"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Select a party member to empower."), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
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
      # Cycles through party Pokemon or the type list, depending on selectionMode.
      if Input.repeat?(Input::UP)
        case selectionMode
        when 0 # Cycles through party.
          next if party_select.length <= 1
          pbPlayCursorSE
          nextIdx = party_select.index(idxPkmn) - 1
          idxPkmn = party_select[nextIdx] || party_select.last
          PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
        when 1 # Cycles through type list.
          pbPlayCursorSE
          idxType -= 1
          idxType = types.length - 1 if idxType < 0
          TYPE_LIST_SIZE.times { |i| @sprites["type_#{i}"].selected = (i == idxType) }
        end
      #-------------------------------------------------------------------------
      # DOWN KEY
      #-------------------------------------------------------------------------
      # Cycles through party Pokemon or the type list, depending on selectionMode.
      elsif Input.repeat?(Input::DOWN)
        case selectionMode
        when 0 # Cycles through party.
          next if party_select.length <= 1
          pbPlayCursorSE
          nextIdx = party_select.index(idxPkmn) + 1
          idxPkmn = party_select[nextIdx] || party_select.first
          PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
        when 1 # Cycles through type list.
          pbPlayCursorSE
          idxType += 1
          idxType = 0 if idxType > types.length - 1
          TYPE_LIST_SIZE.times { |i| @sprites["type_#{i}"].selected = (i == idxType) }
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
          break if pbConfirmMessage(_INTL("Exit and stop changing the party's Tera types?"))
        when 1 # Returns to party selection.
          pbPlayCancelSE
          overlay.clear
          textpos[1][0] = _INTL("Select a party member to empower.")
          pbDrawTextPositions(overlay, textpos)
          TYPE_LIST_SIZE.times { |i| @sprites["type_#{i}"].selected = false }
          idxType = 0
          selectionMode = 0
        end
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Selects a party Pokemon or Tera type, depending on selectionMode.
      elsif Input.trigger?(Input::USE)
        pkmn = @sprites["party_#{idxPkmn}"].pokemon
        case selectionMode
        when 0 # Selects a party Pokemon.
          pbPlayDecisionSE
          overlay.clear
          textpos[1][0] = _INTL("Select {1}'s Tera type.", pkmn.name)
          pbDrawTextPositions(overlay, textpos)
          TYPE_LIST_SIZE.times { |i| @sprites["type_#{i}"].selected = (i == idxType) }
          selectionMode = 1
        when 1 # Selects a Tera type to give.
          typeName = @sprites["type_#{idxType}"].type.name
		  if pkmn.has_forced_tera_type?
		    pbMessage("\\se[GUI sel buzzer]" + _INTL("{1}'s Tera type cannot be changed!", pkmn.name))
          elsif pkmn.tera_type == types[idxType]
            pbMessage("\\se[GUI sel buzzer]" + _INTL("{1} already has the {2} Tera type!", pkmn.name, typeName))
          elsif pbConfirmMessage(_INTL("Replace {1}'s Tera type with Tera {2}?", pkmn.name, typeName))
            pkmn.tera_type = types[idxType]
            @sprites["party_#{idxPkmn}"].refresh
			pbMessage("\\se[]" + _INTL("{1}'s Tera type was changed to Tera {2}!", pkmn.name, typeName) + "\\se[Pkmn move learnt]")
            types.delete_at(idxType)
            idxType = 0
            party_select.delete(idxPkmn)
            idxPkmn = party_select.first
            PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
            TYPE_LIST_SIZE.times do |i| 
              @sprites["type_#{i}"].type = types[i]
              @sprites["type_#{i}"].selected = false
            end
            if party_select.length > 0
              textpos[1][0] = _INTL("Select a party member to empower.")
              selectionMode = 0
            else
              textpos = [textpos.first]
              @sprites["button"].visible = false
            end
            overlay.clear
            pbDrawTextPositions(overlay, textpos)
          end
        end
      end
      break if party_select.empty?
    end
  end
end

def pbAdventureMenuTera
  return if !pbInRaidAdventure?
  return if pbRaidAdventureState.style != :Tera
  scene = AdventureMenuScene.new
  scene.pbStartScene(:Tera)
  scene.pbTeraTypeMenu
  scene.pbEndScene
end