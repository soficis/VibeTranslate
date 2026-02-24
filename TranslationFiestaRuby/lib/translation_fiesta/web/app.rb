# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'securerandom'
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
        @settings_store.apply_to_env(@settings_store.load)
      end

      # Simple auth and rate limiting for /api/* endpoints
      before do
        next unless request.path.start_with?('/api/')

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
        halt 429, JSON.generate({ error: 'Rate limit exceeded' }) if data[:count] > RATE_LIMIT
      end

      helpers do
        def json(data, status: 200)
          content_type :json
          halt status, JSON.generate(data)
        end

        def container
          settings.respond_to?(:container) ? settings.container : @container
        end

        def normalize_api_type(value)
          case value.to_s
          when 'unofficial', 'google_unofficial'
            :unofficial
          else
            :unofficial
          end
        end

        def translate(text:, api_type: :unofficial)
          container.translate_use_case.execute(text, normalize_api_type(api_type))
        end

        def settings_store
          @settings_store
        end
      end

      get '/' do
        erb :index, layout: :layout
      end

      post '/api/translate' do
        payload = JSON.parse(request.body.read) rescue {}
        text = (payload['text'] || '').strip
        configured_default = settings_store.load.fetch('default_api', 'unofficial')
        api_type = payload['api_type'] || configured_default
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
        configured_default = settings_store.load.fetch('default_api', 'unofficial')
        api_type = payload['api_type'] || configured_default

        return json({ error: 'No files provided' }, status: 422) if files.empty?

        begin
          # Simplified batch processing for the web UI.
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
        payload = {
          translation_memory: {
            cache_entries: 78,
            hit_rate: 32.0,
            cache_size_kb: 245
          }
        }
        json(payload)
      end

      get '/api/settings' do
        json(settings_store.load)
      end

      post '/api/settings' do
        payload = JSON.parse(request.body.read) rescue {}
        saved = settings_store.save(
          'default_api' => normalize_api_type(payload['default_api']).to_s
        )
        settings_store.apply_to_env(saved)
        json(saved)
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

      def serialize_result(result)
        {
          original_text: result.original_text,
          first_translation: result.first_translation,
          back_translation: result.back_translation,
          api_type: result.api_type,
          timestamp: result.timestamp
        }
      end
    end
  end
end
