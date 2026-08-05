#===============================================================================
# NPC Name Boxes
# Pokémon Essentials v21.1
# You already know who tf coded this shit YEEEEEEEEEEAH BOOOOOOOOOOOOOOOOOOOOOY
#===============================================================================
# TUTORIAL:
# <name>...</name> sets a name for this text box specifically.
#
# <setname>...</setname> sets a name on EVERY text box called until it is cleared
# with the script pbClearNPCName
# <clearname> at the beginning of a message box will also clear the set name.
#
# <noname> at the beginning of a message will display nothing while still preserving
# a setname
#
# You can also use pbSetNPCName("NAME") to accomplish setting a name.
# When setting a name this way, remember that methods require a double backslash \\ for things like \\PN, etc.
#
# \name[Looker] also works, but you can't use formatting this way.
#===============================================================================
module NPCNameBox
  # A name set with <setname>...</setname> remains active until it is cleared.
  @persistent_name = nil

  class << self
    attr_reader :persistent_name
  end

  def self.set_persistent_name(name)
    text = name.to_s
    @persistent_name = text.strip.empty? ? nil : text
  end

  def self.clear_persistent_name
    @persistent_name = nil
  end

  # Horizontal position relative to the main message window.
  # This offset lets me scoot it wherever I want.
  X_OFFSET = 0

  # Moves the name text upward inside the window.
  TEXT_Y_OFFSET = 0 #4

  # Extra room added after the formatted name has been measured.
  EXTRA_WIDTH = 12
  MIN_WIDTH   = 112
  # Wouldn't recommend touching this.
  # Minimum distance from the edge of the screen (set it to 8 or 0, imo).
  SCREEN_GAP  = 0

  # Number of pixels removed from the automatically calculated height.
  HEIGHT_REDUCTION = 0 #6

  # Prevents the box from becoming too short.
  MIN_HEIGHT = 48

  # Welcome to the code.
  def self.extract(message)
    text = message.to_s

    match = /\A[ \t]*<setname>(.*?)<\/setname>[ \t]*(?:\r?\n)?/im.match(text)
    if match
      set_persistent_name(match[1])
      return [@persistent_name, text[match.end(0)..-1] || ""]
    end

    match = /\A[ \t]*\\setname\[([^\]]*)\][ \t]*(?:\r?\n)?/i.match(text)
    if match
      set_persistent_name(match[1])
      return [@persistent_name, text[match.end(0)..-1] || ""]
    end

    match = /\A[ \t]*(?:<clearname\s*\/?>|\\clearname\b)[ \t]*(?:\r?\n)?/i.match(text)
    if match
      clear_persistent_name
      return [nil, text[match.end(0)..-1] || ""]
    end

    match = /\A[ \t]*(?:<noname\s*\/?>|\\noname\b)[ \t]*(?:\r?\n)?/i.match(text)
    if match
      return [nil, text[match.end(0)..-1] || ""]
    end

    match = /\A[ \t]*<name>(.*?)<\/name>[ \t]*(?:\r?\n)?/im.match(text)
    if match
      return [match[1], text[match.end(0)..-1] || ""]
    end

    match = /\A[ \t]*\\name\[([^\]]*)\][ \t]*(?:\r?\n)?/i.match(text)
    if match
      return [match[1], text[match.end(0)..-1] || ""]
    end

    return [@persistent_name, text]
  end

  # Applies the same visual substitutions used by normal message text.
  # Message-only controls such as waits, sound effects and choices are ignored;
  # visual formatting tags such as <b>, <i>, <u>, <s>, <outln>, <fn=...>, etc.
  # pass directly through Window_AdvancedTextPokemon.
  def self.format_text(text, window)
    ret = text.to_s.clone

    # Preserve escaped backslashes while processing control codes.
    ret.gsub!(/\\\\/, "\5")

    if $game_actors
      ret.gsub!(/\\n\[([1-8])\]/i) { $game_actors[$1.to_i].name.to_s }
    end
    ret.gsub!(/\\pn/i, $player.name.to_s) if $player
    if $player
      ret.gsub!(/\\pm/i, _INTL("${1}", $player.money.to_s_formatted))
    end
    ret.gsub!(/\\n/i, "\n")
    ret.gsub!(/\\\[([0-9a-f]{8})\]/i) { "<c2=#{$1}>" }

    # Gender-dependent and fixed gender colours.
    if $player&.male?
      ret.gsub!(/\\pg/i, "\\b")
      ret.gsub!(/\\pog/i, "\\r")
    elsif $player&.female?
      ret.gsub!(/\\pg/i, "\\r")
      ret.gsub!(/\\pog/i, "\\b")
    end
    ret.gsub!(/\\pg/i, "")
    ret.gsub!(/\\pog/i, "")

    male_tag = shadowc3tag(
      MessageConfig::MALE_TEXT_MAIN_COLOR,
      MessageConfig::MALE_TEXT_SHADOW_COLOR
    )
    female_tag = shadowc3tag(
      MessageConfig::FEMALE_TEXT_MAIN_COLOR,
      MessageConfig::FEMALE_TEXT_SHADOW_COLOR
    )
    ret.gsub!(/\\b/i, male_tag)
    ret.gsub!(/\\r/i, female_tag)

    is_dark_skin = isDarkWindowskin(window.windowskin)
    ret.gsub!(/\\c\[([0-9]+)\]/i) do
      getSkinColor(window.windowskin, $1.to_i, is_dark_skin)
    end

    # Resolve variables repeatedly, matching normal message behaviour.
    loop do
      old_text = ret.clone
      ret.gsub!(/\\v\[([0-9]+)\]/i) { $game_variables[$1.to_i].to_s }
      break if ret == old_text
    end

    default_color = if $game_system && $game_system.message_frame != 0
                      getSkinColor(window.windowskin, 0, true)
                    else
                      getSkinColor(window.windowskin, 0, is_dark_skin)
                    end

    ret.gsub!(/\x05/, "\\")
    return default_color + ret
  end

  def self.create(message_window, name_text)
    window = Window_AdvancedTextPokemon.new("")
    window.viewport = message_window.viewport
    window.z = message_window.z + 1
    window.visible = false
    window.letterbyletter = false
    window.back_opacity = MessageConfig::WINDOW_OPACITY
    window.setSkin(MessageConfig.pbGetSpeechFrame)

    formatted_name = format_text(name_text, window)
    max_width = Graphics.width - (SCREEN_GAP * 2)
    window.setTextToFit(formatted_name, max_width)
    window.width = [[window.width + EXTRA_WIDTH, MIN_WIDTH].max, max_width].min

    # Slightly compress the automatically calculated vertical size.
    window.height = [window.height - HEIGHT_REDUCTION, MIN_HEIGHT].max

    # UNUSED - horizontal center in the nametag frame
    #window.text = "<ac>#{formatted_name}"

    # USED: Left-aligning text (normal)
    window.text = formatted_name
    
    # Vertically center the text after compressing the window.
    window.oy = TEXT_Y_OFFSET


    return window
  end

  def self.sync(name_window, message_window)
    return if !name_window || name_window.disposed?
    return if !message_window || message_window.disposed?

    name_window.viewport = message_window.viewport
    name_window.z = message_window.z + 1
    name_window.opacity = message_window.opacity
    name_window.back_opacity = message_window.back_opacity
    name_window.contents_opacity = message_window.contents_opacity

    x = message_window.x + X_OFFSET
    x = SCREEN_GAP if x < SCREEN_GAP
    max_x = Graphics.width - SCREEN_GAP - name_window.width
    x = max_x if x > max_x
    name_window.x = x

    # Bottom/middle message windows get the name box above them. A top message
    # window gets the name box below it so the name is not pushed off-screen.
    if message_window.y <= 0
      y = message_window.y + message_window.height
    else
      y = message_window.y - name_window.height
    end
    y = 0 if y < 0
    max_y = Graphics.height - name_window.height
    y = max_y if y > max_y
    name_window.y = y
    name_window.visible = message_window.visible
  end
