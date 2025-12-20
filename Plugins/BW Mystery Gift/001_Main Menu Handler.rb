MenuHandlers.add(:pause_menu, :Mystery_Gift, {
  "name"      => proc { "Mystery Gift" },
  "order"     => 75,
  "condition" => proc { $player.mystery_gift_unlocked },
  "effect"    => proc { |menu|
    pbPlayDecisionSE
    pbFadeOutIn do
      scene = PokemonMGift_Scene.new
      screen = PokemonMGiftScreen.new(scene)
      screen.pbStartScreen
      menu.pbRefresh
    end
    next false
  }
})
