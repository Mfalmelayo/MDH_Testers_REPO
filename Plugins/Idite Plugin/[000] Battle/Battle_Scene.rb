#===============================================================================
# Phoenix Down Animation.
#===============================================================================
class Battle::Scene::Animation::BattlerReborn1 < Battle::Scene::Animation
  def initialize(sprites,viewport,idxBattler,battle)
    @idxBattler = idxBattler
    @battle     = battle
    super(sprites,viewport)
  end

  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    # Set up battler/shadow sprite
    battler = addSprite(batSprite,PictureOrigin::BOTTOM)
    shadow  = addSprite(shaSprite,PictureOrigin::CENTER)
    # Animation
    # Play cry
    delay = 10
    cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn, "_faint")
    if cry   # Play a specific faint cry
      battler.setSE(0, cry)
      delay = (GameData::Species.cry_length(batSprite.pkmn, nil, nil, "_faint") * 20).ceil
    else
      cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn)
      if cry   # Play the regular cry at a lower pitch (75)
        battler.setSE(0, cry, nil, 75)
        delay = (GameData::Species.cry_length(batSprite.pkmn, nil, 75) * 20).ceil
      end
    end
    shadow.setVisible(0,false)
    battler.setSE(delay,"Pkmn faint")
    16.times do
      batSprite.opacity -= 16
      pbWait(2/16)
    end
    batSprite.opacity = 0
    battler.setVisible(delay,false)
  end
end

class Battle::Scene::Animation::BattlerReborn2 < Battle::Scene::Animation
  def initialize(sprites,viewport,idxBattler,battle)
    @idxBattler = idxBattler
    @battle     = battle
    super(sprites,viewport)
  end

  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    battler = addSprite(batSprite,PictureOrigin::BOTTOM)
    shadow  = addSprite(shaSprite,PictureOrigin::CENTER)
    delay = 10
    cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn)
    if cry   # Play a specific faint cry
      battler.setSE(0, cry)
      delay = (GameData::Species.cry_length(batSprite.pkmn) * 20).ceil
    else
      cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn)
      if cry   # Play the regular cry at a lower pitch (75)
        battler.setSE(0, cry, nil, 75)
        delay = (GameData::Species.cry_length(batSprite.pkmn, nil, 75) * 20).ceil
      end
    end
    battler.setVisible(0,true)
    batSprite.opacity = 0
    16.times do
      batSprite.opacity += 16
      batSprite.color.set(batSprite.opacity,0,0,128)
      pbWait(2/16)
    end
    batSprite.opacity = 255
    battler.setSE(0,cry,nil,60) if cry
    shadow.setVisible(0,true)
  end
end

class Battle::Scene
def pbReborn1Battler(battler)
    @briefMessage = false
    rebornAnim   = Animation::BattlerReborn1.new(@sprites, @viewport, battler.index, @battle)
    dataBoxAnim = Animation::DataBoxDisappear.new(@sprites, @viewport, battler.index)
    loop do
      rebornAnim.update
      dataBoxAnim.update
      pbUpdate
      break if rebornAnim.animDone? && dataBoxAnim.animDone?
    end
    rebornAnim.dispose
    dataBoxAnim.dispose
  end

  def pbReborn2Battler(battler)
    @briefMessage = false
    rebornAnim   = Animation::BattlerReborn2.new(@sprites,@viewport,battler.index,@battle)
    dataBoxAnim = Animation::DataBoxAppear.new(@sprites, @viewport, battler.index)
    loop do
      rebornAnim.update
      dataBoxAnim.update
      pbUpdate
      break if rebornAnim.animDone? && dataBoxAnim.animDone?
    end
    rebornAnim.dispose
    dataBoxAnim.dispose
  end
end