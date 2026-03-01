# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'app_paths'

module TranslationFiesta
  module Infrastructure
    class SettingsStore
      DEFAULT_PROVIDER_ID = 'google_unofficial'
      PROVIDER_ALIASES = {
        'google_unofficial' => DEFAULT_PROVIDER_ID,
        'unofficial' => DEFAULT_PROVIDER_ID,
        'google_unofficial_free' => DEFAULT_PROVIDER_ID,
        'google_free' => DEFAULT_PROVIDER_ID,
        'googletranslate' => DEFAULT_PROVIDER_ID,
        '' => DEFAULT_PROVIDER_ID
      }.freeze

      DEFAULTS = {
        'default_api' => DEFAULT_PROVIDER_ID
      }.freeze

      def initialize(path = nil)
        @path = path || AppPaths.settings_path
      end

      def load
        return DEFAULTS.dup unless File.exist?(@path)

        data = JSON.parse(File.read(@path))
        payload = DEFAULTS.merge(data)
        payload['default_api'] = normalize_provider_id(payload['default_api'])
        payload
      rescue StandardError
        DEFAULTS.dup
      end

      def save(settings)
        payload = DEFAULTS.merge(settings)
        payload['default_api'] = normalize_provider_id(payload['default_api'])
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(payload))
        payload
      rescue StandardError
        DEFAULTS.dup
      end

      def apply_to_env(settings)
        ENV['TF_DEFAULT_API'] = normalize_provider_id(settings.fetch('default_api', DEFAULT_PROVIDER_ID))
      end

      private

      def normalize_provider_id(provider_id)
        normalized = provider_id.to_s.strip.downcase
        PROVIDER_ALIASES.fetch(normalized, DEFAULT_PROVIDER_ID)
      end
    end
  end
end
