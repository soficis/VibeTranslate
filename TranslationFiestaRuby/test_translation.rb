#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/translation_fiesta'

# Test the unofficial translation API
puts "Testing Ruby TranslationFiesta unofficial translation..."

# Create repository and service
repo = TranslationFiesta::Data::Repositories::GoogleTranslationRepository.new(:unofficial)
service = TranslationFiesta::Domain::Services::TranslatorService.new(repo)

begin
  # Test a simple translation
  result = service.perform_back_translation("Hello world", :unofficial)

  puts "Original text: #{result.original_text}"
  puts "First translation (EN->JA): #{result.first_translation}"
  puts "Back translation (JA->EN): #{result.back_translation}"
  puts "Translation successful!"
rescue StandardError => e
  puts "Translation failed: #{e.message}"
  puts "Error class: #{e.class}"
end

