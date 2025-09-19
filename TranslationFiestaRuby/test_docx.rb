#!/usr/bin/env ruby

begin
  puts "Testing DOCX gem availability..."

  # Force Bundler to use the correct gem version
  require 'bundler'
  Bundler.setup

  require 'docx'
  puts "✓ DOCX gem loaded successfully"
  puts "DOCX gem path: #{Docx::Document.method(:new).source_location&.first || 'Unknown'}"

  puts "Testing DOCX document creation..."
  # Version 0.6.2 requires a file path
  # Create a simple test DOCX file first
  test_template = 'template.docx'
  unless File.exist?(test_template)
    puts "Creating test template..."
    # For testing, let's use a simple approach - create an empty file
    File.write(test_template, '')  # This won't work for DOCX, but let's see what happens
  end

  doc = Docx::Document.new(test_template)
  puts "✓ DOCX document created successfully"

  puts "Testing DOCX methods..."
  doc.h1 'Test Document'
  doc.p 'This is a test paragraph'
  puts "✓ DOCX methods work correctly"

  puts "Testing DOCX save functionality..."
  test_file = 'test_docx_output.docx'
  doc.save(test_file)
  puts "✓ DOCX file saved successfully: #{test_file}"

  # Clean up
  if File.exist?(test_file)
    File.delete(test_file)
    puts "✓ Test file cleaned up"
  end

  puts "\n🎉 All DOCX tests passed! DOCX functionality is working."

rescue LoadError => e
  puts "❌ DOCX gem not found: #{e.message}"
  puts "Please install with: gem install docx"
rescue Exception => e
  puts "❌ DOCX error: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end