end

# Keep the name box attached to the message box during movement, opening/closing
# animations and ordinary message updates.
class Window_AdvancedTextPokemon
  attr_accessor :npc_name_box_window

  unless method_defined?(:npc_name_box_update)
    alias npc_name_box_update update
  end

  def update
    npc_name_box_update
    box = @npc_name_box_window
    return if !box || box.disposed?
    NPCNameBox.sync(box, self)
    box.update
  end
end

# Wrap the normal message renderer and apply either a one-message name or the
# currently active persistent name.
unless Object.private_method_defined?(:npc_name_box_pbMessageDisplay)
  Object.class_eval do
    alias_method :npc_name_box_pbMessageDisplay, :pbMessageDisplay
    private :npc_name_box_pbMessageDisplay
  end
end

def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, &block)
  name_text, body_text = NPCNameBox.extract(message)
  if nil_or_empty?(name_text)
    return npc_name_box_pbMessageDisplay(
      msgwindow, body_text, letterbyletter, commandProc, &block
    )
  end

  name_window = nil
  begin
    name_window = NPCNameBox.create(msgwindow, name_text)
    msgwindow.npc_name_box_window = name_window
    NPCNameBox.sync(name_window, msgwindow)
    return npc_name_box_pbMessageDisplay(
      msgwindow, body_text, letterbyletter, commandProc, &block
    )
  ensure
    msgwindow.npc_name_box_window = nil if msgwindow
    name_window.dispose if name_window && !name_window.disposed?
  end
end

# Optional script-call helper.
def pbNamedMessage(name, message, commands = nil, cmdIfCancel = 0,
                   skin = nil, defaultCmd = 0, &block)
  tagged_message = "<name>#{name}</name>#{message}"
  return pbMessage(
    tagged_message, commands, cmdIfCancel, skin, defaultCmd, &block
  )
end


# Persistent-name script calls. These are useful in event Script commands.
def pbSetNPCName(name)
  NPCNameBox.set_persistent_name(name)
end

def pbClearNPCName
  NPCNameBox.clear_persistent_name
end
