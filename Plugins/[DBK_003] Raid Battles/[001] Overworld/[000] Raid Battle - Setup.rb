#===============================================================================
# Main raid battle call.
#-------------------------------------------------------------------------------
# The "pkmn" hash accepts the following keys:
#-------------------------------------------------------------------------------
#	:type          => Filter by species type.
#	:habitat       => Filter by species habitat.
#	:generation    => Filter by species generation.
#	:encounter     => Filter by map encounter table.
#-------------------------------------------------------------------------------
# The "rules" hash accepts the following keys:
#-------------------------------------------------------------------------------
#	:rank          => Sets the raid rank.
#	:style         => Sets the raid type (Raid Dens ignore this).
#	:size          => Sets the battle size on the player's size.
#	:partner       => Sets a partner trainer.
#	:turn_count    => Sets the raid turn counter.
#	:ko_count      => Sets the raid KO counter.
#	:shield_hp     => Sets the raid shield HP.
#	:extra_actions => Sets extra raid actions.
#	:support_moves => Sets extra support moves.
#	:spread_moves  => Sets extra spread moves.
#	:loot          => Sets bonus loot (Raid Den only).
#	:online        => Sets the online status (Raid Den only).
#===============================================================================
class RaidBattle
  def self.start(pkmn = {}, rules = {})
	try_raid = GameData::RaidType.try_get(rules[:style])
	rules[:style] = :Basic if !try_raid || !try_raid.available
	#---------------------------------------------------------------------------
    # Checks for online Raid Den data.
	if rules[:raid_den] && !pkmn.is_a?(Pokemon)
	  useOnlineData = (rules.has_key?(:online)) ? rules[:online] : rand(3) == 0
	  rules[:online] = false
	  if useOnlineData
	    species, pkmn_data, raid_data = pbLoadLiveRaidData
	    if !species[0].nil? && rules[:style] == raid_data[:style] && pbHasBadgesForRank(raid_data[:rank])
		  setBattleRule("editWildPokemon", pkmn_data)
          pkmn = GameData::Species.get_species_form(*species).id
		  rules = raid_data
	    end
	  end
	end
	#---------------------------------------------------------------------------
    # Sets up and validates general raid properties.
	rules[:rank] = pbDefaultRaidProperty(pkmn, :rank, rules) if !rules[:rank]
	rules[:rank] = (rules[:rank] > 0) ? [rules[:rank], 7].min : 1
	if rules[:partner]
	  rules[:size] = 1
	  setBattleRule("2v1")
	else
	  if rules[:size]
	    rules[:size] = 1 if rules[:size] <= 0
	    rules[:size] = 3 if rules[:size] > 3
	  else
	    rules[:size] = (Settings::RAID_BASE_PARTY_SIZE > 0) ? [Settings::RAID_BASE_PARTY_SIZE, 3].min : 1
	  end
	  rules[:size] = $player.able_pokemon_count if $player.able_pokemon_count < rules[:size]
	  setBattleRule(sprintf("%dv1", rules[:size]))
	end
	pkmn = self.generate_raid_foe(pkmn, rules)
    #---------------------------------------------------------------------------
    # Battle start.
	old_partner = $PokemonGlobal.partner
	pbDeregisterPartner
    if rules[:raid_den]
	  decision = pbRaidDenEntry(pkmn, rules)
	else
	  rules[:pokemon] = pkmn
	  pbSetRaidProperties(rules)
	  pbFadeOutIn { decision = WildBattle.start_core(pkmn) }
    end
	#---------------------------------------------------------------------------
    # Battle end.
	$PokemonGlobal.partner = old_partner
	$game_temp.transition_animation_data = nil
	if rules[:pokemon]
      EventHandlers.trigger(:on_wild_battle_end, 
		rules[:pokemon].species_data.id, rules[:pokemon].level, decision)
	end
    return [1, 4].include?(decision)
  end
  
  #-----------------------------------------------------------------------------
  # Generates the raid Pokemon based on entered data.
  #-----------------------------------------------------------------------------
  def self.generate_raid_foe(pkmn, rules)
    return pkmn if pkmn.is_a?(Pokemon)
    if pkmn.nil? || pkmn.is_a?(Hash)
      pkmn = {} if pkmn.nil?
	  filter = []
	  enc_list = $PokemonEncounters.get_encounter_list(pkmn[:encounter])
      raidRanks = GameData::Species.generate_raid_lists(rules[:style])
      raidRanks[rules[:rank]].each do |s|
        sp = GameData::Species.get(s)
        next if pkmn[:type]       && !sp.types.include?(pkmn[:type])
        next if pkmn[:habitat]    && sp.habitat != pkmn[:habitat]
        next if pkmn[:generation] && sp.generation != pkmn[:generation]
		next if pkmn[:encounter]  && !enc_list.include?(sp.id)
        filter.push(s)
      end
      pkmn = filter.sample
    end
	species = pbDefaultRaidProperty(pkmn, :species, rules)
    level = pbDefaultRaidProperty(species, :level, rules)
    pkmn = Pokemon.new(species, level)
	pkmn.setRaidBossAttributes(rules)
	return pkmn
  end
