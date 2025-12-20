#===============================================================================
# [Wondercard viewer] 3_RedeemTracker.rb
# Wonder Card Redeem Tracking & Album Limit System
#===============================================================================
# Ensures:
# - Players cannot exceed 12 Wonder Cards
# - Players cannot re-download gifts they’ve already received
# - Players cannot delete cards that haven’t been redeemed
#===============================================================================

module MysteryGift
  MAX_CARDS = 16
end

#-------------------------------------------------------------------------------
# Extend PokemonGlobalMetadata to store permanent redemption data
#-------------------------------------------------------------------------------
class PokemonGlobalMetadata
  attr_accessor :redeemed_mystery_gifts

  alias wondercardtracker_initialize initialize
  def initialize
    wondercardtracker_initialize
    @redeemed_mystery_gifts ||= []
  end
end

#-------------------------------------------------------------------------------
# Main receive method – prevents duplicates and reclaims
#-------------------------------------------------------------------------------
def pbReceiveWonderCard(gift)
  # Check for duplicate Wonder Cards in album
  if $PokemonGlobal.mystery_gifts.any? { |g| g.id == gift.id }
    pbMessage(_INTL("You already have this Wonder Card."))
    return
  end

  # Check for re-claim attempts
  if $PokemonGlobal.redeemed_mystery_gifts.include?(gift.id)
    pbMessage(_INTL("You already received this gift before."))
    return
  end

  # Check album capacity
  if $PokemonGlobal.mystery_gifts.length >= MysteryGift::MAX_CARDS
    pbMessage(_INTL("Your Wonder Card album is full. Delete one before receiving another."))
    return
  end

  # Add the Wonder Card
  $PokemonGlobal.mystery_gifts.push(gift)
  pbMessage(_INTL("The Wonder Card was added to your album!"))
end

#-------------------------------------------------------------------------------
# Claiming a Wonder Card gift – permanently mark as redeemed
#-------------------------------------------------------------------------------
def pbClaimWonderGift(card)
  return if !card
  # Actual gift logic (items, Pokémon, etc.)
  if card.respond_to?(:give_gift)
    card.give_gift
  else
    pbMessage(_INTL("Gift data missing or unsupported."))
    return
  end

  # Permanently record redemption
  $PokemonGlobal.redeemed_mystery_gifts.push(card.id) unless
    $PokemonGlobal.redeemed_mystery_gifts.include?(card.id)

  # Mark as redeemed for local reference
  card.redeemed = true if card.respond_to?(:redeemed=)

  pbMessage(_INTL("You have successfully claimed this gift!"))
end

#-------------------------------------------------------------------------------
# Safe deletion method – prevent removing unclaimed cards
#-------------------------------------------------------------------------------
def pbDeleteWonderCard(index)
  card = $PokemonGlobal.mystery_gifts[index]
  return if !card

  if !card.redeemed
    pbMessage(_INTL("You can't delete a Wonder Card with an unclaimed gift."))
    return
  end

  $PokemonGlobal.mystery_gifts.delete_at(index)
  pbMessage(_INTL("The Wonder Card was deleted."))
end

#===============================================================================
# Auto-collect Wonder Card after receiving Mystery Gift
#===============================================================================

# Alias the original method so we don't lose it
alias pbReceiveMysteryGift_Original pbReceiveMysteryGift

def pbReceiveMysteryGift(id)
  # Call the original logic
  pbReceiveMysteryGift_Original(id)
  
  # Then automatically collect the Wonder Card
  pbCollectWonderCard(id)
end
#===============================================================================
# End of file
#===============================================================================