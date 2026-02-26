# frozen_string_literal: true

require 'time'
require 'wx'

require_relative '../infrastructure/app_paths'

module TranslationFiesta
  module Gui
    APP_DISPLAY_NAME = 'TranslationFiesta Ruby'

    class MainFrame < Wx::Frame
      IMPORT_WILDCARD = 'Supported files (*.txt;*.md;*.html;*.epub)|*.txt;*.md;*.html;*.epub|All files (*.*)|*.*'
      EXPORT_WILDCARD = [
        'Text files (*.txt)|*.txt',
        'Markdown files (*.md)|*.md',
        'HTML files (*.html)|*.html',
        'PDF files (*.pdf)|*.pdf',
        'Word files (*.docx)|*.docx'
      ].join('|')

      # Unified dark colour palette
      WINDOW_BACKGROUND = Wx::Colour.new(15, 20, 25)       # #0F1419
      CONTENT_BACKGROUND = Wx::Colour.new(26, 31, 46)      # #1A1F2E
      ELEVATED_BACKGROUND = Wx::Colour.new(36, 42, 56)     # #242A38
      ACCENT_BLUE = Wx::Colour.new(59, 130, 246)           # #3B82F6
      ACCENT_HOVER = Wx::Colour.new(37, 99, 235)           # #2563EB
      BORDER_COLOUR = Wx::Colour.new(46, 54, 72)           # #2E3648
      TEXT_PRIMARY = Wx::Colour.new(232, 236, 241)          # #E8ECF1
      TEXT_SECONDARY = Wx::Colour.new(139, 149, 165)        # #8B95A5
      STATUS_ERROR = Wx::Colour.new(239, 68, 68)            # #EF4444
      STATUS_SUCCESS = Wx::Colour.new(16, 185, 129)         # #10B981
      STATUS_AMBER = Wx::Colour.new(245, 158, 11)           # #F59E0B

      def initialize(container:, settings_store:)
        super(nil, :title => APP_DISPLAY_NAME, :size => [1024, 720])

        @container = container
        @settings_store = settings_store
        @last_result = nil
        @busy = false

        self.min_size = [800, 600]

        build_menu
        build_layout
        bind_events
        apply_initial_state
      end

      private

      attr_reader :container, :settings_store

      def build_menu
        menu_bar = Wx::MenuBar.new

        file_menu = Wx::Menu.new
        file_menu.append(Wx::ID_OPEN, '&Open Source...\tCtrl+O')
        file_menu.append(Wx::ID_SAVE, '&Export Result...\tCtrl+S')
        file_menu.append_separator
        file_menu.append(Wx::ID_EXIT, 'E&xit\tCtrl+Q')
        menu_bar.append(file_menu, '&File')

        help_menu = Wx::Menu.new
        help_menu.append(Wx::ID_ABOUT, '&About')
        menu_bar.append(help_menu, '&Help')

        self.menu_bar = menu_bar
      end

      def build_layout
        self.background_colour = WINDOW_BACKGROUND

        panel = Wx::Panel.new(self)
        panel.background_colour = WINDOW_BACKGROUND

        title_font = Wx::Font.new(16, Wx::FONTFAMILY_SWISS, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
        label_font = Wx::Font.new(8, Wx::FONTFAMILY_SWISS, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
        editor_font = Wx::Font.new(10, Wx::FONTFAMILY_SWISS, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
        btn_font = Wx::Font.new(10, Wx::FONTFAMILY_SWISS, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
        hero_font = Wx::Font.new(10, Wx::FONTFAMILY_SWISS, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)

        root_sizer = Wx::BoxSizer.new(Wx::VERTICAL)

        # === Header row: title + provider ===
        header_row = Wx::BoxSizer.new(Wx::HORIZONTAL)

        title_label = Wx::StaticText.new(panel, :label => APP_DISPLAY_NAME)
        title_label.font = title_font
        title_label.foreground_colour = TEXT_PRIMARY
        header_row.add(title_label, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::RIGHT, 16)

        @provider_choice = Wx::Choice.new(panel, :choices => ['Google Translate (Unofficial / Free)'])
        @provider_choice.foreground_colour = TEXT_PRIMARY
        @provider_choice.background_colour = CONTENT_BACKGROUND
        header_row.add(@provider_choice, 1, Wx::ALIGN_CENTER_VERTICAL)

        root_sizer.add(header_row, 0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::TOP, 24)

        # === Input section ===
        input_label = Wx::StaticText.new(panel, :label => 'INPUT')
        input_label.font = label_font
        input_label.foreground_colour = TEXT_SECONDARY
        root_sizer.add(input_label, 0, Wx::LEFT | Wx::TOP, 24)

        @source_text = Wx::TextCtrl.new(
          panel,
          :style => Wx::TE_MULTILINE | Wx::TE_RICH2 | Wx::BORDER_NONE
        )
        @source_text.font = editor_font
        @source_text.background_colour = CONTENT_BACKGROUND
        @source_text.foreground_colour = TEXT_PRIMARY
        root_sizer.add(@source_text, 1, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::TOP, 24)

        # === Action row ===
        action_row = Wx::BoxSizer.new(Wx::HORIZONTAL)

        @translate_button = Wx::Button.new(panel, :label => "\u29BF Backtranslate")
        @translate_button.font = hero_font
        @translate_button.background_colour = ACCENT_BLUE
        @translate_button.foreground_colour = Wx::WHITE
        action_row.add(@translate_button, 0, Wx::RIGHT, 8)

        @open_button = Wx::Button.new(panel, :label => 'Import')
        @open_button.font = btn_font
        @open_button.background_colour = ELEVATED_BACKGROUND
        @open_button.foreground_colour = TEXT_PRIMARY
        action_row.add(@open_button, 0, Wx::RIGHT, 8)

        @export_button = Wx::Button.new(panel, :label => 'Save')
        @export_button.font = btn_font
        @export_button.background_colour = ELEVATED_BACKGROUND
        @export_button.foreground_colour = TEXT_PRIMARY
        action_row.add(@export_button, 0, Wx::RIGHT, 8)

        @clear_button = Wx::Button.new(panel, :label => 'Clear')
        @clear_button.font = btn_font
        @clear_button.background_colour = ELEVATED_BACKGROUND
        @clear_button.foreground_colour = TEXT_PRIMARY
        action_row.add(@clear_button, 0)

        root_sizer.add(action_row, 0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::TOP, 24)

        # === Side-by-side output panels ===
        output_labels_row = Wx::BoxSizer.new(Wx::HORIZONTAL)
        ja_label = Wx::StaticText.new(panel, :label => 'INTERMEDIATE (JA)')
        ja_label.font = label_font
        ja_label.foreground_colour = TEXT_SECONDARY
        output_labels_row.add(ja_label, 1, Wx::LEFT, 0)

        back_label = Wx::StaticText.new(panel, :label => 'RESULT (EN)')
        back_label.font = label_font
        back_label.foreground_colour = TEXT_SECONDARY
        output_labels_row.add(back_label, 1, Wx::LEFT, 12)

        root_sizer.add(output_labels_row, 0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::TOP, 24)

        result_row = Wx::BoxSizer.new(Wx::HORIZONTAL)
        @japanese_text = Wx::TextCtrl.new(
          panel,
          :style => Wx::TE_MULTILINE | Wx::TE_RICH2 | Wx::TE_READONLY | Wx::BORDER_NONE
        )
        @japanese_text.font = editor_font
        @japanese_text.background_colour = CONTENT_BACKGROUND
        @japanese_text.foreground_colour = TEXT_PRIMARY
        result_row.add(@japanese_text, 1, Wx::EXPAND | Wx::RIGHT, 6)

        @back_text = Wx::TextCtrl.new(
          panel,
          :style => Wx::TE_MULTILINE | Wx::TE_RICH2 | Wx::TE_READONLY | Wx::BORDER_NONE
        )
        @back_text.font = editor_font
        @back_text.background_colour = CONTENT_BACKGROUND
        @back_text.foreground_colour = TEXT_PRIMARY
        result_row.add(@back_text, 1, Wx::EXPAND | Wx::LEFT, 6)
        root_sizer.add(result_row, 1, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::TOP, 24)

        # === Footer / status ===
        footer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        @busy_indicator = Wx::ActivityIndicator.new(panel)
        footer.add(@busy_indicator, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::RIGHT, 8)

        @status_label = Wx::StaticText.new(panel, :label => 'Ready')
        @status_label.foreground_colour = TEXT_SECONDARY
        footer.add(@status_label, 1, Wx::ALIGN_CENTER_VERTICAL)

        root_sizer.add(footer, 0, Wx::EXPAND | Wx::ALL, 24)

        panel.sizer = root_sizer
        create_status_bar(1)
        self.status_text = 'Ready'
      end

      def bind_events
        evt_menu(Wx::ID_OPEN, :on_open_source)
        evt_menu(Wx::ID_SAVE, :on_export_result)
        evt_menu(Wx::ID_EXIT, :on_quit_requested)
        evt_menu(Wx::ID_ABOUT, :on_about_requested)

        evt_button(@open_button, :on_open_source)
        evt_button(@translate_button, :on_translate_requested)
        evt_button(@export_button, :on_export_result)
        evt_button(@clear_button, :on_clear_requested)

        evt_close do |event|
          persist_settings
          event.skip
        end
      end

      def apply_initial_state
        @provider_choice.set_selection(0)
        @busy_indicator.stop
        update_export_state
      end

      def on_open_source(_event)
        return if @busy

        Wx.FileDialog(
          self,
          'Choose a source file',
          Infrastructure::AppPaths.data_root,
          '',
          IMPORT_WILDCARD,
          Wx::FD_OPEN | Wx::FD_FILE_MUST_EXIST
        ) do |dialog|
          next unless dialog.show_modal == Wx::ID_OK

          selected_path = dialog.get_path
          content = container.file_repository.read_text_file(selected_path)
          @source_text.value = content
          clear_results
          set_status("Loaded #{File.basename(selected_path)}")
        rescue StandardError => e
          show_error("Failed to open file: #{e.message}")
        end
      end

      def on_translate_requested(_event)
        return if @busy

        source_text = @source_text.value.to_s
        if source_text.strip.empty?
          show_error('Enter source text before translating.')
          return
        end

        set_busy(true, 'Translating…')

        Thread.new do
          begin
            result = container.translate_use_case.execute(source_text, selected_api_type)
            call_after(:apply_translation_result, result)
          rescue StandardError => e
            call_after(:show_error, "Translation failed: #{e.message}")
          ensure
            call_after(:set_busy, false)
          end
        end
      end

      def on_export_result(_event)
        return if @busy

        unless @last_result
          show_error('Translate text before exporting.')
          return
        end

        default_name = "backtranslation-#{Time.now.strftime('%Y%m%d-%H%M%S')}.txt"
        Wx.FileDialog(
          self,
          'Export translated result',
          Infrastructure::AppPaths.exports_dir,
          default_name,
          EXPORT_WILDCARD,
          Wx::FD_SAVE | Wx::FD_OVERWRITE_PROMPT
        ) do |dialog|
          next unless dialog.show_modal == Wx::ID_OK

          output_path = dialog.get_path
          container.export_manager.export_single_result(@last_result, output_path)
          set_status("Exported to #{output_path}", color: STATUS_SUCCESS)
        rescue StandardError => e
          show_error("Export failed: #{e.message}")
        end
      end

      def on_clear_requested(_event)
        return if @busy

        @source_text.clear
        clear_results
        set_status('Cleared')
      end

      def on_quit_requested(_event)
        close
      end

      def on_about_requested(_event)
        Wx.message_box(
          "#{APP_DISPLAY_NAME}\nNative wxRuby desktop app.",
          "About #{APP_DISPLAY_NAME}",
          Wx::OK | Wx::ICON_INFORMATION,
          self
        )
      end

      def clear_results
        @japanese_text.clear
        @back_text.clear
        @last_result = nil
        update_export_state
      end

      def apply_translation_result(result)
        @last_result = result
        @japanese_text.value = result.first_translation
        @back_text.value = result.back_translation
        update_export_state
        set_status('Translation completed.', color: STATUS_SUCCESS)
      end

      def selected_api_type
        :unofficial
      end

      def update_export_state
        @export_button.enable(!@busy && !@last_result.nil?)
      end

      def set_busy(value, message = nil)
        @busy = value
        @open_button.enable(!value)
        @translate_button.enable(!value)
        @clear_button.enable(!value)
        update_export_state

        if value
          @busy_indicator.start
        else
          @busy_indicator.stop
        end

        return if message.nil? && !value

        set_status(message || 'Working…')
      end

      def show_error(message)
        set_status(message, color: STATUS_ERROR)
        Wx.message_box(message, "#{APP_DISPLAY_NAME} Error", Wx::OK | Wx::ICON_ERROR, self)
      end

      def set_status(message, color: TEXT_SECONDARY)
        @status_label.foreground_colour = color
        @status_label.label = message
        self.status_text = message
      end

      def persist_settings
        settings_store.save('default_api' => selected_api_type.to_s)
      rescue StandardError => e
        warn("Failed to persist settings: #{e.message}")
      end
    end

    module DesktopApp
      module_function

      def run(container:, settings_store:)
        Wx::App.run do
          self.app_name = 'TranslationFiestaRuby'
          @thread_yield_timer = Wx::Timer.every(25) { Thread.pass }
          MainFrame.new(container: container, settings_store: settings_store).show
        end
      end
    end
  end
end
