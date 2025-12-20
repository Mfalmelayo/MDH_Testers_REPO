
#===============================================================================
# Wonder Cards System for Mystery Gifts
#===============================================================================

#===============================================================================
# WonderCard class
#===============================================================================
class WonderCard
  attr_accessor :id, :title, :description, :gift_type, :item, :quantity,
                :pokemon_data, :claimed, :date_received, :redeemed

  def initialize(id, title, description = "", gift_type = 0, data = nil, qty = 1)
    @id            = id
    @title         = title
    @description   = description
    @gift_type     = gift_type    # 0 = Pokémon, 1 = Item
    @item          = (gift_type == 1) ? data : nil
    @pokemon_data  = (gift_type == 0) ? data : nil
    @quantity      = qty
    @claimed       = false
    @redeemed      = false
    @date_received = nil
  end

  def claim!
    @claimed = true
    @date_received = Time.now
  end

  def claimed?; @claimed; end
  def redeem!; @redeemed = true; end
  def deletable?; @redeemed; end
end

#===============================================================================
# Extend Player to store Wonder Cards safely
#===============================================================================
class Player
  attr_accessor :wonder_cards

  alias __wondercards_init initialize
  def initialize(*args)
    __wondercards_init(*args)
    @wonder_cards ||= []
  end
end

#===============================================================================
# Add a new Wonder Card from a received gift
#===============================================================================
def pbAddWonderCard(gift)
  return unless $player
  $player.wonder_cards ||= []

  gift_id      = gift[0]
  gift_type    = gift[1]
  data         = gift[2]      # Pokémon object or item symbol
  gift_name    = gift[3].to_s
  description  = gift[4] || (gift_type == 0 ? _INTL("Special Pokémon delivery!") : _INTL("Mystery Item delivery!"))
  qty          = 1
  item_sym     = nil

  if gift_type == 1 && data
    # Ensure we use internal symbol if stored
    item_sym = gift[5] || data
    # Check for "xN" quantity if data is string
    if data.is_a?(String)
      parts = data.split(" x")
      item_sym = parts[0].to_sym
      qty = parts[1]&.to_i || 1
    end
  end

  card = WonderCard.new(gift_id, gift_name, description, gift_type,
                        (gift_type == 0 ? data : item_sym), qty)
  card.date_received = Time.now
  $player.wonder_cards << card

  puts "[WonderCard DEBUG] Added card: #{card.title}, Type: #{card.gift_type}, Item: #{card.item || card.pokemon_data}, Quantity: #{card.quantity}"
  card
end

#===============================================================================
# Mark a Wonder Card as claimed
#===============================================================================
def pbCollectWonderCard(gift_id)
  return unless $player && $player.wonder_cards
  card = $player.wonder_cards.find { |c| c.id == gift_id }
  if card
    card.claim!
    card.redeem!
  end
end

#===============================================================================
# Hook to automatically create Wonder Cards on receiving a Mystery Gift
#===============================================================================
alias __wondercards_receive pbReceiveMysteryGift
def pbReceiveMysteryGift(id)
  success = __wondercards_receive(id)
  if success
    gift = $player.mystery_gifts.find { |g| g[0] == id }
    pbAddWonderCard(gift) if gift && !($player.wonder_cards.any? { |c| c.id == id })
  end
  success
end

