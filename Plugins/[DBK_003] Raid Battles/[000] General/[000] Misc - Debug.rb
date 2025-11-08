#===============================================================================
# Adds Raid-related tools to debug options.
#===============================================================================

#-------------------------------------------------------------------------------
# Battle rule options.
#-------------------------------------------------------------------------------
MenuHandlers.add(:battle_rules_menu, :cheerBattle, {
  "name"        => "Cheer battle: [{1}]",
  "rule"        => "cheerBattle",
  "order"       => 314,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Enables all trainers to use the Cheer command."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("cheerBattle", :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :cheerMode, {
  "name"        => "Cheer mode: [{1}]",
  "rule"        => "cheerMode",
  "order"       => 315,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determines the specific cheer commands displayed."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("cheerMode", :Integer, 0, 
      _INTL("Set a cheer mode to determine the cheer commands displayed."))
  }
})

#-------------------------------------------------------------------------------
# General Debug options.
#-------------------------------------------------------------------------------
MenuHandlers.add(:debug_menu, :deluxe_raid_settings, {
  "name"        => _INTL("Raid settings..."),
  "parent"      => :deluxe_plugins_menu,
  "description" => _INTL("Edit and test features related to Raid Battles."),
  "effect"      => proc {
    styles = []
    style_choices = []
    GameData::RaidType.each_available do |raid|
      styles.push(raid.id)
      style_choices.push(raid.name)
    end
    val = $PokemonGlobal.raid_adventure_endless_unlocked
    command  = 0
    commands = [
      _INTL("Empty all Raid Dens"),
      _INTL("Reset all Raid Dens"),
      _INTL("Endless Adventure Mode unlocked [{1}]", (val ? "YES" : "NO")),
      _INTL("Edit saved Adventure routes"),
      _INTL("Edit Adventure maps"),
      _INTL("Playtest a Raid battle"),
      _INTL("Playtest a Raid Adventure")
    ]
    loop do
      command = pbShowCommands(nil, commands, -1, command)
      break if command < 0
      case command
      when 0 # Empty All Dens
        pbClearAllRaids(false)
        pbMessage(_INTL("Raid events on all maps were emptied of all Pokémon."))
      when 1 # Reset All Dens
        pbClearAllRaids(true)
        pbMessage(_INTL("Raid events on all maps were reset with new Pokémon."))
      when 2 # Unlock Endless Mode
        pbPlayDecisionSE
        $PokemonGlobal.raid_adventure_endless_unlocked = !val
        val = $PokemonGlobal.raid_adventure_endless_unlocked
        commands[2] = _INTL("Endless Adventure Mode unlocked [{1}]", (val ? "YES" : "NO"))
      when 3 # Edit saved Adventure routes
        cmd = pbMessage(_INTL("Select a type of Adventure to edit routes for."), style_choices, -1)
        pbPlayCancelSE if cmd < 0
        if cmd >= 0
          pbPlayDecisionSE
          style = styles[cmd]
          name = GameData::RaidType.get(style).lair_name
          species_list = GameData::Species.generate_raid_lists(style, true)[6]
          choices = [
            _INTL("Add a new {1} route", name),
            _INTL("Clear an existing {1} route", name),
            _INTL("Clear all {1} routes", name)
          ]
          loop do
            cmd = pbShowCommands(nil, choices, -1, 0)
            pbPlayCancelSE if cmd < 0
            break if cmd < 0
            routes = $PokemonGlobal.raid_adventure_routes(style)
            case cmd
            when 0 # Add a new route
              if routes.keys.length >= 3
                pbMessage(_INTL("The max number of saved {1} routes has already been met.", name))
              elsif species_list.empty?
                pbMessage(_INTL("There aren't any eligible {1} boss species found.", name))
              else
                pbMessage(_INTL("Choose a boss species for this {1} route.", name))
                species = pbChooseFromGameDataList(:Species) do |data|
                  next nil if !species_list.include?(data.id)
                  next (data.form > 0) ? sprintf("%s_%d", data.real_name, data.form) : data.real_name
                end
                if species
                  sp_name = GameData::Species.get(species).name
                  if routes.keys.include?(species)
                    pbMessage(_INTL("There is already an existing {1} route leading to {2}.", name, sp_name))
                  else
                    pbMessage(_INTL("Choose an Adventure map to encounter {1} on.", sp_name))
                    mapID = pbChooseFromGameDataList(:AdventureMap) do |data|
                      next data.real_name
                    end
                    if mapID
                      map_name = GameData::AdventureMap.get(mapID).name
                      pbMessage(_INTL("A new {1} route to {2} was found within {3}.", name, sp_name, map_name))
                      routes[species] = mapID
                    end
                  end
                end
              end
            when 1 # Clear an existing route
              if routes.empty?
                pbMessage(_INTL("No saved {1} routes exist.", name))
              else
                route_choices = []
                routes.each do |sp, map|
                  sp_name = GameData::Species.get(sp).name
                  map_name = GameData::AdventureMap.get(map).name
                  route_choices.push(_INTL("{1} in {2}", sp_name, map_name))
                end
                new_cmd = pbMessage(_INTL("Select a saved {1} route to remove.", name), route_choices, -1)
                if new_cmd >= 0
                  species = routes.keys[new_cmd]
                  sp_name = GameData::Species.get(species).name
                  pbMessage(_INTL("The {1} route to {2} was cleared.", name, sp_name))
                  routes.delete(species)
                end
              end
            when 2 # Clear all routes
              pbMessage(_INTL("All saved {1} routes were cleared.", name))
              routes.clear
            end
          end
        end
      when 4 # Edit Adventure maps
        pbFadeOutIn do
          scene = AdventureMapEditor.new
          screen = AdventureMapEditorScreen.new(scene)
          screen.pbStart
        end
      when 5 # Playtest a Raid battle
        cmd = pbMessage(_INTL("Select a type of raid to test."), style_choices, -1)
        pbPlayCancelSE if cmd < 0
        if cmd >= 0
          pbPlayDecisionSE
          style = styles[cmd]
          raidType = GameData::RaidType.get(style).name
          pbMessage(_INTL("Choose a species to challenge in the {1} Raid.", raidType))
          species = pbChooseFromGameDataList(:Species) do |data|
            next nil if !data.raid_species?(style)
            next (data.form > 0) ? sprintf("%s_%d", data.real_name, data.form) : data.real_name
          end
          pbDebugRaidBattle(species, style)
          break
        end
      when 6 # Begin a Raid Adventure
        cmd = pbMessage(_INTL("Select a type of lair to explore."), style_choices, -1)
        pbPlayCancelSE if cmd < 0
        if cmd >= 0
          pbPlayDecisionSE
          data = {}
          data[:style] = styles[cmd]
          name = GameData::RaidType.get(data[:style]).lair_name
          data[:darkness] = pbConfirmMessageSerious(_INTL("Apply Darkness Mode to this {1}?", name))
          RaidAdventure.start(data)
          break
        end
      end
    end
  }
})

