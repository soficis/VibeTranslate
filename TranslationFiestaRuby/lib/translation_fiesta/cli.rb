# frozen_string_literal: true

require 'optparse'
require_relative 'infrastructure/dependency_container'

module TranslationFiesta
  class CLI
    PROVIDER_ALIASES = %w[
      google_unofficial
      unofficial
      google_unofficial_free
      google_free
      googletranslate
    ].freeze

    def initialize(container: Infrastructure::DependencyContainer.new)
      @container = container
      @options = {}
    end

    def run(args)
      parse_options(args)
      execute_command
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end

    private

    attr_reader :container, :options

    def parse_options(args)
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [options]"
        opts.separator ""
        opts.separator "Commands:"
        opts.separator "  translate TEXT           Translate text and show results"
        opts.separator "  file FILE_PATH           Process a single file"
        opts.separator "  batch DIRECTORY          Process all files in directory"
        opts.separator ""
        opts.separator "Options:"

        opts.on('-a', '--api API_TYPE', PROVIDER_ALIASES,
                "API type to use (default: google_unofficial; aliases: #{PROVIDER_ALIASES.join(', ')})") do |api|
          @options[:api_type] = normalize_api_type(api)
        end

        opts.on('-o', '--output FILE', 'Output file for results') do |file|
          @options[:output_file] = file
        end

        opts.on('-f', '--format FORMAT', ['txt', 'pdf', 'docx', 'html'], 
                'Export format (txt, pdf, docx, html)') do |format|
          @options[:format] = format
        end

        opts.on('-t', '--threads COUNT', Integer, 'Number of threads for batch processing') do |count|
          @options[:threads] = count
        end

        opts.on('-v', '--verbose', 'Verbose output') do
          @options[:verbose] = true
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end

        opts.on('--version', 'Show version') do
          puts "TranslationFiesta Ruby v#{VERSION}"
          exit
        end
      end

      @remaining_args = parser.parse(args)
      @options[:api_type] ||= normalize_api_type(ENV.fetch('TF_DEFAULT_API', 'google_unofficial'))
      @options[:threads] ||= 4
    end

    def execute_command
      return show_help if @remaining_args.empty?

      command = @remaining_args.first
      case command
      when 'translate'
        translate_text_command
      when 'file'
        process_file_command
      when 'batch'
        batch_process_command
      else
        puts "Unknown command: #{command}"
        show_help
        exit 1
      end
    end

    def translate_text_command
      text = @remaining_args[1]
      return puts "Error: No text provided" unless text

      puts "Translating text using #{@options[:api_type]} API..." if @options[:verbose]
      
      result = container.translate_use_case.execute(text, @options[:api_type])
      
      display_translation_result(result)
      export_result(result) if @options[:output_file]
    end

    def process_file_command
      file_path = @remaining_args[1]
      return puts "Error: No file path provided" unless file_path
      return puts "Error: File does not exist: #{file_path}" unless File.exist?(file_path)

      puts "Processing file: #{file_path}" if @options[:verbose]
      
      result = container.process_file_use_case.execute(file_path, @options[:api_type])
      
      puts "\nFile: #{result[:file_item].name}"
      display_translation_result(result[:translation_result])
      export_result(result[:translation_result]) if @options[:output_file]
    end

    def batch_process_command
      directory = @remaining_args[1]
      return puts "Error: No directory provided" unless directory
      return puts "Error: Directory does not exist: #{directory}" unless Dir.exist?(directory)

      puts "Processing directory: #{directory}" if @options[:verbose]
      puts "Using #{@options[:threads]} threads" if @options[:verbose]

      # Set up progress callback
      container.batch_processor.on_progress do |progress|
        if @options[:verbose]
          puts(
            "Progress: #{progress[:current]}/#{progress[:total]} "\
            "(#{progress[:percentage]}%) - #{progress[:current_file]}"
          )
        else
          print "."
        end
      end

      # Set up error callback
      container.batch_processor.on_error do |error|
        puts "\nError processing #{error[:file]}: #{error[:error]}"
      end

      result = container.batch_processor.process_directory(
        directory, 
        @options[:api_type], 
        @options[:threads]
      )

      puts "\n\nBatch processing completed!"
      puts "Total files: #{result[:total_files]}"
      puts "Successful: #{result[:successful_files]}"
      puts "Failed: #{result[:failed_files]}"

      if @options[:output_file] && result[:results].any?
        output_dir = File.dirname(@options[:output_file])
        container.batch_processor.export_batch_results(result[:results], output_dir)
        puts "Results exported to: #{output_dir}"
      end
    end

    def display_translation_result(result)
      puts "\n" + "─" * 60
      puts "TRANSLATION RESULT"
      puts "─" * 60
      
      puts "\nOriginal Text:"
      puts result.original_text
      
      puts "\nJapanese Translation:"
      puts result.first_translation
      
      puts "\nBack Translation:"
      puts result.back_translation
      
      puts "\nMetrics:"
      puts "  API Used: #{result.api_type.to_s.capitalize}"
      puts "  Timestamp: #{result.timestamp}"
      puts "─" * 60
    end

    def export_result(result)
      puts "Exporting result to: #{@options[:output_file]}" if @options[:verbose]
      container.export_manager.export_single_result(result, @options[:output_file])
      puts "Export completed!"
    end

    def show_help
      puts "TranslationFiesta Ruby CLI"
      puts ""
      puts "Usage:"
      puts "  #{$0} translate 'Hello world'"
      puts "  #{$0} file sample.txt"
      puts "  #{$0} batch /path/to/directory"
      puts ""
      puts "For more options, use: #{$0} --help"
    end

    def normalize_api_type(raw_api_type)
      value = raw_api_type.to_s.strip.downcase

      # Default and alias resolution currently map to the unofficial provider.
      # Using PROVIDER_ALIASES avoids duplicating the alias list here.
      return :unofficial if value.empty? || PROVIDER_ALIASES.include?(value)

      :unofficial
    end
  end
end
