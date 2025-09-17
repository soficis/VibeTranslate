# frozen_string_literal: true

require 'concurrent'
require 'fileutils'

module TranslationFiesta
  module Features
    class BatchProcessor
      def initialize(process_file_use_case, file_repository)
        @process_file_use_case = process_file_use_case
        @file_repository = file_repository
        @results = []
        @progress_callback = nil
        @error_callback = nil
      end

      def process_directory(directory_path, api_type = :unofficial, max_threads = 4)
        validate_directory(directory_path)
        
        files = file_repository.list_files_in_directory(directory_path)
        return { results: [], errors: [], total_files: 0 } if files.empty?

        @results = []
        errors = []
        total_files = files.length
        processed_count = 0

        # Create thread pool
        pool = Concurrent::FixedThreadPool.new(max_threads)
        
        files.each_with_index do |file_item, index|
          pool.post do
            begin
              result = process_file_use_case.execute(file_item.path, api_type)
              @results << result
              
              processed_count += 1
              notify_progress(processed_count, total_files, file_item.name)
            rescue StandardError => e
              error_info = {
                file: file_item.name,
                path: file_item.path,
                error: e.message
              }
              errors << error_info
              notify_error(error_info)
              
              processed_count += 1
              notify_progress(processed_count, total_files, file_item.name)
            end
          end
        end

        pool.shutdown
        pool.wait_for_termination

        {
          results: @results,
          errors: errors,
          total_files: total_files,
          successful_files: @results.length,
          failed_files: errors.length
        }
      end

      def on_progress(&block)
        @progress_callback = block
      end

      def on_error(&block)
        @error_callback = block
      end

      def export_batch_results(results, output_directory, format = :txt)
        FileUtils.mkdir_p(output_directory) unless Dir.exist?(output_directory)

        results.each_with_index do |result, index|
          file_name = generate_output_filename(result[:file_item], index, format)
          output_path = File.join(output_directory, file_name)
          
          export_single_result(result[:translation_result], output_path)
        end
      end

      private

      attr_reader :process_file_use_case, :file_repository, :progress_callback, :error_callback

      def validate_directory(directory_path)
        raise ArgumentError, 'Directory path cannot be nil or empty' if directory_path.nil? || directory_path.strip.empty?
        raise ArgumentError, "Directory does not exist: #{directory_path}" unless Dir.exist?(directory_path)
        raise ArgumentError, "Path is not a directory: #{directory_path}" unless File.directory?(directory_path)
      end

      def notify_progress(current, total, current_file)
        return unless progress_callback

        progress_callback.call({
          current: current,
          total: total,
          percentage: (current.to_f / total * 100).round(2),
          current_file: current_file
        })
      end

      def notify_error(error_info)
        return unless error_callback

        error_callback.call(error_info)
      end

      def generate_output_filename(file_item, index, format)
        base_name = File.basename(file_item.name, File.extname(file_item.name))
        "#{base_name}_translation_#{index + 1}.#{format}"
      end

      def export_single_result(translation_result, output_path)
        content = format_translation_result(translation_result)
        File.write(output_path, content, encoding: 'UTF-8')
      end

      def format_translation_result(result)
        <<~CONTENT
          # Translation Result
          
          **Original Text:**
          #{result.original_text}
          
          **Japanese Translation:**
          #{result.first_translation}
          
          **Back Translation:**
          #{result.back_translation}
          
          **Metrics:**
          - BLEU Score: #{result.bleu_score ? (result.bleu_score * 100).round(2) : 'N/A'}%
          - Quality Rating: #{result.quality_rating}
          - API Used: #{result.api_type.to_s.capitalize}
          - Cost: $#{result.cost.round(4)}
          - Timestamp: #{result.timestamp}
        CONTENT
      end
    end
  end
end