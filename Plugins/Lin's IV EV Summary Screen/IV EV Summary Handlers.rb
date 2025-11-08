#===============================================================================
# Pokemon Summary handlers.
#===============================================================================
UIHandlers.add(:summary, :page_allstats, { 
  "name"      => "Stats",
  "suffix"    => "allstats",
  "order"     => 35,
  "options"   => [:item, :nickname, :pokedex, :mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageAllStats }
})