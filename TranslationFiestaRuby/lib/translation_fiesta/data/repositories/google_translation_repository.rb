# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require_relative '../../domain/repositories/translation_repository'

module TranslationFiesta
  module Data
    module Repositories
      class GoogleTranslationRepository < TranslationFiesta::Domain::Repositories::TranslationRepository
        LOCAL_HEALTH_PATH = '/health'
        LOCAL_TRANSLATE_PATH = '/translate'

        def initialize(api_type = :unofficial)
          @api_type = api_type
        end

        def translate_text(text, from_language, to_language, api_type)
          normalized = normalize_api_type(api_type)
          case normalized
          when :unofficial
            translate_unofficial(text, from_language, to_language)
          when :local
            translate_local(text, from_language, to_language)
          else
            raise ArgumentError, "Unknown API type: #{api_type}"
          end
        end

        def detect_language(text)
          raise TranslationError, 'Text cannot be empty' if text.nil? || text.strip.empty?

          'en'
        end

        def available?
          case normalize_api_type(@api_type)
          when :unofficial
            true
          when :local
            local_service_available?
          end
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

        def translate_local(text, from_language, to_language)
          return '' if text.nil? || text.strip.empty?
          ensure_local_service

          uri = URI.join(local_service_url, LOCAL_TRANSLATE_PATH)
          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Post.new(uri.request_uri)
          request['Content-Type'] = 'application/json'
          request.body = JSON.generate(
            text: text,
            source_lang: from_language,
            target_lang: to_language
          )

          response = http.request(request)
          if response.code.to_i >= 400
            raise TranslationError, "Local provider error: HTTP #{response.code}"
          end

          payload = JSON.parse(response.body)
          translated = payload['translated_text']
          return translated if translated.is_a?(String)

          raise TranslationError, 'Invalid local provider response'
        rescue StandardError => e
          raise TranslationError, "Local translation failed: #{e.message}"
        end

        def local_service_url
          ENV.fetch('TF_LOCAL_URL', 'http://127.0.0.1:5055')
        end

        def normalize_api_type(api_type)
          value = api_type.to_s
          case value
          when 'google_unofficial', 'unofficial'
            :unofficial
          when 'local'
            :local
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
          http_class = proxy_uri ? Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password) : Net::HTTP
          http = http_class.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.read_timeout = 15
          http
        end

        def local_service_available?
          uri = URI.join(local_service_url, LOCAL_HEALTH_PATH)
          http = Net::HTTP.new(uri.host, uri.port)
          response = http.get(uri.request_uri)
          response.code.to_i == 200
        rescue StandardError
          false
        end

        def ensure_local_service
          return if local_service_available?
          return unless local_auto_start?

          start_local_service
          deadline = Time.now + 6
          until local_service_available? || Time.now > deadline
            sleep 0.2
          end
          raise TranslationError, 'Local provider is not available' unless local_service_available?
        end

        def local_auto_start?
          env_value = ENV['TF_LOCAL_AUTOSTART']
          return true if env_value.nil?
          !%w[0 false False].include?(env_value)
        end

        def start_local_service
          script_path = ENV['TF_LOCAL_SCRIPT'] || default_local_script_path
          return unless script_path && File.exist?(script_path)

          python = ENV.fetch('PYTHON', 'python')
          pid = Process.spawn(
            { 'PYTHONUNBUFFERED' => '1' },
            python,
            script_path,
            chdir: File.dirname(script_path),
            out: File::NULL,
            err: File::NULL
          )
          Process.detach(pid)
        rescue StandardError
          nil
        end

        def default_local_script_path
          File.expand_path('../../../../TranslationFiestaLocal/local_service.py', __dir__)
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
