#===============================================================================
# Core Adventure Menu scene.
#===============================================================================
class AdventureMenuScene  
  #-----------------------------------------------------------------------------
  # Endless Record menu.
  #-----------------------------------------------------------------------------
  def pbRecordMenu
	record = $PokemonGlobal.raid_adventure_records(@style)
	return if !record || record.empty?
	record[:party].each_with_index do |pkmn, i|
	  @sprites["rental_#{i}"] = AdventureRentalDatabox.new(pkmn, @style, i, @viewport)
	end
    @sprites["button"] = IconSprite.new(20, Graphics.height - 32, @viewport)
    @sprites["button"].setBitmap(@path + "buttons")
    @sprites["button"].src_rect.width = 32
    overlay = @sprites["overlay"].bitmap
    overlay.clear
	data_types = [
	  _INTL("Adventure Map:"), 
	  _INTL("Floor Reached:"), 
	  _INTL("Battles Won:")
	]
	data_values = [
	  GameData::AdventureMap.get(record[:map]).name, 
	  sprintf("%d", record[:floor]), 
	  sprintf("%d", record[:battles])
	]
	imagepos = []
	textpos = [
      [_INTL("RECORD DATA"), 79, 8, :center, BASE_COLOR, SHADOW_COLOR, :outline],
      [_INTL("Endless {1} party:", GameData::RaidType.get(@style).lair_name), 337, 12, :center, BASE_COLOR, SHADOW_COLOR],
	  [_INTL("Summary"), 56, Graphics.height - 20, :left, BASE_COLOR, SHADOW_COLOR, :outline]
    ]
	3.times do |i|
	  ypos = 60 + (96 * i)
	  imagepos.push([@path + "party_slot", 2, ypos, 0, 64, 154, 24])
	  textpos.push(
	    [data_types[i], 10, ypos + 4, :left, BASE_COLOR, SHADOW_COLOR],
		[data_values[i], 10, ypos + 36, :left, BASE_COLOR, SHADOW_COLOR, :outline]
	  )
	end
	pbDrawImagePositions(overlay, imagepos)
    pbDrawTextPositions(overlay, textpos)
    loop do
      Input.update
      Graphics.update
      pbUpdate
      if Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        pbSummary(record[:party])
      elsif Input.trigger?(Input::BACK)
        break
      end
    end
  end
end

def pbAdventureRecord(style = nil)
  pbFadeOutIn {
    scene = AdventureMenuScene.new
    scene.pbStartScene(style)
    scene.pbRecordMenu
    scene.pbEndScene
  }
end