#-------------------------------------------------------------------------------
# Utility for initiating a debug raid battle.
#-------------------------------------------------------------------------------
def pbDebugRaidBattle(species, style)
  return if !GameData::Species.exists?(species)
  raid_party = []
  $player.party.each do |p|
    next if !p.able?
	raid_party.push(p)
	break if raid_party.length >= Settings::RAID_BASE_PARTY_SIZE
  end
  if raid_party.empty?
    pbMessage(_INTL("You don't have any Pokémon in your party to enter a Raid battle."))
	return
  end
  max_size = raid_party.length
  ruleset = PokemonRuleSet.new
  ruleset.setNumber(max_size)
  ruleset.addPokemonRule(AblePokemonRestriction.new)
  rules = { 
    :style => style,
    :size  => max_size,
    :rank  => GameData::Species.get(species).raid_ranks.first
  }
  [:ko_count, :turn_count, :shield_hp, :extra_actions].each do |r|
    rules[r] = pbDefaultRaidProperty(species, r, rules)
  end
  raidType = GameData::RaidType.get(style)
  speciesName = GameData::Species.get(species).name
  loop do
    options = [
      _INTL("[Battle {1}]",              speciesName),
	  _INTL("Set raid rank [{1}]",       rules[:rank]),
      _INTL("Set raid party [{1} PkMn]", rules[:size]),
	  _INTL("Set raid partner [{1}]",    (rules[:partner] ? rules[:partner][1] : "None"))
    ]
    case pbMessage(_INTL("Set {1} Raid battle properties.", raidType.name), options, -1)
    when 0 # Start battle
	  raid_party.each { |pkmn| pkmn.heal }
	  setBattleRule("tempParty", raid_party)
	  setBattleRule("raidStyleCapture", {
        :capture_chance => 100,
        :capture_bgm    => raidType.capture_bgm
      })
      RaidBattle.start(species, rules)
	  break
	when 1 # Set raid rank
      ranks = GameData::Species.get(species).raid_ranks.clone
	  ranks.push(7)
      if ranks.length > 1
	    pbPlayDecisionSE
		choices = []
		ranks.each { |r| choices.push(r.to_s) }
        choice = pbMessage(_INTL("Choose a raid rank."), choices, -1)
        if choice >= 0
		  pbPlayDecisionSE
		  rules[:rank] = ranks[choice]
		end
      else
        pbPlayBuzzerSE
      end
	when 2 # Set raid party
	  pbPlayDecisionSE
      ruleset.setNumber(max_size) if !rules[:partner] && max_size > rules[:size]
      pbFadeOutIn {
        scene = PokemonParty_Scene.new
        screen = PokemonPartyScreen.new(scene, $player.party)
        ret = screen.pbPokemonMultipleEntryScreenEx(ruleset)
        if ret
          raid_party = ret 
          rules[:size] = raid_party.length
        end
      }
    when 3 # Set raid partner
	  pbPlayDecisionSE
      choice = 1
      if rules[:partner]
        choices = [_INTL("Remove"), _INTL("Replace"), _INTL("Cancel")]
        choice = pbMessage(
          _INTL("Do what with the existing raid partner? ({1})", rules[:partner][1]), choices, -1)
        rules.delete(:partner) if choice == 0
      end
      next if choice != 1
      trdata = pbListScreen(_INTL("PARTNER TRAINER"), TrainerBattleLister.new(0, false))
      if trdata
        backSprite = false
        if trdata[2] > 0 && pbResolveBitmap(sprintf("Graphics/Trainers/%s_%s_back", trdata[0], trdata[2]))
          backSprite = true
        end
        if !backSprite && pbResolveBitmap(sprintf("Graphics/Trainers/%s_back", trdata[0]))
          backSprite = true
        end
        if backSprite
          rules[:size] = 1
          ruleset.setNumber(1)
          raid_party = [raid_party.first]
          rules[:partner] = trdata
          pbMessage(_INTL("Set {1} as raid partner.", trdata[1]))
        else
          pbMessage(_INTL("Trainer is missing a back sprite.\nUnable to set as partner."))
        end
      end
	else
	  break if pbConfirmMessage(_INTL("Are you sure you want to abandon this raid battle?"))
    end
  end
