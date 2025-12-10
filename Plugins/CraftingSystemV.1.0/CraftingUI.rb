# ===============================================================================
# File: Plugins/CraftingSystem/CraftingUI.rb
# Main crafting interface system with recipe selection, ingredient display, and crafting execution
# ===============================================================================

#===============================================================================
# Window_CraftingRecipeList - Recipe selection window with scrolling support
# Displays craftable recipes with color-coded availability and built-in cursor navigation
#===============================================================================
class Window_CraftingRecipeList < Window_DrawableCommand
  include CraftingUIConfig
  
  attr_reader :current_category
  attr_accessor :recipes

  # Initialize recipe selection window with dimensions and basic setup
  def initialize(x, y, width, height)
    @current_category = "All Items"
    @recipes = []
    @scene = nil
    @last_index = -1
    
    super(x, y, width, height)
    
    # Load custom cursor graphic with fallback handling
    begin
      @selarrow = AnimatedBitmap.new(CURSOR_GRAPHIC)
    rescue => e
      puts "Warning: Could not load cursor graphic '#{CURSOR_GRAPHIC}': #{e.message}"
      @selarrow = nil
    end
    
    # Configure window appearance and behavior
    self.windowskin = nil
    update_window_dependencies
    @index = 0
    @last_index = 0
    self.active = false
    
    update_recipe_list
  end

  # Calculate window layout parameters from background graphics and configuration
  def update_window_dependencies
    begin
      # Retrieve window dimensions from scene or asset manager
      if @scene && @scene.respond_to?(:get_recipe_window_dimensions)
        recipe_dims = @scene.get_recipe_window_dimensions
      else
        recipe_dims = CraftingAssetManager.get_dimensions(RECIPE_BG_GRAPHIC, :ui)
        recipe_dims[:x] = RECIPE_WINDOW_X
        recipe_dims[:y] = RECIPE_WINDOW_Y
      end
      
      # Calculate optimal row height for configured number of visible recipes
      @row_height = CraftingUIConfig.calculate_row_height(
        recipe_dims[:height], 
        RECIPE_WINDOW_CONTENT_MARGIN, 
        RECIPE_WINDOW_MAX_VISIBLE, 
        RECIPE_ROW_EXTRA_SPACING
      )
      
      @recipes_per_page = RECIPE_WINDOW_MAX_VISIBLE
      @font_scale = CraftingUIConfig.calculate_font_scale_factor(recipe_dims[:width])
      
      # Define content area within window margins
      @content_area = {
        x: RECIPE_WINDOW_CONTENT_MARGIN,
        y: RECIPE_WINDOW_CONTENT_MARGIN,
        width: recipe_dims[:width] - (RECIPE_WINDOW_CONTENT_MARGIN * 2),
        height: @recipes_per_page * @row_height
      }
    rescue => e
      puts "Warning: Error updating window dependencies: #{e.message}"
      # Set fallback values
      @row_height = 30
      @recipes_per_page = RECIPE_WINDOW_MAX_VISIBLE
      @font_scale = 1.0
      @content_area = { x: 2, y: 2, width: self.width - 4, height: self.height - 4 }
    end
  end

  # Pokemon Essentials scrolling configuration
  def page_row_max
    RECIPE_WINDOW_MAX_VISIBLE  
  end

  def page_item_max  
    RECIPE_WINDOW_MAX_VISIBLE  
  end

  # Calculate display rectangle for item at specific index within scroll view
  def itemRect(item)
    return Rect.new(0, 0, 0, 0) if item < 0 || item >= @item_max
    
    # Skip items outside visible scroll range
    if item < self.top_item || item >= self.top_item + self.page_item_max
      return Rect.new(0, 0, 0, 0)
    end
    
    # Use calculated content area or fallback margins
    content = @content_area || {
      x: RECIPE_WINDOW_CONTENT_MARGIN,
      y: RECIPE_WINDOW_CONTENT_MARGIN,
      width: self.width - (RECIPE_WINDOW_CONTENT_MARGIN * 2),
      height: self.height - (RECIPE_WINDOW_CONTENT_MARGIN * 2)
    }
    
    # Position relative to current scroll position
    relative_item = item - self.top_item
    
    x = content[:x]
    y = content[:y] + (relative_item * @row_height)
    width = content[:width]
    height = @row_height
    
    return Rect.new(x, y, width, height)
  end

  # Draw cursor using built-in bitmap copying for stability with integrated offsets
  def drawCursor(index, rect)
    if self.index == index && @selarrow && @selarrow.bitmap && !@selarrow.bitmap.disposed?
      # Apply cursor offsets from configuration
      cursor_x = rect.x + CURSOR_X_OFFSET
      cursor_y = rect.y + CURSOR_Y_OFFSET
      
      begin
        pbCopyBitmap(self.contents, @selarrow.bitmap, cursor_x, cursor_y)
      rescue => e
        puts "Warning: Error drawing cursor: #{e.message}"
      end
    end
  end

  # Monitor cursor movement to trigger ingredient display updates
  def check_index_change
    if @index != @last_index
      @last_index = @index
      
      if REFRESH_ON_INDEX_CHANGE && @scene
        begin
          @scene.update_ingredients_display
        rescue => e
          puts "Warning: Error updating ingredients display: #{e.message}"
        end
      end
    end
  end

  # Determine text color based on recipe availability status
  def get_recipe_color(recipe)
    begin
      if recipe.can_craft?
        COLOR_CRAFTABLE
      elsif recipe.unlocked?
        COLOR_LOCKED
      else
        COLOR_UNAVAILABLE
      end
    rescue => e
      puts "Warning: Error getting recipe color: #{e.message}"
      COLOR_UNAVAILABLE
    end
  end

  # Render individual recipe with name, quantity, and color coding
  def draw_recipe_item(recipe, rect)
    begin
      color = get_recipe_color(recipe)
      
      # Calculate maximum displayable characters
      char_width = self.contents.text_size("A").width
      max_chars = ((rect.width - RECIPE_TEXT_MAX_CHAR_CALC) / char_width).to_i
      
      # Clean recipe name encoding and handle special characters
      recipe_name = recipe.name.to_s.dup
      begin
        recipe_name = recipe_name.force_encoding("UTF-8")
      rescue
        # Use string as-is if encoding fails
      end
      
      recipe_name = recipe_name.gsub(/[^\x20-\x7E\u00A0-\uFFFF]/, '')
      name = recipe_name.length > max_chars ? recipe_name[0..max_chars-3] + "..." : recipe_name
      
      # Apply font scaling to text positioning
      text_x_offset = (RECIPE_TEXT_X_OFFSET * (@font_scale || 1.0)).round
      text_y_offset = (RECIPE_TEXT_Y_OFFSET * (@font_scale || 1.0)).round
      
      # Prepare recipe name text
      textpos = [[name, rect.x + text_x_offset, rect.y + text_y_offset, :left, color, COLOR_TEXT]]
      
      # Add quantity indicator if crafting multiple items
      if recipe.result_quantity > 1
        qty_text = "x#{recipe.result_quantity}"
        qty_margin = (QUANTITY_TEXT_RIGHT_MARGIN * (@font_scale || 1.0)).round
        qty_x = rect.x + rect.width - self.contents.text_size(qty_text).width - qty_margin
        textpos.push([qty_text, qty_x, rect.y + text_y_offset, :left, color, COLOR_TEXT])
      end
      
      pbDrawTextPositions(self.contents, textpos)
    rescue => e
      puts "Warning: Error drawing recipe item: #{e.message}"
    end
  end

  # Establish connection to parent scene for layout dependency updates
  def connect_to_scene(scene)
    @scene = scene
    update_window_dependencies
  end

  # Get currently selected recipe or cancel option
  def item
    return nil if @recipes.empty? && self.index != 0
    return :cancel if self.index == @recipes.length
    return :cancel if @recipes.empty? && self.index == 0
    return nil if self.index >= @recipes.length
    return @recipes[self.index]
  end

  # Calculate total item count including cancel option
  def itemCount
    @recipes.empty? ? 1 : @recipes.length + 1
  end

  # Render specific item at given index (recipe or cancel option)
  def drawItem(index, _count, rect)
    begin
      # Handle empty recipe list case
      if @recipes.empty?
        if index == 0
          textpos = [["Cancel", rect.x + 8, rect.y + 7, :left, COLOR_CANCEL, COLOR_TEXT]]
          pbDrawTextPositions(self.contents, textpos)
        end
        return
      end
      
      # Handle cancel option at end of list
      if index == @recipes.length
        textpos = [["Cancel", rect.x + 8, rect.y + 7, :left, COLOR_CANCEL, COLOR_TEXT]]
        pbDrawTextPositions(self.contents, textpos)
        return
      end
      
      return if index >= @recipes.length
      recipe = @recipes[index]
      return unless recipe
      
      draw_recipe_item(recipe, rect)
    rescue => e
      puts "Warning: Error drawing item at index #{index}: #{e.message}"
    end
  end

  # Update recipe list based on selected category
  def update_recipe_list
    begin
      @recipes = CraftingRecipeManager.recipes_by_category(@current_category) || []
      @item_max = itemCount
      
      update_window_dependencies
      
      # Ensure cursor stays within valid bounds
      max_index = [itemCount - 1, 0].max
      self.index = max_index if self.index > max_index
      self.index = 0 if self.index < 0
      
      refresh
    rescue => e
      puts "Error: Failed to update recipe list: #{e.message}"
      @recipes = []
      @item_max = 1
    end
  end

  # Safe resource disposal with error handling
  def dispose
    # Clean up cursor graphic
    begin
      if @selarrow && @selarrow.respond_to?(:dispose) && !@selarrow.disposed?
        @selarrow.dispose
      end
    rescue => e
      puts "Warning: Error disposing cursor graphic: #{e.message}"
    end
    @selarrow = nil
    
    # Clean up window contents
    begin
      if self.contents && self.contents.respond_to?(:dispose) && !self.contents.disposed?
        self.contents.dispose
      end
      self.contents = nil
    rescue => e
      puts "Warning: Error disposing window contents: #{e.message}"
    end
    
    # Skip parent disposal to avoid nil reference errors
  end

  # Initialize window contents bitmap with font configuration
  def setup_contents
    begin
      dwidth = self.width - self.borderX
      dheight = self.height - self.borderY
      
      if self.contents && !self.contents.disposed?
        self.contents.dispose
      end
      
      self.contents = Bitmap.new(dwidth, dheight)
      CraftingUIConfig.setup_crafting_font(self.contents, RECIPE_TEXT_SCALING_ENABLED, @font_scale || 1.0)
    rescue => e
      puts "Error: Failed to setup window contents: #{e.message}"
    end
  end

  # Refresh window display with cursor and item rendering
  def refresh
    begin
      @item_max = itemCount
      self.update_cursor_rect
      
      setup_contents
      self.contents.clear
      
      # Draw cursor as background highlight
      drawCursor(self.index, itemRect(self.index))
      
      # Draw all visible items over cursor
      @item_max.times do |i|
        next if i < self.top_item || i >= self.top_item + self.page_item_max
        rect = itemRect(i)
        if rect.width > 0 && rect.height > 0
          drawItem(i, @item_max, rect)
        end
      end
    rescue => e
      puts "Error: Failed to refresh recipe window: #{e.message}"
    end
  end

  # Update window state and animations
  def update
    # Skip Pokemon Essentials built-in input handling for manual control
    check_index_change
    
    # Animate cursor graphic
    if @selarrow
      begin
        @selarrow.update
      rescue => e
        puts "Warning: Error updating cursor animation: #{e.message}"
      end
    end
  end

  # Handle index changes and trigger refresh
  def index=(new_index)
    old_index = @index
    super(new_index)
    refresh if @index != old_index
  end

  # Change active category and reload recipes
  def current_category=(new_category)
    return if @current_category == new_category
    @current_category = new_category
    update_recipe_list
  end
