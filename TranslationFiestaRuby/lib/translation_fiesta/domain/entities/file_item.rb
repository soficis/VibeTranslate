# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Entities
      class FileItem
        attr_reader :path, :type, :size, :last_modified

        SUPPORTED_TYPES = %w[.txt .md .html .epub].freeze

        def initialize(path)
          @path = path
          @type = File.extname(path).downcase
          @size = File.size(path)
          @last_modified = File.mtime(path)
        end

        def supported?
          SUPPORTED_TYPES.include?(type)
        end

        def name
          File.basename(path)
        end

        def directory
          File.dirname(path)
        end

        def readable?
          File.readable?(path)
        end

        def to_s
          "#{name} (#{format_size})"
        end

        private

        def format_size
          units = %w[B KB MB GB]
          size_float = size.to_f
          unit_index = 0

          while size_float >= 1024.0 && unit_index < units.length - 1
            size_float /= 1024.0
            unit_index += 1
          end

          "#{size_float.round(1)} #{units[unit_index]}"
        end
      end
    end
  end
end