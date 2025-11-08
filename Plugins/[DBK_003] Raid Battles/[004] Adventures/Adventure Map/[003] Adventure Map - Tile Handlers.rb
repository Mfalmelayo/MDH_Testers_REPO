#===============================================================================
# Adventure Tile handlers.
#===============================================================================
class AdventureTileHandlerHash < HandlerHashSymbol
end

module AdventureTileEffects
  MapTile = AdventureTileHandlerHash.new
  
  def self.trigger(hash, *args, ret: false)
    new_ret = hash.trigger(*args)
    return (!new_ret.nil?) ? new_ret : ret
  end
  
  def self.triggerTile(id, tile, adventure, scene, dir, dirs)
    return trigger(MapTile, id, tile, adventure, scene, dir, dirs, ret: dir)
  end
end

#===============================================================================
# Landmark tiles
#===============================================================================

AdventureTileEffects::MapTile.add(:Pathway,
  proc { |id, tile, adventure, scene, dir, dirs|
    next dir if dirs.include?(dir)
    pbSEPlay("Player bump")
    next scene.pbRedirectMovement(dir, dirs)
  }
)

AdventureTileEffects::MapTile.copy(:Pathway, :StartPoint)

AdventureTileEffects::MapTile.add(:Crossroad,
  proc { |id, tile, adventure, scene, dir, dirs|
    next scene.pbSelectRoute(dir, dirs)
  }
)

AdventureTileEffects::MapTile.add(:Battle,
  proc { |id, tile, adventure, scene, dir, dirs|
    boss_id = scene.boss_tile.battle_id
    battle_id = scene.player_tile.battle_id
    if adventure.playtesting
      scene.pbAutoPosition(scene.player_tile, 6)
      adventure.outcome = 1 if battle_id == boss_id
      next dir
    end
    rules = scene.raid_battles[battle_id]
    next dir if rules[:battled]
    $game_temp.clear_battle_rules
    rules[:ko_count] = adventure.hearts
    adventure.boss_battled = (battle_id == boss_id)
    setBattleRule($PokemonGlobal.partner.nil? ? "3v1" : "2v1")
    raidType = GameData::RaidType.get(adventure.style)
    setBattleRule("environment", raidType.battle_environ)
    pbSetRaidProperties(rules)
	raid_pkmn = rules[:pokemon].clone
    scene.pbAutoPosition(scene.player_tile, 6)
    continue = true
    pbFadeOutIn {
      adventure.last_battled = battle_id if adventure.floor == 1
      scene.map_sprites["pokemon_#{battle_id}"].visible = false
      scene.map_sprites["pokemon_#{battle_id}"].color.alpha = 0
      scene.map_sprites["pkmntype_#{battle_id}"].visible = false
      decision = WildBattle.start_core(raid_pkmn)
	  decision = 2 if adventure.hearts == 0
      $game_temp.transition_animation_data = nil
      EventHandlers.trigger(:on_wild_battle_end, raid_pkmn.species_data.id, raid_pkmn.level, decision)
      continue = [1, 4].include?(decision)
      rules[:battled] = true
      scene.pbUpdateHearts
	  $player.party.each { |p| p.heal if p.fainted? }
	  if decision == 4 && (!adventure.boss_battled || adventure.endlessMode?)
	    pkmn = adventure.captures.last
	    pbFadeOutIn { pbAdventureMenuExchange(pkmn) }
	  end
    }
	# Continues Adventure if raid Pokemon was captured or defeated.
    if continue
      scene.pbUpdateDarkness(true)
      adventure.battle_count += 1
      if adventure.boss_battled
	    # Proceed to next floor if boss defeated in Endless Mode.
        if adventure.endlessMode?
          adventure.floor += 1
          $stats.endless_adventure_floors += 1
          next scene.pbResetLair
		# Proceed to rewards selection if boss defeated in Normal Mode.
        else
          adventure.outcome = 1
        end
      end
	# If the player's hearts have all been depleted, or the entire party has been KO'd:
	# -Decides if a new record should be set if playing in Endless Mode.
    elsif adventure.floor > 1
      record = $PokemonGlobal.raid_adventure_records[adventure.style]
      newRecord = record.nil? || record.empty? || adventure.floor > record[:floor]
      adventure.outcome = (newRecord) ? 1 : 2
	# -Decides if the lair route may be saved if playing in Normal Mode.
    else
      adventure.outcome = (adventure.boss_battled) ? 3 : 2
    end
    next dir
  }
)

#===============================================================================
# Directional tiles
#===============================================================================