end

#===============================================================================
# Generates a list of eligible raid species when :encounter is set in "pkmn" hash.
#===============================================================================
class PokemonEncounters
  def get_encounter_list(enc_type)
    enc_list = []
    return enc_list if !enc_type
	species = []
	enc_type = find_valid_encounter_type_for_time(enc_type, pbGetTimeNow)
	return enc_list if !@encounter_tables[enc_type]
	@encounter_tables[enc_type].each do |enc| 
	  next if species.include?(enc[1])
	  species.push(enc[1])
	end
    species.each do |sp|
      sp_data = GameData::Species.get(sp)
	  if MultipleForms.hasFunction?(sp, "getForm")
	    try_pkmn = Pokemon.new(sp, 1)
		check_form = try_pkmn.form
	  else
	    check_form = sp_data.form
	  end
	  sp_data.get_family_species.each do |fam|
	    if fam == sp
		  enc_list.push(fam)
		else
		  id = GameData::Species.get_species_form(fam, check_form).id
		  base_form = GameData::Species.get(id).base_form
		  next if base_form > 0 && base_form != check_form
		  enc_list.push(id)
		end
	  end
    end
	return enc_list
  end
end

#===============================================================================
# Returns whether the player has enough badges for a certain raid rank.
#===============================================================================
def pbHasBadgesForRank(rank)
  badges = $player.badge_count
  return true if !rank || badges >= 8
  return true if rank == 4 && badges >= 6
  return true if rank == 3 && badges >= 3
  return true if rank <= 2
  return false
end

