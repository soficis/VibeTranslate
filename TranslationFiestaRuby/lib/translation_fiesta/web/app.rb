# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'securerandom'
require 'net/http'
require 'uri'
require_relative '../infrastructure/dependency_container'
require_relative '../infrastructure/settings_store'

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
  
  # Enable file uploads
  set :max_file_size, 10_000_000 # 10MB

      RATE_LIMIT = ENV.fetch('TF_RATE_LIMIT', '60').to_i

      @@rate_limits = {}

      def initialize(app = nil, container: Infrastructure::DependencyContainer.new)
        super(app)
        @container = container
        @results = {}
        @settings_store = Infrastructure::SettingsStore.new
        stored = @settings_store.load
        @settings_store.apply_to_env(stored)
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

        def local_settings_store
          @settings_store
        end

        def local_settings_payload
          local_settings_store.load
        end

        def apply_local_settings(settings)
          local_settings_store.apply_to_env(settings)
        end

        def local_service_request(method, path, body = nil)
          base = ENV.fetch('TF_LOCAL_URL', 'http://127.0.0.1:5055')
          uri = URI.join(base, path)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          request = case method
                    when :get then Net::HTTP::Get.new(uri.request_uri)
                    else
                      req = Net::HTTP::Post.new(uri.request_uri)
                      req['Content-Type'] = 'application/json'
                      req.body = JSON.generate(body || {})
                      req
                    end
          response = http.request(request)
          [response.code.to_i, response.body]
        end
      end

      get '/' do
        erb :index, layout: :layout
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

      post '/api/upload' do
        file = params[:file]
        return json({ error: 'No file provided' }, status: 422) unless file

        begin
          file_path = file[:tempfile].path
          content = container.file_repository.read_text_file(file_path)
          json({ content: content, filename: file[:filename] })
        rescue StandardError => e
          json({ error: "File processing failed: #{e.message}" }, status: 500)
        end
      end

      post '/api/batch' do
        payload = JSON.parse(request.body.read) rescue {}
        files = payload['files'] || []
        api_type = (payload['api_type'] || 'unofficial').to_sym
        threads = (payload['threads'] || 4).to_i

        return json({ error: 'No files provided' }, status: 422) if files.empty?

        begin
          # This is a simplified batch processing for the web UI
          # In a real implementation, this would use the actual BatchProcessor
          results = []
          files.each do |file_data|
            result = translate(text: file_data['content'], api_type: api_type)
            id = SecureRandom.uuid
            @results[id] = result
            results << { id: id, filename: file_data['filename'], result: serialize_result(result) }
          end

          json({ results: results })
        rescue StandardError => e
          json({ error: e.message }, status: 500)
        end
      end

      get '/api/analytics' do
        # Mock analytics data - in real implementation, this would come from the database
        payload = {
          translation_memory: {
            cache_entries: 78,
            hit_rate: 32.0,
            savings: 1.23,
            cache_size_kb: 245
          }
        }
        if ENV['TF_COST_TRACKING_ENABLED'] == '1'
          payload[:cost_tracking] = {
            monthly_cost: 2.45,
            budget_remaining: 7.55,
            budget_usage: 24.5,
            total_characters: 125750,
            unofficial_usage: 143,
            official_cost: 2.45
          }
        end
        json(payload)
      end

      get '/api/local/settings' do
        json(local_settings_payload)
      end

      post '/api/local/settings' do
        payload = JSON.parse(request.body.read) rescue {}
        saved = local_settings_store.save(
          'local_service_url' => payload['local_service_url'].to_s,
          'local_model_dir' => payload['local_model_dir'].to_s,
          'local_auto_start' => payload.fetch('local_auto_start', true),
          'cost_tracking_enabled' => payload.fetch('cost_tracking_enabled', false)
        )
        apply_local_settings(saved)
        json(saved)
      end

      get '/api/local/models' do
        status, body = local_service_request(:get, '/models')
        json({ status: status, body: body }, status: status == 200 ? 200 : 502)
      end

      post '/api/local/models/verify' do
        status, body = local_service_request(:post, '/models/verify')
        json({ status: status, body: body }, status: status == 200 ? 200 : 502)
      end

      post '/api/local/models/remove' do
        status, body = local_service_request(:post, '/models/remove')
        json({ status: status, body: body }, status: status == 200 ? 200 : 502)
      end

      post '/api/local/models/install' do
        status, body = local_service_request(:post, '/models/install', {})
        json({ status: status, body: body }, status: status == 200 ? 200 : 502)
      end

      get '/api/export/test-docx' do
        begin
          # Use the same availability check as the export manager
          export_manager_class = container.export_manager.class
          available = export_manager_class.docx_available?
          if available
            json({ available: true })
          else
            json({
              available: false,
              error: 'DOCX functionality is having compatibility issues. Please use PDF or HTML export instead.',
              alternative: 'Use PDF or HTML export formats which are fully supported.'
            }, status: 503)
          end
        rescue StandardError => e
          json({
            available: false,
            error: "DOCX check failed: #{e.message}",
            alternative: 'Use PDF or HTML export formats which are fully supported.'
          }, status: 503)
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
          cost: ENV['TF_COST_TRACKING_ENABLED'] == '1' ? r.cost : nil,
          timestamp: r.timestamp
        }
      end
    end
  end
end
