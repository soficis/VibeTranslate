# frozen_string_literal: true

require_relative 'lib/translation_fiesta/version'

Gem::Specification.new do |spec|
  spec.name          = 'translation_fiesta'
  spec.version       = TranslationFiesta::VERSION
  spec.authors       = ['TranslationFiesta Team']
  spec.email         = ['team@translationfiesta.com']

  spec.summary       = 'English ↔ Japanese Back-Translation Tool'
  spec.description   = 'A comprehensive Ruby application for back-translation'
  spec.homepage      = 'https://github.com/soficis/VibeTranslate'
  spec.license       = 'GPL-3.0-only'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.2.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob('lib/**/*') + %w[README.md LICENSE]
  spec.bindir        = 'bin'
  spec.executables   = ['translation_fiesta']
  spec.require_paths = ['lib']

  # Runtime dependencies
  # Replaced Tk GUI with Sinatra web UI
  spec.add_runtime_dependency 'sinatra', '~> 4.2'
  spec.add_runtime_dependency 'easy_translate', '~> 0.5.1'
  spec.add_runtime_dependency 'nokogiri', '>= 1.19'
  spec.add_runtime_dependency 'rouge', '~> 4.7'
  spec.add_runtime_dependency 'prawn', '~> 2.5'
  spec.add_runtime_dependency 'prawn-table', '~> 0.2.2'
  spec.add_runtime_dependency 'docx', '~> 0.10'
  spec.add_runtime_dependency 'epub-parser', '~> 0.5'
  spec.add_runtime_dependency 'sqlite3', '~> 2.9'
  spec.add_runtime_dependency 'fast_blank', '~> 1.0.0'
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1.3'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rspec-mocks', '~> 3.13'
  spec.add_development_dependency 'factory_bot', '~> 6.5'
  spec.add_development_dependency 'rubocop', '~> 1.84'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.9'
  spec.add_development_dependency 'pry', '~> 0.16'
  spec.add_development_dependency 'pry-byebug', '~> 3.12'
end