#===============================================================================
# Applies all raid attributes to Pokemon in a raid setting.
#===============================================================================
class Pokemon

  #-----------------------------------------------------------------------------
  # Applies raid attributes to rental Pokemon.
  #-----------------------------------------------------------------------------
  def setRaidRentalAttributes(style = :Basic, rank = 4)
    self.shadow = nil if self.shadow
	#---------------------------------------------------------------------------
	# Various settings related to the raid style.
	self.dynamax_able = false if defined?(dynamax_able) && style != :Max
	self.terastal_able = false if defined?(terastal_able) && style != :Tera
	case style
	when :Ultra
	  self.makeUnUltra
	when :Max
	  self.dynamax_lvl = 5
	  if species_data.gmax_move
	    self.gmax_factor = true
		self.form = species_data.ungmax_form
	  end
	when :Tera
	  self.makeUnterastal
	  self.tera_type = :Random if rank > 2
	end
	self.form
	#---------------------------------------------------------------------------
	# Compiles a moveset suited for raid battles.
	self.moves.clear
	moves_to_learn = []
	raid_moves = self.getRaidMoves(style, true).clone
	move_categories = [:other, :primary, :status]
	loop do
	  move_categories.length.times do |i|
	    category = move_categories[i]
	    if !raid_moves.has_key?(category) || raid_moves[category].empty?
		  move_categories[i] = nil
		else
		  m = raid_moves[category].sample
		  moves_to_learn.push(m) if !moves_to_learn.include?(m)
		  raid_moves[category].delete(m)
	      move_categories[i] = nil if raid_moves[category].empty?
		  break if moves_to_learn.length >= MAX_MOVES
		end
	  end
	  move_categories.compact!
	  break if move_categories.empty?
	  break if moves_to_learn.length >= MAX_MOVES
	end
	moves_to_learn.each { |m| self.learn_move(m) }
	if style == :Ultra
	  self.item = GameData::Item.get_compatible_crystal(self)
	end
	#---------------------------------------------------------------------------
	# May randomly set Hidden Ability.
	if !species_data.hidden_abilities.empty? && rank >= 3
      self.ability_index = 2 if rand(10) < rank
    end
	#---------------------------------------------------------------------------
	# Sets the IV's.
	case rank
    when 1 then maxIVs = 1
    when 2 then maxIVs = 1
    when 3 then maxIVs = 2
    when 4 then maxIVs = 3
    when 5 then maxIVs = 4
    when 6 then maxIVs = 5
    when 7 then maxIVs = 6
    end
	iv_stats = []
	GameData::Stat.each_main do |s|
      next if self.iv[s.id] == IV_STAT_LIMIT
      iv_stats.push(s.id)
	end
	tries = 0
	iv_stats.shuffle.each do |stat|
      break if tries >= maxIVs
      self.iv[stat] = IV_STAT_LIMIT
      tries += 1
	end
	#---------------------------------------------------------------------------
	# Sets the EV's.
	ev_stats = [nil, :DEFENSE, :SPECIAL_DEFENSE]
	ev_stats.push(:ATTACK) if self.moves.any? { |m| m.physical_move? }
	ev_stats.push(:SPECIAL_ATTACK) if self.moves.any? { |m| m.special_move? }
	ev_stats.push(:SPEED) if self.baseStats[:SPEED] > 60
	stat = ev_stats.sample
	self.ev[:HP] = EV_STAT_LIMIT
	if GameData::Stat.exists?(stat)
	  self.ev[stat] = EV_STAT_LIMIT
	else
	  GameData::Stat.each_main_battle do |s|
	    self.ev[s.id] = (EV_STAT_LIMIT / 5).floor
	  end
	end
	self.calc_stats
	self.heal
  end
  
  #-----------------------------------------------------------------------------
  # Applies raid attributes to wild Pokemon.
  #-----------------------------------------------------------------------------
  def setRaidBossAttributes(rules)
    return if !species_data.raid_species?(rules[:style])
	editedPkmn = $game_temp.battle_rules["editWildPokemon"].clone
	#---------------------------------------------------------------------------
	# Sets default values for various attributes related to form and cosmetics.
	EventHandlers.trigger(:on_wild_pokemon_created, self)
	if pbInRaidAdventure?
      self.shiny = false
      self.super_shiny = false
    end
	self.shadow = nil if self.shadow
	self.form #if !species_data.raid_species?(rules[:style])
	#---------------------------------------------------------------------------
	# Applies various attributes related to the raid style.
	case rules[:style]
	when :Ultra
	  if MultipleForms.hasFunction?(self, "getUltraItem")
	    self.form_simple = 1 if isSpecies?(:NECROZMA)
		self.item = MultipleForms.call("getUltraItem", self)
	    self.makeUltra
	  elsif !self.hasZCrystal? && editedPkmn && editedPkmn[:moves]
	    self.item = GameData::Item.get_compatible_crystal(self)
	  end
	when :Max
	  self.gmax_factor = true if species_data.gmax_move
	  self.dynamax_lvl = 10
	  self.dynamax = true
	when :Tera
	  self.tera_type = :Random if rules[:rank] > 2 && !(editedPkmn && editedPkmn[:tera_type])
	  self.terastallized = true
	  self.forced_form = @form + 4 if isSpecies?(:OGERPON)
	end
	#---------------------------------------------------------------------------
	# Determines the max number of IV's and the amount of HP scaling to apply.
    case rules[:rank]
    when 1 then maxIVs = 1; hpBoost = 4
    when 2 then maxIVs = 1; hpBoost = 6
    when 3 then maxIVs = 2; hpBoost = 8
    when 4 then maxIVs = 3; hpBoost = 12
    when 5 then maxIVs = 4; hpBoost = 20
    when 6 then maxIVs = 5; hpBoost = 24
    when 7 then maxIVs = 6; hpBoost = 30
    end
	hpBoost -= ((GameData::GrowthRate.max_level - self.level) / 10).floor - 1
	hpBoost = (hpBoost / 2).floor if rules[:style] == :Max
	hpBoost = 2 if hpBoost < 1
	#---------------------------------------------------------------------------
	# Forces required boss immunities if other immunities are already set.
	if editedPkmn && editedPkmn[:immunities]
      self.immunities.push(:RAIDBOSS, :FLINCH, :PPLOSS, :ITEMREMOVAL, :OHKO, :SELFKO, :ESCAPE)
      self.immunities.uniq!
    end
	#---------------------------------------------------------------------------
	# Forces the Mightiest Mark memento on Rank 7 raid bosses if no memento is set.
	if rules[:rank] == 7 && defined?(self.memento) && !(editedPkmn && editedPkmn[:memento])
	  self.memento = :MIGHTIESTMARK
	end
	#---------------------------------------------------------------------------
	# Applies values if unset via the "editWildPokemon" battle rule.
	[:hp_level, :immunities, :ability_index, :iv, :moves].each do |property|
	  next if editedPkmn && editedPkmn[property]
	  case property
	  #-------------------------------------------------------------------------
	  # Applies boss HP scaling.
	  when :hp_level
	    self.hp_level = hpBoost
	  #-------------------------------------------------------------------------
	  # Applies boss immunities.
	  when :immunities
	    self.immunities = [:RAIDBOSS, :FLINCH, :PPLOSS, :ITEMREMOVAL, :OHKO, :SELFKO, :ESCAPE]
	  #-------------------------------------------------------------------------
	  # Has a chance to set Hidden Ability, based on rank.
	  when :ability_index
	    if !species_data.hidden_abilities.empty? && rules[:rank] >= 3
          self.ability_index = 2 if rand(10) < rules[:rank]
        end
	  #-------------------------------------------------------------------------
	  # Compiles moves suited for a raid boss.
	  when :moves
		self.moves.clear
	    moves_to_learn = []
	    move_categories = [:primary, :secondary, :other, :status]
	    raid_moves = self.getRaidMoves(rules[:style]).clone
	    loop do
	      move_categories.length.times do |i|
	        category = move_categories[i]
	        if !raid_moves.has_key?(category) || raid_moves[category].empty?
		      move_categories[i] = nil
		    else
		      m = raid_moves[category].sample
		      moves_to_learn.push(m) if !moves_to_learn.include?(m)
		      raid_moves[category].delete(m)
	          move_categories[i] = nil if raid_moves[category].empty?
		      break if moves_to_learn.length >= MAX_MOVES
		    end
	      end
	      move_categories.compact!
	      break if move_categories.empty?
	      break if moves_to_learn.length >= MAX_MOVES
	    end
	    moves_to_learn.each { |m| self.learn_move(m) }
		if raid_moves.has_key?(:support) && !rules.has_key?(:support_moves)
		  rules[:support_moves] = raid_moves[:support]
		end
		if raid_moves.has_key?(:spread) && !rules.has_key?(:spread_moves)
		  rules[:spread_moves] = raid_moves[:spread]
		end
		if rules[:style] == :Ultra && !self.hasZCrystal? && !self.ultra?
		  self.item = GameData::Item.get_compatible_crystal(self)
		end
	  #-------------------------------------------------------------------------
	  # Sets the necessary number of max IV's, based on rank.
	  when :iv
	    stats = []
		GameData::Stat.each_main do |s|
          next if self.iv[s.id] == IV_STAT_LIMIT
          stats.push(s.id)
		end
		tries = 0
		stats.shuffle.each do |stat|
          break if tries >= maxIVs
          self.iv[stat] = IV_STAT_LIMIT
          tries += 1
		end
	  end
	end
    self.calc_stats
  end
