# frozen_string_literal: true

require 'nokogiri'
require 'epub/parser'
require_relative '../../domain/repositories/file_repository'

module TranslationFiesta
  module Data
    module Repositories
      class FileSystemRepository < TranslationFiesta::Domain::Repositories::FileRepository
        def read_text_file(file_path)
          raise FileProcessingError, "File does not exist: #{file_path}" unless File.exist?(file_path)

          case File.extname(file_path).downcase
          when '.txt', '.md'
            read_plain_text(file_path)
          when '.html'
            read_html_file(file_path)
          when '.epub'
            read_epub_file(file_path)
          else
            raise FileProcessingError, "Unsupported file type: #{File.extname(file_path)}"
          end
        end

        def write_text_file(file_path, content)
          File.write(file_path, content, encoding: 'UTF-8')
        rescue StandardError => e
          raise FileProcessingError, "Failed to write file #{file_path}: #{e.message}"
        end

        def list_files_in_directory(directory_path, extensions = nil)
          raise FileProcessingError, "Directory does not exist: #{directory_path}" unless Dir.exist?(directory_path)

          extensions ||= %w[.txt .md .html .epub]
          pattern = "**/*{#{extensions.join(',')}}"
          
          Dir.glob(File.join(directory_path, pattern)).map do |file_path|
            Domain::Entities::FileItem.new(file_path)
          end.select(&:supported?)
        end

        def file_exists?(file_path)
          File.exist?(file_path)
        end

        private

        def read_plain_text(file_path)
          File.read(file_path, encoding: 'UTF-8').strip
        rescue StandardError => e
          raise FileProcessingError, "Failed to read text file #{file_path}: #{e.message}"
        end

        def read_html_file(file_path)
          html_content = File.read(file_path, encoding: 'UTF-8')
          doc = Nokogiri::HTML(html_content)
          
          # Remove script and style elements
          doc.search('script, style').remove
          
          # Extract text content
          doc.text.strip.gsub(/\s+/, ' ')
        rescue StandardError => e
          raise FileProcessingError, "Failed to read HTML file #{file_path}: #{e.message}"
        end

        def read_epub_file(file_path)
          book = EPUB::Parser.parse(file_path)
          
          text_content = []
          book.each_content do |content|
            if content.media_type == 'application/xhtml+xml'
              doc = Nokogiri::HTML(content.read)
              doc.search('script, style').remove
              text = doc.text.strip.gsub(/\s+/, ' ')
              text_content << text unless text.empty?
            end
          end
          
          text_content.join("\n\n")
        rescue StandardError => e
          raise FileProcessingError, "Failed to read EPUB file #{file_path}: #{e.message}"
        end
      end
    end
  end
end