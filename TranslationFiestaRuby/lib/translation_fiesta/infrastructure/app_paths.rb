# frozen_string_literal: true

require 'fileutils'

module TranslationFiesta
  module Infrastructure
    module AppPaths
      module_function

      def app_root
        @app_root ||= begin
          executable_dir = File.dirname(File.expand_path($PROGRAM_NAME))
          find_app_root_from(executable_dir) || File.expand_path('../../../..', __dir__)
        end
      end

      def data_root
        @data_root ||= begin
          override = ENV['TF_APP_HOME']
          path = override.nil? || override.strip.empty? ? File.join(app_root, 'data') : override
          ensure_dir(path)
        end
      end

      def logs_dir
        ensure_dir(File.join(data_root, 'logs'))
      end

      def exports_dir
        ensure_dir(File.join(data_root, 'exports'))
      end

      def settings_path
        File.join(data_root, 'settings.json')
      end

      def memory_db_path
        File.join(data_root, 'translation_memory.db')
      end

      def ensure_dir(path)
        FileUtils.mkdir_p(path)
        path
      end

      def find_app_root_from(start_dir)
        current = start_dir
        loop do
          return current if app_root_candidate?(current)

          parent = File.expand_path('..', current)
          return nil if parent == current

          current = parent
        end
      end
      private_class_method :find_app_root_from

      def app_root_candidate?(directory)
        File.exist?(File.join(directory, 'bin', 'translation_fiesta')) &&
          File.directory?(File.join(directory, 'lib', 'translation_fiesta'))
      end
      private_class_method :app_root_candidate?

      private_class_method :ensure_dir
    end
  end
end
