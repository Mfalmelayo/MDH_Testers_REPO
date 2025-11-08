# Ensure item IDs are valid
def pbDynamicItemList(*args)
  ret = []
  args.each { |arg| ret.push(arg) if GameData::Item.exists?(arg) }
  return ret
end

# Define item pools for each type and level range
PICKUP_ITEM_TABLES = {
  :NORMAL => {
    :common => {
      1..20 => [:POTION, :ANTIDOTE, :SUPERPOTION],
      21..40 => [:GREATBALL, :REPEL, :STARDUST],
      41..60 => [:FULLHEAL, :HYPERPOTION, :SILKSCARF],
      61..80 => [:ULTRABALL, :REVIVE, :SILKSCARF],
      81..100 => [:PPUP, :FULLRESTORE, :SILKSCARF]
    },
    :rare => {
      1..20 => [:LUXURYBALL, :FULLHEAL, :NORMALTERASHARD],
      21..40 => [:DUSKBALL, :HYPERPOTION, :NORMALTERASHARD],
      41..60 => [:MAXPOTION, :KINGSROCK, :NORMALTERASHARD],
      61..80 => [:RARECANDY, :LEFTOVERS, :NORMALTERASHARD],
      81..100 => [:FULLRESTORE, :BEASTBALL, :NORMALTERASHARD, :NORMALIUMZ]
    }
  },
  :GHOST => {
    :common => {
      1..20 => [:POTION, :BURNHEAL, :SUPERPOTION, :SPELLTAG],
      21..40 => [:MOONBALL, :PPUP, :STARDUST, :SPELLTAG],
      41..60 => [:FULLHEAL, :HYPERPOTION, :SPELLTAG, :MOONBALL],
      61..80 => [:ULTRABALL, :REVIVE, :SPELLTAG, :MOONBALL],
      81..100 => [:ZINC, :MAXPOTION, :SPELLTAG, :MOONBALL]
    },
    :rare => {
      1..20 => [:DUSKBALL, :FULLHEAL, :GHOSTTERASHARD],
      21..40 => [:RELICSILVER, :SPELLTAG, :GHOSTTERASHARD],
      41..60 => [:MAXPOTION, :REAPERCLOTH, :GHOSTTERASHARD],
      61..80 => [:EXPCANDYXL, :MAXREVIVE, :GHOSTTERASHARD],
      81..100 => [:SPELLTAG, :BEASTBALL, :GHOSTTERASHARD, :GHOSTIUMZ]
    }
  },
  :ELECTRIC => {
    :common => {
      1..20 => [:PARALYZEHEAL, :POKEBALL, :THUNDERSTONE, :FASTBALL],
      21..40 => [:SUPERPOTION, :GREATBALL, :THUNDERSTONE, :FASTBALL],
      41..60 => [:HYPERPOTION, :ULTRABALL, :ELECTIRIZER, :FASTBALL],
      61..80 => [:FULLRESTORE, :RARECANDY, :FASTBALL],
      81..100 => [:CALCIUM, :ZAPPLATE, :ELECTIRIZER, :FASTBALL]
    },
    :rare => {
      1..20 => [:MAGNET, :LIGHTBALL, :ELECTRICTERASHARD],
      21..40 => [:ELECTRICSEED, :THUNDERSTONE, :ELECTRICTERASHARD],
      41..60 => [:LIGHTCLAY, :RARECANDY, :ELECTRICTERASHARD],
      61..80 => [:CHOICESCARF, :LIFEORB, :ELECTRICTERASHARD],
      81..100 => [:ELECTRIUMZ, :MAGNET, :ELECTRICTERASHARD]
    }
  },
  :FLYING => {
    :common => {
      1..20 => [:HEALTHFEATHER, :MUSCLEFEATHER, :RESISTFEATHER, :GENIUSFEATHER, :SWIFTFEATHER, :CLEVERFEATHER],
      21..40 => [:HEALTHFEATHER, :MUSCLEFEATHER, :RESISTFEATHER, :GENIUSFEATHER, :SWIFTFEATHER, :CLEVERFEATHER],
      41..60 => [:HEALTHFEATHER, :MUSCLEFEATHER, :RESISTFEATHER, :GENIUSFEATHER, :SWIFTFEATHER, :CLEVERFEATHER],
      61..80 => [:PPUP, :RARECANDY, :FLOATSTONE],
      81..100 => [:SKYPLATE, :SHARPBEAK, :CHOICESCARF]
    },
    :rare => {
      1..20 => [:SHARPBEAK, :FLYINGGEM, :FLYINGTERASHARD],
      21..40 => [:SHARPBEAK, :EVIOLITE, :RARECANDY, :FLYINGTERASHARD],
      41..60 => [:SHARPBEAK, :SKYPLATE, :POWERHERB, :FLYINGTERASHARD],
      61..80 => [:SHARPBEAK, :LEFTOVERS, :LIFEORB, :FLYINGTERASHARD],
      81..100 => [:SHARPBEAK, :FLYINIUMZ, :CHOICEBAND, :FLYINGTERASHARD]
    }
  },
  :FIRE => {
    :common => {
      1..20 => [:BURNHEAL, :POKEBALL, :FIRESTONE],
      21..40 => [:SUPERPOTION, :GREATBALL, :FIRESTONE],
      41..60 => [:HYPERPOTION, :ULTRABALL, :MAGMARIZER],
      61..80 => [:FULLRESTORE, :RARECANDY],
      81..100 => [:FLAMEPLATE, :FLAMEORB, :MAGMARIZER]
    },
    :rare => {
      1..20 => [:CHARCOAL, :HEATROCK, :FIRETERASHARD],
      21..40 => [:CHARCOAL, :EVIOLITE, :FIRESTONE, :FIRETERASHARD],
      41..60 => [:CHARCOAL, :LEFTOVERS, :LIFEORB, :FIRETERASHARD],
      61..80 => [:CHARCOAL, :CHOICESCARF, :HEATROCK, :FIRETERASHARD],
      81..100 => [:CHARCOAL, :FIRIUMZ, :FLAMEORB, :FIRETERASHARD]
    }
  },
  :GROUND => {
    :common => {
      1..20 => [:POTION, :RAREBONE, :SAFARIBALL],
      21..40 => [:SUPERPOTION, :RAREBONE, :SAFARIBALL],
      41..60 => [:HYPERPOTION, :SAFARIBALL, :PASSHOBERRY],
      61..80 => [:FULLRESTORE, :RARECANDY, :SAFARIBALL],
      81..100 => [:EARTHPLATE, :FRESHSTARTMOCHI, :HPUP]
    },
    :rare => {
      1..20 => [:SOFTSAND, :RELICCOPPER, :LEFTOVERS, :GROUNDTERASHARD],
      21..40 => [:SOFTSAND, :RELICCOPPER, :LEFTOVERS, :GROUNDTERASHARD, :RELICSILVER],
      41..60 => [:SOFTSAND, :RELICSILVER, :LEFTOVERS, :GROUNDTERASHARD, :EARTHPLATE],
      61..80 => [:SOFTSAND, :RELICSILVER, :RELICGOLD, :GROUNDTERASHARD, :EARTHPLATE],
      81..100 => [:SOFTSAND, :RELICGOLD, :GROUNDIUMZ, :GROUNDTERASHARD]
    }
  }
  # Add other types here as needed
}

