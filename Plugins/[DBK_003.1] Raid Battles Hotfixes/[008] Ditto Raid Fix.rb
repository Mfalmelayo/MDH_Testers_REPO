#===============================================================================
# Fix for Ditto and Pokemon without viable moves in Raid Battles
#===============================================================================
# Bug 1: Ditto causes baseMoves error in shield damage calculation
# Bug 2: Ditto/Wobbuffet/etc have no compatible damage-dealing moves in Tera Raids
# Root Cause 1: baseMoves attribute may not exist or be nil for transformed Pokemon
# Root Cause 2: Some Pokemon only learn non-damaging moves (Transform, Counter, etc)
#===============================================================================

#===============================================================================
# Fix baseMoves reference in raid shield damage calculation
#===============================================================================
# This prevents the error when Ditto (or transformed Pokemon) uses moves
#===============================================================================
class Battle::Battler
  alias ditto_raid_setRaidShieldHP setRaidShieldHP
  
  def setRaidShieldHP(amt, user = nil)
    return if !hasRaidShield?
    maxHP = @battle.raidRules[:shield_hp]
    oldShield = @shieldHP
    
    if $DEBUG && Input.press?(Input::CTRL)
      amt = (amt > 0) ? maxHP : -maxHP
    elsif user && amt < 0
      move = GameData::Move.try_get(user.lastMoveUsed)
      if move && move.damaging?
        amt -= 1 if user.pbOwnSide.effects[PBEffects::CheerOffense3] > 0
        case @battle.raidRules[:style]
        #-----------------------------------------------------------------------
        # Basic Raids
        #-----------------------------------------------------------------------
        when :Basic
          amt -= 1 if Effectiveness.super_effective?(@damageState.typeMod)
        #-----------------------------------------------------------------------
        # Ultra Raids
        #-----------------------------------------------------------------------
        when :Ultra
          # Fixed: Check if baseMoves exists and is not empty
          if user.respond_to?(:baseMoves) && user.baseMoves && !user.baseMoves.empty? && 
             user.lastMoveUsedIsZMove && move.zMove?
            amt -= 2
          elsif user.ultra?
            amt -= 1
          end
        #-----------------------------------------------------------------------
        # Max Raids
        #-----------------------------------------------------------------------
        when :Max
          # Fixed: Check if baseMoves exists and is not empty
          if user.respond_to?(:baseMoves) && user.baseMoves && !user.baseMoves.empty? && 
             user.dynamax? && move.dynamaxMove?
            amt -= 1
            amt -= 1 if user.gmax? && move.gmaxMove?
          end
        #-----------------------------------------------------------------------
        # Tera Raids
        #-----------------------------------------------------------------------
        when :Tera
          if user.tera?
            amt -= 1 if user.types.include?(user.lastMoveUsedType)
            amt -= 1 if user.typeTeraBoosted?(user.lastMoveUsedType)
          end
        end
      end
    end
    
    @shieldHP += amt
    @shieldHP = maxHP if @shieldHP > maxHP
    @shieldHP = 0 if @shieldHP < 0
    return if @shieldHP == oldShield
    
    PBDebug.log("[Raid mechanics] #{pbThis(true)} #{@index}'s raid shield HP changed (#{oldShield} => #{@shieldHP})")
    @battle.scene.pbRefreshOne(@index)
    @battle.scene.pbAnimateRaidShield(self, oldShield)
    @battle.pbDeluxeTriggers(@index, nil, "RaidShieldDamaged") if @shieldHP > 0 && @shieldHP < oldShield
    return if @shieldHP > 0
    return if @battle.pbAllFainted? || @battle.decision > 0
    
    @battle.pbDisplay(_INTL("The mysterious barrier disappeared!"))
    oldhp = @hp
    @hp -= @totalhp / 8
    @hp = 1 if @hp <= 1
    @battle.scene.pbHPChanged(self, oldhp)
    [:DEFENSE, :SPECIAL_DEFENSE].each do |stat|
      if pbCanLowerStatStage?(stat, self, nil, true)
        pbLowerStatStage(stat, 2, self, true, false, 0, true)
      end
    end
    @battle.raidRules.delete(:shield_hp)
    @battle.pbDeluxeTriggers(@index, nil, "RaidShieldBroken")
  end
