# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'app_paths'

module TranslationFiesta
  module Infrastructure
    class SettingsStore
      DEFAULTS = {
        'default_api' => 'unofficial'
      }.freeze

      def initialize(path = nil)
        @path = path || AppPaths.settings_path
      end

      def load
        return DEFAULTS.dup unless File.exist?(@path)

        data = JSON.parse(File.read(@path))
        DEFAULTS.merge(data)
      rescue StandardError
        DEFAULTS.dup
      end

      def save(settings)
        payload = DEFAULTS.merge(settings)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(payload))
        payload
      rescue StandardError
        DEFAULTS.dup
      end

      def apply_to_env(settings)
        ENV['TF_DEFAULT_API'] = settings.fetch('default_api', 'unofficial').to_s
      end
    end
  end
end
