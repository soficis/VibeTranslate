# frozen_string_literal: true

require_relative 'infrastructure/dependency_container'
require_relative 'infrastructure/settings_store'

module TranslationFiesta
  class Application
    def initialize
      @settings_store = Infrastructure::SettingsStore.new
      @settings_store.apply_to_env(@settings_store.load)
      @container = Infrastructure::DependencyContainer.new
    end

    def run
      require_relative 'gui/desktop_app'

      Gui::DesktopApp.run(container: @container, settings_store: @settings_store)
    rescue LoadError => e
      raise LoadError, "#{e.message}\nInstall desktop dependencies with: bundle install\nRun with: bundle exec ruby bin/translation_fiesta"
    end

    private

    attr_reader :container, :settings_store
  end
end
