# ===============================================================================
# File: Plugins/CraftingSystem/CraftingAssets.rb
# Graphics loading and caching system for the crafting interface
# ===============================================================================

#===============================================================================
# CraftingAssetManager Module - Asset loading with caching and fallback support
# Handles graphics loading, provides fallback images for missing files, and manages memory
# Supports multiple file paths and naming conventions for flexible asset organization
#===============================================================================

module CraftingAssetManager
  # Base directory for UI graphics
  ASSET_PATH = "Graphics/UI/Crafting/"
  
  # Internal cache to avoid reloading the same graphics
  @cached_assets = {}
  
  #===============================================================================
  # Asset Loading Methods
  #===============================================================================
  
  # Load and cache an asset with automatic fallback for missing files
  # Returns cached version if already loaded, creates fallback if file missing
  def self.load_asset(filename, asset_type = :ui)
    return @cached_assets[filename] if @cached_assets[filename]
    
    begin
      # Try multiple possible file paths
      possible_paths = generate_asset_paths(filename, asset_type)
      
      # Attempt to load from each possible path
      possible_paths.each do |path|
        if File.exist?(path)
          @cached_assets[filename] = Bitmap.new(path)
          return @cached_assets[filename]
        end
      end
      
      # No file found - create appropriate fallback graphic
      puts "Warning: Asset file not found: #{filename}. Using fallback graphic."
      @cached_assets[filename] = create_fallback_graphic(asset_type)
      return @cached_assets[filename]
    rescue => e
      puts "Error: Failed to load asset '#{filename}': #{e.message}"
      @cached_assets[filename] = create_fallback_graphic(asset_type)
      return @cached_assets[filename]
    end
  end
  
  #===============================================================================
  # Path Generation
  #===============================================================================
  
  # Generate multiple possible file paths to check for asset loading
  # Supports different cases and file extensions for flexibility
  def self.generate_asset_paths(filename, asset_type)
    paths = []
    
    begin
      case asset_type
      when :item
        # Item graphics can have various naming conventions
        base_path = CraftingUIConfig::ITEM_GRAPHICS_PATH
        item_name = filename.gsub('.png', '')
        paths = [
          "#{base_path}#{item_name}.png",        # Exact name
          "#{base_path}#{item_name.downcase}.png", # Lowercase
          "#{base_path}#{item_name.capitalize}.png", # Capitalized
          "#{base_path}#{item_name}.PNG"         # Uppercase extension
        ]
      when :ui
        # UI graphics typically use standard paths
        paths = [
          "#{ASSET_PATH}#{filename}",    # Standard UI path
          filename                       # Allow full paths to be passed directly
        ]
      end
    rescue => e
      puts "Warning: Error generating asset paths for '#{filename}': #{e.message}"
      # Fallback to basic path
      paths = [filename]
    end
    
    paths
  end
  
  #===============================================================================
  # Fallback Graphics
  #===============================================================================
  
  # Create appropriate fallback graphic when asset file is missing
  # Different colors/styles for different asset types for easier debugging
  def self.create_fallback_graphic(asset_type)
    begin
      case asset_type
      when :item
        # Item fallback: Light gray with border (looks like generic item icon)
        fallback = Bitmap.new(32, 32)
        fallback.fill_rect(0, 0, 32, 32, Color.new(200, 200, 200))  # Light gray background
        fallback.fill_rect(2, 2, 28, 28, Color.new(160, 160, 160))  # Darker gray border
        
        # Add text indicator using centralized font setup
        CraftingUIConfig.setup_crafting_font(fallback)
        fallback.font.size = 8
        fallback.draw_text(0, 12, 32, 8, "?", 1)  # Center question mark
        
      when :ui
        # UI fallback: Blue-ish color to distinguish from items
        fallback = Bitmap.new(32, 32)
        fallback.fill_rect(0, 0, 32, 32, Color.new(100, 100, 150))
        
        # Add text indicator using centralized font setup
        CraftingUIConfig.setup_crafting_font(fallback)
        fallback.font.size = 8
        fallback.draw_text(0, 12, 32, 8, "UI", 1)  # Center "UI" text
        
      else
        # Generic fallback: Medium gray
        fallback = Bitmap.new(32, 32)
        fallback.fill_rect(0, 0, 32, 32, Color.new(150, 150, 150))
        
        # Add text indicator using centralized font setup
        CraftingUIConfig.setup_crafting_font(fallback)
        fallback.font.size = 8
        fallback.draw_text(0, 12, 32, 8, "??", 1)  # Center question marks
      end
      
      fallback
    rescue => e
      puts "Error: Failed to create fallback graphic: #{e.message}"
      # Emergency fallback - simple bitmap
      emergency_fallback = Bitmap.new(32, 32)
      emergency_fallback.fill_rect(0, 0, 32, 32, Color.new(128, 128, 128))
      emergency_fallback
    end
  end
  
  #===============================================================================
  # Asset Utility Methods
  #===============================================================================
  
  # Get dimensions of an asset (loads if not cached, but doesn't cache just for dimensions)
  def self.get_dimensions(filename, asset_type = :ui)
    begin
      asset = load_asset(filename, asset_type)
      { width: asset.width, height: asset.height }
    rescue => e
      puts "Warning: Error getting dimensions for '#{filename}': #{e.message}"
      { width: 32, height: 32 }  # Safe fallback dimensions
    end
  end
  
  # Create a scaled version of an asset (for resizing icons)
  # Note: Caller is responsible for disposing the returned bitmap
  def self.create_scaled_asset(filename, width, height, asset_type = :ui)
    begin
      source = load_asset(filename, asset_type)
      return nil unless source && !source.disposed?
      
      scaled = Bitmap.new(width, height)
      
      # Use stretch_blt for high-quality scaling
      scaled.stretch_blt(
        Rect.new(0, 0, width, height), 
        source, 
        Rect.new(0, 0, source.width, source.height)
      )
      
      scaled
    rescue => e
      puts "Error: Failed to create scaled asset '#{filename}': #{e.message}"
      # Return a fallback scaled graphic
      fallback = Bitmap.new(width, height)
      fallback.fill_rect(0, 0, width, height, Color.new(128, 128, 128))
      fallback
    end
  end
  
  #===============================================================================
  # Memory Management
  #===============================================================================
  
  # Dispose all cached assets and clear the cache
  # Call this when exiting the crafting system to free memory
  def self.dispose_all
    begin
      @cached_assets.each do |filename, bitmap|
        begin
          if bitmap && bitmap.respond_to?(:dispose) && !bitmap.disposed?
            bitmap.dispose
          end
        rescue => e
          puts "Warning: Error disposing cached asset '#{filename}': #{e.message}"
        end
      end
      @cached_assets.clear
    rescue => e
      puts "Error: Failed to dispose all assets: #{e.message}"
      @cached_assets.clear  # Clear the cache even if disposal fails
    end
  end
  
  #===============================================================================
  # Convenience Methods
  #===============================================================================
  
  # Load item graphic specifically (convenience method for item icons)
  # Automatically adds .png extension and uses :item asset type
  def self.load_item_graphic(item_symbol)
    begin
      item_name = item_symbol.to_s
      load_asset("#{item_name}.png", :item)
    rescue => e
      puts "Warning: Error loading item graphic for '#{item_symbol}': #{e.message}"
      create_fallback_graphic(:item)
    end
  end
end