# frozen_string_literal: true

require 'easy_translate'
require 'google/cloud/translate/v2'
require 'net/http'
require 'uri'
require 'json'
require_relative '../../domain/repositories/translation_repository'

module TranslationFiesta
  module Data
    module Repositories
      class GoogleTranslationRepository < TranslationFiesta::Domain::Repositories::TranslationRepository
        def initialize(api_type = :unofficial, api_key = nil)
          @api_type = api_type
          @api_key = api_key
          setup_client
        end

        def translate_text(text, from_language, to_language, api_type)
          case api_type
          when :unofficial
            translate_unofficial(text, from_language, to_language)
          when :official
            translate_official(text, from_language, to_language)
          else
            raise ArgumentError, "Unknown API type: #{api_type}"
          end
        end

        def detect_language(text)
          case @api_type
          when :unofficial
            EasyTranslate.detect(text, key: @api_key)
          when :official
            return 'en' unless @official_client
            
            result = @official_client.detect(text)
            result.language
          end
        rescue StandardError => e
          raise TranslationError, "Language detection failed: #{e.message}"
        end

        def available?
          case @api_type
          when :unofficial
            true # Easy translate doesn't require API key for basic functionality
          when :official
            !@api_key.nil? && !@api_key.empty?
          end
        end

        private

        attr_reader :api_type, :api_key, :official_client

        def setup_client
          case @api_type
          when :official
            setup_official_client if @api_key
          end
        end

        def setup_official_client
          @official_client = Google::Cloud::Translate::V2.new(key: @api_key)
        rescue StandardError => e
          raise APIError, "Failed to initialize Google Cloud Translate client: #{e.message}"
        end

        def translate_unofficial(text, from_language, to_language)
          return '' if text.nil? || text.strip.empty?

          encoded_text = URI.encode_www_form_component(text)
          url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=#{from_language}&tl=#{to_language}&dt=t&q=#{encoded_text}"

          uri = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Get.new(uri.request_uri)

          response = http.request(request)

          if response.code.to_i >= 400
            raise TranslationError, "HTTP #{response.code}: #{response.body}"
          end

          begin
            data = JSON.parse(response.body)
          rescue JSON::ParserError => e
            raise TranslationError, "Failed to parse response: #{e.message}"
          end

          extract_translated_text(data)
        rescue StandardError => e
          raise TranslationError, "Unofficial translation failed: #{e.message}"
        end

        def translate_official(text, from_language, to_language)
          raise APIError, 'Official API client not available' unless @official_client

          result = @official_client.translate(text, from: from_language, to: to_language)
          result.text
        rescue StandardError => e
          raise TranslationError, "Official translation failed: #{e.message}"
        end

        def extract_translated_text(data)
          return '' unless data.is_a?(Array) && data.length > 0
          return '' unless data[0].is_a?(Array)

          translated_parts = []
          data[0].each do |sentence|
            next unless sentence.is_a?(Array) && sentence.length > 0
            part = sentence[0]
            translated_parts << part if part.is_a?(String) && !part.empty?
          end

          translated_parts.join('')
        end
      end
    end
  end
end