AdventureTileEffects::MapTile.add(:TurnNorth,
  proc { |id, tile, adventure, scene, dir, dirs|
    next (dirs.include?(0)) ? 0 : dir
  }
)

AdventureTileEffects::MapTile.add(:TurnSouth,
  proc { |id, tile, adventure, scene, dir, dirs|
    next (dirs.include?(1)) ? 1 : dir
  }
)

AdventureTileEffects::MapTile.add(:TurnWest,
  proc { |id, tile, adventure, scene, dir, dirs|
    next (dirs.include?(2)) ? 2 : dir
  }
)

AdventureTileEffects::MapTile.add(:TurnEast,
  proc { |id, tile, adventure, scene, dir, dirs|
    next (dirs.include?(3)) ? 3 : dir
  }
)

AdventureTileEffects::MapTile.add(:RandomTurn,
  proc { |id, tile, adventure, scene, dir, dirs|
	dirs.delete(dir)
    next dirs.sample || dir
  }
)

AdventureTileEffects::MapTile.add(:ReverseTurn,
  proc { |id, tile, adventure, scene, dir, dirs|
    case dir
    when 0 then next 1 if dirs.include?(1) # Reverse south
    when 1 then next 0 if dirs.include?(0) # Reverse north
    when 2 then next 3 if dirs.include?(3) # Reverse east
    when 3 then next 2 if dirs.include?(2) # Reverse west
    end
  }
)

#===============================================================================
# Object tiles
#===============================================================================

