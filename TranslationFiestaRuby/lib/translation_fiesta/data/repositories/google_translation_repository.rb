# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require_relative '../../domain/repositories/translation_repository'

module TranslationFiesta
  module Data
    module Repositories
      class GoogleTranslationRepository < TranslationFiesta::Domain::Repositories::TranslationRepository
        def initialize(api_type = :unofficial)
          @api_type = normalize_api_type(api_type)
        end

        def translate_text(text, from_language, to_language, _api_type)
          translate_unofficial(text, from_language, to_language)
        end

        def detect_language(text)
          raise TranslationError, 'Text cannot be empty' if text.nil? || text.strip.empty?

          'en'
        end

        def available?
          true
        end

        private

        attr_reader :api_type

        def translate_unofficial(text, from_language, to_language)
          return '' if text.nil? || text.strip.empty?

          encoded_text = URI.encode_www_form_component(text)
          url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=#{from_language}&tl=#{to_language}&dt=t&q=#{encoded_text}"

          max_attempts = (ENV.fetch('TF_UNOFFICIAL_MAX_RETRIES', '3')).to_i
          min_backoff = (ENV.fetch('TF_UNOFFICIAL_MIN_BACKOFF_MS', '200')).to_i
          max_backoff = (ENV.fetch('TF_UNOFFICIAL_MAX_BACKOFF_MS', '2000')).to_i
          user_agent = ENV['TF_UNOFFICIAL_USER_AGENT']
          proxy_url = ENV['TF_UNOFFICIAL_PROXY_URL']

          attempt = 0
          last_error = nil

          while attempt < max_attempts
            attempt += 1
            begin
              uri = URI.parse(url)
              http = build_http_client(uri, proxy_url)
              request = Net::HTTP::Get.new(uri.request_uri)
              request['Accept'] = 'application/json,text/plain,*/*'
              request['User-Agent'] = user_agent if user_agent && !user_agent.strip.empty?

              response = http.request(request)
              status = response.code.to_i
              body = response.body.to_s

              if status == 429
                raise TranslationError, 'rate_limited: provider rate limited' if attempt >= max_attempts

                sleep(backoff_delay(attempt, min_backoff, max_backoff))
                next
              end

              raise TranslationError, 'blocked: provider blocked or captcha detected' if status == 403

              if status >= 400
                code = status >= 500 ? 'network_error' : 'invalid_response'
                raise TranslationError, "#{code}: HTTP #{status}"
              end

              raise TranslationError, 'invalid_response: empty response body' if body.strip.empty?

              lower = body.downcase
              if lower.include?('<html') || lower.include?('captcha')
                raise TranslationError, 'blocked: provider blocked or captcha detected'
              end

              data = JSON.parse(body)
              return extract_translated_text(data)
            rescue TranslationError => e
              last_error = e
              raise if attempt >= max_attempts

              sleep(backoff_delay(attempt, min_backoff, max_backoff))
            rescue JSON::ParserError => e
              last_error = TranslationError.new("invalid_response: #{e.message}")
              raise last_error if attempt >= max_attempts

              sleep(backoff_delay(attempt, min_backoff, max_backoff))
            rescue StandardError => e
              last_error = TranslationError.new("network_error: #{e.message}")
              raise last_error if attempt >= max_attempts

              sleep(backoff_delay(attempt, min_backoff, max_backoff))
            end
          end

          raise(last_error || TranslationError.new('network_error: unofficial translation failed'))
        end

        def normalize_api_type(api_type)
          value = api_type.to_s
          case value
          when 'google_unofficial', 'unofficial'
            :unofficial
          else
            :unofficial
          end
        end

        def backoff_delay(attempt, min_backoff, max_backoff)
          base = [max_backoff, min_backoff * (2**(attempt - 1))].min
          jitter = rand(0..200)
          (base + jitter) / 1000.0
        end

        def build_http_client(uri, proxy_url)
          proxy_uri = proxy_url && !proxy_url.strip.empty? ? URI.parse(proxy_url) : nil
          http_class = if proxy_uri
                         Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
                       else
                         Net::HTTP
                       end
          http = http_class.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.read_timeout = 15
          http
        end

        def extract_translated_text(data)
          return '' unless data.is_a?(Array) && data.length.positive?
          return '' unless data[0].is_a?(Array)

          translated_parts = []
          data[0].each do |sentence|
            next unless sentence.is_a?(Array) && sentence.length.positive?

            part = sentence[0]
            translated_parts << part if part.is_a?(String) && !part.empty?
          end

          translated_parts.join('')
        end
      end
    end
  end
end
