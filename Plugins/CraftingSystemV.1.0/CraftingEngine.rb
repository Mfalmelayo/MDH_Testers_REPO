# ===============================================================================
# File: Plugins/CraftingSystem/CraftingEngine.rb
# Core crafting logic: recipe management, unlock conditions, and crafting execution
# ===============================================================================

#===============================================================================
# CraftingRecipe Class - Individual recipe representation
# Handles recipe data, unlock conditions, and crafting execution
#===============================================================================

class CraftingRecipe
  attr_reader :id, :result_item, :result_quantity, :ingredients, :name, :description, :category, :unlock_condition
  
  # Initialize a new crafting recipe with all necessary data
  def initialize(id, result_item, result_quantity, ingredients, name = nil, description = nil, unlock_condition = nil)
    @id = id
    @result_item = result_item
    @result_quantity = result_quantity
    @ingredients = ingredients
    
    begin
      @name = name || GameData::Item.get(result_item).name
    rescue => e
      puts "Warning: Could not get name for item #{result_item}: #{e.message}"
      @name = name || result_item.to_s.capitalize
    end
    
    @description = description || "Craft #{@name}"
    @category = nil
    @unlock_condition = unlock_condition
  end
  
  # Get category name for UI filtering - defaults to "All Items" if none set
  def category_name
    return @category if @category && !@category.empty?
    return "All Items"
  end

  # Check if recipe unlock conditions are met
  def unlocked?
    return true if @unlock_condition.nil? || @unlock_condition.empty?
    begin
      return CraftingUnlockChecker.check_condition(@unlock_condition)
    rescue => e
      puts "Warning: Error checking unlock condition '#{@unlock_condition}': #{e.message}"
      return false
    end
  end
  
  # Check if player can craft this recipe (unlocked + has ingredients)
  def can_craft?
    return false unless unlocked?
    
    begin
      @ingredients.each do |item, quantity|
        return false if $bag.quantity(item) < quantity
      end
      return true
    rescue => e
      puts "Warning: Error checking crafting availability for #{@name}: #{e.message}"
      return false
    end
  end
  
  # Execute the crafting process - remove ingredients and add result item
  def craft!
    return false unless can_craft?
    
    begin
      @ingredients.each { |item, quantity| $bag.remove(item, quantity) }
      $bag.add(@result_item, @result_quantity)
      return true
    rescue => e
      puts "Error: Failed to craft #{@name}: #{e.message}"
      return false
    end
  end
end

#===============================================================================
# CraftingUnlockChecker Module - Recipe unlock condition evaluation
# Handles various unlock condition types: badges, story flags, items, pokemon data, money
#===============================================================================

