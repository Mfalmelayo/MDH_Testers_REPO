#===============================================================================
# Wonder Card Album Viewer (2x2 row-first grid, looping pages, title + arrows)
#===============================================================================

class WonderCardAlbumScene
  GRID_COLUMNS = 2
  GRID_ROWS    = 2
  CARD_WIDTH   = 200
  CARD_HEIGHT  = 200
  PADDING_X    = 40
  PADDING_Y    = -72
  START_X      = 52
  START_Y      = 68
  CARDS_PER_PAGE = GRID_COLUMNS * GRID_ROWS

  CURSOR_START_X = START_X - 40
  CURSOR_START_Y = START_Y - 10
  CURSOR_OFFSET_X = CARD_WIDTH + PADDING_X
  CURSOR_OFFSET_Y = CARD_HEIGHT + PADDING_Y

  # Icon adjusters
  POKEMON_ICON_X = 100
  POKEMON_ICON_Y = -10
  ITEM_ICON_X    = 110
  ITEM_ICON_Y    = 6

  # Title & arrows offsets
  TITLE_Y = 24

  #---------------------------------------------------------------------------
  # Initialize scene
  #---------------------------------------------------------------------------
  def pbStartScene(cards)
    @cards = cards
    @selected_card = 0
    @page_index = 0
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}

    # Background
    @sprites["background"] = Sprite.new(@viewport)

    # Card placeholders
    GRID_ROWS.times do |row|
      GRID_COLUMNS.times do |col|
        idx = row * GRID_COLUMNS + col
        sprite = Sprite.new(@viewport)
        sprite.x = START_X + col * (CARD_WIDTH + PADDING_X)
        sprite.y = START_Y + row * (CARD_HEIGHT + PADDING_Y)
        sprite.z = 1
        @sprites["card_#{idx}"] = sprite
      end
    end

    # Cursor
    @sprites["cursor"] = Sprite.new(@viewport)
    @sprites["cursor"].bitmap = RPG::Cache.load_bitmap("", "Graphics/UI/Mystery Gift/album_cursor")
    @sprites["cursor"].z = 2

    # Page indicator image
    @sprites["page_image"] = Sprite.new(@viewport)
    @sprites["page_image"].bitmap = RPG::Cache.load_bitmap("", "Graphics/UI/Mystery Gift/album_info")
    @sprites["page_image"].x = 10
    @sprites["page_image"].y = Graphics.height - @sprites["page_image"].bitmap.height - 10
    @sprites["page_image"].z = 3

    # Page indicator text
    @sprites["page_text"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["page_text"].x = 10
    @sprites["page_text"].y = 5
    @sprites["page_text"].z = 4

    # Title text
    @sprites["title_text"] = BitmapSprite.new(Graphics.width, 32, @viewport)
    @sprites["title_text"].y = TITLE_Y
    @sprites["title_text"].z = 4

    # Page arrows
    @sprites["arrows"] = Sprite.new(@viewport)
    @sprites["arrows"].bitmap = RPG::Cache.load_bitmap("", "Graphics/UI/Mystery Gift/album_arrows")
    @sprites["arrows"].z = 4
    @sprites["arrows"].visible = @cards.length > CARDS_PER_PAGE

    # Initial draw
    refreshBackground
    updateTitleText
    updateCursorPosition
    pbDrawGrid
    pbFadeInAndShow(@sprites)
  end

  #---------------------------------------------------------------------------
  # Draw cards (with date + icons)
  #---------------------------------------------------------------------------
def pbDrawGrid
  GRID_ROWS.times do |row|
    GRID_COLUMNS.times do |col|
      idx = row * GRID_COLUMNS + col
      sprite = @sprites["card_#{idx}"]
      card_idx = @page_index * CARDS_PER_PAGE + row * GRID_COLUMNS + col
      if card_idx < @cards.length
        card = @cards[card_idx]
        bg_file = card.claimed? ? "Graphics/UI/Mystery Gift/album_card_seen" : "Graphics/UI/Mystery Gift/album_card_unseen"
        sprite.bitmap&.dispose
        base_bitmap = RPG::Cache.load_bitmap("", bg_file)

        overlay = Bitmap.new(base_bitmap.width, base_bitmap.height)
        overlay.blt(0, 0, base_bitmap, base_bitmap.rect)
        base_bitmap.dispose

        # Received date
        text = card.date_received ? card.date_received.strftime("%d %b %Y") : "Invalid Date"
        base_color = Color.new(90, 82, 82)
        shadow_color = Color.new(165, 165, 173)
        pbSetSystemFont(overlay)
        text_width = overlay.text_size(text).width
        text_x = (overlay.width - text_width) / 2
        text_y = overlay.height - 38
        pbDrawTextPositions(overlay, [[text, text_x + 2, text_y + 2, 0, shadow_color, shadow_color]])
        pbDrawTextPositions(overlay, [[text, text_x, text_y, 0, base_color, shadow_color]])

        # Pokémon icon
        if card.gift_type == 0 && card.pokemon_data
          species = card.pokemon_data.species.to_s
          icon_path = "Graphics/Pokemon/Icons/#{species}"
          if File.exist?("#{icon_path}.png")
            icon = RPG::Cache.load_bitmap("", icon_path)
            frame_rect = Rect.new(0, 0, icon.width / 2, icon.height)
            overlay.blt(POKEMON_ICON_X, POKEMON_ICON_Y, icon, frame_rect)
            icon.dispose
          end
        end

        # Item icon
        if card.gift_type > 0 && card.item
          item_id = card.item.is_a?(Symbol) || card.item.is_a?(String) ? card.item : card.item.id
          if item_id
            icon_path = "Graphics/Items/#{item_id}"
            if File.exist?("#{icon_path}.png")
              icon = RPG::Cache.load_bitmap("", icon_path)
              overlay.blt(ITEM_ICON_X, ITEM_ICON_Y, icon, icon.rect)
              icon.dispose
            end
          end

          # Quantity
          if card.gift_type > 1
            pbSetSystemFont(overlay)
            qty_text = "x#{card.gift_type}"
            text_color   = Color.new(248, 248, 248)
            shadow_color = Color.new(72, 72, 72)
            text_width = overlay.text_size(qty_text).width
            overlay.draw_text(
              ITEM_ICON_X + overlay.width - text_width - 6,
              ITEM_ICON_Y + overlay.height - 18,
              text_width + 4, 16,
              qty_text, 1
            )
          end
        end

        sprite.bitmap = overlay
      else
        sprite.bitmap&.dispose
        sprite.bitmap = nil
      end
    end
  end
end


  #---------------------------------------------------------------------------
  # Update cursor & page text
  #---------------------------------------------------------------------------
def updateCursorPosition
  @page_index = @selected_card / CARDS_PER_PAGE
  page_start = @page_index * CARDS_PER_PAGE
  rel_index = @selected_card - page_start

  row = rel_index / GRID_COLUMNS
  col = rel_index % GRID_COLUMNS

  # Ensure cursor never goes to empty slot
  max_index = [@cards.length - 1, page_start + CARDS_PER_PAGE - 1].min
  max_row = (max_index - page_start) / GRID_COLUMNS
  max_col_last_row = (max_index - page_start) % GRID_COLUMNS

  row = max_row if row > max_row
  col = (row == max_row && col > max_col_last_row) ? max_col_last_row : col

  @sprites["cursor"].x = CURSOR_START_X + col * CURSOR_OFFSET_X
  @sprites["cursor"].y = CURSOR_START_Y + row * CURSOR_OFFSET_Y

  updatePageText
end


  def updatePageText
    bmp = @sprites["page_text"].bitmap
    bmp.clear
    total_pages = (@cards.length.to_f / CARDS_PER_PAGE).ceil
    text = "Page  #{@page_index + 1} / #{total_pages}"
    text_color   = Color.new(248, 248, 248)
    shadow_color = Color.new(72, 72, 72)
    pbSetSystemFont(bmp)
    text_x = @sprites["page_image"].x + 10
    text_y = @sprites["page_image"].y + 10
    pbDrawTextPositions(bmp, [[text, text_x + 1, text_y + 1, 0, shadow_color, shadow_color]])
    pbDrawTextPositions(bmp, [[text, text_x, text_y, 0, text_color, shadow_color]])

    @sprites["arrows"].visible = @cards.length > CARDS_PER_PAGE
  end

  #---------------------------------------------------------------------------
  # Background
  #---------------------------------------------------------------------------
  def refreshBackground
    page_num = @page_index + 1
    bg_file = "Graphics/UI/Mystery Gift/album_bg#{page_num}"
    if File.exist?("#{bg_file}.png")
      @sprites["background"].bitmap&.dispose
      @sprites["background"].bitmap = RPG::Cache.load_bitmap("", bg_file)
    end
  end

  #---------------------------------------------------------------------------
  # Title & arrows positioning
  #---------------------------------------------------------------------------
  def updateTitleText
    bmp = @sprites["title_text"].bitmap
    bmp.clear
    text = "Wonder Card Album"
    text_color   = Color.new(248, 248, 248)
    shadow_color = Color.new(72, 72, 72)
    pbSetSystemFont(bmp)

    text_width = bmp.text_size(text).width
    text_x = (Graphics.width - text_width) / 2
    text_y = 0
    pbDrawTextPositions(bmp, [[text, text_x + 1, text_y + 1, 0, shadow_color, shadow_color]])
    pbDrawTextPositions(bmp, [[text, text_x, text_y, 0, text_color, shadow_color]])

    if @sprites["arrows"]
      arrows_width = @sprites["arrows"].bitmap.width
      @sprites["arrows"].x = text_x + (text_width - arrows_width) / 2
      @sprites["arrows"].y = TITLE_Y - 24
    end
  end

  #---------------------------------------------------------------------------
  # Main loop with row-first navigation & looping pages
  #---------------------------------------------------------------------------
#---------------------------------------------------------------------------
# Main loop with safe navigation for partially filled pages
#---------------------------------------------------------------------------
def pbMain
  loop do
    Graphics.update
    Input.update
    pbUpdateSpriteHash(@sprites)
    moved = false
    total_cards = @cards.length
    total_pages = (total_cards.to_f / CARDS_PER_PAGE).ceil
    page_start = @page_index * CARDS_PER_PAGE
    page_card_count = [total_cards - page_start, CARDS_PER_PAGE].min

    # Current relative row/col in batten layout
    rel_index = @selected_card - page_start
    row = rel_index / GRID_COLUMNS
    col = rel_index % GRID_COLUMNS

    # Maximum valid row/col for this page
    max_row = (page_card_count - 1) / GRID_COLUMNS
    max_col = [page_card_count, GRID_COLUMNS].min - 1
    page_cards = []
    page_card_count.times { |i| page_cards << page_start + i }

    if Input.trigger?(Input::LEFT)
      col -= 1
      if col < 0
        # Go to previous page
        @page_index = (@page_index - 1) % total_pages
        page_start = @page_index * CARDS_PER_PAGE
        page_card_count = [total_cards - page_start, CARDS_PER_PAGE].min
        col = [page_card_count, GRID_COLUMNS].min - 1
      end
      row = [row, (page_card_count - 1) / GRID_COLUMNS].min
      new_index = page_start + row * GRID_COLUMNS + col
      @selected_card = [new_index, total_cards - 1].min
      moved = true
    elsif Input.trigger?(Input::RIGHT)
      col += 1
      if col > max_col
        # Go to next page
        @page_index = (@page_index + 1) % total_pages
        page_start = @page_index * CARDS_PER_PAGE
        page_card_count = [total_cards - page_start, CARDS_PER_PAGE].min
        col = 0
      end
      row = [row, (page_card_count - 1) / GRID_COLUMNS].min
      new_index = page_start + row * GRID_COLUMNS + col
      @selected_card = [new_index, total_cards - 1].min
      moved = true
    elsif Input.trigger?(Input::UP)
      row -= 1
      if row < 0
        # Wrap to bottom row on current page
        row = (page_card_count - 1) / GRID_COLUMNS
      end
      new_index = page_start + row * GRID_COLUMNS + col
      @selected_card = [new_index, total_cards - 1].min
      moved = true
    elsif Input.trigger?(Input::DOWN)
      row += 1
      if row > (page_card_count - 1) / GRID_COLUMNS
        # Wrap to top row
        row = 0
      end
      new_index = page_start + row * GRID_COLUMNS + col
      @selected_card = [new_index, total_cards - 1].min
      moved = true
    elsif Input.trigger?(Input::BACK)
      pbSEPlay("GUI menu close")
      break
    elsif Input.trigger?(Input::USE)
      selectCard(@selected_card) if @selected_card < total_cards
    end

    if moved
      updateCursorPosition
      pbDrawGrid
      refreshBackground
      updateTitleText
    end
  end
end


  #---------------------------------------------------------------------------
  # Card menu
  #---------------------------------------------------------------------------
  def selectCard(index)
    return if index.nil? || !@cards[index]
    card = @cards[index]

    pbSEPlay("GUI sel decision")
    commands = [_INTL("View"), _INTL("Delete"), _INTL("Cancel")]
    choice = pbMessage(_INTL("What would you like to do with this Wonder Card?"), commands, 3)

    case choice
    when 0 # View
      pbSEPlay("GUI open panel")
      pbFadeOutIn(10) { pbOpenWonderCardViewerAt(card) }
    when 1 # Delete
      pbSEPlay("GUI sel decision")
      if index == 0
        pbSEPlay("GUI buzzer")
        pbMessage(_INTL("This Wonder Card cannot be deleted."))
      elsif !card.claimed?
        pbSEPlay("GUI buzzer")
        pbMessage(_INTL("You can't delete a Wonder Card with an unclaimed gift."))
      else
        if pbConfirmMessage(_INTL("Are you sure you want to delete this Wonder Card?"))
          pbSEPlay("GUI delete choice")
          pbFadeOutIn(10) { @cards.delete_at(index) }
          pbMessage(_INTL("The Wonder Card was deleted."))
          updateAfterDelete
        end
      end
    else
      pbSEPlay("GUI menu close")
    end
  end

  #---------------------------------------------------------------------------
  def updateAfterDelete
    total_pages = (@cards.length.to_f / CARDS_PER_PAGE).ceil
    @page_index = [@page_index, total_pages - 1].max
    @selected_card = [@selected_card, @cards.length - 1].max if @cards.length > 0
    pbDrawGrid
    updateCursorPosition
    refreshBackground
    updateTitleText
  end

  #---------------------------------------------------------------------------
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end


#===============================================================================
# Wrapper + public calls
#===============================================================================
class WonderCardAlbum
  def initialize(scene); @scene = scene; end
  def pbStartScreen(cards)
    return if cards.nil? || cards.empty?
    @scene.pbStartScene(cards)
    @scene.pbMain
    @scene.pbEndScene
  end
end

def pbOpenWonderCardAlbum
  if !$player || $player.wonder_cards.nil? || $player.wonder_cards.empty?
    pbMessage(_INTL("You don't have any Wonder Cards yet."))
    return
  end
  scene = WonderCardAlbumScene.new
  screen = WonderCardAlbum.new(scene)
  screen.pbStartScreen($player.wonder_cards)
end

def pbOpenWonderCardViewerAt(card)
  scene = WonderCardScene.new
  screen = WonderCardScreen.new(scene)
  screen.pbStartScreen([card])
end