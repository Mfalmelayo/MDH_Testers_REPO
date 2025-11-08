#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene
  #-----------------------------------------------------------------------------
  # Party exchange menu.
  #-----------------------------------------------------------------------------
  def pbExchangeMenu(new_pkmn = nil)
    idxPkmn = 0
	exchangeEnd = false
    if new_pkmn.nil?
      raid_species = GameData::Species.generate_raid_lists(@style)[5].clone
      $player.party.each do |pkmn|
        raid_species.delete(pkmn.species)
        raid_species.delete(pkmn.species_data.id) if pkmn.form > 0
      end
      new_pkmn = pbGenerateRental(raid_species)
    end
    @sprites["pokemon"] = AdventureRentalDatabox.new(new_pkmn, @style, 1, @viewport)
    PARTY_SIZE.times do |i|
      pkmn = $player.party[i]
      @sprites["party_#{i}"] = AdventurePartyDatabox.new(pkmn, @style, i, @viewport)
      @sprites["party_#{i}"].selected = (i == idxPkmn)
    end
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    statIcon = @sprites["pokemon"].statIcon
    spriteX, spriteY = @sprites["pokemon"].spriteX, @sprites["pokemon"].spriteY
    spriteW, spriteH = @sprites["pokemon"].bitmap.width, @sprites["pokemon"].bitmap.height
    buttonX1 = spriteX + 12
    buttonX2 = spriteW / 2 + buttonX1
    buttonY = spriteH / 2 + spriteY + 8
    imagepos = [
      [@path + "buttons", buttonX1, buttonY, 0, 0, 32, 32],
      [@path + "buttons", buttonX2, buttonY, 32, 0, 32, 32],
      [sprintf("%s%s/rental_info", @path, @style), spriteX, spriteY - 58],
      [sprintf("Graphics/UI/Summary/icon_ball_%s", new_pkmn.poke_ball), spriteX + 14, spriteY - 50],
      [@path + "stat_icons", Graphics.width - 54, spriteY - 46, 28 * statIcon, 0, 28, 26]
    ]
    textpos = [
      [_INTL("RENTAL PARTY"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Add {1} to the party?", new_pkmn.name), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
      [_INTL("New Pokémon!"), spriteX + 52, spriteY - 38, :left, BASE_COLOR, Color.new(248, 32, 32), :outline],
      [_INTL("View Summary"), buttonX1 + 40, buttonY + 10, :left, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Keep Party"), buttonX2 + 40, buttonY + 10, :left, BASE_COLOR, SHADOW_COLOR, :outline]
    ]
    pbDrawImagePositions(overlay, imagepos)
    pbDrawTextPositions(overlay, textpos)
    until exchangeEnd
      Input.update
      Graphics.update
      pbUpdate
      #-------------------------------------------------------------------------
      # UP/DOWN KEYS
      #-------------------------------------------------------------------------
      # Cycles through party Pokemon.
      if Input.repeat?(Input::UP)
        pbPlayCursorSE
        idxPkmn -= 1
        idxPkmn = PARTY_SIZE - 1 if idxPkmn < 0
        PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
      elsif Input.repeat?(Input::DOWN)
        pbPlayCursorSE
        idxPkmn += 1
        idxPkmn = 0 if idxPkmn > PARTY_SIZE - 1
        PARTY_SIZE.times { |i| @sprites["party_#{i}"].selected = (i == idxPkmn) }
      #-------------------------------------------------------------------------
      # ACTION KEY
      #-------------------------------------------------------------------------
      # Opens the Summary for the new Pokemon.
      elsif Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        pbSummary(new_pkmn)
      #-------------------------------------------------------------------------
      # BACK KEY
      #-------------------------------------------------------------------------
      # Exits the menu and keeps the same party.
      elsif Input.trigger?(Input::BACK)
        exchangeEnd = pbConfirmMessage(_INTL("Exit and keep your current party?"))
      #-------------------------------------------------------------------------
      # USE KEY
      #-------------------------------------------------------------------------
      # Selects a party Pokemon and opens the command menu.
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        pkmn = $player.party[idxPkmn]
        commands = [_INTL("Select"), _INTL("Summary"), _INTL("Back")]
        cmd = 0
        loop do
          cmd = pbShowCommands(commands, cmd)
          break if cmd < 0 || cmd == commands.length - 1
          case cmd
          when 0 # Select
            if pbConfirmMessage(_INTL("Exchange {1} for {2}?", pkmn.name, new_pkmn.name))
              if pkmn.hasItem? && pkmn.item_id != new_pkmn.item_id
                pbMessage(_INTL("{1} is currently holding the {2}...", pkmn.name, pkmn.item.portion_name))
                if new_pkmn.hasItem?
                  msg = _INTL("Should this item replace {1}'s held {2}?", new_pkmn.name, new_pkmn.item.portion_name)
                else
                  msg = _INTL("Should this item be given to {1} to hold now instead?", new_pkmn.name)
                end
                if pbConfirmMessage(msg)
                  new_pkmn.item = pkmn.item_id
                  pkmn.item = nil
                end
              end
			  overlay.clear
              textpos = [textpos.first]
              pbDrawTextPositions(overlay, textpos)
              @sprites["party_#{idxPkmn}"].visible = false
              @sprites["party_#{idxPkmn}"].pokemon = new_pkmn
              @sprites["party_#{idxPkmn}"].selected = false
              @sprites["pokemon"].pokemon = pkmn
              cryFile = GameData::Species.cry_filename_from_pokemon(pkmn)
              pbMessage("\\se[#{cryFile}]" + _INTL("{1} was removed from the party...\\wtnp[30]", pkmn.name))
              pbMessage(_INTL("And...\\wtnp[10]"))
              @sprites["party_#{idxPkmn}"].visible = true
              cryFile = GameData::Species.cry_filename_from_pokemon(new_pkmn)
              pbMessage("\\se[#{cryFile}]" + _INTL("{1} was added to the rental team!\\wtnp[30]", new_pkmn.name))
              pbSEPlay("GUI party switch")
              startX = @sprites["pokemon"].spriteX
              pbWait(0.5) do |delta_t|
                @sprites["pokemon"].x = lerp(startX, Graphics.width, 0.35, delta_t)
              end
              pbMessage(_INTL("Bye-bye, {1}!", pkmn.name))
              $player.party[idxPkmn] = new_pkmn
              exchangeEnd = true
              break
            end
          when 1 # Summary
            pbSummary($player.party[0...PARTY_SIZE], idxPkmn)
          end
        end
      end
    end
  end
end

def pbAdventureMenuExchange(pkmn = nil)
  return if !pbInRaidAdventure?
  style = pbRaidAdventureState.style
  scene = AdventureMenuScene.new
  scene.pbStartScene(style)
  scene.pbExchangeMenu(pkmn)
  scene.pbEndScene
end