module CraftingUnlockChecker
  # Parse and check unlock condition string - supports multiple conditions separated by commas
  def self.check_condition(condition_string)
    return true if condition_string.nil? || condition_string.strip.empty?
    
    begin
      conditions = condition_string.split(",").map(&:strip)
      conditions.all? { |condition| evaluate_single_condition(condition) }
    rescue => e
      puts "Warning: Error parsing unlock condition '#{condition_string}': #{e.message}"
      return false
    end
  end
  
  private
  
  # Evaluate a single unlock condition using regex pattern matching
  def self.evaluate_single_condition(condition)
    begin
      case condition
      # Badge count conditions (e.g., "badges >= 3")
      when /^badges\s*([><=]+)\s*(\d+)$/i
        operator, value = $1, $2.to_i
        badge_count = $player.badge_count rescue 0
        compare_values(badge_count, operator, value)
        
      # Story flag conditions (e.g., "story_flag('CHAMPION_DEFEATED')")
      when /^story_flag\s*\(\s*["\']([^"\']+)["\']\s*\)$/i
        flag_name = $1
        switch_id = find_switch_id(flag_name)
        return false if switch_id == 0
        $game_switches && $game_switches[switch_id] rescue false
        
      # Item possession conditions (e.g., "has_item('MASTERBALL')")
      when /^has_item\s*\(\s*["\']([^"\']+)["\']\s*\)$/i
        item_symbol = $1.upcase.to_sym
        $bag.has?(item_symbol) rescue false
        
      # Pokemon seen count conditions (e.g., "pokemon_seen >= 50")
      when /^pokemon_seen\s*([><=]+)\s*(\d+)$/i
        operator, value = $1, $2.to_i
        seen_count = $player.pokedex.seen_count rescue 0
        compare_values(seen_count, operator, value)
        
      # Pokemon caught count conditions (e.g., "pokemon_caught >= 25")
      when /^pokemon_caught\s*([><=]+)\s*(\d+)$/i
        operator, value = $1, $2.to_i
        owned_count = $player.pokedex.owned_count rescue 0
        compare_values(owned_count, operator, value)
        
      # Pokemon level conditions (e.g., "level >= 30")
      when /^level\s*([><=]+)\s*(\d+)$/i
        operator, value = $1, $2.to_i
        max_level = $player.party.map(&:level).max rescue 1
        compare_values(max_level, operator, value)
        
      # Money conditions (e.g., "money >= 10000")
      when /^money\s*([><=]+)\s*(\d+)$/i
        operator, value = $1, $2.to_i
        player_money = $player.money rescue 0
        compare_values(player_money, operator, value)
        
      # Unknown condition type - return false
      else
        puts "Warning: Unknown unlock condition type: #{condition}"
        false
      end
    rescue => e
      puts "Warning: Error evaluating unlock condition '#{condition}': #{e.message}"
      false
    end
  end
  
  # Compare two values using the specified operator (>=, <=, ==, >, <)
  def self.compare_values(actual, operator, expected)
    case operator.strip
    when ">=" then actual >= expected
    when "<=" then actual <= expected
    when "==" then actual == expected
    when ">" then actual > expected
    when "<" then actual < expected
    else false
    end
  end
  
  # Map story flag names to game switch IDs using configurable hash
  def self.find_switch_id(name)
    begin
      # Check configurable switches first
      switch_id = CraftingUIConfig::STORY_SWITCHES[name.upcase]
      return switch_id if switch_id
      
      # Try to find the switch in GameData if not in configured list
      game_data_switch = GameData::Switch.try_get(name.upcase.to_sym)
      return game_data_switch.id if game_data_switch
      
      puts "Warning: Switch '#{name}' not found in STORY_SWITCHES or GameData"
      return 0
    rescue => e
      puts "Warning: Error finding switch ID for '#{name}': #{e.message}"
      return 0
    end
  end
end

#===============================================================================
# CraftingRecipeManager Module - Recipe data management and PBS loading
# Handles loading recipes from PBS file and filtering by categories
#===============================================================================

module CraftingRecipeManager
  @recipes = {}
  @loaded = false

  # Load all recipes from the PBS file (only loads once per game session)
  def self.load_recipes
    return if @loaded
    
    @recipes.clear
    filename = "PBS/crafting_recipes.txt"
    
    # Exit early if PBS file doesn't exist
    unless File.exist?(filename)
      puts "Warning: Crafting recipes file not found: #{filename}"
      @loaded = true
      return
    end
    
    begin
      # Parse the PBS file line by line
      current_recipe = nil
      
      File.open(filename, "rb") do |file|
        file.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?("#")  # Skip empty lines and comments
          
          # Recipe section headers [recipe_id]
          if line.start_with?("[") && line.end_with?("]")
            save_current_recipe(current_recipe) if current_recipe  # Save previous recipe
            current_recipe = { id: line[1..-2].downcase.to_sym }   # Start new recipe
            
          # Recipe property lines (key = value)
          elsif current_recipe && line.include?("=")
            key, value = line.split("=", 2).map(&:strip)
            
            case key.downcase
            when "name"
              current_recipe[:name] = value
            when "description"
              current_recipe[:description] = value
            when "result"
              # Parse result item and quantity (e.g., "POKEBALL, 5")
              item, qty = value.split(",").map(&:strip)
              current_recipe[:result_item] = item.upcase.to_sym
              current_recipe[:result_quantity] = qty.to_i
            when "ingredients"
              # Parse ingredients list (e.g., "APRICORN, 2, IRON, 1")
              ingredients = {}
              items = value.split(",").map(&:strip)
              
              # Process ingredients in pairs (item, quantity)
              items.each_slice(2) do |item, qty|
                next unless item && qty && !item.empty? && !qty.empty?
                clean_item = item.strip.upcase.to_sym
                clean_qty = qty.strip.to_i
                ingredients[clean_item] = clean_qty if clean_qty > 0
              end
              current_recipe[:ingredients] = ingredients
            when "category"
              current_recipe[:category] = value
            when "unlockcondition"
              current_recipe[:unlock_condition] = value
            end
          end
        end
        
        # Save the last recipe
        save_current_recipe(current_recipe) if current_recipe
      end
    rescue => e
      puts "Error: Failed to load crafting recipes from #{filename}: #{e.message}"
    end
    
    @loaded = true
  end
  
  # Convert parsed recipe data into a CraftingRecipe object and store it
  def self.save_current_recipe(recipe_data)
    return unless recipe_data[:result_item] && recipe_data[:ingredients]
    
    begin
      recipe = CraftingRecipe.new(
        recipe_data[:id],
        recipe_data[:result_item],
        recipe_data[:result_quantity] || 1,
        recipe_data[:ingredients],
        recipe_data[:name],
        recipe_data[:description],
        recipe_data[:unlock_condition]
      )
      recipe.instance_variable_set(:@category, recipe_data[:category])
      @recipes[recipe.id] = recipe
    rescue => e
      puts "Warning: Failed to create recipe #{recipe_data[:id]}: #{e.message}"
    end
  end
  
  # Get all unlocked recipes (used for "All Items" category)
  def self.unlocked_recipes
    begin
      load_recipes
      return @recipes.values.select { |recipe| recipe.unlocked? }
    rescue => e
      puts "Error: Failed to get unlocked recipes: #{e.message}"
      return []
    end
  end
  
  # Get recipes filtered by category and sorted alphabetically
  def self.recipes_by_category(category_name)
    begin
      load_recipes
      recipes = @recipes.values.select { |recipe| recipe.unlocked? }
      
      # Filter by category unless "All Items" is selected
      if category_name == "All Items"
        filtered_recipes = recipes
      else
        filtered_recipes = recipes.select { |recipe| recipe.category_name == category_name }
      end
      
      return filtered_recipes.sort_by { |recipe| recipe.name.downcase }
    rescue => e
      puts "Error: Failed to get recipes by category '#{category_name}': #{e.message}"
      return []
    end
  end
end