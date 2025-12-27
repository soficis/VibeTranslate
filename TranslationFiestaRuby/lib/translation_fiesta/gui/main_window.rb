# frozen_string_literal: true

# DEPRECATED: Tk GUI has been replaced by Sinatra web UI (see translation_fiesta/web/app.rb)
# This file is retained temporarily for reference and will be removed in a future release.
begin
  require 'tk'
rescue LoadError
  # Ignore: Tk not required anymore
end

module TranslationFiesta
  module GUI
    class MainWindow
      def initialize(container)
        @container = container
        @current_result = nil
        setup_ui
        setup_bindings
      end

      def show
        @root.mainloop
      end

      private

      attr_reader :container, :root, :current_result

      def setup_ui
        @root = TkRoot.new
        @root.title = 'TranslationFiesta Ruby - English ↔ Japanese Back-Translation'
        @root.geometry = '800x600'

        create_menu_bar
        create_main_frame
        create_input_section
        create_translation_section
        create_status_section
      end

      def create_menu_bar
        menubar = TkMenu.new(@root)
        @root.menu = menubar

        # File menu
        file_menu = TkMenu.new(menubar, tearoff: false)
        menubar.add('cascade', label: 'File', menu: file_menu)
        file_menu.add('command', label: 'Open File...', command: method(:open_file))
        file_menu.add('command', label: 'Batch Process...', command: method(:batch_process))
        file_menu.add('separator')
        file_menu.add('command', label: 'Export Results...', command: method(:export_results))
        file_menu.add('separator')
        file_menu.add('command', label: 'Exit', command: method(:exit_app))

        # Tools menu
        tools_menu = TkMenu.new(menubar, tearoff: false)
        menubar.add('cascade', label: 'Tools', menu: tools_menu)
        if container.cost_tracker
          tools_menu.add('command', label: 'Cost Tracker...', command: method(:show_cost_tracker))
        end
        tools_menu.add('command', label: 'Settings...', command: method(:show_settings))
        tools_menu.add('command', label: 'Clear Translation Memory', command: method(:clear_memory))

        # Help menu
        help_menu = TkMenu.new(menubar, tearoff: false)
        menubar.add('cascade', label: 'Help', menu: help_menu)
        help_menu.add('command', label: 'About', command: method(:show_about))
      end

      def create_main_frame
        @main_frame = TkFrame.new(@root)
        @main_frame.pack(fill: 'both', expand: true, padx: 10, pady: 10)
      end

      def create_input_section
        input_frame = TkLabelFrame.new(@main_frame, text: 'Input Text')
        input_frame.pack(fill: 'both', expand: true, pady: [0, 10])

        @text_input = TkText.new(input_frame, height: 8, wrap: 'word')
        @text_input.pack(fill: 'both', expand: true, padx: 5, pady: 5)

        button_frame = TkFrame.new(input_frame)
        button_frame.pack(fill: 'x', padx: 5, pady: [0, 5])

        @api_var = TkVariable.new('unofficial')
        api_frame = TkFrame.new(button_frame)
        api_frame.pack(side: 'left')

        TkLabel.new(api_frame, text: 'API:').pack(side: 'left')
        unofficial_radio = TkRadioButton.new(api_frame, text: 'Unofficial (Free)', 
                                           variable: @api_var, value: 'unofficial')
        unofficial_radio.pack(side: 'left', padx: [5, 0])
        official_radio = TkRadioButton.new(api_frame, text: 'Official (Paid)', 
                                         variable: @api_var, value: 'official')
        official_radio.pack(side: 'left', padx: [5, 0])

        @translate_button = TkButton.new(button_frame, text: 'Translate', 
                                               command: method(:translate_text))
        @translate_button.pack(side: 'right')
      end

      def create_translation_section
        translation_frame = TkLabelFrame.new(@main_frame, text: 'Translation Results')
        translation_frame.pack(fill: 'both', expand: true, pady: [0, 10])

        # Japanese translation
        japanese_frame = TkFrame.new(translation_frame)
        japanese_frame.pack(fill: 'both', expand: true, padx: 5, pady: 5)
        TkLabel.new(japanese_frame, text: 'Japanese Translation:').pack(anchor: 'w')
        @japanese_text = TkText.new(japanese_frame, height: 4, wrap: 'word', state: 'disabled')
        @japanese_text.pack(fill: 'both', expand: true)

        # Back translation
        back_frame = TkFrame.new(translation_frame)
        back_frame.pack(fill: 'both', expand: true, padx: 5, pady: 5)
        TkLabel.new(back_frame, text: 'Back Translation:').pack(anchor: 'w')
        @back_text = TkText.new(back_frame, height: 4, wrap: 'word', state: 'disabled')
        @back_text.pack(fill: 'both', expand: true)

        # Metrics
        metrics_frame = TkFrame.new(translation_frame)
        metrics_frame.pack(fill: 'x', padx: 5, pady: 5)
        @metrics_label = TkLabel.new(metrics_frame, text: 'Metrics: -')
        @metrics_label.pack(anchor: 'w')
      end

      def create_status_section
        @status_bar = TkLabel.new(@root, text: 'Ready', relief: 'sunken', anchor: 'w')
        @status_bar.pack(side: 'bottom', fill: 'x')
      end

      def setup_bindings
        @root.bind('Control-o', method(:open_file))
        @root.bind('Control-s', method(:export_results))
        @root.bind('F5', method(:translate_text))
      end

      # Event handlers
      def translate_text
        text = @text_input.get('1.0', 'end-1c').strip
        return show_error('Please enter some text to translate') if text.empty?

        @translate_button.configure(state: 'disabled')
        update_status('Translating...')

        Thread.new do
          begin
            api_type = @api_var.value == 'official' ? :official : :unofficial
            @current_result = container.translate_use_case.execute(text, api_type)
            
            Tk.callback do
              display_translation_result(@current_result)
              update_status('Translation completed')
              @translate_button.configure(state: 'normal')
            end
          rescue StandardError => e
            Tk.callback do
              show_error("Translation failed: #{e.message}")
              update_status('Translation failed')
              @translate_button.configure(state: 'normal')
            end
          end
        end
      end

      def open_file
        file_path = Tk.getOpenFile(
          title: 'Open File',
          filetypes: [
            ['Text files', '.txt'],
            ['Markdown files', '.md'],
            ['HTML files', '.html'],
            ['EPUB files', '.epub'],
            ['All files', '*']
          ]
        )

        return if file_path.empty?

        begin
          content = container.process_file_use_case.file_repository.read_text_file(file_path)
          @text_input.delete('1.0', 'end')
          @text_input.insert('1.0', content)
          update_status("Loaded file: #{File.basename(file_path)}")
        rescue StandardError => e
          show_error("Failed to open file: #{e.message}")
        end
      end

      def batch_process
        directory = Tk.chooseDirectory(title: 'Select Directory for Batch Processing')
        return if directory.empty?

        begin
          update_status('Processing directory...')
          result = container.batch_processor.process_directory(directory)
          
          message = "Batch processing completed!\n\n"
          message += "Total files: #{result[:total_files]}\n"
          message += "Successful: #{result[:successful_files]}\n"
          message += "Failed: #{result[:failed_files]}"
          
          Tk.messageBox(
            type: 'ok',
            icon: 'info',
            title: 'Batch Processing Complete',
            message: message
          )
          
          update_status('Batch processing completed')
        rescue StandardError => e
          show_error("Batch processing failed: #{e.message}")
        end
      end

      def export_results
        return show_error('No translation results to export') unless @current_result

        file_path = Tk.getSaveFile(
          title: 'Export Results',
          defaultextension: '.txt',
          filetypes: [
            ['Text files', '.txt'],
            ['PDF files', '.pdf'],
            ['Word documents', '.docx'],
            ['HTML files', '.html']
          ]
        )

        return if file_path.empty?

        begin
          container.export_manager.export_single_result(@current_result, file_path)
          update_status("Results exported to: #{File.basename(file_path)}")
        rescue StandardError => e
          show_error("Export failed: #{e.message}")
        end
      end

      def show_cost_tracker
        summary = container.cost_tracker.get_monthly_summary
        
        message = "Monthly Cost Summary\n\n"
        message += "Total Cost: $#{summary[:total_cost].round(4)}\n"
        message += "Budget Used: #{summary[:budget_used_percentage]}%\n"
        message += "Budget Remaining: $#{summary[:budget_remaining].round(4)}\n"
        message += "Total Characters: #{summary[:total_characters]}\n"
        message += "Total Entries: #{summary[:entries_count]}"
        
        Tk.messageBox(
          type: 'ok',
          icon: 'info',
          title: 'Cost Tracker',
          message: message
        )
      end

      def show_settings
        Tk.messageBox(
          type: 'ok',
          icon: 'info',
          title: 'Settings',
          message: 'Settings dialog not yet implemented.\nComing soon!'
        )
      end

      def clear_memory
        result = Tk.messageBox(
          type: 'yesno',
          icon: 'question',
          title: 'Clear Translation Memory',
          message: 'Are you sure you want to clear the translation memory cache?'
        )

        if result == 'yes'
          container.translate_use_case.translator_service.memory_repo&.clear_cache
          update_status('Translation memory cleared')
        end
      end

      def show_about
        Tk.messageBox(
          type: 'ok',
          icon: 'info',
          title: 'About TranslationFiesta Ruby',
          message: "TranslationFiesta Ruby v#{VERSION}\n\n" \
                   "English ↔ Japanese Back-Translation Tool\n" \
                   "Built with Ruby and Tk\n\n" \
                   "Part of the VibeTranslate project"
        )
      end

      def exit_app
        @root.destroy
      end

      # Helper methods
      def display_translation_result(result)
        @japanese_text.configure(state: 'normal')
        @japanese_text.delete('1.0', 'end')
        @japanese_text.insert('1.0', result.first_translation)
        @japanese_text.configure(state: 'disabled')

        @back_text.configure(state: 'normal')
        @back_text.delete('1.0', 'end')
        @back_text.insert('1.0', result.back_translation)
        @back_text.configure(state: 'disabled')

        metrics_text = "BLEU Score: "
        metrics_text += if result.bleu_score
                          "#{(result.bleu_score * 100).round(2)}% (#{result.quality_rating})"
                        else
                          'N/A'
                        end
        
        metrics_text += " | Cost: $#{result.cost.round(4)}" if result.cost > 0
        metrics_text += " | API: #{result.api_type.to_s.capitalize}"
        
        @metrics_label.configure(text: "Metrics: #{metrics_text}")
      end

      def update_status(message)
        @status_bar.configure(text: message)
      end

      def show_error(message)
        Tk.messageBox(
          type: 'ok',
          icon: 'error',
          title: 'Error',
          message: message
        )
      end
    end
  end
end
