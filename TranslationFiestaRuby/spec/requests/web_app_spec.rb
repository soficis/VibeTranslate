require 'rack/test'
require 'rspec'

ENV['TF_USE_MOCK'] = '1'
require_relative '../../lib/translation_fiesta/web/app'

RSpec.describe TranslationFiesta::Web::App do
  include Rack::Test::Methods

  def app
    TranslationFiesta::Web::App.new
  end


  it 'returns health ok' do
    get '/health', {}, { 'HTTP_HOST' => '127.0.0.1' }
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body['status']).to eq('ok')
  end

  it 'translates text via api' do
    payload = { text: 'Hello world', api_type: 'unofficial' }
    post '/api/translate', payload.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_HOST' => '127.0.0.1' }
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['id']).not_to be_nil
    expect(body['result']['first_translation']).to include('[ja]')
  end
end
