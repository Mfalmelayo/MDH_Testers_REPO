#===============================================================================
# Mystery Gift Download with D-Terminal Animation + Sliding Card Interface
#===============================================================================
module MysteryGiftCustom
  #---------------------------------------------------------------------------
  # Internet gifts (passwordless only) with sliding card interface
  #---------------------------------------------------------------------------
def self.pbDownloadMysteryGift_Internet(trainer)
  sprites = {}
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99_999

  # ------------------------
  # Load backgrounds and grids
  sprites["background"] = IconSprite.new(0, 0, viewport)
  sprites["background"].setBitmap("Graphics/UI/Mystery Gift/base")
  sprites["background"].zoom_x = 0.5
  sprites["background"].zoom_y = 0.5
  sprites["background"].x = (Graphics.width - sprites["background"].bitmap.width * 0.5) / 2
  sprites["background"].y = (Graphics.height - sprites["background"].bitmap.height * 0.5) / 2 + 50
  sprites["background"].z = 0

  sprites["grid"] = AnimatedPlane.new(viewport)
  sprites["grid"].bitmap = Bitmap.new("Graphics/UI/Mystery Gift/bg")
  sprites["grid"].z = -1

  sprites["background2"] = IconSprite.new(0, 0, viewport)
  sprites["background2"].setBitmap("Graphics/UI/Mystery Gift/baseReceiving")
  sprites["background2"].zoom_x = 0.5
  sprites["background2"].zoom_y = 0.5
  sprites["background2"].x = sprites["background"].x
  sprites["background2"].y = sprites["background"].y
  sprites["background2"].z = -1

  sprites["grid2"] = AnimatedPlane.new(viewport)
  sprites["grid2"].bitmap = Bitmap.new("Graphics/UI/Mystery Gift/bgReceiving")
  sprites["grid2"].z = -2

  # Message window
  sprites["msgwindow"] = pbCreateMessageWindow

  # Standalone front Pokémon sprite
  sprites[:frontpokemon] = IconSprite.new(Graphics.width / 2, Graphics.height / 2, viewport)
  sprites[:frontpokemon].z = 5
  sprites[:frontpokemon].visible = false
  sprites[:frontpokemon].opacity = 0

  # ------------------------
  # Searching for gifts
  pbMessageDisplay(sprites["msgwindow"], _INTL("Searching for a gift.\nPlease wait...") + "\\wtnp[0]") {
    [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
  }

  string = pbDownloadToString(MysteryGift::URL)
  if nil_or_empty?(string)
    pbMessageDisplay(sprites["msgwindow"], _INTL("No new gifts are available.")) {
      [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
    }
    return disposeDtermScene(sprites, viewport)
  end

  online = pbMysteryGiftDecrypt(string)
  pending = online.select { |gift| !trainer.mystery_gifts.any? { |g| g[0] == gift[0] } && (gift[6].nil? || gift[6] == "") }

  if pending.empty?
    pbMessageDisplay(sprites["msgwindow"], _INTL("No new gifts are available.")) {
      [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
    }
    return disposeDtermScene(sprites, viewport)
  end

  # ------------------------
  # Prepare card sprites
  card_count = [pending.length, 3].min
  card_sprites = []
  card_count.times do |i|
    card = IconSprite.new(Graphics.width / 2, Graphics.height / 2, viewport)
    card.setBitmap("Graphics/UI/Mystery Gift/DIM")
    card.zoom_x = card.zoom_y = 1
    card_sprites << card
  end

  # Helper to calculate card positions
  focal_x = Graphics.width / 2 - 28
  focal_y = Graphics.height / 2 - 60
  card_spacing = 180
  calc_positions = lambda do |count|
    case count
    when 1 then [[focal_x, focal_y]]
    when 2 then [[focal_x - card_spacing, focal_y], [focal_x, focal_y]]
    when 3 then [[focal_x - card_spacing, focal_y], [focal_x, focal_y], [focal_x + card_spacing, focal_y]]
    end
  end

  # ------------------------
  # Helper to update front Pokémon sprite with solid grey mask
  define_singleton_method(:updateFrontPokemon) do |sprites, species, x = nil, y = nil|
    x ||= Graphics.width / 2
    y ||= Graphics.height / 2
    species = species.species.to_s if species.is_a?(Pokemon)
    return if species.nil? || species.empty?

    sprites[:frontpokemon].bitmap.dispose if sprites[:frontpokemon].bitmap

    path = "Graphics/Pokemon/Front/#{species}"
    if File.exist?(path + ".png")
      bmp = Bitmap.new(path)
      grey_bmp = Bitmap.new(bmp.width, bmp.height)

      bmp.height.times do |py|
        bmp.width.times do |px|
          color = bmp.get_pixel(px, py)
          if color.alpha > 0
            grey_bmp.set_pixel(px, py, Color.new(64, 64, 64, color.alpha))
          else
            grey_bmp.set_pixel(px, py, Color.new(0, 0, 0, 0))
          end
        end
      end

      sprites[:frontpokemon].bitmap = grey_bmp
      sprites[:frontpokemon].x = x -100
      sprites[:frontpokemon].y = y -100
      sprites[:frontpokemon].visible = true
      sprites[:frontpokemon].opacity = 0
      15.times do |i|
        sprites[:frontpokemon].opacity = (200 * (i + 1) / 15.0).to_i
        Graphics.update
        Input.update
      end
    else
      sprites[:frontpokemon].visible = false
    end
  end

  # ------------------------
  # Bobbing parameters
  bob_amplitude_center = 3
  bob_amplitude_side = 1.5
  bob_speed = 3.0

  # ------------------------
  index = 0
  pending_length = pending.length
  visual_order = card_sprites[0, card_count]

  # Initialize first selection
  current = pending[index]
  if current[1] == 0
    updateFrontPokemon(sprites, current[2])
  else
    sprites[:frontpokemon].visible = false
  end

  # ------------------------
  # Main loop
  loop do
    current = pending[index % pending_length]

    # Update message window
    sprites["msgwindow"].contents.clear
    pbDrawTextPositions(sprites["msgwindow"].contents, [
      [_INTL("{1}", current[3]), 0, 14, :left, Color.new(48, 80, 200), Color.new(160, 160, 168)]
    ])

    # Update card positions and bobbing
    target_positions = calc_positions.call(card_count)
    current_time = System.uptime
    visual_order.each_with_index do |card, i|
      gift_index = (index + i - card_count/2) % pending_length
      gift = pending[gift_index]

      # Card graphics
      if gift[1] == 0
        card.setBitmap("Graphics/UI/Mystery Gift/DIM")
      else
        item_path = "Graphics/Items/#{gift[2]}"
        if File.exist?(item_path + ".png") || File.exist?(item_path + ".bmp")
          card.setBitmap(item_path)
        else
          card.setBitmap("Graphics/UI/Mystery Gift/DIM")
        end
      end

      # Smooth position
      target_x, target_y = target_positions[i]
      card.x += (target_x - card.x) / 4.0
      card.y += (target_y - card.y) / 4.0

      # Bobbing
      is_center = (i == card_count / 2)
      amplitude = is_center ? bob_amplitude_center : bob_amplitude_side
      card.y += Math.sin(current_time * bob_speed + i) * amplitude

      # Scale
      scale = is_center ? 1.0 : 0.5
      card.zoom_x += (scale - card.zoom_x) / 4.0
      card.zoom_y += (scale - card.zoom_y) / 4.0
    end

    Graphics.update
    Input.update
    [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }

    # ------------------------
    # Scroll left/right
    if pending_length > 1
      scrolled = false
      if Input.trigger?(Input::LEFT)
        visual_order.unshift(visual_order.pop)
        index = (index - 1) % pending_length
        scrolled = true
      elsif Input.trigger?(Input::RIGHT)
        visual_order.push(visual_order.shift)
        index = (index + 1) % pending_length
        scrolled = true
      end

      if scrolled
        # Fade out current front Pokémon
        if sprites[:frontpokemon].visible
          10.times do |i|
            sprites[:frontpokemon].opacity -= (200 / 10.0).to_i
            Graphics.update
            Input.update
          end
          sprites[:frontpokemon].visible = false
        end

        # Show new front Pokémon if Pokémon
        current = pending[index % pending_length]
        if current[1] == 0
          updateFrontPokemon(sprites, current[2])
        else
          sprites[:frontpokemon].visible = false
        end
      end
    end

    # ------------------------
    # Confirm selection
    if Input.trigger?(Input::C)
      gift = pending[index % pending_length]

      # Fade out front Pokémon first
      if sprites[:frontpokemon].visible
        15.times do |i|
          sprites[:frontpokemon].opacity = 200 - (200 * (i + 1) / 15.0).to_i
          Graphics.update
          Input.update
        end
        sprites[:frontpokemon].visible = false
      end
        # Hide message window and cards
        sprites["msgwindow"].visible = false
        card_sprites.each { |c| c.visible = false }

        # Spawn Pokémon or Item sprite
        if gift[1] == 0
          sprite = PokemonSprite.new(viewport)
          sprite.setOffset(PictureOrigin::CENTER)
          sprite.setPokemonBitmap(gift[2])
          sprite.x = Graphics.width / 2
          sprite.y = -sprite.bitmap.height / 2
        else
          sprite = ItemIconSprite.new(0, 0, gift[2], viewport)
          sprite.x = Graphics.width / 2
          sprite.y = -sprite.height / 2
        end

        # Fade out BG & drop-in animation
        15.times do |i|
          sprites["background"].opacity = 255 - (255 * i / 14)
          sprites["grid"].opacity       = 255 - (255 * i / 14)
          Graphics.update
          Input.update
          [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
        end

        start_y = sprite.y
        timer_start = System.uptime
        loop do
          sprite.y = lerp(start_y, Graphics.height / 2, 1.5, timer_start, System.uptime)
          Graphics.update
          Input.update
          sprite.update
          [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
          break if sprite.y >= Graphics.height / 2
        end

        pbMEPlay("Battle capture success")
        pbWait(2.0) { sprite.update; [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update } }

        # Show messages
        sprites["msgwindow"].visible = true
        pbMessageDisplay(sprites["msgwindow"], _INTL("The gift has been received!") + "\1") {
          sprite.update; [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
        }
        pbMessageDisplay(sprites["msgwindow"], _INTL("Please pick up your gift from the deliverygirl in any Poké center.")) {
          sprite.update; [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
        }

        # Fade sprite out & restore BG
        timer_start = System.uptime
        loop do
          elapsed = System.uptime - timer_start
          sprite.opacity = lerp(255, 0, 1.5, 0, elapsed)
          sprites["background"].opacity = lerp(0, 255, 1.5, 0, elapsed)
          sprites["grid"].opacity       = lerp(0, 255, 1.5, 0, elapsed)
          [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
          Graphics.update
          Input.update
          sprite.update
          break if sprite.opacity <= 0
        end
        sprite.dispose

        trainer.mystery_gifts.push(gift)
        pbAddWonderCard(gift)
# Remove received gift
pending.delete(gift)

# Reset index & length to avoid nil errors
pending_length = pending.length
index = 0 if index >= pending_length

# Only refresh cards if there are remaining gifts
unless pending.empty?
       if sprites[:frontpokemon].visible
          10.times do |i|
            sprites[:frontpokemon].opacity -= (200 / 10.0).to_i
            Graphics.update
            Input.update
          end
          sprites[:frontpokemon].visible = false
        end

        # Show new front Pokémon if Pokémon
        current = pending[index % pending_length]
        if current[1] == 0
          updateFrontPokemon(sprites, current[2])
        else
          sprites[:frontpokemon].visible = false
        end
  card_count = [pending.length, 3].min
  visual_order = card_sprites[0, card_count]
  visual_order.each_with_index do |c, i|
    c.visible = true
    c.setBitmap("Graphics/UI/Mystery Gift/DIM")
    positions = calc_positions.call(card_count)
    c.x, c.y = positions[i]
    if card_count == 1
      c.zoom_x = c.zoom_y = 1.0
    elsif card_count == 2
      c.zoom_x = c.zoom_y = (i == 1 ? 1.0 : 0.5)
    else
      c.zoom_x = c.zoom_y = (i == 1 ? 1.0 : 0.5)
    end
  end
end

        break if pending.empty?
      end

      break if Input.trigger?(Input::B) # Cancel
    end

  # ------------------------
  # Dispose
  card_sprites.each(&:dispose)
  disposeDtermScene(sprites, viewport)
end




#---------------------------------------------------------------------------
# Password gifts
#---------------------------------------------------------------------------
def self.pbDownloadMysteryGift_Password(trainer)

  sprites = {}
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99_999

  # Load all 4 sprites (original + receiving)
  sprites["background"]  = IconSprite.new(0, 0, viewport)
  sprites["background"].setBitmap("Graphics/UI/Mystery Gift/base")
  sprites["background"].zoom_x = 0.5
  sprites["background"].zoom_y = 0.5
  sprites["background"].x = (Graphics.width / 2) - (sprites["background"].bitmap.width * 0.5 / 2)
  sprites["background"].y = (Graphics.height / 2) - (sprites["background"].bitmap.height * 0.5 / 2) + 50
  sprites["background"].z = 0

  sprites["grid"] = AnimatedPlane.new(viewport)
  sprites["grid"].bitmap = Bitmap.new("Graphics/UI/Mystery Gift/bg")
  sprites["grid"].z = -1

  sprites["background2"] = IconSprite.new(0, 0, viewport)
  sprites["background2"].setBitmap("Graphics/UI/Mystery Gift/basePassword")
  sprites["background2"].zoom_x = 0.5
  sprites["background2"].zoom_y = 0.5
  sprites["background2"].x = sprites["background"].x
  sprites["background2"].y = sprites["background"].y
  sprites["background2"].z = -1

  sprites["grid2"] = AnimatedPlane.new(viewport)
  sprites["grid2"].bitmap = Bitmap.new("Graphics/UI/Mystery Gift/bgPassword")
  sprites["grid2"].z = -2

  sprites["msgwindow"] = pbCreateMessageWindow

  # Searching message
  pbMessageDisplay(sprites["msgwindow"], _INTL("Searching for a gift.\nPlease wait...") + "\\wtnp[0]") {
    [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
  }

  string = pbDownloadToString(MysteryGift::URL)
  if nil_or_empty?(string)
    pbMessageDisplay(sprites["msgwindow"], _INTL("No new gifts are available.")) {
      [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
    }
    return disposeDtermScene(sprites, viewport)
  end

  sprites["msgwindow"].visible = false
  pw = nil
  loop do
    pw = pbEnterPasswordFreeText
    sprites["msgwindow"].visible = true
    if nil_or_empty?(pw)
      pbMessageDisplay(sprites["msgwindow"], _INTL("You must enter a password."))
      sprites["msgwindow"].visible = false
      next
    else
      break
    end
  end

  match = pbMysteryGiftDecrypt(string).find { |g| g.length > 6 && g[6] == pw }

  if match
    if trainer.mystery_gifts.any? { |g| g[0] == match[0] }
      pbMessageDisplay(sprites["msgwindow"], _INTL("You already have this gift."))
    else
      gift = match
      sprites["msgwindow"].visible = false

      # Spawn Pokémon or Item sprite
      if gift[1] == 0
        sprite = PokemonSprite.new(viewport)
        sprite.setOffset(PictureOrigin::CENTER)
        sprite.setPokemonBitmap(gift[2])
        sprite.x = Graphics.width / 2
        sprite.y = -sprite.bitmap.height / 2
      else
        sprite = ItemIconSprite.new(0, 0, gift[2], viewport)
        sprite.x = Graphics.width / 2
        sprite.y = -sprite.height / 2
      end

      # ------------------------
      # Fade out original BG before drop-down
      15.times do |i|
        sprites["background"].opacity = 255 - (255 * i / 14)
        sprites["grid"].opacity       = 255 - (255 * i / 14)
        Graphics.update
        Input.update
      end

      # Drop-in animation
      start_y = sprite.y
      timer_start = System.uptime
      loop do
        [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
        sprite.y = lerp(start_y, Graphics.height / 2, 1.5, timer_start, System.uptime)
        Graphics.update
        Input.update
        sprite.update
        break if sprite.y >= Graphics.height / 2
      end

      pbMEPlay("Battle capture success")
      pbWait(2.0) { sprite.update; [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update } }

      sprites["msgwindow"].visible = true
      pbMessageDisplay(sprites["msgwindow"], _INTL("The gift has been received!") + "\1") {
        sprite.update; [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
      }
      pbMessageDisplay(sprites["msgwindow"], _INTL("Please pick up your gift from the deliverygirl in any Poké center.")) {
        sprite.update; [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
      }

      # Restore original BG while sprite fades out simultaneously
      timer_start = System.uptime
      loop do
        elapsed = System.uptime - timer_start
        sprite.opacity = lerp(255, 0, 1.5, 0, elapsed)
        sprites["background"].opacity = lerp(0, 255, 1.5, 0, elapsed)
        sprites["grid"].opacity       = lerp(0, 255, 1.5, 0, elapsed)
        [sprites["grid"], sprites["grid2"]].each { |g| g.oy += 1; g.update }
        Graphics.update
        Input.update
        sprite.update
        break if sprite.opacity <= 0
      end
      sprite.dispose

      trainer.mystery_gifts.push(gift)
      pbAddWonderCard(gift)
    end
  else
    pbMessageDisplay(sprites["msgwindow"], _INTL("No gift matches that password."))
  end

  disposeDtermScene(sprites, viewport)
end



  #---------------------------------------------------------------------------
  # Shared cleanup
  #---------------------------------------------------------------------------
  def self.disposeDtermScene(sprites, viewport)
    pbDisposeMessageWindow(sprites["msgwindow"]) if sprites["msgwindow"]
    pbDisposeSpriteHash(sprites)
    viewport.dispose
  end
  end
  