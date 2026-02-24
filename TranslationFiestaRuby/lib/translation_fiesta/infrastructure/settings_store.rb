# frozen_string_literal: true

require 'json'
require 'fileutils'

module TranslationFiesta
  module Infrastructure
    class SettingsStore
      DEFAULTS = {
        'local_service_url' => '',
        'local_model_dir' => '',
        'local_auto_start' => true
      }.freeze

      def initialize(path = nil)
        @path = path || File.join(Dir.home, '.translation_fiesta', 'settings.json')
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
        url = settings['local_service_url'].to_s.strip
        model_dir = settings['local_model_dir'].to_s.strip
        auto_start = settings.fetch('local_auto_start', true)

        ENV['TF_LOCAL_URL'] = url unless url.empty?
        ENV.delete('TF_LOCAL_URL') if url.empty?

        ENV['TF_LOCAL_MODEL_DIR'] = model_dir unless model_dir.empty?
        ENV.delete('TF_LOCAL_MODEL_DIR') if model_dir.empty?

        ENV['TF_LOCAL_AUTOSTART'] = auto_start ? '1' : '0'
      end
    end
  end
end