end

#===============================================================================
# General utility for setting default raid property values.
#===============================================================================
def pbDefaultRaidProperty(pkmn, property, rules)
  rank = rules[:rank]
  case property
  #-----------------------------------------------------------------------------
  # Determines the species of the raid Pokemon in this raid battle.
  when :species
    species_data = GameData::Species.try_get(pkmn)
    return :DITTO if !species_data
    if species_data.form > 0 && !species_data.raid_species?(rules[:style])
	  pkmn = species_data.species
      species_data = GameData::Species.get(pkmn)
	  rules[:rank] = species_data.raid_ranks.sample if !species_data.raid_ranks.include?(rules[:rank])
    end
	pkmn = :DITTO if !species_data.raid_species?(rules[:style])
    return pkmn
  #-----------------------------------------------------------------------------
  # Determines the level of the raid Pokemon in this raid battle.
  when :level
    if rank.nil?
      case pkmn
      when Integer then rank = pkmn
      when Pokemon then rank = pkmn.species_data.raid_ranks.sample
      when Symbol  then rank = GameData::Species.get(pkmn).raid_ranks.sample
      end
    end
    case rank
    when 1 then return 10 + rand(6)
    when 2 then return 20 + rand(6)
    when 3 then return 30 + rand(6)
    when 4 then return 40 + rand(6)
    when 5 then return 65 + rand(6)
    when 6 then return 75 + rand(6)
    when 7 then return 100
	else        return 1
    end
  #-----------------------------------------------------------------------------
  # Determines the rank for this raid battle.
  when :rank
    case pkmn
    when Pokemon
	  case pkmn.level
	  when 0..19  then return 1
	  when 20..29 then return 2
	  when 30..39 then return 3
	  when 40..64 then return 4
	  when 65..74 then return 5
	  when 75..99 then return 6
	  else             return 7
	  end
    when Symbol
	  pkmn = GameData::Species.try_get(pkmn)
	  if pkmn && pkmn.raid_species?(rules[:style])
	    raid_ranks = pkmn.raid_ranks
        return (rank && raid_ranks.include?(rank)) ? rank : raid_ranks.sample
	  end
    end
    odds = rand(100)
    badges = $player.badge_count
    if badges >= 8
      return (odds < 40) ? 3 : [4, 5].sample
    elsif badges >= 6
      return (odds < 40) ? [1, 2].sample : [3, 4].sample
    elsif badges >= 3
      return (odds < 40) ? 2 : [1, 3].sample
    else
      return (odds < 80) ? 1 : 2
    end
  #-----------------------------------------------------------------------------
  # Determines the initial KO counter for this raid battle.
  when :ko_count
    size = (rules[:partner]) ? 2 : rules[:size]
    return 1 if size == 1
	return rules[:ko_count] if rules.has_key?(:ko_count)
    count = Settings::RAID_BASE_KNOCK_OUTS
    count += 1 if size == 2
    count += 1 if rank && rank > 5
    return count
  #-----------------------------------------------------------------------------
  # Determines the initial turn counter for this raid battle.
  when :turn_count
	return rules[:turn_count] if rules.has_key?(:turn_count)
    count = Settings::RAID_BASE_TURN_LIMIT
	size = ((rules[:partner]) ? 2 : rules[:size]) || Settings::RAID_BASE_PARTY_SIZE
    count += size if size < 3
    count += (rank / 2).ceil if rank
    return count
  #-----------------------------------------------------------------------------
  # Determines the amount of HP raid Pokemon's shields will have in this raid battle.
  when :shield_hp
    count = rules.has_key?(:shield_hp)
	return nil if count && !rules[:shield_hp]
	count = rules[:shield_hp]
	if rank && !count
	  case rank
	  when 1, 2 then count = 4
	  when 3    then count = 5
	  when 4    then count = 6
	  when 5    then count = 7
	  when 6, 7 then count = 8
	  end
	  size = ((rules[:partner]) ? 2 : rules[:size]) || Settings::RAID_BASE_PARTY_SIZE
	  count -= [2, 1, 0][size - 1]
	else
	  count = 0 if !count
	end
	return (count > 8) ? 8 : count
  #-----------------------------------------------------------------------------
  # Determines the kinds of extra actions the raid Pokemon may perform.
  when :extra_actions
	return rules[:extra_actions] if rules.has_key?(:extra_actions)
	actions = []
	actions.push(:reset_drops)  if rank && rank >= 3
	actions.push(:reset_boosts) if rank && rank >= 4
	actions.push(:drain_cheer)  if rank && rank >= 5
	return actions
  end
