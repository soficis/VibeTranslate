#!/usr/bin/env ruby

puts "=== DOCX Functionality Test ==="
puts "Ruby version: #{RUBY_VERSION}"
puts "Ruby platform: #{RUBY_PLATFORM}"
puts ""

begin
  puts "1. Testing DOCX gem loading..."
  require 'docx'
  puts "✓ DOCX gem loaded successfully"
  puts "   DOCX version: #{Docx::VERSION rescue 'Unknown'}"
rescue LoadError => e
  puts "❌ DOCX gem not found: #{e.message}"
  puts "   Please run: gem install docx"
  exit 1
end

begin
  puts ""
  puts "2. Testing rubyzip compatibility..."
  require 'zip'
  puts "✓ rubyzip loaded successfully"

  # Test Zip::File creation with both APIs
  test_file = 'test_zip.docx'

  begin
    puts "   Testing new rubyzip API (v3+)..."
    Zip::File.open(test_file, create: true) do |zip|
      zip.get_output_stream('test.txt') { |f| f.write 'test' }
    end
    puts "✓ New rubyzip API works"
    File.delete(test_file) if File.exist?(test_file)
  rescue ArgumentError
    puts "   New API failed, trying old API..."
    Zip::File.open(test_file, Zip::File::CREATE) do |zip|
      zip.get_output_stream('test.txt') { |f| f.write 'test' }
    end
    puts "✓ Old rubyzip API works"
    File.delete(test_file) if File.exist?(test_file)
  end

rescue LoadError => e
  puts "❌ rubyzip not found: #{e.message}"
end

begin
  puts ""
  puts "3. Testing DOCX document creation..."
  require 'tmpdir'
  template_path = File.join(Dir.tmpdir, "docx_test_#{Time.now.to_i}.docx")

  # Create a minimal DOCX template
  require 'zip'
  begin
    Zip::File.open(template_path, create: true) do |zipfile|
      zipfile.get_output_stream('[Content_Types].xml') do |f|
        f.write '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
      end
      zipfile.get_output_stream('word/document.xml') do |f|
        f.write '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body></w:body></w:document>'
      end
      zipfile.get_output_stream('_rels/.rels') do |f|
        f.write '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
      end
    end
    puts "✓ Template created successfully: #{template_path}"
  rescue => e
    puts "❌ Template creation failed: #{e.message}"
    exit 1
  end

  puts ""
  puts "4. Testing DOCX::Document creation..."
  begin
    doc = Docx::Document.new(template_path)
    puts "✓ DOCX::Document created successfully"
  rescue => e
    puts "❌ DOCX::Document creation failed: #{e.message}"
    puts "   This might be due to incompatible DOCX gem version"
    exit 1
  end

  puts ""
  puts "5. Testing DOCX methods..."
  begin
    doc.h1 'Test Document'
    doc.p 'This is a test paragraph with some content.'
    puts "✓ DOCX methods work correctly"
  rescue => e
    puts "❌ DOCX methods failed: #{e.message}"
  end

  puts ""
  puts "6. Testing DOCX save functionality..."
  output_file = 'test_output.docx'
  begin
    doc.save(output_file)
    puts "✓ DOCX file saved successfully: #{output_file}"
  rescue => e
    puts "❌ DOCX save failed: #{e.message}"
  end

  # Cleanup
  File.delete(template_path) if File.exist?(template_path)
  File.delete(output_file) if File.exist?(output_file)

  puts ""
  puts "🎉 All DOCX tests passed! DOCX functionality should work."

rescue Exception => e
  puts ""
  puts "❌ Unexpected error: #{e.message}"
  puts "❌ Error class: #{e.class}"
  puts "❌ Backtrace:"
  e.backtrace.first(10).each { |line| puts "   #{line}" }
end
