# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'securerandom'
require_relative '../infrastructure/dependency_container'

module TranslationFiesta
  module Web
    # Lightweight Sinatra-based web UI replacing Tk GUI for better cross-platform support.
    class App < Sinatra::Base
      set :bind, ENV.fetch('TF_WEB_BIND', '127.0.0.1')
      set :port, ENV.fetch('TF_WEB_PORT', 4567)
      set :static, true
      set :public_folder, File.expand_path('../public', __dir__)
  set :views, File.expand_path('views', __dir__)
  # Avoid blocking tests or non-standard hosts (Rack::Protection may reject test Host headers)
  set :protection, except: :http_host

      RATE_LIMIT = ENV.fetch('TF_RATE_LIMIT', '60').to_i

      @@rate_limits = {}

      def initialize(app = nil, container: Infrastructure::DependencyContainer.new)
        super(app)
        @container = container
        @results = {}
      end

      # Simple auth and rate limiting for /api/* endpoints
      before do
        if request.path.start_with?('/api/')
          # API token enforcement (if TF_API_TOKEN is set)
          token = ENV['TF_API_TOKEN']
          if token
            provided = request.env['HTTP_X_API_TOKEN'] || params['api_token']
            halt 401, JSON.generate({ error: 'Unauthorized' }) unless provided == token
          end

          # Rate limit per IP (sliding window of 60s)
          client = request.ip
          now = Time.now.to_i
          data = @@rate_limits[client] || { count: 0, window_start: now }
          if now - data[:window_start] >= 60
            data = { count: 0, window_start: now }
          end
          data[:count] += 1
          @@rate_limits[client] = data
          if data[:count] > RATE_LIMIT
            halt 429, JSON.generate({ error: 'Rate limit exceeded' })
          end
        end
      end

      helpers do
        def json(data, status: 200)
          content_type :json
          halt status, JSON.generate(data)
        end

        def container
          settings.respond_to?(:container) ? settings.container : @container
        end

        def translate(text:, api_type: :unofficial)
          container.translate_use_case.execute(text, api_type)
        end
      end

      get '/' do
        erb :index
      end

      post '/api/translate' do
        payload = JSON.parse(request.body.read) rescue {}
        text = (payload['text'] || '').strip
        api_type = (payload['api_type'] || 'unofficial').to_sym
        return json({ error: 'Text is required' }, status: 422) if text.empty?

        begin
          result = translate(text: text, api_type: api_type)
          id = SecureRandom.uuid
          @results[id] = result
          json({ id: id, result: serialize_result(result) })
        rescue StandardError => e
          json({ error: e.message }, status: 500)
        end
      end

      get '/api/result/:id' do
        result = @results[params[:id]]
        return json({ error: 'Not found' }, status: 404) unless result
        json({ id: params[:id], result: serialize_result(result) })
      end

      post '/api/export/:id' do
        result = @results[params[:id]]
        return json({ error: 'Not found' }, status: 404) unless result

        payload = JSON.parse(request.body.read) rescue {}
        format = (payload['format'] || 'txt').downcase
        dir = ENV.fetch('TF_EXPORT_DIR', 'exports')
        Dir.mkdir(dir) unless Dir.exist?(dir)
        filename = File.join(dir, "translation_#{params[:id]}.#{format}")

        begin
          container.export_manager.export_single_result(result, filename)
          json({ exported: true, path: filename })
        rescue StandardError => e
          json({ error: e.message }, status: 500)
        end
      end

      get '/health' do
        json({ status: 'ok', time: Time.now.utc })
      end

      private

      def serialize_result(r)
        {
          original_text: r.original_text,
          first_translation: r.first_translation,
          back_translation: r.back_translation,
          bleu_score: r.bleu_score,
          quality_rating: r.quality_rating,
          api_type: r.api_type,
          cost: r.cost,
          timestamp: r.timestamp
        }
      end
    end
  end
end
