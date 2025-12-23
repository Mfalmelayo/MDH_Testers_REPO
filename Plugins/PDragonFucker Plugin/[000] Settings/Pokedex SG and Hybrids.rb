module Compiler
  class << self
    alias __dexext_parseSpecies parseSpecies

    def parseSpecies(species)
      clonspecies = species.upcase
      clonspecies.gsub!(/^\s*/, "")
      clonspecies.gsub!(/\s*$/, "")

      # --- Original Essentials fixes ---
      clonspecies = "NIDORANmA" if clonspecies == "NIDORANMA"
      clonspecies = "NIDORANfE" if clonspecies == "NIDORANFE"
      
	  # --- Cultivation Pokemons ---
      clonspecies = "BRAIXENx" if clonspecies == "BRAIXENX"
      clonspecies = "RALTSx" if clonspecies == "RALTSX"
      clonspecies = "VAPOREONx" if clonspecies == "VAPOREONX"
      clonspecies = "VULPIXx" if clonspecies == "VULPIXX"
	  clonspecies = "MAWILEx" if clonspecies == "MAWILEX"
      clonspecies = "UMBREONsh" if clonspecies == "UMBREONSH"
      clonspecies = "UMBREONshD" if clonspecies == "UMBREONSHD"
      clonspecies = "EEVEEx" if clonspecies == "EEVEEX"
      clonspecies = "NOIBATx" if clonspecies == "NOIBATX"
      clonspecies = "MAROWAKx" if clonspecies == "MAROWAKX"
      clonspecies = "GALLADEh_1" if clonspecies == "GALLADEH_1"
      clonspecies = "GARDEVOIRdnd" if clonspecies == "GARDEVOIRDND"
	  clonspecies = "NOIVERNdnd" if clonspecies == "NOIVERNDND"
      clonspecies = "SPRIGATITOx" if clonspecies == "SPRIGATITOX"
      clonspecies = "FLORAGATOx" if clonspecies == "FLORAGATOX"
      clonspecies = "MEOWSCARADAx" if clonspecies == "MEOWSCARADAX"
      clonspecies = "SCORBUNNYx" if clonspecies == "SCORBUNNYX"
      clonspecies = "RABOOTx" if clonspecies == "RABOOTX"
      clonspecies = "CINDERACEx" if clonspecies == "CINDERACEX"
      clonspecies = "POPPLIOx" if clonspecies == "POPPLIOX"
      clonspecies = "BRIONNEx" if clonspecies == "BRIONNEX"
      clonspecies = "PRIMARINAx" if clonspecies == "PRIMARINAX"
      clonspecies = "DELPHOXmgq" if clonspecies == "DELPHOXMGQ"
      clonspecies = "HOUNDOOMx" if clonspecies == "HOUNDOOMX"
      clonspecies = "LOPUNNYsg" if clonspecies == "LOPUNNYSG"
      clonspecies = "AGGRONx" if clonspecies == "AGGRONX"
      clonspecies = "MARACTUSx" if clonspecies == "MARACTUSX"
      clonspecies = "MILTANKx" if clonspecies == "MILTANKX"
      clonspecies = "FEEBASh" if clonspecies == "FEEBASH"
      clonspecies = "MILOTICh" if clonspecies == "MILOTICH"
      clonspecies = "HOUNDOURh" if clonspecies == "HOUNDOURH"
      clonspecies = "HOUNDOOMh" if clonspecies == "HOUNDOOMH"
      clonspecies = "MARACTUSh" if clonspecies == "MARACTUSH"
      clonspecies = "TSAREENAsg" if clonspecies == "TSAREENASG"
      clonspecies = "FLYGONsg" if clonspecies == "FLYGONSG"
      clonspecies = "EMPOLEONsg" if clonspecies == "EMPOLEONSG"
      clonspecies = "CERULEDGEsg" if clonspecies == "CERULEDGESG"
      clonspecies = "SMEARGLEsg" if clonspecies == "SMEARGLESG"
      clonspecies = "SUICUNEh" if clonspecies == "SUICUNEH"
      clonspecies = "RAIKOUh" if clonspecies == "RAIKOUH"
      clonspecies = "ENTEIh" if clonspecies == "ENTEIH"
      clonspecies = "SERPERIORsg" if clonspecies == "SERPERIORSG"
      
      # add as many as you want here

      spec = GameData::Species.try_get(clonspecies)
      if !spec
        raise _INTL(
          "Undefined species constant name: {1}\n" \
          "Make sure the species is defined in PBS/pokemon.txt.\n{2}",
          species, FileLineData.linereport
        )
      end
      return spec.id
    end
  end
end
