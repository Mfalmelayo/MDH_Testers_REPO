#===============================================================================
# Handles the battle transition animations for raid battles.
#===============================================================================
SpecialBattleIntroAnimations.register("vs_raid_pokemon_animation", 100,
  proc { |battle_type, foe, location|
    next false if battle_type.odd? || foe.length != 1
    anim = $game_temp.transition_animation_data
    next !anim.nil? && GameData::RaidType.exists?(anim[1])
  },
  proc { |viewport, battle_type, foe, location|
    path = Settings::RAID_GRAPHICS_PATH + "Transitions/"
    anim = $game_temp.transition_animation_data
    folder = "#{anim[1]}/"
    bg = Sprite.new(viewport)
    bg.bitmap = RPG::Cache.load_bitmap(path + folder, "bg")
    spiral = Sprite.new(viewport)
	spiral2 = Sprite.new(viewport)
    if pbResolveBitmap(path + folder + "spiral")
      spiral.bitmap = RPG::Cache.load_bitmap(path + folder, "spiral")
      spiral.ox = spiral.bitmap.width / 2
      spiral.oy = spiral.bitmap.height / 2
      spiral.x = Graphics.width / 2
      spiral.y = Graphics.height / 2
	  if pbResolveBitmap(path + folder + "spiral2")
	    spiral2.bitmap = RPG::Cache.load_bitmap(path + folder, "spiral2")
        spiral2.ox = spiral2.bitmap.width / 2
        spiral2.oy = spiral2.bitmap.height / 2
        spiral2.x = Graphics.width / 2
        spiral2.y = Graphics.height / 2
	  end
    end
    shine = Sprite.new(viewport)
    shine.bitmap = RPG::Cache.load_bitmap(path, "shine")
	shine.opacity = 200
    shine.visible = false
    icon = Sprite.new(viewport)
    icon.bitmap = RPG::Cache.load_bitmap(path + folder, "icon")
    icon.ox = icon.bitmap.width / 2
    icon.oy = icon.bitmap.height / 2
    icon.x = Graphics.width / 2
    icon.y = Graphics.height / 2
    icon.zoom_x = 0
    icon.zoom_y = 0
    icon.visible = false
    impact = Sprite.new(viewport)
    impact.bitmap  = RPG::Cache.load_bitmap(path, "impact")
    impact.visible = false
    pkmn_array = []
    [ [2, 0], [-2, 0], [0, 2], [0, -2], [2, 2], [-2, -2], [2, -2], [-2, 2], [0, 0] ].each do |offset|
      pkmn = PokemonSprite.new(viewport)
      pkmn.setOffset(PictureOrigin::CENTER)
      pkmn.setPokemonBitmap(anim[0])
      pkmn.visible = false
	  pkmn.pattern = nil
      pkmn.x = Graphics.width / 2 + offset[0]
      pkmn.y = Graphics.height / 2 + offset[1]
      if defined?(pkmn.display_values)
        adjust = findCenter(pkmn.bitmap) if !adjust
        sp_offset = Settings::POKEMON_UI_METRICS[pkmn.pkmn.species_data.id] || [0, 0]
        pkmn.x += adjust[0] + sp_offset[0]
        pkmn.y += adjust[1] + sp_offset[1]
      end
      pkmn.zoom_x = 2
      pkmn.zoom_y = 2
      pkmn.tone = (offset == [0, 0]) ? Tone.new(-255, -255, -255) : Tone.new(255, 255, 255)
      pkmn_array.push(pkmn)
    end
    bars = Sprite.new(viewport)
    bars.bitmap  = RPG::Cache.load_bitmap(path, "black_bars")
    vs = Sprite.new(viewport)
    vs.bitmap  = RPG::Cache.load_bitmap(path, "vs")
    vs.ox      = vs.bitmap.width / 2
    vs.oy      = vs.bitmap.height / 2
    vs.x       = Graphics.width / 2
    vs.y       = Graphics.height - (vs.bitmap.height / 2)
    vs.visible = false
    transition = Sprite.new(viewport)
    transition.bitmap = RPG::Cache.transition("vsFlash")
    transition.tone = Tone.new(-255, -255, -255)
    angle = 0
	new_angle = 15
	pbWait(0.25) do |delta_t|
      transition.opacity = lerp(255, 0, 0.25, delta_t)
      spiral.angle = lerp(angle, new_angle, 0.25, delta_t)
	  spiral2.angle = lerp(angle, -new_angle, 0.25, delta_t)
    end
    transition.tone = Tone.new(255, 255, 255)
    icon.visible = true
	angle = new_angle
	new_angle = angle + 90
    pbWait(1.25) do |delta_t|
      icon.zoom_x = lerp(0, 1, 0.25, delta_t)
      icon.zoom_y = lerp(0, 1, 0.25, delta_t)
      spiral.angle = lerp(angle, new_angle, 1.25, delta_t)
	  spiral2.angle = lerp(-angle, -new_angle, 1.25, delta_t)
    end
    shine.visible = true if anim[1] == :Max
    pbSEPlay("Vs flash")
    pbSEPlay("Vs sword")
    transition.opacity = 255
    pkmn_array.each { |pkmn| pkmn.visible = true }
	angle = new_angle
	new_angle = angle + 90
    pbWait(1.25) do |delta_t|
      transition.opacity = lerp(255, 0, 0.25, delta_t)
      spiral.angle = lerp(angle, new_angle, 1.25, delta_t)
	  spiral2.angle = lerp(-angle, -new_angle, 1.25, delta_t)
    end
	angle = new_angle
	new_angle = angle + 90
    pbWait(1.25) do |delta_t|
      t = lerp(-255, 0, 0.25, delta_t).to_i
      pkmn_array.last.tone = Tone.new(t, t, t)
      spiral.angle = lerp(angle, new_angle, 1.25, delta_t)
	  spiral2.angle = lerp(-angle, -new_angle, 1.25, delta_t)
    end
    transition.opacity = 255
    pbSEPlay("Vs sword")
    impact.visible = true if anim[1] == :Basic
    vs.visible = true
    vs_x, vs_y = vs.x, vs.y
    shudder_time = 1.75
    zoom_time = 2.25
	angle = new_angle
	new_angle = angle + 165
    pbWait(2.8) do |delta_t|
      if delta_t <= shudder_time
        transition.opacity = lerp(255, 0, 0.25, delta_t)
      elsif delta_t >= zoom_time
        transition.tone = Tone.new(-255, -255, -255)
        transition.opacity = lerp(0, 255, 0.25, delta_t - zoom_time)
      end
      spiral.angle = lerp(angle, new_angle, 2.8, delta_t)
	  spiral2.angle = lerp(-angle, -new_angle, 2.8, delta_t)
      if delta_t <= shudder_time
        period = (delta_t / 0.025).to_i % 4
        shudder_delta = [2, 0, -2, 0][period]
        vs.x = vs_x + shudder_delta
        vs.y = vs_y - shudder_delta
      elsif delta_t <= zoom_time
        vs.zoom_x = lerp(1.0, 12.0, zoom_time - shudder_time, delta_t - shudder_time)
        vs.zoom_y = vs.zoom_x
      end
    end
    transition.dispose
    bg.dispose
    shine.dispose
    spiral.dispose
	spiral2.dispose
    icon.dispose
    bars.dispose
    vs.dispose
    impact.dispose
    pkmn_array.each { |pkmn| pkmn.dispose }
    viewport.color = Color.black
    $game_temp.transition_animation_data = nil
  }
)