# Did somebody say BUSSY?
# Wait, no. Not like that.
# Stop.

MultipleForms.register(:LOPUNNYx,{
  "getFormOnCreation" => proc { |pkmn|
    r = rand(100)
    if r<1;     next 0   # Nip Slip & Vag (Fuck you guys, I kept it.)
    elsif r<13; next 1   # Blue
    elsif r<27; next 2   # Green
    elsif r<41; next 3   # Red
    elsif r<54; next 4   # Yellow
    elsif r<67; next 5   # Purple
    elsif r<80; next 6   # Black
    elsif r<93; next 7   # Pink
    end
  }
})