end

#===============================================================================
# Fix for Pokemon without viable moves - Add failsafe moves
#===============================================================================
# This prevents Pokemon like Ditto from having empty movesets in raids
#===============================================================================
class Pokemon
  alias failsafe_setRaidBossAttributes setRaidBossAttributes
  
  def setRaidBossAttributes(rules)
    failsafe_setRaidBossAttributes(rules)
    
    # Check if the moveset is empty or has no damaging moves after raid generation
    has_damaging_move = @moves.any? { |m| 
      m && m.id && GameData::Move.get(m.id).power > 0
    }
    
    # If no viable moves, add failsafe moves based on raid style
    if @moves.empty? || !has_damaging_move
      primary_type = species_data.types[0]
      
      case rules[:style]
      when :Tera
        # For Tera Raids, add Tera Blast (works with any Tera type)
        learn_move(:TERABLAST)
        
      when :Ultra, :Max
        # For Ultra/Max Raids, add type-appropriate universal moves
        failsafe_moves = case primary_type
        when :NORMAL   then [:HYPERBEAM, :GIGAIMPACT, :BODYSLAM, :DOUBLEEDGE]
        when :FIRE     then [:FLAMETHROWER, :FIREBLAST, :OVERHEAT, :FLAREBLITZ]
        when :WATER    then [:SURF, :HYDROPUMP, :SCALD, :WATERFALL]
        when :ELECTRIC then [:THUNDERBOLT, :THUNDER, :DISCHARGE, :WILDCHARGE]
        when :GRASS    then [:ENERGYBALL, :GIGADRAIN, :LEAFSTORM, :SEEDBOMB]
        when :ICE      then [:ICEBEAM, :BLIZZARD, :FREEZEDRY, :ICICLECRASH]
        when :FIGHTING then [:CLOSECOMBAT, :AURASPHERE, :FOCUSBLAST, :DRAINPUNCH]
        when :POISON   then [:SLUDGEBOMB, :SLUDGEWAVE, :GUNKSHOT, :POISONJAB]
        when :GROUND   then [:EARTHQUAKE, :EARTHPOWER, :DRILLRUN, :HIGHHORSEPOWER]
        when :FLYING   then [:HURRICANE, :AIRSLASH, :BRAVEBIRD, :ACROBATICS]
        when :PSYCHIC  then [:PSYCHIC, :PSYSHOCK, :FUTURESIGHT, :ZENHEADBUTT]
        when :BUG      then [:BUGBUZZ, :XSCISSOR, :UTURN, :LEECHLIFE]
        when :ROCK     then [:STONEEDGE, :ROCKSLIDE, :POWERGEM, :ROCKBLAST]
        when :GHOST    then [:SHADOWBALL, :POLTERGEIST, :SHADOWCLAW, :PHANTOMFORCE]
        when :DRAGON   then [:DRACOMETEOR, :DRAGONPULSE, :OUTRAGE, :DRAGONCLAW]
        when :DARK     then [:DARKPULSE, :SUCKERPUNCH, :CRUNCH, :KNOCKOFF]
        when :STEEL    then [:FLASHCANNON, :IRONHEAD, :METEORMASH, :STEELBEAM]
        when :FAIRY    then [:MOONBLAST, :DAZZLINGGLEAM, :PLAYROUGH, :DRAININGKISS]
        else [:TACKLE, :TAKEDOWN, :BODYSLAM, :DOUBLEEDGE]
        end
        
        # Learn up to 4 moves from the failsafe list
        failsafe_moves.take(4).each { |m| learn_move(m) }
        
      else
        # For Basic Raids, use simple universal moves
        [:TACKLE, :BODYSLAM, :TAKEDOWN, :HYPERBEAM].take(4).each { |m| learn_move(m) }
      end
    end
  end
end

puts "Ditto Raid Fix loaded - Shield calculation + Moveset failsafe"
