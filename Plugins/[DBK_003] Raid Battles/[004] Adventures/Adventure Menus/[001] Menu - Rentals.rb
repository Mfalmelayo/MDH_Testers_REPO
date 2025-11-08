#===============================================================================
# Child class used for drawing rental Pokemon databoxes.
#===============================================================================
class AdventureRentalDatabox < AdventureDataboxCore
  #-----------------------------------------------------------------------------
  # Determines how much a party databox is shifted while highlighted.
  #-----------------------------------------------------------------------------
  SLOT_BASE_X      = 166
  SLOT_BASE_Y      = 44
  SELECTION_OFFSET = 8
  
  #-----------------------------------------------------------------------------
  # Sets up a rental databox.
  #-----------------------------------------------------------------------------
  def initialize(pokemon, style, index, viewport = nil)
    super(pokemon, style, index, viewport)
    @iconOffset = [36, 0]
    @itemOffset = [4, -6]
    @heldOffset = [22, 38]
    @sprites["bg"].setBitmap(sprintf("%s%s/rental_slot", @path, @style))
	@spriteHeight = @sprites["bg"].bitmap.height / 2
    @sprites["bg"].src_rect.height = @spriteHeight
	self.x = SLOT_BASE_X
    self.y = @index * @spriteHeight + SLOT_BASE_Y
    self.z = 99999
    x, y = @spriteX - 42, @spriteY + 24
    @sprites["box"] = IconSprite.new(x, y, viewport)
    @sprites["box"].setBitmap(sprintf("%s%s/rental_select", @path, @style))
    @sprites["box"].src_rect.width = 0
    @sprites["box"].z = 99999
    @sprites["stat"] = IconSprite.new(x + 12, y + 14, viewport)
    @sprites["stat"].setBitmap(@path + "stat_icons")
    @sprites["stat"].src_rect.set(-28, 0, 28, 26)
    @sprites["stat"].z = 99999
    @contents = Bitmap.new(@sprites["bg"].bitmap.width, @sprites["bg"].bitmap.height)
    self.bitmap  = @contents
    pbSetSmallFont(self.bitmap)
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Changes the Pokemon assigned to a rental databox and refreshes it.
  #-----------------------------------------------------------------------------
  def pokemon=(pkmn)
    super(pkmn)
    @sprites["stat"].src_rect.x = (@selected) ? @statIcon * 28 : -28
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
      self.x += SELECTION_OFFSET
      @sprites["bg"].src_rect.y = @spriteHeight
      @sprites["box"].src_rect.width = 62
      @sprites["stat"].src_rect.x = @statIcon * 28
    else
      self.x -= SELECTION_OFFSET
      @sprites["bg"].src_rect.y = 0
      @sprites["box"].src_rect.width = 0
      @sprites["stat"].src_rect.x = -28
    end
    refresh
  end
  
  #-----------------------------------------------------------------------------
  # Refreshes and draws the entire rental databox.
  #-----------------------------------------------------------------------------
  def refresh
    self.bitmap.clear
    return if !@pokemon
    #---------------------------------------------------------------------------
    # Draws all images
    imagepos = []
    case @style
    when :Max
      if @pokemon.gmax_factor?
        icon_path = Settings::DYNAMAX_GRAPHICS_PATH + "gmax_factor"
        imagepos.push([icon_path, 6, 8])
      end
    when :Tera
      icon_path = Settings::TERASTAL_GRAPHICS_PATH + "tera_types"
      icon_pos = GameData::Type.get(@pokemon.tera_type).icon_position
      imagepos.push([icon_path, 6, 6, 0, icon_pos * 32, 32, 32])
    end
    @pokemon.types.each_with_index do |type, i|
      icon_pos = GameData::Type.get(type).icon_position
      imagepos.push(["Graphics/UI/types", 100, 28 * i + 6, 0, icon_pos * 28, 64, 28])
    end
    pbDrawImagePositions(self.bitmap, imagepos)
    #---------------------------------------------------------------------------
    # Draws all text.
    base = (@selected) ? LIGHT_BASE_COLOR : DARK_BASE_COLOR
    shadow = (@selected) ? LIGHT_SHADOW_COLOR : DARK_SHADOW_COLOR
    outline = (@selected) ? :outline : nil
    textpos =[
      [@pokemon.name, 12, 62, :left, base, shadow, outline],
      [@pokemon.ability.name, 12, 82, :left, base, shadow]
    ]
    genderX = self.bitmap.text_size(@pokemon.name).width + 14
    case @pokemon.gender
    when 0 then textpos.push([_INTL("♂"), genderX, 62, :left, MALE_BASE_COLOR, shadow])
    when 1 then textpos.push([_INTL("♀"), genderX, 62, :left, FEMALE_BASE_COLOR, shadow])
    end
    @pokemon.moves.each_with_index do |move, i|
      textpos.push([move.name, 176, 24 * i + 10, :left, base, shadow])
    end
    pbDrawTextPositions(self.bitmap, textpos)
  end
end

