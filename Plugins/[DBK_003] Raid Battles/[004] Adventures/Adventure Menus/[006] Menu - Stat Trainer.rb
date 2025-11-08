#===============================================================================
# Draws stat databoxes in Adventure menus.
#===============================================================================
class AdventureStatbox < AdventureAttributebox
  #-----------------------------------------------------------------------------
  # Sets up a stat databox.
  #-----------------------------------------------------------------------------
  def initialize(stat, index, viewport = nil)
    super(stat, index, viewport)
    @attribute = (GameData::Stat.exists?(stat) || stat == :BALANCED) ? stat : nil
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Returns the stat ID assigned to a stat databox.
  #-----------------------------------------------------------------------------
  def stat
    return @attribute
  end
  
  #-----------------------------------------------------------------------------
  # Changes the stat assigned to a stat databox and refreshes it.
  #-----------------------------------------------------------------------------
  def stat=(value)
    if GameData::Stat.exists?(value) || value == :BALANCED
      @attribute = value
    else
      @attribute = nil
    end
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Returns the display name of the stat assigned to a stat box.
  #-----------------------------------------------------------------------------
  def stat_name
    case @attribute
    when :BALANCED
      return _INTL("Balanced")
    else
      data = GameData::Stat.try_get(@attribute)
      return (data.nil?) ? "" : data.name
    end
  end
  
  #-----------------------------------------------------------------------------
  # Returns the icon position of the stat assigned to a stat box.
  #-----------------------------------------------------------------------------
  def statIcon
    return if !@attribute
    data = GameData::Stat.try_get(@attribute)
    return (data.nil?) ? 0 : data.pbs_order
  end
  
  #-----------------------------------------------------------------------------
  # Refreshes and draws the entire stat databox.
  #-----------------------------------------------------------------------------
  def refresh
    self.bitmap.clear
    return if !@attribute
    rectY = (@selected) ? SLOT_BASE_HEIGHT * 2 : SLOT_BASE_HEIGHT
    icon = (GameData::Stat.exists?(@attribute)) ? GameData::Stat.get(@attribute).pbs_order : 0
    imagepos = [
      [@path + "text_slot", 0, 0, 0, rectY, SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT],
      [@path + "stat_icons", 24, 14, 28 * icon, 0, 28, 26]
    ]
    imagepos.push([@path + "text_slot", 0, 0, 0, 0, SLOT_BASE_WIDTH, SLOT_BASE_HEIGHT]) if @selected
    pbDrawImagePositions(self.bitmap, imagepos)
    base   = (@selected) ? LIGHT_BASE_COLOR   : DARK_BASE_COLOR
    shadow = (@selected) ? LIGHT_SHADOW_COLOR : DARK_SHADOW_COLOR
    outline = (@selected) ? :outline : nil
    pbDrawTextPositions(self.bitmap, [[self.stat_name, 156, 20, :center, base, shadow, outline]])
  end
end