end

#===============================================================================
# CraftingScene - Visual management for crafting interface
# Handles window positioning, background graphics, ingredient display, and result preview
#===============================================================================
class CraftingScene
  include CraftingUIConfig
  
  def initialize
    @current_category = "All Items"
    @disposed = false
  end

  # Get recipe window dimensions for layout calculations
  def get_recipe_window_dimensions
    begin
      dims = CraftingAssetManager.get_dimensions(RECIPE_BG_GRAPHIC, :ui)
      {
        x: RECIPE_WINDOW_X,
        y: RECIPE_WINDOW_Y,
        width: dims[:width],
        height: dims[:height]
      }
    rescue => e
      puts "Warning: Error getting recipe window dimensions: #{e.message}"
      { x: RECIPE_WINDOW_X, y: RECIPE_WINDOW_Y, width: 200, height: 200 }
    end
  end
    
  # Calculate category window position with screen boundary enforcement
  def calculate_category_window_position
    begin
      category_dims = CraftingAssetManager.get_dimensions(CATEGORY_BG_GRAPHIC, :ui)
      
      category_x = CATEGORY_WINDOW_X
      category_y = CATEGORY_WINDOW_Y
      
      # Keep window on screen
      category_x = [category_x, 0].max
      category_x = [category_x, Graphics.width - category_dims[:width]].min
      category_y = [category_y, 0].max
      category_y = [category_y, Graphics.height - category_dims[:height]].min
      
      {
        x: category_x,
        y: category_y,
        width: category_dims[:width],
        height: category_dims[:height]
      }
    rescue => e
      puts "Warning: Error calculating category window position: #{e.message}"
      { x: CATEGORY_WINDOW_X, y: CATEGORY_WINDOW_Y, width: 100, height: 50 }
    end
  end
    
  # Calculate navigation arrow positions relative to category window
  def calculate_arrow_positions
    begin
      category_pos = calculate_category_window_position
      arrow_left_dims = CraftingAssetManager.get_dimensions(ARROW_LEFT_GRAPHIC, :ui)
      arrow_right_dims = CraftingAssetManager.get_dimensions(ARROW_RIGHT_GRAPHIC, :ui)
      
      # Position arrows on either side of category window
      left_arrow_x = category_pos[:x] - arrow_left_dims[:width] - CATEGORY_ARROW_SPACING
      right_arrow_x = category_pos[:x] + category_pos[:width] + CATEGORY_ARROW_SPACING
      arrow_y = category_pos[:y] + (category_pos[:height] / 2) - (arrow_left_dims[:height] / 2)
      
      # Ensure arrows stay on screen
      left_arrow_x = [left_arrow_x, 0].max
      right_arrow_x = [right_arrow_x, Graphics.width - arrow_right_dims[:width]].min
      
      {
        left: { x: left_arrow_x, y: arrow_y },
        right: { x: right_arrow_x, y: arrow_y }
      }
    rescue => e
      puts "Warning: Error calculating arrow positions: #{e.message}"
      {
        left: { x: 10, y: CATEGORY_WINDOW_Y },
        right: { x: Graphics.width - 30, y: CATEGORY_WINDOW_Y }
      }
    end
  end

  # Initialize and display crafting scene
  def pbStartScene
    begin
      create_viewport
      create_background_sprites
      create_windows
      create_overlays
      
      update_arrow_visibility
      pbRefresh
      pbFadeInAndShow(@sprites)
    rescue => e
      puts "Error: Failed to start crafting scene: #{e.message}"
      puts "Error backtrace: #{e.backtrace.first(5).join("\n")}"
      dispose
    end
  end

  # Hide and cleanup crafting scene
  def pbEndScene
    begin
      pbFadeOutAndHide(@sprites)
    rescue => e
      puts "Warning: Error fading out crafting scene: #{e.message}"
    end
    dispose
  end

  # Manual resource disposal with error handling
  def dispose
    return if @disposed
    @disposed = true
    
    # Dispose all sprites safely
    if @sprites
      @sprites.each do |key, sprite|
        begin
          if sprite && sprite.respond_to?(:dispose)
            if sprite.respond_to?(:disposed?)
              sprite.dispose unless sprite.disposed?
            else
              sprite.dispose
            end
          end
        rescue => e
          puts "Warning: Error disposing sprite '#{key}': #{e.message}"
        end
      end
      @sprites.clear
    end
    
    # Dispose asset manager
    begin
      CraftingAssetManager.dispose_all
    rescue => e
      puts "Warning: Error disposing asset manager: #{e.message}"
    end
    
    # Dispose viewport
    begin
      if @viewport && @viewport.respond_to?(:dispose)
        if @viewport.respond_to?(:disposed?)
          @viewport.dispose unless @viewport.disposed?
        else
          @viewport.dispose
        end
      end
    rescue => e
      puts "Warning: Error disposing viewport: #{e.message}"
    end
    @viewport = nil
  end

  private

  # Create main viewport for sprite rendering
  def create_viewport
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
  end

  # Create background and UI element sprites
  def create_background_sprites
    begin
      # Main background
      @sprites["background"] = IconSprite.new(0, 0, @viewport)
      @sprites["background"].bitmap = CraftingAssetManager.load_asset("background.png", :ui)
      @sprites["background"].z = 0
      
      create_window_backgrounds
      create_navigation_arrows
    rescue => e
      puts "Error: Failed to create background sprites: #{e.message}"
    end
  end

  # Create window background graphics
  def create_window_backgrounds
    begin
      # Ingredients window background
      @sprites["ingredients_bg"] = IconSprite.new(INGREDIENTS_WINDOW_X, INGREDIENTS_WINDOW_Y, @viewport)
      @sprites["ingredients_bg"].bitmap = CraftingAssetManager.load_asset("ingredients_window.png", :ui)
      @sprites["ingredients_bg"].z = 1
      
      # Recipe list window background
      @sprites["recipe_bg"] = IconSprite.new(RECIPE_WINDOW_X, RECIPE_WINDOW_Y, @viewport)
      @sprites["recipe_bg"].bitmap = CraftingAssetManager.load_asset("recipe_window.png", :ui)
      @sprites["recipe_bg"].z = 1
      
      # Category selection window background
      category_pos = calculate_category_window_position
      @sprites["category_bg"] = IconSprite.new(category_pos[:x], category_pos[:y], @viewport)
      @sprites["category_bg"].bitmap = CraftingAssetManager.load_asset("category_window.png", :ui)
      @sprites["category_bg"].z = 1
      
      # Result description window background
      @sprites["description_bg"] = IconSprite.new(0, DESC_WINDOW_Y, @viewport)
      @sprites["description_bg"].bitmap = CraftingAssetManager.load_asset("craftable_description.png", :ui)
      @sprites["description_bg"].z = 1
    rescue => e
      puts "Error: Failed to create window backgrounds: #{e.message}"
    end
  end

  # Create category navigation arrows
  def create_navigation_arrows
    begin
      arrow_positions = calculate_arrow_positions
      
      @sprites["arrow_left"] = IconSprite.new(arrow_positions[:left][:x], arrow_positions[:left][:y], @viewport)
      @sprites["arrow_left"].bitmap = CraftingAssetManager.load_asset("arrow_left.png", :ui)
      @sprites["arrow_left"].z = 2
      
      @sprites["arrow_right"] = IconSprite.new(arrow_positions[:right][:x], arrow_positions[:right][:y], @viewport)
      @sprites["arrow_right"].bitmap = CraftingAssetManager.load_asset("arrow_right.png", :ui)
      @sprites["arrow_right"].z = 2
    rescue => e
      puts "Error: Failed to create navigation arrows: #{e.message}"
    end
  end

  # Create recipe selection window
  def create_windows
    begin
      recipe_dims = get_recipe_window_dimensions
      
      @sprites["recipelist"] = Window_CraftingRecipeList.new(
        recipe_dims[:x], 
        recipe_dims[:y], 
        recipe_dims[:width], 
        recipe_dims[:height]
      )
      @sprites["recipelist"].viewport = @viewport
      @sprites["recipelist"].z = 2
      @sprites["recipelist"].current_category = @current_category
      
      @sprites["recipelist"].connect_to_scene(self)
    rescue => e
      puts "Error: Failed to create recipe window: #{e.message}"
    end
  end

  # Create text overlay bitmaps for dynamic content
  def create_overlays
    begin
      ["ingredients_overlay", "result_item_overlay", "overlay"].each do |overlay_name|
        @sprites[overlay_name] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
        CraftingUIConfig.setup_crafting_font(@sprites[overlay_name].bitmap)
        @sprites[overlay_name].z = 3
      end
    rescue => e
      puts "Error: Failed to create overlays: #{e.message}"
    end
  end

  public

  # Update ingredient list and result preview based on selected recipe
  def update_ingredients_display
    begin
      clear_overlays
      
      recipe = current_recipe
      draw_ingredients_title
      
      return unless recipe && recipe != :cancel && recipe.is_a?(CraftingRecipe)
      
      draw_ingredients_list(recipe)
      draw_result_item(recipe)
    rescue => e
      puts "Error: Failed to update ingredients display: #{e.message}"
    end
  end

  private

  # Clear overlay bitmaps and reset font configuration
  def clear_overlays
    begin
      @sprites["ingredients_overlay"].bitmap.clear
      @sprites["result_item_overlay"].bitmap.clear
      
      CraftingUIConfig.setup_crafting_font(@sprites["ingredients_overlay"].bitmap)
      CraftingUIConfig.setup_crafting_font(@sprites["result_item_overlay"].bitmap)
    rescue => e
      puts "Warning: Error clearing overlays: #{e.message}"
    end
  end

  # Draw ingredients section title
  def draw_ingredients_title
    begin
      ingredients_window_width = CraftingAssetManager.get_dimensions("ingredients_window.png", :ui)[:width]
      title_x = INGREDIENTS_WINDOW_X + (ingredients_window_width / 2)
      title_y = INGREDIENTS_WINDOW_Y + INGREDIENTS_TITLE_Y_OFFSET
      
      textpos = [["Ingredients", title_x, title_y, :center, COLOR_TITLE, COLOR_TEXT]]
      pbDrawTextPositions(@sprites["ingredients_overlay"].bitmap, textpos)
    rescue => e
      puts "Warning: Error drawing ingredients title: #{e.message}"
    end
  end

  # Draw list of required ingredients with icons and quantities
  def draw_ingredients_list(recipe)
    begin
      ingredients_x = INGREDIENTS_WINDOW_X + INGREDIENTS_WINDOW_PADDING  
      ingredients_y = INGREDIENTS_WINDOW_Y + INGREDIENTS_LIST_Y_OFFSET
      
      recipe.ingredients.each_with_index do |(item_symbol, quantity), index|
        y_pos = ingredients_y + (index * INGREDIENT_SPACING)
        draw_single_ingredient(item_symbol, quantity, ingredients_x, y_pos)
      end
    rescue => e
      puts "Warning: Error drawing ingredients list: #{e.message}"
    end
  end

  # Draw individual ingredient with icon and text
  def draw_single_ingredient(item_symbol, quantity, x, y)
    begin
      draw_ingredient_icon(item_symbol, x, y)
      draw_ingredient_text(item_symbol, quantity, x + INGREDIENT_TEXT_X_OFFSET, y)
    rescue => e
      puts "Warning: Error drawing ingredient #{item_symbol}: #{e.message}"
    end
  end

  # Draw scaled ingredient icon
  def draw_ingredient_icon(item_symbol, x, y)
    begin
      item_graphic = CraftingAssetManager.load_item_graphic(item_symbol)
      return unless item_graphic && !item_graphic.disposed?
      
      scaled_graphic = CraftingAssetManager.create_scaled_asset(
        "#{item_symbol}.png", 
        INGREDIENT_ICON_SIZE, 
        INGREDIENT_ICON_SIZE, 
        :item
      )
      
      # Verify bitmaps are valid before blitting
      if scaled_graphic && !scaled_graphic.disposed? && 
        @sprites["ingredients_overlay"] && 
        @sprites["ingredients_overlay"].bitmap && 
        !@sprites["ingredients_overlay"].bitmap.disposed?
        
        @sprites["ingredients_overlay"].bitmap.blt(x, y, scaled_graphic, 
          Rect.new(0, 0, INGREDIENT_ICON_SIZE, INGREDIENT_ICON_SIZE))
      end
      
      # Clean up temporary scaled graphic
      if scaled_graphic && !scaled_graphic.disposed?
        scaled_graphic.dispose
      end
    rescue => e
      puts "Warning: Error drawing ingredient icon for #{item_symbol}: #{e.message}"
    end
  end

  # Draw ingredient text with availability-based coloring
  def draw_ingredient_text(item_symbol, quantity, x, y)
    begin
      item_data = CraftingUIConfig.get_item_data(item_symbol)
      
      # Color based on whether player has sufficient quantity
      text_color = item_data[:player_quantity] >= quantity ? COLOR_AVAILABLE : COLOR_MISSING
      ingredient_text = "#{item_data[:name]} x#{quantity}"
      
      # Use smaller font for ingredient text
      with_smaller_font do
        textpos = [[ingredient_text, x, y + INGREDIENT_TEXT_Y_OFFSET, :left, text_color, COLOR_TEXT]]
        pbDrawTextPositions(@sprites["ingredients_overlay"].bitmap, textpos)
      end
    rescue => e
      puts "Warning: Error drawing ingredient text for #{item_symbol}: #{e.message}"
    end
  end

  # Draw result item icon and description
  def draw_result_item(recipe)
    begin
      # Draw result item icon
      result_graphic = CraftingAssetManager.load_item_graphic(recipe.result_item)
      return unless result_graphic && !result_graphic.disposed?
      
      scaled_result = CraftingAssetManager.create_scaled_asset(
        "#{recipe.result_item}.png", 
        RESULT_ITEM_ICON_SIZE, 
        RESULT_ITEM_ICON_SIZE, 
        :item
      )
      
      # Verify bitmaps before blitting
      if scaled_result && !scaled_result.disposed? && 
        @sprites["result_item_overlay"] && 
        @sprites["result_item_overlay"].bitmap && 
        !@sprites["result_item_overlay"].bitmap.disposed?
        
        @sprites["result_item_overlay"].bitmap.blt(RESULT_ITEM_PANEL_X, RESULT_ITEM_PANEL_Y, 
          scaled_result, Rect.new(0, 0, RESULT_ITEM_ICON_SIZE, RESULT_ITEM_ICON_SIZE))
      end
      
      # Clean up temporary scaled graphic
      if scaled_result && !scaled_result.disposed?
        scaled_result.dispose
      end
      
      draw_result_item_text(recipe)
    rescue => e
      puts "Warning: Error drawing result item: #{e.message}"
    end
  end

  # Draw result item description with text wrapping
  def draw_result_item_text(recipe)
    begin
      result_data = CraftingUIConfig.get_item_data(recipe.result_item)
      
      text_x = RESULT_ITEM_PANEL_X + RESULT_TEXT_X_OFFSET
      textpos = []
      
      desc_y = RESULT_TEXT_Y
      add_wrapped_description(textpos, result_data[:description], text_x, desc_y)
      
      pbDrawTextPositions(@sprites["result_item_overlay"].bitmap, textpos)
    rescue => e
      puts "Warning: Error drawing result item text: #{e.message}"
    end
  end

  # Add word-wrapped text to text position array
  def add_wrapped_description(textpos, description, x, start_y)
    begin
      if description.length > RESULT_DESC_WRAP_THRESHOLD
        desc_lines = wrap_text(description, RESULT_DESC_MAX_CHARS)
        desc_lines.each_with_index do |line, idx|
          y_pos = start_y + (idx * RESULT_DESC_LINE_HEIGHT)
          textpos << [line, x, y_pos, :left, COLOR_TEXT, COLOR_SHADOW]
        end
      else
        textpos << [description, x, start_y, :left, COLOR_TEXT, COLOR_SHADOW]
      end
    rescue => e
      puts "Warning: Error wrapping description text: #{e.message}"
    end
  end

  # Temporarily adjust font size for ingredient text
  def with_smaller_font
    begin
      overlay = @sprites["ingredients_overlay"].bitmap
      old_size = overlay.font.size
      new_size = [old_size - INGREDIENT_FONT_SIZE_REDUCTION, INGREDIENT_MIN_FONT_SIZE].max
      overlay.font.size = new_size
      yield
      overlay.font.size = old_size
    rescue => e
      puts "Warning: Error adjusting font size: #{e.message}"
      yield  # Still execute the block even if font adjustment fails
    end
  end

  # Break text into lines within character limit
  def wrap_text(text, max_chars)
    words = text.split(' ')
    lines = []
    current_line = ""
    
    words.each do |word|
      if (current_line + word).length > max_chars
        lines << current_line.strip unless current_line.strip.empty?
        current_line = word + " "
      else
        current_line += word + " "
      end
    end
    lines << current_line.strip unless current_line.strip.empty?
    lines
  end

  public

  # Refresh all visual elements
  def pbRefresh
    begin
      @sprites["recipelist"]&.refresh
      update_arrow_visibility if @sprites && @sprites["arrow_left"] && @sprites["arrow_right"]
      update_category_text
      update_ingredients_display
    rescue => e
      puts "Error: Failed to refresh crafting scene: #{e.message}"
    end
  end

  # Update category name display with text truncation
  def update_category_text
    begin
      return unless @sprites["overlay"]
      
      @sprites["overlay"].bitmap.clear
      CraftingUIConfig.setup_crafting_font(@sprites["overlay"].bitmap)
      
      category_pos = calculate_category_window_position
      
      text_x = category_pos[:x] + (category_pos[:width] / 2)
      text_y = category_pos[:y] + (category_pos[:height] / 2) + CATEGORY_TEXT_Y_OFFSET
      
      display_name = get_display_category_name(@current_category)
      textpos = [[display_name, text_x, text_y, :center, COLOR_TEXT, COLOR_SHADOW]]
      pbDrawTextPositions(@sprites["overlay"].bitmap, textpos)
    rescue => e
      puts "Warning: Error updating category text: #{e.message}"
    end
  end

  # Truncate category name to fit within window width
  def get_display_category_name(category)
    begin
      category_pos = calculate_category_window_position
      
      temp_bitmap = Bitmap.new(100, 50)
      CraftingUIConfig.setup_crafting_font(temp_bitmap)
      
      text_width = temp_bitmap.text_size(category).width
      available_width = category_pos[:width] - 20
      
      temp_bitmap.dispose
      
      if text_width <= available_width
        return category
      else
        # Truncate with ellipsis
        truncated = category
        temp_bitmap = Bitmap.new(100, 50)
        CraftingUIConfig.setup_crafting_font(temp_bitmap)
        
        while temp_bitmap.text_size(truncated + "...").width > available_width && truncated.length > 1
          truncated = truncated[0..-2]
        end
        
        temp_bitmap.dispose
        truncated == category ? category : truncated + "..."
      end
    rescue => e
      puts "Warning: Error truncating category name: #{e.message}"
      return category
    end
  end

  # Update arrow opacity based on navigation availability
  def update_arrow_visibility
    begin
      current_index = CATEGORIES.index(@current_category) || 0
      total_categories = CATEGORIES.length
      
      # Dim arrows when navigation unavailable
      left_opacity = current_index > 0 ? ARROW_OPACITY_BRIGHT : ARROW_OPACITY_DIM
      right_opacity = current_index < total_categories - 1 ? ARROW_OPACITY_BRIGHT : ARROW_OPACITY_DIM
      
      set_arrow_opacity(left_opacity, right_opacity)
    rescue => e
      puts "Warning: Error updating arrow visibility: #{e.message}"
    end
  end

  # Switch between categories with left/right navigation
  def switch_category(direction)
    begin
      old_category = @current_category
      current_index = CATEGORIES.index(@current_category) || 0
      
      case direction
      when :left
        new_index = current_index > 0 ? current_index - 1 : current_index
      when :right
        new_index = current_index < CATEGORIES.length - 1 ? current_index + 1 : current_index
      else
        new_index = current_index
      end
      
      @current_category = CATEGORIES[new_index]
      
      # Update interface only if category changed
      if @current_category != old_category
        @sprites["recipelist"].current_category = @current_category
        update_arrow_visibility if @sprites && @sprites["arrow_left"] && @sprites["arrow_right"]
        update_category_text
        update_ingredients_display
      end
    rescue => e
      puts "Error: Failed to switch category: #{e.message}"
    end
  end

  # Update all sprite animations
  def pbUpdate
    begin
      pbUpdateSpriteHash(@sprites)
    rescue => e
      puts "Warning: Error updating sprites: #{e.message}"
    end
  end

  # Get currently selected recipe
  def current_recipe
    begin
      @sprites["recipelist"].item
    rescue => e
      puts "Warning: Error getting current recipe: #{e.message}"
      :cancel
    end
  end

  # Get current category name
  def current_category
    @current_category
  end

  # Provide access to sprites hash
  def sprites
    @sprites
  end

  private

  # Set navigation arrow opacity levels
  def set_arrow_opacity(left_opacity, right_opacity)
    begin
      @sprites["arrow_left"].opacity = left_opacity if @sprites["arrow_left"]
      @sprites["arrow_right"].opacity = right_opacity if @sprites["arrow_right"]
    rescue => e
      puts "Warning: Error setting arrow opacity: #{e.message}"
    end
  end