#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  RENTAL_LIST_SIZE = 3
  
  #-----------------------------------------------------------------------------
  # Utility for generating a rental Pokemon.
  #-----------------------------------------------------------------------------
  def pbGenerateRental(species_list)
    species = species_list.sample
    species_list.delete(species)
    rules = { :rank => 4, :style => @style }
    species = pbDefaultRaidProperty(species, :species, rules)
    level = [($player.badge_count + 1) * 10, 70].min
    owner = Pokemon::Owner.new(0, _INTL("RENTAL"), 2, $player.language)
    pkmn = Pokemon.new(species, level, owner)
    pkmn.setRaidRentalAttributes(@style)
    pkmn.obtain_text = _INTL("Adventure Rental.")
    pkmn.item = :SITRUSBERRY if !pkmn.hasItem? && rand(10) < 2
    return pkmn
  end
  
  #-----------------------------------------------------------------------------
  # Rental Pokemon selection menu.
  #-----------------------------------------------------------------------------
  def pbRentalsMenu
    idxPkmn = 0
    new_party = []
    raid_species = GameData::Species.generate_raid_lists(@style)[4].clone
    RENTAL_LIST_SIZE.times do |i|
      pkmn = pbGenerateRental(raid_species)
      @sprites["rental_#{i}"] = AdventureRentalDatabox.new(pkmn, @style, i, @viewport)
      @sprites["rental_#{i}"].selected = (i == idxPkmn)
    end
    @sprites["button"] = IconSprite.new(20, Graphics.height - 32, @viewport)
    @sprites["button"].setBitmap(@path + "buttons")
    @sprites["button"].src_rect.width = 32
    @sprites["button"].visible = false
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    remainder = PARTY_SIZE
    textpos = [
      [_INTL("RENTAL PARTY"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Form a party of {1} rental Pokémon.", remainder), 337, 12, :center, BASE_COLOR, SHADOW_COLOR]
    ]
    pbDrawTextPositions(overlay, textpos)
    adventure_name = GameData::RaidType.get(@style).lair_name
    until new_party.length == PARTY_SIZE
      Input.update
      Graphics.update
      pbUpdate
      #-------------------------------------------------------------------------
      # UP/DOWN KEYS
      #-------------------------------------------------------------------------
      # Cycles through list of rental Pokemon.
      if Input.repeat?(Input::UP)
        pbPlayCursorSE
        idxPkmn -= 1
        idxPkmn = RENTAL_LIST_SIZE - 1 if idxPkmn < 0
        RENTAL_LIST_SIZE.times { |i| @sprites["rental_#{i}"].selected = (i == idxPkmn) }
      elsif Input.repeat?(Input::DOWN)
        pbPlayCursorSE
        idxPkmn += 1
        idxPkmn = 0 if idxPkmn > RENTAL_LIST_SIZE - 1
        RENTAL_LIST_SIZE.times { |i| @sprites["rental_#{i}"].selected = (i == idxPkmn) }
      #-------------------------------------------------------------------------
      # ACTION KEY
      #-------------------------------------------------------------------------
      # Opens the Summary for the rental party.
      elsif Input.trigger?(Input::ACTION)
        next if new_party.empty?
        pbPlayDecisionSE
        pbSummary(new_party)
      #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      # Exits the menu and prematurely ends the Adventure.
      elsif Input.trigger?(Input::BACK)
        break if pbConfirmMessage(_INTL("Exit and end your {1}?", adventure_name))
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Selects a rental Pokemon and opens the command menu.
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        pkmn = @sprites["rental_#{idxPkmn}"].pokemon
        commands = [_INTL("Select"), _INTL("Summary"), _INTL("Back")]
        cmd = 0
        loop do
          cmd = pbShowCommands(commands, cmd)
          break if cmd < 0 || cmd == commands.length - 1
          case cmd
          when 0 # Select
            if pbConfirmMessage(_INTL("Add {1} to your rental team?", pkmn.name))
              RENTAL_LIST_SIZE.times { |i| @sprites["rental_#{i}"].selected = false }
              startX = @sprites["rental_0"].spriteX
              pbSEPlay("GUI party switch")
              pbWait(RENTAL_LIST_SIZE * 0.2) do |delta_t|
			    RENTAL_LIST_SIZE.times do |i|
				  @sprites["rental_#{i}"].x = lerp(startX, Graphics.width, i * 0.10 + 0.25, delta_t)
				end
              end
              idxParty = new_party.length
              new_party.push(pkmn)
              @sprites["party_#{idxParty}"] = AdventurePartyDatabox.new(pkmn, @style, idxParty, @viewport)
              cryFile = GameData::Species.cry_filename_from_pokemon(pkmn)
              pbMessage("\\se[#{cryFile}]" + _INTL("{1} was added to the rental team!\\wtnp[30]", pkmn.name))
              if textpos.length < 3
                textpos.push([_INTL("Summary"), 56, Graphics.height - 20, :left, BASE_COLOR, SHADOW_COLOR, :outline])
              end
              if new_party.length < PARTY_SIZE
                raid_species.length.times do |i|
                  species = GameData::Species.get(raid_species[i]).species
                  raid_species[i] = nil if pkmn.species == species
                end
                raid_species.compact!
                RENTAL_LIST_SIZE.times do |i|
                  rental = pbGenerateRental(raid_species)
                  @sprites["rental_#{i}"].pokemon = rental
                end
                pbSEPlay("GUI party switch")
                pbWait(RENTAL_LIST_SIZE * 0.2) do |delta_t|
                  RENTAL_LIST_SIZE.times do |i|
				    @sprites["rental_#{i}"].x = lerp(Graphics.width, startX, i * 0.10 + 0.25, delta_t)
				  end
                end
                overlay.clear
				remainder -= 1
                textpos[1][0] = _INTL("Select {1} more rental Pokémon.", remainder)
				@sprites["rental_0"].selected = true
				@sprites["button"].visible = true
				idxPkmn = 0
              else
                overlay.clear
                textpos = [textpos.first]
				@sprites["button"].visible = false
              end
              pbDrawTextPositions(overlay, textpos)
              break
            end
          when 1 # Summary
            pbSummary(pkmn)
          end
        end
      end
    end
    return new_party
  end
end

def pbAdventureMenuRentals(style = nil)
  party = nil
  pbFadeOutIn {
    scene = AdventureMenuScene.new
    scene.pbStartScene(style)
    party = scene.pbRentalsMenu
    scene.pbEndScene
  }
  return party
end