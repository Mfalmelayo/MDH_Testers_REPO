#===============================================================================
# Mystery Gift Password Plugin
# Adds an optional password field to each Mystery Gift
#===============================================================================

module MysteryGiftPassword
  # Returns the password if it exists
  def self.get_password(gift)
    return gift[6] || ""   # store password in the 7th element
  end

  # Sets the password
  def self.set_password(gift, text)
    gift[6] = text
  end
end

#===============================================================================
# Extend pbEditMysteryGift to include password input (fixed)
#===============================================================================
alias mg_original_pbEditMysteryGift_password_fixed pbEditMysteryGift
def pbEditMysteryGift(type, item, id = 0, giftname = "", description = "")
  gift = mg_original_pbEditMysteryGift_password_fixed(type, item, id, giftname)
  return nil if gift.nil?

  # --- Only handle password here, do NOT ask for description again ---
  pw = pbMessageFreeText(_INTL("Enter a password for this gift (optional):"), MysteryGiftPassword.get_password(gift), false, 50)
  MysteryGiftPassword.set_password(gift, pw)

  return gift
end

#===============================================================================
# Extend pbManageMysteryGifts to view/edit passwords
#===============================================================================
alias mg_original_pbManageMysteryGifts_password pbManageMysteryGifts
def pbManageMysteryGifts
  mg_original_pbManageMysteryGifts_password
  return if !FileTest.exist?("MysteryGiftMaster.txt")
  master = IO.read("MysteryGiftMaster.txt")
  master = pbMysteryGiftDecrypt(master)
  return if !master || !master.is_a?(Array) || master.empty?

  command = 0
  loop do
    commands = master.map do |gift|
      name = gift[3]
      desc = MysteryGiftDescription.get_description(gift)
      pw = MysteryGiftPassword.get_password(gift)
      _INTL("{1}: {2} [{3}]", name, desc.empty? ? "(no description)" : desc, pw.empty? ? "(no password)" : pw)
    end
    commands.push(_INTL("Cancel"))
    command = pbMessage("\\ts[]" + _INTL("Edit Mystery Gift passwords:"), commands, -1, nil, command)
    break if command == -1 || command == commands.length - 1

    gift = master[command]
    current_pw = MysteryGiftPassword.get_password(gift)
    new_pw = pbMessageFreeText(_INTL("Enter new password:"), current_pw, false, 50)
    MysteryGiftPassword.set_password(gift, new_pw)

    # Save updated master file
    begin
      string = pbMysteryGiftEncrypt(master)
      File.open("MysteryGiftMaster.txt", "wb") { |f| f.write(string) }
      pbMessage(_INTL("Password updated!"))
    rescue
      pbMessage(_INTL("Couldn't save the updated Mystery Gifts."))
    end
  end
end