AdventureTileEffects::MapTile.add(:Door,
  proc { |id, tile, adventure, scene, dir, dirs|
    pbMessage(_INTL("A massive locked door blocks your path.")) { scene.pbUpdate }
    if adventure.keys > 0 || $DEBUG && Input.press?(Input::CTRL)
      pbMessage(_INTL("You used a key to open the door!")) { scene.pbUpdate }
      scene.pbUpdateKeys(-1)
      pbSEPlay("Battle catch click")
      scene.pbPauseScene(0.5)
      tile.deactivate
      pbSEPlay("Door enter")
    else
      pbMessage(_INTL("Unable to proceed, you turned back the way you came.")) { scene.pbUpdate }
      next AdventureTileEffects.triggerTile(:ReverseTurn, tile, adventure, scene, dir, dirs)
    end
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Switch,
  proc { |id, tile, adventure, scene, dir, dirs|
    scene.pbPauseScene(0.5)
    pbSEPlay("Voltorb flip tile")
    tile.flip_switch
    scene.map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      sprite.toggle
    end
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Warp,
  proc { |id, tile, adventure, scene, dir, dirs|
    x, y = *tile.warp_point
    scene.player_tile = scene.map_sprites["tile_#{x}_#{y}"]
    scene.player_tile.make_visited
    scene.pbPauseScene(0.5)
    scene.player.visible = false
    pbSEPlay("Player jump")
    scene.pbPauseScene(0.5)
    scene.player.x = scene.player_tile.x
    scene.player.y = scene.player_tile.y
    scene.pbAutoPosition(scene.player_tile, 6)
    scene.pbPauseScene(0.5)
    scene.player.visible = true
    pbSEPlay("Player jump")
    scene.pbPauseScene(0.5)
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Portal,
  proc { |id, tile, adventure, scene, dir, dirs|
    player = adventure.map.player
    x, y = player[0..1].to_i, player[2..3].to_i
    scene.player_tile = scene.map_sprites["tile_#{x}_#{y}"]
    scene.pbPauseScene(0.5)
    scene.player.visible = false
    scene.player.x = scene.player_tile.x
    scene.player.y = scene.player_tile.y
    pbSEPlay("Anim/Teleport")
    scene.pbPauseScene(0.5)
    pbFadeOutIn { 
      scene.pbAutoPosition(scene.player_tile, 0)
      scene.player.visible = true
      scene.pbUpdate(true)
    }
    scene.pbPauseScene(0.5)
    pbMessage(_INTL("You were transported back to the start of the lair!")) { scene.pbUpdate }
    if    scene.start_tile.x > scene.player_tile.x then next 3 # East
    elsif scene.start_tile.x < scene.player_tile.x then next 2 # West
    elsif scene.start_tile.y > scene.player_tile.y then next 1 # South
    else                                                next 0 # North
    end
  }
)

AdventureTileEffects::MapTile.add(:Teleporter,
  proc { |id, tile, adventure, scene, dir, dirs|
    crossroads = []
    scene.map_sprites.each_value do |sprite|
      next if !sprite.is_a?(AdventureTileSprite)
      next if !sprite.isTile?(:Crossroad)
      crossroads.push(sprite)
    end
    if crossroads.length >= 2
      crossroad = GameData::AdventureTile.get(:Crossroad).name
      msgs = [_INTL("You stepped on a {1}!", tile.tile.name),
              _INTL("Please select a previously visited {1} tile to teleport to.", crossroad)]
      msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } }
      crossroads.each { |sprite| sprite.color = Color.new(255, 0, 0, 125) if !sprite.visited? }
      scene.pbFreeMapScrolling(true)
      crossroads.each { |sprite| sprite.color = Color.new(0, 0, 0, 0) }
      scene.pbHideUI
      dirs = scene.pbUpdateDirections
      scene.player.visible = true
      pbSEPlay("Player jump")
      scene.pbPauseScene(0.5)
      next scene.pbSelectRoute(dir, dirs)
    else
      pbMessage(_INTL("You stepped on a {1}, but it doesn't seem to be operational at this time.", tile.tile.name)) { scene.pbUpdate }
    end
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Roadblock,
  proc { |id, tile, adventure, scene, dir, dirs|
    if adventure.playtesting
      pbMessage(_INTL("You bypassed an obstacle in your path!")) { scene.pbUpdate }
      tile.deactivate
      next dir
    end
    pkmn = nil
    pokeName = ""
    case tile.variable
    when 0 # Chasm [Requires Flying-type]
      type = GameData::Type.get(:FLYING)
      $player.pokemon_party.each { |p| pkmn = p if p.hasType?(type.id) }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("A deep chasm blocks your path!"), 
              _INTL("A {1}-type Pokémon may be able to lift you safely across.", type.name),
              _INTL("{1} happily carried you across the chasm!", pokeName)]
    when 1 # Pool [Requires Water-type]
      type = GameData::Type.get(:WATER)
      $player.pokemon_party.each { |p| pkmn = p if p.hasType?(type.id) }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("A large pool of murky water blocks your path!"), 
              _INTL("A {1}-type Pokémon may be able to ferry you safely across.", type.name),
              _INTL("{1} happily carried you across the water!", pokeName)]
    when 2 # Rock Wall [Requires Fighting-type]
      type = GameData::Type.get(:FIGHTING)
      $player.pokemon_party.each { |p| pkmn = p if p.hasType?(type.id) }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("You reached what appears to be a dead end, but the wall here seems thin."), 
              _INTL("A {1}-type Pokémon may be able to punch through the wall and forge a path forward!", type.name),
              _INTL("{1} bashed through the wall with a mighty blow!", pokeName)]
    when 3 # Pitfall [Requires Psychic-type]
      type = GameData::Type.get(:PSYCHIC)
      $player.pokemon_party.each { |p| pkmn = p if p.hasType?(type.id) }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("The floor here seems unstable in certain spots - you may fall through if you proceed!"), 
              _INTL("A {1}-type Pokémon may be able to foresee the safest route forward and avoid any pitfalls.", type.name),
              _INTL("{1} foresaw the dangers ahead and navigated around the pitfalls!", pokeName)]
    when 4 # Dust Storm [Requires Rock, Ground, or Steel-type]
      typeNames = []
      [:ROCK, :GROUND, :STEEL].each do |t|
        typeNames.push(GameData::Type.get(t).name)
        next if pkmn
        $player.pokemon_party.each do |p|
          pkmn = p if p.types.include?(t)
          pokeName = pkmn.name if pkmn
          break if pkmn
        end
      end
      msgs = [_INTL("Strong winds funneled through the passage have whipped up a storm of dust that blocks your path!"),
              _INTL("A {1}, {2}, or {3}-type Pokémon may be able to safely guide you through the dust storm.", *typeNames),
              _INTL("{1} bravely traversed the dust storm and led you across!", pokeName)]
    when 5 # Eerie Wail [Requires Bug, Dark, or Ghost-type]
      typeNames = []
      [:BUG, :DARK, :GHOST].each do |t|
        typeNames.push(GameData::Type.get(t).name)
        next if pkmn
        $player.pokemon_party.each do |p|
          pkmn = p if p.types.include?(t)
          pokeName = pkmn.name if pkmn
          break if pkmn
        end
      end
      msgs = [_INTL("An eerie wail howling from the depths of the lair stops you cold in your tracks..."),
              _INTL("A {1}, {2}, or {3}-type Pokémon may be able to scout the path ahead without fear!", *typeNames),
              _INTL("{1} investigated the eerie wailing and discovered it was just the wind!", pokeName)]
    when 6 # Boulder [Requires max Attack EV's]
      stat = GameData::Stat.get(:ATTACK)
      $player.pokemon_party.each { |p| pkmn = p if p.ev[stat.id] == Pokemon::EV_STAT_LIMIT }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("A massive boulder blocks your path!"),
              _INTL("A Pokémon sufficienty trained in {1} may be physically capable of moving it.", stat.name),
              _INTL("{1} flexed its muscles and tossed the boulder aside with ease!", pokeName)]
    when 7 # Rockslide [Requires max Defense EV's]
      stat = GameData::Stat.get(:DEFENSE)
      $player.pokemon_party.each { |p| pkmn = p if p.ev[stat.id] == Pokemon::EV_STAT_LIMIT }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("Falling rocks makes it too dangerous to press on!"),
              _INTL("A Pokémon sufficienty trained in {1} may be tough enough to shield you from harm.", stat.name),
              _INTL("{1} unflinchingly shrugged off the falling rocks as you moved on ahead!", pokeName)]
    when 8 # Incline [Requires max Speed EV's]
      stat = GameData::Stat.get(:SPEED)
      $player.pokemon_party.each { |p| pkmn = p if p.ev[stat.id] == Pokemon::EV_STAT_LIMIT }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("A steep incline makes it too difficult to climb any further..."),
              _INTL("A Pokémon sufficienty trained in {1} may be quick enough to carry you up with ease!", stat.name),
              _INTL("{1} bolted you up the incline without breaking a sweat!", pokeName)]
    when 9 # Energy Barrier [Requires max Sp. Atk EV's]
      stat = GameData::Stat.get(:SPECIAL_ATTACK)
      $player.pokemon_party.each { |p| pkmn = p if p.ev[stat.id] == Pokemon::EV_STAT_LIMIT }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("An impenetrable barrier of mysterious energy blocks your path!"),
              _INTL("A Pokémon sufficienty trained in {1} may be powerful enough to blast through it.", stat.name),
              _INTL("{1} effortlessly blasted through the barrier with sheer willpower!", pokeName)]
    when 10 # Energy Waves [Requires max Sp. Def EV's]
      stat = GameData::Stat.get(:SPECIAL_DEFENSE)
      $player.pokemon_party.each { |p| pkmn = p if p.ev[stat.id] == Pokemon::EV_STAT_LIMIT }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("A powerful wave of mysterious energy prevents you from moving forward!"),
              _INTL("A Pokémon sufficienty trained in {1} may have the fortitude to withstand the energy.", stat.name),
              _INTL("{1} swatted away the waves of energy and guided you through unscathed!", pokeName)]
    when 11 # Gauntlet [Requires balanced EV's]
      $player.pokemon_party.each { |p| pkmn = p if p.ev[:ATTACK] > 0 && p.ev[:ATTACK] < Pokemon::EV_STAT_LIMIT }
      pokeName = pkmn.name if pkmn
      msgs = [_INTL("An intimidating gauntlet of various challenges prevents you from pressing onwards..."),
              _INTL("A Pokémon with balanced training may be capable of overcoming the numerous obstacles."),
              _INTL("{1} impressively traversed the gauntlet with perfect form!", pokeName)]
    end
    msgs[0..1].each { |msg| pbMessage(msg) { scene.pbUpdate } }
    if pkmn
      pbHiddenMoveAnimation(pkmn)
      pbMessage(msgs[2]) { scene.pbUpdate }
      tile.deactivate
    else
      pbMessage(_INTL("Unable to proceed, you turned back the way you came.")) { scene.pbUpdate }
      next AdventureTileEffects.triggerTile(:ReverseTurn, tile, adventure, scene, dir, dirs)
    end
    next dir
  }
)

