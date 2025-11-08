module GameData
  class Species
    attr_reader :innates

    alias original_initialize initialize
    def initialize(hash)
      @innates = hash[:innates] || []
      original_initialize(hash)
    end

	class << self
      alias_method :original_schema, :schema
	  alias_method :original_editor_properties, :editor_properties

      def schema(compiling_forms = false)
        ret = original_schema(compiling_forms)
        ret["Innates"] = [:innates, "*e", :Ability]
        return ret
      end

      def editor_properties
        ret = original_editor_properties
        ret << ["Innates", AbilitiesProperty.new, _INTL("Abilities the pokemon always had")]
        return ret
      end
	end
  end
end