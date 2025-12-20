#===============================================================================
# Custom TextEntry Window with forced font colors
#===============================================================================
class Window_TextEntry_Custom < Window_TextEntry_Keyboard
  attr_accessor :baseColor, :shadowColor, :fontName, :fontSize

  def initialize(text = "", x = 0, y = 0, width = 240, height = 64)
    super(text, x, y, width, height)
    @baseColor   = Color.new(255, 255, 255)
    @shadowColor = Color.new(0, 0, 0)
    @fontName    = "Power Green" # Symbol font
    @fontSize    = 28
    self.contents.font.name = @fontName
    self.contents.font.size = @fontSize
  end

  def draw_text(x, y, w, h, text, align = 0)
    self.contents.font.name = @fontName
    self.contents.font.size = @fontSize
    self.contents.font.color = @shadowColor
    self.contents.draw_text(x + 1, y + 1, w, h, text, align)
    self.contents.font.color = @baseColor
    self.contents.draw_text(x, y, w, h, text, align)
  end
end

#===============================================================================
# Password Input Function with readable overlay
#===============================================================================
def pbEnterPasswordFreeText(prompt = "Enter the password:", maxLength = 50)
  sprites = {}
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99999

  # Custom background (can be fully transparent)
  sprites["background"] = Sprite.new(viewport)
  sprites["background"].bitmap = Bitmap.new("Graphics/UI/Mystery Gift/Input/bg.png")
  sprites["background"].x = 0
  sprites["background"].y = 0

  # Overlay to display readable text
  overlay = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
  overlay.z = 100_000
  overlay.bitmap.font.name = "Power Green"  # Use the registered readable font
  overlay.bitmap.font.size = 48
  overlay.bitmap.font.color = Color.new(255, 255, 255)

  pbFadeInAndShow(sprites)

  password = nil
  loop do
    msgwindow = pbCreateMessageWindow

    password = pbMessageDisplay(msgwindow, prompt, true,
      proc { |msgwndw|
        # Hidden input in Digicode
        window = Window_TextEntry_Custom.new("", 140, 30, 240, 64)
        window.maxlength = maxLength
        window.visible = true
        window.z = 99999
        window.opacity = 0
        window.back_opacity = 0
        window.windowskin = nil
        window.passwordChar = nil
        window.baseColor   = Color.new(255, 255, 255)
        window.shadowColor = Color.new(0, 0, 0)

        Input.text_input = true
        ret = ""
        loop do
          Graphics.update
          Input.update
          window.update
          msgwndw&.update

          # Draw readable overlay copy centered
          overlay.bitmap.clear
          overlay_text = window.text
          text_width = overlay.bitmap.text_size(overlay_text).width
          x_centered = (Graphics.width - text_width) / 2
          overlay.bitmap.draw_text(x_centered, 200, text_width, 32, overlay_text, 0)

          if Input.triggerex?(:ESCAPE)
            ret = ""
            break
          elsif Input.triggerex?(:RETURN)
            ret = window.text
            break
          end
        end
        Input.text_input = false
        window.dispose
        Input.update
        ret
      }
    )

    pbDisposeMessageWindow(msgwindow)

    if nil_or_empty?(password)
      pbMessage(_INTL("You must enter a password."))
    else
      break
    end
  end

  pbFadeOutAndHide(sprites)
  sprites["background"].dispose
  overlay.dispose
  viewport.dispose

  return password
end