end

#===============================================================================
# Applies all relevant battle rules and properties for a raid battle.
#===============================================================================
def pbSetRaidProperties(rules)
  $game_temp.transition_animation_data = [rules[:pokemon], rules[:style]]
  [:ko_count, :turn_count, :shield_hp, :extra_actions].each do |r|
	rules[r] = pbDefaultRaidProperty(rules[:pokemon], r, rules)
  end
  rules[:max_koCount] = rules[:ko_count]
  rules[:max_turnCount] = rules[:turn_count]
  raidType = GameData::RaidType.get(rules[:style])
  setBattleRule("raidBattle", rules)
  battleRules = $game_temp.battle_rules
  if !battleRules["backdrop"]
    bg = base = nil
    case battleRules["environment"]
	when raidType.battle_environ     then bg = raidType.battle_bg
    when :None                       then bg = "city"
    when :Grass, :TallGrass, :Puddle then bg = "field"
    when :MovingWater, :StillWater   then bg = "water"
    when :Underwater                 then bg = "underwater"
	when :Cave                       then bg = "cave3"
    when :Rock, :Volcano, :Sand      then bg = "rocky"
    when :Forest, :ForestGrass       then bg = "forest"
    when :Snow, :Ice                 then bg = "snow"
    when :Graveyard                  then bg = "distortion"
    end
    case battleRules["environment"]
	when raidType.battle_environ     then base = raidType.battle_base
    when :Grass, :TallGrass          then base = "grass"
    when :Sand                       then base = "sand"
    when :Ice                        then base = "ice"
    else                                  base = bg
    end
    setBattleRule("base", base) if base
    setBattleRule("backdrop", bg) if bg
  end
  if !battleRules["battleBGM"]
    bgm = raidType.battle_bgm
	if rules[:rank] == 7 || pbInRaidAdventure? && pbRaidAdventureState.boss_battled
      track = bgm[1]
	else
	  track = bgm[0]
	end
	species = (rules[:pokemon]) ? rules[:pokemon].species_data.id : nil
    case rules[:style]
    when :Ultra then track = bgm[2] if [:NECROZMA_3, :NECROZMA_4].include?(species)
    when :Max   then track = bgm[2] if species == :ETERNATUS_1
    when :Tera  then track = bgm[2] if species == :TERAPAGOS_2
    end 
	if pbResolveAudioFile(track)
      setBattleRule("battleBGM", track)
	  setBattleRule("lowHealthBGM", "")
	end
  end
  setBattleRule("canLose")
  setBattleRule("setSlideSprite", "still") if !battleRules["slideSpriteStyle"]
  setBattleRule("databoxStyle", :Long) if !battleRules["databoxStyle"]
  pbRegisterPartner(*rules[:partner][0..2]) if rules[:partner]
  case rules[:style]
  when :Ultra then setBattleRule("noZMoves", :Player)
  when :Max   then setBattleRule("noDynamax", :Player)
  when :Tera  then setBattleRule("noTerastallize", :Player)
  end
