# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TranslationFiesta::CLI do
  around do |example|
    original = ENV['TF_DEFAULT_API']
    ENV['TF_DEFAULT_API'] = 'google_free'
    example.run
  ensure
    ENV['TF_DEFAULT_API'] = original
  end

  it 'uses TF_DEFAULT_API when --api is not provided' do
    translation_result = TranslationFiesta::Domain::Entities::TranslationResult.new(
      original_text: 'Hello world',
      first_translation: 'こんにちは世界',
      back_translation: 'Hello world',
      api_type: :custom_api
    )
    translate_use_case = instance_double(TranslationFiesta::UseCases::TranslateTextUseCase)
    container = instance_double(
      TranslationFiesta::Infrastructure::DependencyContainer,
      translate_use_case: translate_use_case
    )

    allow(translate_use_case).to receive(:execute)
      .with('Hello world', :unofficial)
      .and_return(translation_result)

    cli = described_class.new(container: container)

    expect { cli.run(%w[translate Hello\ world]) }.to output(/TRANSLATION RESULT/).to_stdout
  end
end