end

#-------------------------------------------------------------------------------
# Battle Debug options.
#-------------------------------------------------------------------------------
MenuHandlers.add(:battle_debug_menu, :deluxe_battle_cheer_level, {
  "name"        => _INTL("Cheer Levels"),
  "parent"      => :trainers,
  "description" => _INTL("Current Cheer level of each trainer."),
  "effect"      => proc { |battle|
    cmd = 0
    loop do
      commands = []
      cmds = []
      battle.cheerLevel.each_with_index do |side_values, side|
        trainers = (side == 0) ? battle.player : battle.opponent
        next if !trainers
        side_values.each_with_index do |value, i|
          next if !trainers[i]
          text = (side == 0) ? "Your side:" : "Foe side:"
          text += sprintf(" %d: %s", i, trainers[i].name)
          text += sprintf(" (%d)", value)
          commands.push(text)
          cmds.push([side, i])
        end
      end
      if battle.cheerMode
        cmd = pbMessage("\\ts[]" + _INTL("Choose a trainer's Cheer level to edit."),
                        commands, -1, nil, cmd)
        break if cmd < 0
        real_cmd = cmds[cmd]
        maxLvl = 3
        level = battle.cheerLevel[real_cmd[0]][real_cmd[1]]
        params = ChooseNumberParams.new
        params.setRange(0, maxLvl)
        params.setInitialValue(level)
        params.setCancelValue(level)
        newLvl = pbMessageChooseNumber(
          "\\ts[]" + _INTL("Set Cheer level (max={1}).", maxLvl), params
        )
        battle.cheerLevel[real_cmd[0]][real_cmd[1]] = newLvl if newLvl != level
      else
        pbMessage(_INTL("Cheer commands are not available in this battle."))
        break
      end
    end
  }
})