# Default loot table if Pokémon's type is not in PICKUP_ITEM_TABLES
PICKUP_DEFAULT_TABLE = {
  :common => {
    1..20 => [:POTION, :POKEBALL, :REPEL],
    21..40 => [:SUPERPOTION, :GREATBALL, :ANTIDOTE],
    41..60 => [:FULLHEAL, :HYPERPOTION, :STARDUST],
    61..80 => [:ULTRABALL, :MAXPOTION, :STARPIECE],
    81..100 => [:FULLRESTORE, :RARECANDY, :STARPIECE]
  },
  :rare => {
    1..20 => [:NUGGET, :RARECANDY],
    21..40 => [:MAXREVIVE, :KINGSROCK],
    41..60 => [:CHOICESPEC, :LIFEORB],
    61..80 => [:LEFTOVERS, :HYPERPOTION],
    81..100 => [:PPMAX, :RARECANDY]
  }
}

def pbPickup(pkmn)
  # Check if Pokémon has Pickup or EndlessGreed as an active ability or innate
  has_pickup = pkmn.hasAbility?(:PICKUP) || pkmn.hasAbility?(:ENDLESSGREED) ||
               getActiveInnates(pkmn).include?(:PICKUP) || getActiveInnates(pkmn).include?(:ENDLESSGREED)
  return if pkmn.egg? || !has_pickup
  return unless rand(100) < 20 # 20% chance for Pickup to trigger, buffed from 10% in the 12/9/24 build.

  # Get the type-specific item pools
  types = pkmn.types
  combined_items = { common: [], rare: [] }

  # Check if any type rolls for the rare pool
  use_rare_pool = false
  types.each do |type|
    use_rare_pool ||= (rand(100) < 33) # 33% chance for each type to use the rare pool
  end

  types.each do |type|
    item_table = PICKUP_ITEM_TABLES[type] || PICKUP_DEFAULT_TABLE
    # Get the item tables for the current type and level
    level_range = item_table[:common].keys.find { |range| range.include?(pkmn.level) }
    next unless level_range
    if use_rare_pool
      combined_items[:rare].concat(item_table[:rare][level_range])
    else
      combined_items[:common].concat(item_table[:common][level_range])
    end
  end

  return if combined_items[:common].empty? && combined_items[:rare].empty?

  # Ensure combined item lists contain defined items
  valid_common_items = pbDynamicItemList(*combined_items[:common].uniq)
  valid_rare_items = pbDynamicItemList(*combined_items[:rare].uniq)
  return if valid_common_items.empty? && valid_rare_items.empty?

  # Select the item pool to use
  item_pool = use_rare_pool ? valid_rare_items : valid_common_items
  return if item_pool.empty?

  # Randomly choose an item from the pool
  item = item_pool.sample
  return if !item

  # Add the item to the player's bag instead of giving it to the Pokémon
  if $bag.add(item)
    if use_rare_pool
      pbMessage(_INTL("Oh? {1} found a rare {2}! Incredible!", pkmn.name, GameData::Item.get(item).name))
    else
      pbMessage(_INTL("{1} picked up a {2} and placed it in the bag.", pkmn.name, GameData::Item.get(item).name))
    end
  else
    pbMessage(_INTL("{1} tried to pick up a {2}, but the bag is full!", pkmn.name, GameData::Item.get(item).name))
  end
end
