# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TranslationFiesta::Data::Repositories::GoogleTranslationRepository do
  let(:repo) { described_class.new(:google_unofficial) }
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(repo).to receive(:build_http_client).and_return(http)
    allow(repo).to receive(:backoff_delay).and_return(0)
  end

  it 'parses unofficial translation response' do
    payload = [[['Hello', 'こんにちは', nil, nil]]]
    response = instance_double(Net::HTTPResponse, code: '200', body: JSON.generate(payload))
    allow(http).to receive(:request).and_return(response)

    result = repo.send(:translate_unofficial, 'こんにちは', 'ja', 'en')

    expect(result).to eq('Hello')
  end

  it 'maps rate limited response' do
    response = instance_double(Net::HTTPResponse, code: '429', body: 'too many')
    allow(http).to receive(:request).and_return(response)

    expect {
      repo.send(:translate_unofficial, 'hello', 'en', 'ja')
    }.to raise_error(TranslationFiesta::TranslationError, /rate_limited/)
  end

  it 'normalizes provider aliases to unofficial mode' do
    aliases = %w[google_unofficial unofficial google_unofficial_free google_free googletranslate]
    aliases.each do |alias_name|
      normalized = repo.send(:normalize_api_type, alias_name)
      expect(normalized).to eq(:unofficial)
    end
  end
end
