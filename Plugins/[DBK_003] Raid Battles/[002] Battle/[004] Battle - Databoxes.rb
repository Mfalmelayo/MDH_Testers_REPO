class Battle::Scene::PokemonDataBox
  attr_reader :shieldXY, :shieldWH, :shieldOffset, :shieldHPWidth
  
  alias raid_set_style_properties set_style_properties
  def set_style_properties(sideSize)
    raid_set_style_properties(sideSize)
    case @style.id
    when :Long
      @turnPosition  = [@spriteBaseX + 4, 66, :left]
      @koPosition    = [@spriteBaseX + 4, 88, :left]
      @shieldXY      = [@spriteBaseX + 150, 46]
      @shieldWH      = [192, 6]
      @shieldOffset  = [10, 2]
      @shieldHPWidth = 24
    else
      @turnPosition  = [@spriteBaseX + 4, 66, :left]
      @koPosition    = [@spriteBaseX + 4, 88, :left]
      @shieldXY      = [@spriteBaseX + 66, 34]
      @shieldWH      = [192, 6]
      @shieldOffset  = [4, 2]
      @shieldHPWidth = 24
    end
  end
  
  alias raid_draw_plugin_elements draw_plugin_elements
  def draw_plugin_elements
    raid_draw_plugin_elements
    rules = @battler.battle.raidRules
	if @battler.isRaidBoss?
      textpos = []
      c = {
        :w => [Color.new(248, 248, 248), Color.new(138, 138, 138)],  # White text
        :y => [Color.new(248, 192, 0), Color.new(144, 104, 0)],      # Yellow text
        :o => [Color.new(255, 141, 0), Color.new(151, 73, 0)],       # Orange text
        :r => [Color.new(255, 82, 0), Color.new(151, 38, 0)]         # Red text
      }
      turn = rules[:turn_count]
      if turn && turn >= 0
        turn_colors = c[:w]
        turn_colors = c[:y] if turn <= Settings::RAID_BASE_TURN_LIMIT / 2
        turn_colors = c[:o] if turn <= Settings::RAID_BASE_TURN_LIMIT / 4
        turn_colors = c[:r] if turn <= Settings::RAID_BASE_TURN_LIMIT / 8
        textpos.push([_INTL("TURN:{1}", turn), *@turnPosition, turn_colors[0], turn_colors[1], :outline])
      end
      ko = rules[:ko_count]
      if ko && ko >= 0
        ko_colors = c[:w]
        ko_colors = c[:y] if ko <= Settings::RAID_BASE_KNOCK_OUTS / 2
        ko_colors = c[:o] if ko <= Settings::RAID_BASE_KNOCK_OUTS / 4
        ko_colors = c[:r] if ko <= 1
        position = (textpos.empty?) ? @turnPosition : @koPosition
        textpos.push([_INTL("KO:{1}", ko), *position, ko_colors[0], ko_colors[1], :outline])
      end
      pbDrawTextPositions(self.bitmap, textpos)
	end
    return if !@battler.hasRaidShield?
    shieldMaxHP = rules[:shield_hp]
	shield_bg = sprintf("%s/%s/shield_bg", @path, @style.id)
	raid_shield = sprintf("%s/%s/raid_shield", @path, @style.id)
    centerX = @shieldXY[0] + @shieldOffset[0] + (@shieldWH[0] / 2 - (shieldMaxHP * @shieldHPWidth / 2))
    pbDrawImagePositions(self.bitmap, [
      [shield_bg, *@shieldXY],
      [raid_shield, centerX, @shieldXY[1] + @shieldOffset[1], 0, 0, shieldMaxHP * @shieldHPWidth, @shieldWH[1]],
      [raid_shield, centerX, @shieldXY[1] + @shieldOffset[1], 0, @shieldWH[1], @battler.shieldHP * @shieldHPWidth, @shieldWH[1]]
    ])
  end
end