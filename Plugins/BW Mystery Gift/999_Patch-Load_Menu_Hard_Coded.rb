#===============================================================================
# Hide Mystery Gift option in Load Screen completely for multi-save (brute force approch)
#===============================================================================
if Object.const_defined?(:PokemonLoadScreen) && defined?(SaveData::AUTO_SLOTS)
  class PokemonLoadScreen
    alias_method :pbStartLoadScreen_old, :pbStartLoadScreen

    def pbStartLoadScreen
      save_file_list = SaveData::AUTO_SLOTS + SaveData::MANUAL_SLOTS
      first_time = true
      loop do
        if @selected_file
          @save_data = load_save_file(SaveData.get_full_path(@selected_file))
        else
          @save_data = {}
        end

        commands = []
        cmd_continue     = -1
        cmd_new_game     = -1
        cmd_options      = -1
        cmd_language     = -1
        cmd_debug        = -1
        cmd_quit         = -1

        show_continue = !@save_data.empty?
        if show_continue
          commands[cmd_continue = commands.length] = " <- #{@selected_file} -> "
        end

        commands[cmd_new_game = commands.length]  = _INTL('New Game')
        commands[cmd_options = commands.length]   = _INTL('Options')
        commands[cmd_language = commands.length]  = _INTL('Language') if Settings::LANGUAGES.length >= 2
        commands[cmd_debug = commands.length]     = _INTL('Debug') if $DEBUG
        commands[cmd_quit = commands.length]      = _INTL('Quit Game')

        cmd_left = -3
        cmd_right = -2

        map_id = show_continue ? @save_data[:map_factory].map.map_id : 0
        @scene.pbStartScene(commands, show_continue, @save_data[:player], @save_data[:stats], map_id)
        @scene.pbSetParty(@save_data[:player]) if show_continue
        if first_time
          @scene.pbStartScene2
          first_time = false
        else
          @scene.pbUpdate
        end

        loop do
          command = @scene.pbChoose(commands, cmd_continue)
          pbPlayDecisionSE if command != cmd_quit

          case command
          when cmd_continue
            @scene.pbEndScene
            Game.load(@save_data)
            return
          when cmd_new_game
            @scene.pbEndScene
            Game.start_new
            return
          when cmd_options
            pbFadeOutIn do
              scene = PokemonOption_Scene.new
              screen = PokemonOptionScreen.new(scene)
              screen.pbStartScreen(true)
            end
          when cmd_language
            @scene.pbEndScene
            $PokemonSystem.language = pbChooseLanguage
            MessageTypes.load_message_files(Settings::LANGUAGES[$PokemonSystem.language][1])
            if show_continue
              @save_data[:pokemon_system] = $PokemonSystem
              File.open(SaveData.get_full_path(@selected_file), "wb") { |file| Marshal.dump(@save_data, file) }
            end
            $scene = pbCallTitle
            return
          when cmd_debug
            pbFadeOutIn { pbDebugMenu(false) }
          when cmd_quit
            pbPlayCloseMenuSE
            @scene.pbEndScene
            $scene = nil
            return
          when cmd_left
            @scene.pbCloseScene
            @selected_file = SaveData.get_prev_slot(save_file_list, @selected_file)
            break
          when cmd_right
            @scene.pbCloseScene
            @selected_file = SaveData.get_next_slot(save_file_list, @selected_file)
            break
          else
            pbPlayBuzzerSE
          end
        end
      end
    end
  end
end
