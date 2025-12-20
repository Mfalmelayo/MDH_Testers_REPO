#===============================================================================
# Debug Mystery Gift Saver (Unencoded)
#===============================================================================
# This plugin saves the Mystery Gift master list in a human-readable format
# so you can inspect the contents without encoding/decoding.
#===============================================================================

module DebugMysteryGift
  MASTER_FILE_DEBUG = "MysteryGiftMaster_debug.txt"

  # Saves the current Mystery Gift master list in readable form
  def self.save_debug(master)
    File.open(MASTER_FILE_DEBUG, "w") do |f|
      master.each do |gift|
        id   = gift[0]
        type = gift[1]
        item = gift[2]
        name = gift[3]
        item_str = if type == 0 && item.respond_to?(:species)
                     "#{item.species} (Lv#{item.level})"
                   elsif type > 0
                     "#{item} x#{type}"
                   else
                     item.inspect
                   end
        f.puts("ID: #{id} | Type: #{type} | Item: #{item_str} | Name: #{name}")
      end
    end
  rescue => e
    pbMessage(_INTL("Failed to save debug Mystery Gift file: {1}", e.message))
  end
end

#===============================================================================
# Overwrite or wrap the standard save function for testing purposes
#===============================================================================
alias _debug_pbCreateMysteryGift pbCreateMysteryGift
def pbCreateMysteryGift(type, item)
  gift = pbEditMysteryGift(type, item)
  if gift
    begin
      master = []
      if FileTest.exist?("MysteryGiftMaster.txt")
        master = IO.read("MysteryGiftMaster.txt")
        master = pbMysteryGiftDecrypt(master)
      end
      master.push(gift)

      # Save normal encoded file
      string = pbMysteryGiftEncrypt(master)
      File.open("MysteryGiftMaster.txt", "wb") { |f| f.write(string) }

      # Save unencoded debug file
      DebugMysteryGift.save_debug(master)

      pbMessage(_INTL("The gift was saved to MysteryGiftMaster.txt\nDebug file saved to {1}", DebugMysteryGift::MASTER_FILE_DEBUG))
    rescue
      pbMessage(_INTL("Couldn't save the gift to MysteryGiftMaster.txt"))
    end
  else
    pbMessage(_INTL("Didn't create a gift."))
  end
end

#===============================================================================
# Temporarily Disable Mystery Gift Load Screen Command (Soft Touch)
#===============================================================================
# Hides the Mystery Gift option in the load screen without permanently
# modifying the save data.
#===============================================================================


#===============================================================================
# Register all fonts in /Fonts/ for Pokémon Essentials (MKXP compatible)
#===============================================================================
module FontLoader
  def self.register_all_fonts
    font_dir = File.join(Dir.pwd, "Fonts")
    return unless Dir.exist?(font_dir)

    Dir.glob(File.join(font_dir, "*.{ttf,TTF,otf,OTF}")) do |path|
      font_name = File.basename(path, File.extname(path))
      begin
        # MKXP will auto-detect fonts in the Fonts folder if you use the filename
        puts "[FontLoader] Found font: #{font_name}"
      rescue => e
        puts "[FontLoader] Failed to load: #{font_name} (#{e})"
      end
    end
  end

  # Optional helper to set a default font globally
  def self.set_default_font(font_name)
    Font.default_name = font_name
    MessageConfig.pbSetSystemFont(font_name) if defined?(MessageConfig)
    puts "[FontLoader] Default font set to: #{font_name}"
  end
end

# Run once at startup
FontLoader.register_all_fonts
# FontLoader.set_default_font("MyCustomFont")  # Uncomment to set default
