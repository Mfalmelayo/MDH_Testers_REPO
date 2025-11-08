module GameData
  class Innate
    attr_reader :id
    attr_reader :real_name
    attr_reader :real_description
   # attr_reader :expanded_info
    attr_reader :flags
    attr_reader :pbs_file_suffix

    DATA = {}
    DATA_FILENAME = "abilities.dat"
    PBS_BASE_FILENAME = "innates"

    extend ClassMethodsSymbols
    include InstanceMethods

    SCHEMA = {
      "SectionName" => [:id,               "m"],
      "Name"        => [:real_name,        "s"],
      "Description" => [:real_description, "q"],
  #    "Info"        => [:expanded_info,    "q"],
      "Flags"       => [:flags,            "*s"]
    }

    def initialize(hash)
      @id               = hash[:id]
      @real_name        = hash[:real_name]        || "Unnamed"
      @real_description = hash[:real_description] || "???"
    #  @expanded_info    = hash[:expanded_info]    || "???"
      @flags            = hash[:flags]            || []
      @pbs_file_suffix  = hash[:pbs_file_suffix]  || ""
    end

    # @return [String] the translated name of this ability
    def name
      return pbGetMessageFromHash(MessageTypes::ABILITY_NAMES, @real_name)
    end

    # @return [String] the translated description of this ability
    def description
      return pbGetMessageFromHash(MessageTypes::ABILITY_DESCRIPTIONS, @real_description)
    end
    
    # @return [String] the translated description of this ability
 #   def info
  #    return pbGetMessageFromHash(MessageTypes::ABILITY_EXPANDED_INFO, @@expanded_info)
  #  end

    def has_flag?(flag)
      return @flags.any? { |f| f.downcase == flag.downcase }
    end
  end
end