end

#===============================================================================
# CraftingScreen - Input handling and crafting execution
# Manages user input processing, recipe selection, and crafting confirmation
#===============================================================================
class CraftingScreen
  include CraftingUIConfig
  
  def initialize(scene)
    @scene = scene
  end

  # Main screen execution loop
  def pbStartScreen
    begin
      @scene.pbStartScene
      @recipe_window = @scene.sprites["recipelist"]
      
      handle_input_loop
    rescue => e
      puts "Error: Failed to start crafting screen: #{e.message}"
    ensure
      @scene.pbEndScene
    end
  end

  private

  # Primary input handling loop
  def handle_input_loop
    loop do
      begin
        Graphics.update
        Input.update
        @scene.pbUpdate
        
        break if process_input
      rescue => e
        puts "Error: Input handling error: #{e.message}"
        break
      end
    end
  end

  # Process user input and navigation
  def process_input
    begin
      if Input.trigger?(Input::UP)
        if @recipe_window.index > 0
          @recipe_window.index = @recipe_window.index - 1
          pbPlayCursorSE
        end
      elsif Input.trigger?(Input::DOWN)
        if @recipe_window.index < @recipe_window.itemCount - 1
          @recipe_window.index = @recipe_window.index + 1
          pbPlayCursorSE
        end
      elsif Input.trigger?(Input::LEFT)
        @scene.switch_category(:left)
        pbPlayCursorSE
      elsif Input.trigger?(Input::RIGHT)
        @scene.switch_category(:right)
        pbPlayCursorSE
      elsif Input.trigger?(Input::USE)
        return true if handle_selection
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        return true
      end
      
      false
    rescue => e
      puts "Error: Input processing error: #{e.message}"
      true  # Exit on error
    end
  end

  # Handle recipe selection and cancel option
  def handle_selection
    begin
      current_item = @scene.current_recipe
      
      # Exit on cancel selection
      if current_item == :cancel
        pbPlayCloseMenuSE
        return true
      end
      
      if current_item&.is_a?(CraftingRecipe)
        attempt_crafting(current_item)
      else
        pbSEPlay("GUI sel buzzer")
      end
      
      false
    rescue => e
      puts "Error: Selection handling error: #{e.message}"
      false
    end
  end

  # Attempt to craft selected recipe with validation
  def attempt_crafting(recipe)
    begin
      if recipe.can_craft?
        if pbConfirmMessage("Craft #{recipe.name}?")
          craft_recipe(recipe)
        end
      else
        pbSEPlay("GUI sel buzzer")
        Graphics.update
        show_crafting_error(recipe)
      end
    rescue => e
      puts "Error: Crafting attempt error: #{e.message}"
      pbSEPlay("GUI sel buzzer")
      pbMessage("An error occurred while trying to craft!")
    end
  end

  # Execute crafting process and display result
  def craft_recipe(recipe)
    begin
      if recipe.craft!
        # Play success sound effect
        begin
          pbMEPlay("Item get")
        rescue
          pbSEPlay("GUI menu open")
        end
        
        pbMessage("Successfully crafted #{recipe.name}!")
        @recipe_window.refresh
        @scene.pbRefresh
      else
        pbSEPlay("GUI sel buzzer")
        pbMessage("Failed to craft #{recipe.name}!")
      end
    rescue => e
      puts "Error: Recipe crafting error: #{e.message}"
      pbSEPlay("GUI sel buzzer")
      pbMessage("An error occurred during crafting!")
    end
  end

  # Display appropriate error message for failed crafting attempts
  def show_crafting_error(recipe)
    begin
      if recipe.unlocked?
        pbMessage("You don't have the required materials to craft #{recipe.name}!")
      else
        unlock_text = recipe.unlock_condition || "Complete certain requirements"
        pbMessage("This recipe is locked! #{unlock_text}")
      end
    rescue => e
      puts "Error: Error message display error: #{e.message}"
      pbMessage("Cannot craft this recipe!")
    end
  end
end

#===============================================================================
# Entry points and compatibility
#===============================================================================

# Primary function to launch crafting interface
def pbCraftingMenu
  begin
    scene = CraftingScene.new
    screen = CraftingScreen.new(scene)
    screen.pbStartScreen
  rescue => e
    puts "Error: Failed to launch crafting menu: #{e.message}"
  end
end

# Backward compatibility for legacy calling conventions
class Scene_Crafting
  def main
    pbCraftingMenu
  end
end