AdventureTileEffects::MapTile.add(:HiddenTrap,
  proc { |id, tile, adventure, scene, dir, dirs|
    if adventure.playtesting
      pbMessage(_INTL("You bypassed a hidden trap!")) { scene.pbUpdate }
      tile.deactivate
      next dir
    end
    pkmn = $player.party.sample
    statuses = [:NONE, :SLEEP, :POISON, :BURN, :PARALYSIS, :FROZEN]
    newStatus = (pkmn.status == :NONE) ? statuses.sample : statuses.first
    msgs = ["\\se[Exclaim]...!\\wtnp[20]"]
    case newStatus
    # Cloud of spores [Inflicts Sleep]
    when :SLEEP, :DROWSY
      failure = pkmn.types.include?(:GRASS) && Settings::MORE_TYPE_EFFECTS
      msgs.push("An overgrown fungus nearby suddenly burst and released a cloud of spores!",
                "{1} pushed you to safety and was hit by the cloud of spores instead!",
                "\\se[Mining found all]Luckily, the cloud of spores had no effect on {1}!\\wtnp[20]",
                "\\se[Anim/Sleep]{1} became sleepy due to inhaling the cloud of spores!\\wtnp[20]")
    # Mysterious ooze [Inflicts Poison]
    when :POISON
      failure = pkmn.types.include?(:POISON) || pkmn.types.include?(:STEEL)
      msgs.push("A mysterious ooze leaking from the cieling suddenly fell towards you!",
                "{1} pushed you to safety and was drenched in the mysterious ooze instead!",
                "\\se[Mining found all]Luckily, the mysterious ooze had no effect on {1}!\\wtnp[20]",
                "\\se[Anim/Poison]{1} became poisoned due to being drenched the mysterious ooze!\\wtnp[20]")
    # Hot steam [Inflicts Burn]
    when :BURN
      failure = pkmn.types.include?(:FIRE)
      msgs.push("A geyser of hot steam suddenly erupted beneath your feet!",
                "{1} pushed you to safety and was hit by the hot steam instead!",
                "\\se[Mining found all]Luckily, the hot steam had no effect on {1}!\\wtnp[20]",
                "\\se[Anim/Fire2]{1} became burned due to being hit by the hot steam!\\wtnp[20]")
    # Lightning bolt [Inflicts Paralysis]
    when :PARALYSIS
      failure = pkmn.types.include?(:ELECTRIC) && Settings::MORE_TYPE_EFFECTS
      msgs.push("Intense static in the air caused bolts of lightning to suddenly strike around you!",
                "{1} pushed you to safety and was struck by a bolt of lightning instead!",
                "\\se[Mining found all]Luckily, the bolt of lightning had no effect on {1}!\\wtnp[20]",
                "\\se[Anim/Paralyze1]{1} became paralyzed due to being struck by the bolt of lightning!\\wtnp[20]")
    # Frigid water [Inflicts Frozen]
    when :FROZEN, :FROSTBITE
      failure = pkmn.types.include?(:ICE)
      msgs.push("You walked over a sheet of ice and it suddenly began to crack beneath your feet!",
                "{1} pushed you to safety and was plunged into the frigid water instead!",
                "\\se[Mining found all]Luckily, the frigid water had no effect on {1}!\\wtnp[20]",
                "\\se[Anim/Ice5]{1} began to freeze due to being plunged in the frigid water!\\wtnp[20]")
    # Cave fissure [Inflicts damage]
    else
      failure = rand(10) < 2
      msgs.push("The floor beneath you suddenly began to crack, causing you to fall down a fissure!",
                "{1} came to your rescue and cushioned your fall!",
                "\\se[Mining found all]Luckily, the fissure was quite shallow and {1} didn't suffer any damage!\\wtnp[20]",
                "\\se[Anim/Damage1]{1} suffered some damage from cushioning your fall!\\wtnp[20]")
    end
    msgs[0..2].each { |msg| pbMessage(_INTL(msg, pkmn.name)) { scene.pbUpdate } }
    pbHiddenMoveAnimation(pkmn)
    if failure
      pbMessage(_INTL(msgs[3], pkmn.name)) { scene.pbUpdate }
    else
      if newStatus == :NONE
        pkmn.hp = [1, (pkmn.hp - (pkmn.hp / 3)).round].max
      else
        pkmn.status = newStatus
        pkmn.statusCount = 3 if [:SLEEP, :DROWSY].include?(pkmn.status)
      end
      pbMessage(_INTL(msgs[4], pkmn.name)) { scene.pbUpdate }
    end
    tile.deactivate
    next dir
  }
)