#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  #-----------------------------------------------------------------------------
  # Utility for generating the list of stats Pokemon can be trained in.
  #-----------------------------------------------------------------------------
  def pbGenerateStatList
    stat_list = [:BALANCED]
    GameData::Stat.each_main_battle do |stat|
      stat_list[stat.pbs_order] = stat.id
    end
    return stat_list
  end
  
  #-----------------------------------------------------------------------------
  # Stat Trainer menu.
  #-----------------------------------------------------------------------------
  def pbStatTrainerMenu
    stats = pbGenerateStatList
    idxPkmn = 0
    idxStat = 0
    selectionMode = 0
    party_select = (0...PARTY_SIZE).to_a
    stat_list_size = stats.length
    PARTY_SIZE.times do |i|
      @sprites["party_#{i}"] = AdventurePartyDatabox.new($player.party[i], @style, i, @viewport)
      @sprites["party_#{i}"].selected = (i == idxPkmn)
    end
    stat_list_size.times { |i| @sprites["stat_#{i}"] = AdventureStatbox.new(stats[i], i, @viewport) }
    @sprites["button"] = IconSprite.new(20, Graphics.height - 32, @viewport)
    @sprites["button"].setBitmap(@path + "buttons")
    @sprites["button"].src_rect.width = 32
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    textpos = [
      [_INTL("RENTAL PARTY"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Select a party member to train."), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
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
      # Cycles through party Pokemon or the stat list, depending on selectionMode.
      if Input.repeat?(Input::UP)
        case selectionMode
        when 0 # Cycles through party.
          next if party_select.length <= 1
          pbPlayCursorSE
          nextIdx = party_select.index(idxPkmn) - 1
          idxPkmn = party_select[nextIdx] || party_select.last
          PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
        when 1 # Cycles through stat list.
          pbPlayCursorSE
          idxStat -= 1
          idxStat = stats.length - 1 if idxStat < 0
          stat_list_size.times { |i| @sprites["stat_#{i}"].selected = (i == idxStat) }
        end
      #-------------------------------------------------------------------------
      # DOWN KEY
      #-------------------------------------------------------------------------
      # Cycles through party Pokemon or the stat list, depending on selectionMode.
      elsif Input.repeat?(Input::DOWN)
        case selectionMode
        when 0 # Cycles through party.
          next if party_select.length <= 1
          pbPlayCursorSE
          nextIdx = party_select.index(idxPkmn) + 1
          idxPkmn = party_select[nextIdx] || party_select.first
          PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
        when 1 # Cycles through stat list.
          pbPlayCursorSE
          idxStat += 1
          idxStat = 0 if idxStat > stats.length - 1
          stat_list_size.times { |i| @sprites["stat_#{i}"].selected = (i == idxStat) }
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
          break if pbConfirmMessage(_INTL("Exit and stop training the party's stats?"))
        when 1 # Returns to party selection.
          pbPlayCancelSE
          overlay.clear
          textpos[1][0] = _INTL("Select a party member to train.")
          pbDrawTextPositions(overlay, textpos)
          stat_list_size.times { |i| @sprites["stat_#{i}"].selected = false }
          idxStat = 0
          selectionMode = 0
        end
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Selects a party Pokemon or stat training, depending on selectionMode.
      elsif Input.trigger?(Input::USE)
        pkmn = @sprites["party_#{idxPkmn}"].pokemon
        case selectionMode
        when 0 # Selects a party Pokemon.
          pbPlayDecisionSE
          overlay.clear
          textpos[1][0] = _INTL("Select training for {1}.", pkmn.name)
          pbDrawTextPositions(overlay, textpos)
          stat_list_size.times { |i| @sprites["stat_#{i}"].selected = (i == idxStat) }
          selectionMode = 1
        when 1 # Selects a stat to train.
          statName = @sprites["stat_#{idxStat}"].stat_name
          if @sprites["party_#{idxPkmn}"].statIcon == @sprites["stat_#{idxStat}"].statIcon
            pbMessage("\\se[GUI sel buzzer]" + _INTL("{1} already has {2} training!", pkmn.name, statName))
          elsif pbConfirmMessage(_INTL("Undo {1}'s current training and give it {2} training instead?", pkmn.name, statName))
            GameData::Stat.each_main_battle do |s|
			  if s.id == stats[idxStat]
			    pkmn.ev[s.id] = Pokemon::EV_STAT_LIMIT
			  elsif stats[idxStat] == :BALANCED
			    pkmn.ev[s.id] = (Pokemon::EV_STAT_LIMIT / 5).floor
			  else
			    pkmn.ev[s.id] = 0
			  end
            end
			pkmn.calc_stats
            @sprites["party_#{idxPkmn}"].refreshStat
			pbMessage("\\se[]" + _INTL("{1} was given {2} training!", pkmn.name, statName) + "\\se[Pkmn move learnt]")
            stats.delete_at(idxStat)
            idxStat = 0
            party_select.delete(idxPkmn)
            idxPkmn = party_select.first
            PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
            stat_list_size.times do |i| 
              @sprites["stat_#{i}"].stat = stats[i]
              @sprites["stat_#{i}"].selected = false
            end
            if party_select.length > 0
              textpos[1][0] = _INTL("Select a party member to train.")
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

def pbAdventureMenuStats
  return if !pbInRaidAdventure?
  style = pbRaidAdventureState.style
  scene = AdventureMenuScene.new
  scene.pbStartScene(style)
  scene.pbStatTrainerMenu
  scene.pbEndScene
end