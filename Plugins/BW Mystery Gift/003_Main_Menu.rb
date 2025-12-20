#===============================================================================
# MGift Persistent BGM Module
#===============================================================================
module MGiftBGM
  BGM_FILE = "Mystery Gift"  # Name of your BGM in Audio/BGM
  @bgm_playing = false
  @old_bgm = nil

  class << self
    def start
      return if @bgm_playing
      @old_bgm = $game_system.getPlayingBGM
      pbBGMPlay(BGM_FILE)
      @bgm_playing = true
    end

    def stop
      return unless @bgm_playing
      pbBGMPlay(@old_bgm) if @old_bgm
      @bgm_playing = false
      @old_bgm = nil
    end

    def playing?
      @bgm_playing
    end

    # Wrap a method to respect MGift BGM automatically
    def wrap_method(object, method_name)
      return unless object.respond_to?(method_name)
      original = object.method(method_name)
      object.define_singleton_method(method_name) do |*args, &block|
        mgift_bgm_already_playing = MGiftBGM.playing?
        old_bgm = $game_system.getPlayingBGM unless mgift_bgm_already_playing

        MGiftBGM.start unless mgift_bgm_already_playing
        result = original.call(*args, &block)
        pbBGMPlay(old_bgm) if !mgift_bgm_already_playing && old_bgm
        result
      end
    end
  end
end

#===============================================================================
# Simple MGift v1.0 with Exit button using custom button graphic and X offset
#===============================================================================
class MGiftButton < Sprite
  attr_reader :index
  attr_reader :name
  attr_reader :selected

  TEXT_BASE_COLOR = Color.new(248, 248, 248)
  TEXT_SHADOW_COLOR = Color.new(40, 40, 40)

  def initialize(command, x, y, viewport = nil, custom_button = nil)
    super(viewport)
    @image = command[0]
    @name  = command[1]
    @selected = false

    button_file = custom_button || "icon_button"
    @button = AnimatedBitmap.new("Graphics/UI/Mystery Gift/#{button_file}")

    @contents = BitmapWrapper.new(@button.width, @button.height)
    self.bitmap = @contents
    self.x = x - (@button.width / 2)
    self.y = y
    pbSetSystemFont(self.bitmap)
    refresh
  end

  def dispose
    @button.dispose
    @contents.dispose
    super
  end

  def selected=(val)
    oldsel = @selected
    @selected = val
    refresh if oldsel != val
  end

  def refresh
    self.bitmap.clear
    rect = Rect.new(0, 0, @button.width, @button.height / 2)
    rect.y = @button.height / 2 if @selected
    self.bitmap.blt(0, 0, @button.bitmap, rect)

    textpos = [[@name, rect.width / 2, (rect.height / 2) - 10, 2, TEXT_BASE_COLOR, TEXT_SHADOW_COLOR]]
    pbDrawTextPositions(self.bitmap, textpos)

    imagepos = []
    imagepos << ["Graphics/UI/Mystery Gift/icon_" + @image, 8, -6] unless @image.empty?
    pbDrawImagePositions(self.bitmap, imagepos)
  end
end

#===============================================================================
# MGift Scene
#===============================================================================
class PokemonMGift_Scene
  def pbUpdate
    @commands.length.times { |i| @sprites["button#{i}"].selected = (i == @index) }
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene(commands)
    @commands = commands
    @index = 0
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].setBitmap("Graphics/UI/Mystery Gift/menu")
    @sprites["grid"] = AnimatedPlane.new(@viewport)
    @sprites["grid"].bitmap = Bitmap.new("Graphics/UI/Mystery Gift/bg")
    @sprites["grid"].z = -1

    @commands.length.times do |i|
      cmd = @commands[i]
      icon_name = cmd["icon_name"] || ""
      text_name = cmd["name"] || ""
      button_file = cmd.key?(:button_file) ? cmd[:button_file] : "icon_button"
      x = Graphics.width / 2
      x += cmd[:x_offset] if cmd.key?(:x_offset)
      @sprites["button#{i}"] = MGiftButton.new([icon_name, text_name], x, 0, @viewport, button_file)
      button_height = @sprites["button#{i}"].bitmap.height / 2
      @sprites["button#{i}"].y = ((Graphics.height - (@commands.length * button_height)) / 2) + (i * button_height)
    end

    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbScene
    ret = -1
    loop do
      @sprites["grid"].oy += 1
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = @index
        break
      elsif Input.trigger?(Input::UP)
        pbPlayCursorSE if @commands.length > 1
        @index -= 1
        @index = @commands.length - 1 if @index < 0
      elsif Input.trigger?(Input::DOWN)
        pbPlayCursorSE if @commands.length > 1
        @index += 1
        @index = 0 if @index >= @commands.length
      end
    end
    return ret
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    dispose
  end

  def dispose
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# MGift Screen
#===============================================================================
class PokemonMGiftScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    # Start persistent MGift BGM
    MGiftBGM.start

    commands = []
    MenuHandlers.each_available(:MGift_menu) do |option, hash, name|
      commands.push(hash)
    end

    @scene.pbStartScene(commands)

    loop do
      choice = @scene.pbScene
      break if choice < 0 || commands[choice]["effect"].call(@scene)
    end

    @scene.pbEndScene

    # Stop BGM when fully exiting MGift
    MGiftBGM.stop
  end
end

#===============================================================================
# MGift Menu Handlers
#===============================================================================
MenuHandlers.add(:MGift_menu, :mystery_gift_internet, {
  "name"      => _INTL("Mystery Gift Internet"),
  "order"     => 36,
  "icon_name" => "Download",
  "effect"    => proc { |menu|
    if !$player
      pbMessage(_INTL("Mystery Gift can only be accessed in-game."))
      next false
    end
    MGiftBGM.start
    MysteryGiftCustom.pbDownloadMysteryGift_Internet($player)
    next false
  }
})

MenuHandlers.add(:MGift_menu, :mystery_gift_password, {
  "name"      => _INTL("Mystery Gift Password"),
  "order"     => 37,
  "icon_name" => "Password",
  "effect"    => proc { |menu|
    if !$player
      pbMessage(_INTL("Mystery Gift can only be accessed in-game."))
      next false
    end
    MGiftBGM.start
    MysteryGiftCustom.pbDownloadMysteryGift_Password($player)
    next false
  }
})

MenuHandlers.add(:MGift_menu, :mystery_gift_album, {
  "name"      => _INTL("Wonder Card Album"),
  "order"     => 38,
  "icon_name" => "Album",
  "effect"    => proc { |menu|
    if !$player || $player.wonder_cards.nil? || $player.wonder_cards.empty?
      pbMessage(_INTL("You don't have any Wonder Cards yet."))
      next false
    end
    MGiftBGM.start
    scene = WonderCardAlbumScene.new
    screen = WonderCardAlbum.new(scene)
    screen.pbStartScreen($player.wonder_cards)
    next false
  }
})

#===============================================================================
# Exit Button Menu Handler with custom graphic and X offset
#===============================================================================
MenuHandlers.add(:MGift_menu, :mystery_gift_exit, {
  "name"        => _INTL("Exit"),
  "order"       => 999,
  "icon_name"   => "",
  :button_file  => "icon_Ebutton",
  :x_offset     => -40,
  "effect"      => proc { |scene|
    pbPlayCloseMenuSE
    true
  }
})
