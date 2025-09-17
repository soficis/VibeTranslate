# frozen_string_literal: true

require 'prawn'
require 'prawn/table'
require 'erb'
require 'fileutils'

# Conditionally load docx gem (optional). Some platforms (Windows) may not have it installed.
begin
  require 'docx'
  DOCX_AVAILABLE = true
rescue LoadError
  DOCX_AVAILABLE = false
end

module TranslationFiesta
  module Features
    class ExportManager
      def initialize(bleu_scorer = nil)
        @bleu_scorer = bleu_scorer
      end

      def export_single_result(translation_result, file_path)
        case File.extname(file_path).downcase
        when '.txt', '.md'
          export_to_text(translation_result, file_path)
        when '.pdf'
          export_to_pdf(translation_result, file_path)
        when '.docx'
          export_to_docx(translation_result, file_path)
        when '.html'
          export_to_html(translation_result, file_path)
        else
          raise ArgumentError, "Unsupported export format: #{File.extname(file_path)}"
        end
      end

      def export_batch_results(results, output_directory, format = :txt)
        FileUtils.mkdir_p(output_directory) unless Dir.exist?(output_directory)

        case format
        when :summary
          export_batch_summary(results, File.join(output_directory, 'batch_summary.pdf'))
        when :individual
          export_individual_files(results, output_directory)
        when :combined
          export_combined_report(results, File.join(output_directory, 'combined_report.pdf'))
        end
      end

      private

      attr_reader :bleu_scorer

      def export_to_text(result, file_path)
        content = format_text_content(result)
        File.write(file_path, content, encoding: 'UTF-8')
      end

      def export_to_pdf(result, file_path)
        Prawn::Document.generate(file_path) do |pdf|
          pdf.text 'TranslationFiesta - Translation Result', size: 20, style: :bold
          pdf.move_down 20

          pdf.text 'Original Text:', size: 14, style: :bold
          pdf.text result.original_text, size: 12
          pdf.move_down 15

          pdf.text 'Japanese Translation:', size: 14, style: :bold
          pdf.text result.first_translation, size: 12
          pdf.move_down 15

          pdf.text 'Back Translation:', size: 14, style: :bold
          pdf.text result.back_translation, size: 12
          pdf.move_down 15

          # Metrics table
          metrics_data = [
            ['Metric', 'Value'],
            ['BLEU Score', result.bleu_score ? "#{(result.bleu_score * 100).round(2)}%" : 'N/A'],
            ['Quality Rating', result.quality_rating],
            ['API Used', result.api_type.to_s.capitalize],
            ['Cost', "$#{result.cost.round(4)}"],
            ['Timestamp', result.timestamp.strftime('%Y-%m-%d %H:%M:%S')]
          ]

          pdf.text 'Metrics:', size: 14, style: :bold
          pdf.table(metrics_data, header: true, width: pdf.bounds.width) do
            row(0).font_style = :bold
            self.row_colors = ['DDDDDD', 'FFFFFF']
          end
        end
      end

      def export_to_docx(result, file_path)
        unless DOCX_AVAILABLE
          raise LoadError, "docx gem is not available. Install the 'docx' gem to enable .docx exports."
        end

        doc = Docx::Document.new

        doc.h1 'TranslationFiesta - Translation Result'
        
        doc.h2 'Original Text:'
        doc.p result.original_text

        doc.h2 'Japanese Translation:'
        doc.p result.first_translation

        doc.h2 'Back Translation:'
        doc.p result.back_translation

        doc.h2 'Metrics:'
        doc.p "BLEU Score: #{result.bleu_score ? (result.bleu_score * 100).round(2) : 'N/A'}%"
        doc.p "Quality Rating: #{result.quality_rating}"
        doc.p "API Used: #{result.api_type.to_s.capitalize}"
        doc.p "Cost: $#{result.cost.round(4)}"
        doc.p "Timestamp: #{result.timestamp}"

        doc.save(file_path)
      end

      def export_to_html(result, file_path)
        template = ERB.new(html_template)
        html_content = template.result(binding)
        File.write(file_path, html_content, encoding: 'UTF-8')
      end

      def export_batch_summary(results, file_path)
        Prawn::Document.generate(file_path) do |pdf|
          pdf.text 'TranslationFiesta - Batch Processing Summary', size: 20, style: :bold
          pdf.move_down 20

          # Summary statistics
          total_files = results.length
          bleu_scores = results.map(&:bleu_score).compact
          average_bleu = bleu_scores.empty? ? nil : bleu_scores.sum / bleu_scores.length
          total_cost = results.sum(&:cost)

          summary_data = [
            ['Metric', 'Value'],
            ['Total Files Processed', total_files.to_s],
            ['Average BLEU Score', average_bleu ? "#{(average_bleu * 100).round(2)}%" : 'N/A'],
            ['Total Cost', "$#{total_cost.round(4)}"],
            ['Processing Date', Time.now.strftime('%Y-%m-%d %H:%M:%S')]
          ]

          pdf.table(summary_data, header: true, width: pdf.bounds.width) do
            row(0).font_style = :bold
            self.row_colors = ['DDDDDD', 'FFFFFF']
          end
        end
      end

      def format_text_content(result)
        <<~CONTENT
          # Translation Result
          
          ## Original Text:
          #{result.original_text}
          
          ## Japanese Translation:
          #{result.first_translation}
          
          ## Back Translation:
          #{result.back_translation}
          
          ## Metrics:
          - BLEU Score: #{result.bleu_score ? (result.bleu_score * 100).round(2) : 'N/A'}%
          - Quality Rating: #{result.quality_rating}
          - API Used: #{result.api_type.to_s.capitalize}
          - Cost: $#{result.cost.round(4)}
          - Timestamp: #{result.timestamp}
        CONTENT
      end

      def html_template
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>TranslationFiesta - Translation Result</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 40px; }
              h1 { color: #333; }
              h2 { color: #666; margin-top: 30px; }
              .metrics { background-color: #f5f5f5; padding: 15px; border-radius: 5px; }
              .content { margin: 15px 0; padding: 10px; border-left: 3px solid #ccc; }
            </style>
          </head>
          <body>
            <h1>TranslationFiesta - Translation Result</h1>
            
            <h2>Original Text:</h2>
            <div class="content"><%= result.original_text %></div>
            
            <h2>Japanese Translation:</h2>
            <div class="content"><%= result.first_translation %></div>
            
            <h2>Back Translation:</h2>
            <div class="content"><%= result.back_translation %></div>
            
            <h2>Metrics:</h2>
            <div class="metrics">
              <p><strong>BLEU Score:</strong> <%= result.bleu_score ? (result.bleu_score * 100).round(2) : 'N/A' %>%</p>
              <p><strong>Quality Rating:</strong> <%= result.quality_rating %></p>
              <p><strong>API Used:</strong> <%= result.api_type.to_s.capitalize %></p>
              <p><strong>Cost:</strong> $<%= result.cost.round(4) %></p>
              <p><strong>Timestamp:</strong> <%= result.timestamp %></p>
            </div>
          </body>
          </html>
        HTML
      end
    end
  end
end