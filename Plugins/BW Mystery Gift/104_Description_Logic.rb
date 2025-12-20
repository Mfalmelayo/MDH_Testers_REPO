#===============================================================================
# Mystery Gift Description Plugin (Editable in Debug Menu with multiline support)
#===============================================================================

module MysteryGiftDescription
  # Returns the description if it exists
  def self.get_description(gift)
    return gift[4] || ""
  end

  # Sets the description
  def self.set_description(gift, text)
    gift[4] = text
  end
end

#===============================================================================
# Extend pbEditMysteryGift to allow descriptions with \n
#===============================================================================
alias mg_original_pbEditMysteryGift pbEditMysteryGift
def pbEditMysteryGift(type, item, id = 0, giftname = "", description = "")
  gift = mg_original_pbEditMysteryGift(type, item, id, giftname)
  return nil if gift.nil?

  # Ask for description
  loop do
    newdesc = pbMessageFreeText(_INTL("Enter a description for this gift."), description, false, 250)
    if newdesc != ""
      # Convert literal "\n" into actual newlines
      description = newdesc.gsub(/\\n/, "\n")
      break
    end
    return nil if pbConfirmMessage(_INTL("Stop editing this gift?"))
  end

  # Store description in 5th element
  gift[4] = description
  return gift
end

#===============================================================================
# Helper to display description anywhere
#===============================================================================
def pbMysteryGiftDescription(gift)
  return MysteryGiftDescription.get_description(gift)
end

#===============================================================================
# Add description editing to pbManageMysteryGifts with multiline support
#===============================================================================
alias mg_original_pbManageMysteryGifts pbManageMysteryGifts
def pbManageMysteryGifts
  mg_original_pbManageMysteryGifts
  return if !FileTest.exist?("MysteryGiftMaster.txt")
  master = IO.read("MysteryGiftMaster.txt")
  master = pbMysteryGiftDecrypt(master)
  return if !master || !master.is_a?(Array) || master.empty?

  command = 0
  loop do
    commands = master.map do |gift|
      # Show name + description preview
      desc = MysteryGiftDescription.get_description(gift)
      itemname = gift[1] == 0 ? gift[2].speciesName : GameData::Item.get(gift[2]).name
      _INTL("{1}: {2} - {3}", gift[3], itemname, desc.empty? ? "(no description)" : desc)
    end
    commands.push(_INTL("Cancel"))
    command = pbMessage("\\ts[]" + _INTL("Edit Mystery Gift descriptions:"), commands, -1, nil, command)
    break if command == -1 || command == commands.length - 1

    gift = master[command]
    current_desc = MysteryGiftDescription.get_description(gift)
    loop do
      newdesc = pbMessageFreeText(_INTL("Edit description:"), current_desc, false, 250)
      if newdesc != ""
        # Convert literal "\n" into actual newlines
        newdesc = newdesc.gsub(/\\n/, "\n")
        MysteryGiftDescription.set_description(gift, newdesc)
        current_desc = newdesc
        break
      end
      break if pbConfirmMessage(_INTL("Stop editing this description?"))
    end

    # Save updated master file
    begin
      string = pbMysteryGiftEncrypt(master)
      File.open("MysteryGiftMaster.txt", "wb") { |f| f.write(string) }
      pbMessage(_INTL("Description updated!"))
    rescue
      pbMessage(_INTL("Couldn't save the updated Mystery Gifts."))
    end
  end
end

#===============================================================================
# Mystery Gift Internal Item Name Plugin
# Stores the internal item symbol for proper icon handling
#===============================================================================

module MysteryGiftInternalName
  # Returns the internal symbol of an item gift
  def self.get_item_symbol(gift)
    return nil if gift.nil? || gift[1] == 0
    gift[5] || GameData::Item.get(gift[2]).id rescue nil
  end

  # Sets the internal symbol for an item gift
  def self.set_item_symbol(gift, symbol)
    return if gift.nil? || gift[1] == 0
    gift[5] = symbol
  end
end

#===============================================================================
# Extend pbEditMysteryGift to store the internal name for item gifts
#===============================================================================
alias mg_original_pbEditMysteryGift_full pbEditMysteryGift
def pbEditMysteryGift(type, item, id = 0, giftname = "")
  gift = mg_original_pbEditMysteryGift_full(type, item, id, giftname)
  return nil if gift.nil?

  # Fix Pokémon storage
  if type == 0
    gift[2] = item
  end

  # Existing extensions for items and passwords here...
  if type > 0
    symbol = GameData::Item.get(item).id rescue item.to_s.upcase.to_sym
    MysteryGiftInternalName.set_item_symbol(gift, symbol)
  end

  return gift
end


#===============================================================================
# Extend pbManageMysteryGifts to show the internal symbol (optional)
#===============================================================================
alias mg_original_pbManageMysteryGifts_internal pbManageMysteryGifts
def pbManageMysteryGifts
  mg_original_pbManageMysteryGifts_internal
  return if !FileTest.exist?("MysteryGiftMaster.txt")
  master = IO.read("MysteryGiftMaster.txt")
  master = pbMysteryGiftDecrypt(master)
  return if !master || !master.is_a?(Array) || master.empty?

  command = 0
  loop do
    commands = master.map do |gift|
      itemname = gift[1] == 0 ? gift[2].speciesName : GameData::Item.get(gift[2]).name
      internal = MysteryGiftInternalName.get_item_symbol(gift)
      internal_text = internal ? internal.to_s : "(no internal)"
      _INTL("{1}: {2} [{3}]", gift[3], itemname, internal_text)
    end
    commands.push(_INTL("Cancel"))
    command = pbMessage("\\ts[]" + _INTL("View Mystery Gift internal names:"), commands, -1, nil, command)
    break if command == -1 || command == commands.length - 1
  end
end