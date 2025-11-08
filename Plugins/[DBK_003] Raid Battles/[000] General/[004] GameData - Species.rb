#===============================================================================
# Species properties.
#===============================================================================
module GameData
  class Species
    attr_reader :raid_ranks, :raid_style
	
	#---------------------------------------------------------------------------
	# Aliased for adding raid ranks.
	#---------------------------------------------------------------------------
    Species.singleton_class.alias_method :raid_schema, :schema
    def self.schema(compiling_forms = false)
      ret = self.raid_schema(compiling_forms)
      ret["RaidRanks"] = [:raid_ranks, "*u"]
	  ret["RaidStyle"] = [:raid_style, "*e", :RaidType]
      return ret
    end
    
    Species.singleton_class.alias_method :raid_editor_properties, :editor_properties
    def self.editor_properties
      properties = self.raid_editor_properties
      properties.concat([
        ["RaidRanks", RaidRankProperty,     _INTL("The raid ranks this species may appear in.")],
		["RaidStyle", RaidTypeProperty.new, _INTL("The types of raids this species may appear in.")],
      ])
      return properties
    end
    
    alias raid_initialize initialize
    def initialize(hash)
      raid_initialize(hash)
      @raid_ranks = hash[:raid_ranks] || []
	  @raid_style = hash[:raid_style] || []
    end
	
    alias raid_get_property_for_PBS get_property_for_PBS
    def get_property_for_PBS(key, writing_form = false)
      ret = raid_get_property_for_PBS(key, writing_form)
      case key
      when "RaidRanks"
	    if ret
		  ret.uniq!
		  ret.each_with_index do |r, i|
		    ret[i] = nil if r < 1
			ret[i] = nil if r > 6
		  end
		  ret.compact!
		  ret = ret[0..2] if ret.length > 3
		  ret = nil if ret.empty?
		end
	  when "RaidStyle"
		if ret
		  ret.uniq!
		  ret.compact!
		  ret = nil if ret.empty?
		end
      end
      return ret
    end
	
	#---------------------------------------------------------------------------
	# Returns an array of every possible move this species can learn.
	#---------------------------------------------------------------------------
	def get_family_moves
      moves = []
      baby = GameData::Species.get_species_form(get_baby_species, @form)
      prev = GameData::Species.get_species_form(get_previous_species, @form)
      if baby.species != @species
        baby.moves.each { |m| moves.push(m[1]) }
      end
      if prev.species != @species && prev.species != baby.species
        prev.moves.each { |m| moves.push(m[1]) }
      end
      @moves.each { |m| moves.push(m[1]) }
      @tutor_moves.each { |m| moves.push(m) }
      get_egg_moves.each { |m| moves.push(m) }
	  moves.uniq!
	  moves.sort!
      return moves
    end
    
	#---------------------------------------------------------------------------
	# Returns whether this species is capable of appearing in a certain type of raid.
	#---------------------------------------------------------------------------
    def raid_species?(style = :Basic)
      return false if @pokedex_form != @form
	  return false if @raid_ranks.empty? || @raid_ranks.first == 0
	  return false if !@raid_style.empty? && !@raid_style.include?(style)
	  return false if style != :Basic && (@mega_stone || @mega_move)
	  return false if style != :Basic && (@form > 0 && MultipleForms.hasFunction?(@species, "getPrimalForm"))
	  return false if style != :Ultra && (@form > 0 && MultipleForms.hasFunction?(@species, "getUltraForm"))
	  return false if style == :Max   && has_flag?("CannotDynamax")
	  return false if style != :Max   && defined?(@gmax_move) && @gmax_move
	  return false if style != :Max   && (@form > 0 && MultipleForms.hasFunction?(@species, "getEternamaxForm"))
	  return false if style == :Tera  && has_flag?("CannotTerastallize")
	  return false if style != :Tera  && (@form > 0 && MultipleForms.hasFunction?(@species, "getTerastalForm"))
	  return true
    end
    
	#---------------------------------------------------------------------------
	# Utility for generating lists of every species that appears in each raid rank.
	#---------------------------------------------------------------------------
    def self.generate_raid_lists(style = :Basic, bossFilter = false)
      ranks = Hash.new { |key, value| key[value] = [] }
      self.each do |s|
		next if !s.raid_species?(style)
		if s.form > 0
		  # Allows for G-Max Urshifu forms to be eligible.
		  if !(style == :Max && defined?(s.gmax_move) && s.gmax_move)
		    next if MultipleForms.hasFunction?(s.species, "getFormOnCreation")
		  end
		  # Allows for masked Ogerpon forms to be eligible.
		  if !(style == :Tera && s.species == :OGERPON)
		    next if MultipleForms.hasFunction?(s.species, "getForm")
		  end
		end
		# Additional filters applied for boss species found in Raid Adventures.
		if bossFilter && s.raid_ranks.include?(6)
		  case style
	      when :Basic, :Max
	        next if !s.has_flag?("Legendary")
	      when :Tera
	        next if !(s.has_flag?("Paradox") || [:OGERPON, :TERAPAGOS].include?(s.species))
	      when :Ultra
	        next if !(s.has_flag?("UltraBeast") || [:SOLGALEO, :LUNALA, :NECROZMA].include?(s.species))
	      end
		end
        s.raid_ranks.each { |r| ranks[r] << s.id }
        ranks[7] << s.id
      end
      return ranks
    end
  end
end

#===============================================================================
# Utility for setting Raid ranks in the species debug editor.
#===============================================================================
module RaidRankProperty
  def self.set(settingname, oldsetting)
    return oldsetting if !oldsetting
    properties = []
    data = []
    3.times do |r|
      properties[r] = [_INTL("Raid Rank [Slot {1}]", r), LimitProperty2.new(6),
                       _INTL("Raid Ranks that this species appears in.")]
      data[r] = oldsetting[r]
    end
    if pbPropertyList(settingname, data, properties, true)
      ret = []
      3.times { |r| ret[r] = data[r] }
      oldsetting = ret
    end
    return oldsetting
  end

  def self.defaultValue
    return []
  end

  def self.format(value)
    return value.join(",")
  end
end

class RaidTypeProperty < GameDataPoolProperty
  def initialize
    super(:RaidType, false, true)
  end
end