#===============================================================================
# Collectable tiles
#===============================================================================

AdventureTileEffects::MapTile.add(:Berries,
  proc { |id, tile, adventure, scene, dir, dirs|
    needs_healing = false
    $player.party.each { |p| needs_healing = true if p.hp < p.totalhp }
    pbMessage(_INTL("You found some berries lying on the ground!")) { scene.pbUpdate }
    if needs_healing || adventure.playtesting
      pbMessage(_INTL("\\se[Anim/Recovery]Your Pokémon ate the berries and some of their HP was restored!")) { scene.pbUpdate }
      if !adventure.playtesting
        $player.party.each do |pkmn|
          pkmn.hp += pkmn.totalhp / 2
          pkmn.hp = pkmn.totalhp if pkmn.hp > pkmn.totalhp
        end
      end
      tile.deactivate
    else
      msgs = [_INTL("But your Pokémon are already at full health..."),
              _INTL("You decided to leave the berries behind and press on!")]
      msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } }
    end
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Flare,
  proc { |id, tile, adventure, scene, dir, dirs|
    pbMessage(_INTL("\\me[Bug catching 3rd]You found a flare!\\wtnp[20]")) { scene.pbUpdate }
    if adventure.darknessMode? || adventure.playtesting
      pbMessage(_INTL("You lit the flare and increased your visibility!")) { scene.pbUpdate }
      scene.pbUpdateDarkness(true)
      tile.deactivate
    else
      pbMessage(_INTL("But this is of no use to you in this lair...")) { scene.pbUpdate }
    end
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Key,
  proc { |id, tile, adventure, scene, dir, dirs|
    pbMessage(_INTL("\\me[Bug catching 3rd]You found a lair key!\\wtnp[20]")) { scene.pbUpdate }
    scene.pbUpdateKeys(1)
    tile.deactivate
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Chest,
  proc { |id, tile, adventure, scene, dir, dirs|
    pbMessage(_INTL("You found a locked chest!")) { scene.pbUpdate }
    if adventure.keys > 0 || $DEBUG && Input.press?(Input::CTRL)
      if pbConfirmMessage(_INTL("Would you like to use one of your keys to unlock the chest?")) { scene.pbUpdate }
        scene.pbUpdateKeys(-1)
        pbSEPlay("Battle catch click")
		scene.pbPauseScene(0.2)
		if !adventure.playtesting
		  last_battled = adventure.last_battled
		  pokemon = scene.raid_battles[last_battled][:pokemon]
          pbAdventureMenuSpoils(pokemon)
		end
        tile.deactivate
      else
        pbMessage(_INTL("With a heavy sigh, you decided to press on and leave the chest behind.")) { scene.pbUpdate }
      end
    else
      pbMessage(_INTL("But without any keys to unlock it, you decided to leave the chest behind.")) { scene.pbUpdate }
    end
    next dir
  }
)

#===============================================================================
# Character tiles
#===============================================================================

AdventureTileEffects::MapTile.add(:Assistant,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    g = (t.gender == 0) ? "\\b" : (t.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered an {1}!\\wtnp[20]", t.name), nil, 0, skin) { scene.pbUpdate }
    msgs = [_INTL("#{g}How have the results of your adventure been so far?"),
            _INTL("#{g}I have a rental Pokémon here that I could swap with you, if you'd like."),
            _INTL("#{g}I'll head back to study the new data I've gathered."),
            _INTL("#{g}Please report any new findings you may discover on your adventure!")]
    msgs[0..1].each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    pbFadeOutIn { pbAdventureMenuExchange }
    msgs[2..3].each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    tile.deactivate
    next dir
  }
)

AdventureTileEffects::MapTile.add(:ItemVendor,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    g = (t.gender == 0) ? "\\b" : (t.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered an {1}!\\wtnp[20]", t.name), nil, 0, skin) { scene.pbUpdate }
    msgs = [_INTL("#{g}I was worried I'd run into trouble in here, so I stocked up on more than I can carry..."),
            _INTL("#{g}I can share my supplies with you if you're in need. What items would you like?"),
            _INTL("#{g}Remember, preparation is the key to victory!")]
    msgs[0..1].each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    pbFadeOutIn { pbAdventureMenuVendor }
    pbMessage(msgs[2]) { scene.pbUpdate } if !adventure.playtesting
    next dir
  }
)

AdventureTileEffects::MapTile.add(:StatTrainer,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    g = (t.gender == 0) ? "\\b" : (t.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered a {1}!\\wtnp[20]", t.name), nil, 0, skin) { scene.pbUpdate }
    msgs = [_INTL("#{g}I've been training deep in this lair so that I can grow strong like a Raid Pokémon!"),
            _INTL("#{g}Do you want to become strong, too? Let me share my secret training techniques with you!"),
            _INTL("#{g}Keep pushing yourself until you've reached your limits!")]
    msgs[0..1].each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    pbFadeOutIn { pbAdventureMenuStats }
    pbMessage(msgs[2]) { scene.pbUpdate } if !adventure.playtesting
    next dir
  }
)

AdventureTileEffects::MapTile.add(:MoveTutor,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    g = (t.gender == 0) ? "\\b" : (t.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered a {1}!\\wtnp[20]", t.name), nil, 0, skin) { scene.pbUpdate }
    msgs = [_INTL("#{g}I've been studying the most effective tactics to use in Raid battles."),
            _INTL("#{g}If you'd like, I can teach one of your Pokémon a new move to help it excel in battle!"),
            _INTL("#{g}A good strategy will help you overcome any obstacle!")]
    msgs[0..1].each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    pbFadeOutIn { pbAdventureMenuTutor }
    pbMessage(msgs[2]) { scene.pbUpdate } if !adventure.playtesting
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Nurse,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    g = (t.gender == 0) ? "\\b" : (t.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered a {1}!\\wtnp[20]", t.name), nil, 0, skin) { scene.pbUpdate }
    msgs = [_INTL("#{g}Are your Pokémon feeling a bit worn out from your adventure?"),
            _INTL("\\me[Pkmn healing]#{g}Please, let me heal them back to full health.\\wtnp[40]"),
            _INTL("#{g}I'll be going now.\nGood luck with the rest of your adventure!")]
    msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    $player.party.each { |p| p.heal } if !adventure.playtesting
    tile.deactivate
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Mystic,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    g = (t.gender == 0) ? "\\b" : (t.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered a {1}!\\wtnp[20]", t.name), nil, 0, skin) { scene.pbUpdate }
    msgs = [_INTL("#{g}Let me take a good look at you, child...")]
    if adventure.hearts >= adventure.max_hearts
      msgs.push(_INTL("#{g}Ah! So full of heart and soul!\nYou have no need for my services right now."),
                _INTL("#{g}Come back when your spirits grow weary and your heart gets low!"))
      msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } }
      next dir
    end
    msgs.push(_INTL("#{g}Ah! Your spirit beckons to be cleansed of its weariness!"),
              _INTL("#{g}Let me exorcise the demons that plague your heart and soul!"),
              _INTL("#{g}...\\wt[8] ...\\wt[8] ...\\wt[20]Begone!"))
    msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    scene.pbUpdateHearts(adventure.max_hearts)
    pbMessage(_INTL("\\se[Use item in party]Your heart counter was restored to full!\\wtnp[20]"), nil, 0, skin) { scene.pbUpdate }
    msgs = [_INTL("#{g}What am I even doing here, you ask?\nHaha! Let me tell you, child.")]
    case rand(5)
    when 0 # Normal response.
      msgs.push(_INTL("#{g}I go where the spirits say I'm needed! Nothing more!"),
                _INTL("#{g}I must go now, young one. There are many other souls that need saving!"))
    when 1  # Spooky response.
      msgs.push(_INTL("#{g}I was once an adventurer like you who got lost in this lair.\nMany...\\wt[8]many years ago.\\wt[8]"),
                _INTL("Huh?\nThe {1} suddenly vanished into thin air!", t.name))
    when 2 # Goofy response.
      msgs.push(_INTL("#{g}What makes you think I was ever really here at all?\nOooooo....\\wt[8]"),
                _INTL("...\\wt[8] ...\\wt[8] ...\\wt[20]"),
                _INTL("The {1} tripped over a rock during their dramatic exit...", t.name))
    when 3 # Adventurous response.
      msgs.push(_INTL("#{g}I was summoned here by the wailing of souls crying out from this lair!"),
                _INTL("#{g}...but now that I'm here, I think it was just the wind."),
                _INTL("#{g}Perhaps it was fate that drew me here to meet you?\nAlas, it is now time for us to part ways."),
                _INTL("#{g}Farewell, child. Good luck on your journeys!"))
    when 4 # Honest response.
      msgs.push(_INTL("#{g}If you must know, I...\\wt[8]just got lost."),
                _INTL("#{g}The exit is back there, you say?\nThank you, child."),
                _INTL("#{g}May the spirits guide you better than they have me!"))
    end
    msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    tile.deactivate
    next dir
  }
)

AdventureTileEffects::MapTile.add(:MysteryNPC,
  proc { |id, tile, adventure, scene, dir, dirs|
    id = [:Assistant, :ItemVendor, :StatTrainer, :MoveTutor, :Nurse, :Mystic].sample
    AdventureTileEffects.triggerTile(id, tile, adventure, scene, dir, dirs)
    tile.deactivate
    next dir
  }
)

AdventureTileEffects::MapTile.add(:Researcher,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    g = (t.gender == 0) ? "\\b" : (t.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered a {1}!\\wtnp[20]", t.name), nil, 0, skin) { scene.pbUpdate }
    case adventure.style
    when :Ultra
      msgs = [_INTL("#{g}Hiya! I've been conducting my research here to uncover the secrets of Z-Power."),
              _INTL("#{g}I've discovered techniques that allows me to forge Z-Crystals for any Pokémon at will!"),
              _INTL("#{g}At least, I think I have...let me practice on your-\nEhem...I mean, let me forge a Z-Crystal for your Pokémon!")]
    when :Max
      msgs = [_INTL("#{g}Hiya! I've been conducting my research here to uncover the secrets of Dynamax."),
              _INTL("#{g}I've discovered techniques that allows me to maximize the Dynamax level of any Pokémon at will!"),
              _INTL("#{g}At least, I think I have...let me practice on your-\nEhem...I mean, let me change the Dynamax level of your Pokémon!")]
    when :Tera
      msgs = [_INTL("#{g}Hiya! I've been conducting my research here to uncover the secrets of Terastallization."),
              _INTL("#{g}I've discovered techniques that allows me to change the Tera type of any Pokémon at will!"),
              _INTL("#{g}At least, I think I have...let me practice on your-\nEhem...I mean, let me change the Tera types of your Pokémon!")]
    else
	  msgs = []
    end
    msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    case adventure.style
	when :Ultra then pbFadeOutIn { pbAdventureMenuUltra }
	when :Max   then pbFadeOutIn { pbAdventureMenuDynamax }
	when :Tera  then pbFadeOutIn { pbAdventureMenuTera }
	else             pbFadeOutIn
	end
    msgs = [_INTL("#{g}Phew...hey! Nothing exploded this time!\\wt[20] ...Huh?\\wt[20]\nOh, erm...nevermind that."),
            _INTL("#{g}Please come back any time so I can practice- I mean, further my research!")]
    msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } } if !adventure.playtesting
    next dir
  }
)