end

#===============================================================================
# Handler for scaling a partner trainer's attributes to suit a particular raid.
#===============================================================================
EventHandlers.add(:on_trainer_load, :raid_partner,
  proc { |trainer|
    next if !trainer
	if pbInRaidAdventure?
	  rules = {:rank  => 5,
	           :style => pbRaidAdventureState.style}
	else
	  rules = $game_temp.battle_rules["raidBattle"]
	  next if !rules || rules[:partner][3]
	end
	items = {
	  :Basic => [:MEGARING],
	  :Ultra => [:ZRING], 
	  :Max   => [:DYNAMAXBAND], 
	  :Tera  => [:TERAORB]
	}
	trainer.items = items[rules[:style]]
	pkmn = trainer.party.last
	pkmn.level = pbDefaultRaidProperty(pkmn, :level, rules)
	raid_moves = pkmn.getRaidMoves(rules[:style], true)
	[:primary, :secondary, :status, :other].each do |key|
      next if !raid_moves.has_key?(key)
      m = raid_moves[key].sample
	  next if pkmn.hasMove?(m)
	  pkmn.learn_move(m)
    end
	if rules[:style] == :Ultra
	  pkmn.item = GameData::Item.get_compatible_crystal(pkmn)
	elsif rules[:style] != :Basic
	  pkmn.item = nil if pkmn.hasItem? && GameData::Item.get(pkmn.item_id).is_mega_stone?
	end
	pkmn.calc_stats
	trainer.party = [pkmn]
  }
)