#===============================================================================
# Viewer for Wonder Cards
#===============================================================================
class WonderCardScene
  CARD_BG = "Graphics/MysteryGift/wcard_bg"

  def pbStartScene(cards)
    @cards = cards
    @index = 0
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}

    @sprites["base_bg"] = Sprite.new(@viewport)
    @sprites["base_bg"].bitmap = RPG::Cache.load_bitmap("", "Graphics/UI/Mystery Gift/album_bot")
    @sprites["base_bg"].z = 0

    @sprites["background"] = Sprite.new(@viewport)
    @sprites["background"].bitmap = RPG::Cache.load_bitmap("", CARD_BG) if pbResolveBitmap(CARD_BG)
    @sprites["background"].z = 1

    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].z = 2

    pbDrawCard(@cards[@index])
    pbFadeInAndShow(@sprites)
  end

  def pbDrawCard(card)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    base, shadow = Color.new(90, 82, 82), Color.new(165, 165, 173)
    pbSetSystemFont(overlay)

    bg_file = card.claimed? ? "Graphics/UI/Mystery Gift/wondercard_seen" : "Graphics/UI/Mystery Gift/wondercard_unseen"
    @sprites["background"].bitmap&.dispose
    @sprites["background"].bitmap = RPG::Cache.load_bitmap("", bg_file)

    title_text = card.title.to_s
    text_width = overlay.text_size(title_text).width
    x_centered = (overlay.width - text_width) / 2
    pbDrawTextPositions(overlay, [[title_text, x_centered, 100, 0, base, shadow]])

    type_text = card.gift_type == 0 ? "Wonder Card" : "Wonder Card"
    old_name, old_size = overlay.font.name, overlay.font.size
    overlay.font.name, overlay.font.size = "Power Clear Bold" || "Power Green", 40
    pbDrawTextPositions(overlay, [[type_text, 85, 35, 0, Color.new(88, 120, 255), Color.new(48, 60, 100)]])
    overlay.font.name, overlay.font.size = old_name, old_size

    date_text = card.date_received ? card.date_received.strftime("%d %b %Y") : "Invalid Date"
    pbDrawTextPositions(overlay, [[_INTL("Date Received:       {1}", date_text), 75, 325, 0, Color.new(248,248,248), Color.new(72,72,72)]])

    desc = card.description.to_s
    max_width, y_start = 325, 144
    wrapped_lines = []
    desc.split("\n").each do |line|
      current_line = ""
      line.scan(/[^.!?\s]+[.!?]?|\s+/).each do |word|
        test_line = current_line.empty? ? word : "#{current_line}#{word}"
        if overlay.text_size(test_line).width > max_width
          wrapped_lines << current_line.strip unless current_line.empty?
          current_line = word.strip
        else
          current_line += word
        end
      end
      wrapped_lines << current_line.strip unless current_line.empty?
    end
    wrapped_lines.each_with_index { |line,i| pbDrawTextPositions(overlay, [[line, 40, y_start + i*26, 0, base, shadow]]) }

    @sprites["pkmn"]&.dispose
    if card.gift_type == 0 && card.pokemon_data
      puts "[WonderCard DEBUG] Pokémon: #{card.pokemon_data}"
      sprite = PokemonSprite.new(@viewport)
      sprite.setPokemonBitmap(card.pokemon_data)
      bmp = sprite.bitmap
      sprite.x, sprite.y = (Graphics.width/2 + 80) + bmp.width/2, (Graphics.height/2 - 70) + bmp.height/2
      sprite.z, sprite.zoom_x, sprite.zoom_y = 1.5, 1.0, 1.0
      @sprites["pkmn"] = sprite
    elsif card.item
      puts "[WonderCard DEBUG] Attempting to display item: #{card.item.inspect}, Quantity: #{card.quantity}"
      if GameData::Item.exists?(card.item)
        puts "[WonderCard DEBUG] Item exists in GameData: #{card.item}"
        sprite = ItemIconSprite.new(0, 0, card.item, @viewport)
        sprite.setOffset(PictureOrigin::RIGHT)
        sprite.x, sprite.y, sprite.z = Graphics.width/2 + 210, Graphics.height/2 + 28, 1.5
        sprite.zoom_x, sprite.zoom_y = 2.0, 2.0
        @sprites["pkmn"] = sprite
      else
        puts "[WonderCard DEBUG] Item DOES NOT exist in GameData: #{card.item}"
      end
    end
  end

  def pbMain
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      break if Input.trigger?(Input::BACK)
    end
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# Screen wrapper
#===============================================================================
class WonderCardScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(cards)
    @scene.pbStartScene(cards)
    @scene.pbMain
    @scene.pbEndScene
  end
end

#===============================================================================
# Public method to view Wonder Cards
#===============================================================================
def pbOpenWonderCardViewer
  if !$player || $player.wonder_cards.nil? || $player.wonder_cards.empty?
    pbMessage(_INTL("You don't have any Wonder Cards yet."))
    return
  end
  screen = WonderCardScreen.new(WonderCardScene.new)
  screen.pbStartScreen($player.wonder_cards)
end

#===============================================================================
# Auto-attach new gifts to Wonder Cards during download
#===============================================================================
alias __wondercards_download pbDownloadMysteryGift
def pbDownloadMysteryGift(trainer = $player)
  old_gifts = trainer.mystery_gifts ? trainer.mystery_gifts.clone : []
  result = __wondercards_download(trainer)
  new_gifts = trainer.mystery_gifts - old_gifts
  new_gifts.each { |gift| pbAddWonderCard(gift) }
  result
end