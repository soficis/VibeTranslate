# frozen_string_literal: true

require_relative 'infrastructure/dependency_container'
require_relative 'web/app'

module TranslationFiesta
  class Application
    def initialize
      @container = Infrastructure::DependencyContainer.new
    end

    def run
      # Start the Sinatra web application
      puts 'Starting TranslationFiesta Web UI (Sinatra)...'
      TranslationFiesta::Web::App.run!
    end

    private

    attr_reader :container

    # Tk specific methods removed after migration to web UI
  end
end