AdventureTileEffects::MapTile.add(:PartnerA,
  proc { |id, tile, adventure, scene, dir, dirs|
    t = GameData::AdventureTile.get(id)
    trType = GameData::TrainerType.get(t.partner[0])
    g = (trType.gender == 0) ? "\\b" : (trType.gender == 1) ? "\\r" : ""
    skin = "Graphics/Windowskins/sign hgss loc"
    pbMessage(_INTL("You encountered {1}!\\wtnp[20]", t.partner[1]), nil, 0, skin) { scene.pbUpdate }
	next dir if adventure.playtesting
    msgs = [_INTL("#{g}Hey! \\PN! Is that you?"),
            _INTL("#{g}I've been trying to explore this lair, but these raid Pokémon are no joke!"),
            _INTL("#{g}Say...why don't we join forces? It might make battles a little easier.")]
    msgs.push(_INTL("#{g}...Huh?\nOh, it looks like you already teamed up with someone...")) if $PokemonGlobal.partner
    msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } }
    if $PokemonGlobal.partner
      choice = _INTL("#{g}Would you like me to join you instead?")
    else
      choice = _INTL("#{g}What do you say? Should we team up?")
    end
    if pbConfirmMessage(choice) { scene.pbUpdate }
      pbMessage(_INTL("#{g}Alright! Let's show these raid Pokémon what we're made of!")) { scene.pbUpdate }
      scene.pbUpdateHearts(2, true) if !$PokemonGlobal.partner
      pbMessage(_INTL("\\se[Pkmn level up]You partnered up with {1}!\\wtnp[20]", t.partner[1]), nil, 0, skin) { scene.pbUpdate }
      if $PokemonGlobal.partner
        pbMessage(_INTL("You and your previous partner waved goodbye and parted ways.")) { scene.pbUpdate }
      end
      pbRegisterPartner(*t.partner)
      if !adventure.playtesting
        scene.raid_battles.each do |rules| 
        rules[:turn_count] = 12
        rules[:shield_hp]  = 4
        end
      end
      tile.deactivate
    else
      msgs = [_INTL("#{g}Aww...well, you must have a lot of faith in your Pokémon!"),
              _INTL("#{g}Anyway, I'm gonna rest up here some more before continuing."),
              _INTL("#{g}Come back and see me if you change your mind!")]
      msgs.each { |msg| pbMessage(msg) { scene.pbUpdate } }
    end
    next dir
  }
)

AdventureTileEffects::MapTile.copy(:PartnerA, :PartnerB)