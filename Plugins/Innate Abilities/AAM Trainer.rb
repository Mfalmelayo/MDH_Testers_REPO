
module GameData
  class Trainer
  #-----------------------------------------------------------------------------
  # COMPATIBILITY FIX - Previously overwrote Essentials Deluxe code.
  #-----------------------------------------------------------------------------
  # SCHEMA is just a hash, so you don't need to replace th entire hash to add
  # your data. You can just add it to the existing hash.
  #-----------------------------------------------------------------------------
    SCHEMA["AAM"] = [:abilityMutation, "b"]

  #-----------------------------------------------------------------------------
  # COMPATIBILITY FIX - Previously overwrote Essentials Deluxe code.
  #-----------------------------------------------------------------------------
  # Original to_trainer just returns a trainer object after setting all the
  # attributes to the Pokemon in that trainer's party. Because of this, you can
  # just alias this method and iterate through their party to edit any additional
  # attributes you want.
  #-----------------------------------------------------------------------------
    alias aam_to_trainer to_trainer
    def to_trainer
      trainer = aam_to_trainer
      trainer.party.each_with_index do |pkmn, i|
        pkmn_data = @pokemon[i]
        pkmn.abilityMutation = true if pkmn_data[:abilityMutation]
        pkmn.calc_stats
      end
      return trainer
    end
  end
end
