#===============================================================================
# Pokemon Summary handlers.
#===============================================================================
UIHandlers.add(:summary, :page_innates, { 
  "name"      => "INNATES",
  "suffix"    => "innates",
  "order"     => 31,
  "options"   => [:item, :nickname, :pokedex, :mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageINNATES }
})