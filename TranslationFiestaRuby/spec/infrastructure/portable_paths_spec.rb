# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

require_relative '../../lib/translation_fiesta/infrastructure/app_paths'
require_relative '../../lib/translation_fiesta/infrastructure/settings_store'

RSpec.describe 'portable paths' do
  around do |example|
    original = ENV['TF_APP_HOME']
    Dir.mktmpdir do |dir|
      ENV['TF_APP_HOME'] = dir
      TranslationFiesta::Infrastructure::AppPaths.instance_variable_set(:@data_root, nil)
      example.run
    ensure
      ENV['TF_APP_HOME'] = original
      TranslationFiesta::Infrastructure::AppPaths.instance_variable_set(:@data_root, nil)
    end
  end

  it 'persists settings inside TF_APP_HOME' do
    store = TranslationFiesta::Infrastructure::SettingsStore.new
    saved = store.save('default_api' => 'google_unofficial')

    expect(saved.fetch('default_api')).to eq('google_unofficial')
    expect(File).to exist(File.join(ENV.fetch('TF_APP_HOME'), 'settings.json'))
  end

  it 'normalizes provider aliases when saving settings' do
    store = TranslationFiesta::Infrastructure::SettingsStore.new
    saved = store.save('default_api' => 'google_free')

    expect(saved.fetch('default_api')).to eq('google_unofficial')
  end

  it 'uses TF_APP_HOME for translation memory db path' do
    path = TranslationFiesta::Infrastructure::AppPaths.memory_db_path
    expect(path).to eq(File.join(ENV.fetch('TF_APP_HOME'), 'translation_memory.db'))
  end
end
