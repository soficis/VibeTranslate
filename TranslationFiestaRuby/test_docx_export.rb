#!/usr/bin/env ruby

require_relative 'lib/translation_fiesta'

puts "=== Testing DOCX Export ==="

# Create a mock translation result
result = TranslationFiesta::Domain::Entities::TranslationResult.new(
  original_text: "Hello world",
  first_translation: "こんにちは世界",
  back_translation: "Hello world",
  bleu_score: 1.0,
  api_type: :unofficial,
  cost: 0.0001,
  timestamp: Time.now
)

puts "Created test translation result:"
puts "Original: #{result.original_text}"
puts "Japanese: #{result.first_translation}"
puts "Back: #{result.back_translation}"

# Test DOCX export
export_manager = TranslationFiesta::Infrastructure::DependencyContainer.new.export_manager
output_file = 'test_export.docx'

begin
  puts "\nTesting DOCX export..."
  export_manager.export_single_result(result, output_file)
  puts "✓ DOCX export successful: #{output_file}"

  if File.exist?(output_file)
    puts "✓ Output file created (#{File.size(output_file)} bytes)"
  else
    puts "❌ Output file not found"
  end

rescue Exception => e
  puts "❌ DOCX export failed: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end

# Cleanup
if File.exist?(output_file)
  File.delete(output_file)
  puts "✓ Test file cleaned up"
end

puts "\n=== DOCX Export Test Complete ==="
