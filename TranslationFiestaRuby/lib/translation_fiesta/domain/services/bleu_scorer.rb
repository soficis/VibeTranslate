# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Services
      class BleuScorer
        def initialize(max_n_gram = 4)
          @max_n_gram = max_n_gram
        end

        def calculate_score(reference, candidate)
          reference_tokens = tokenize(reference.downcase)
          candidate_tokens = tokenize(candidate.downcase)

          return 0.0 if candidate_tokens.empty?

          # Calculate brevity penalty
          brevity_penalty = calculate_brevity_penalty(reference_tokens, candidate_tokens)

          # Calculate precision for each n-gram level
          precisions = (1..@max_n_gram).map do |n|
            calculate_n_gram_precision(reference_tokens, candidate_tokens, n)
          end

          # Return 0 if any precision is 0
          return 0.0 if precisions.any?(&:zero?)

          # Calculate geometric mean of precisions
          log_precisions = precisions.map { |p| Math.log(p) }
          geometric_mean = Math.exp(log_precisions.sum / log_precisions.length)

          brevity_penalty * geometric_mean
        end

        private

        attr_reader :max_n_gram

        def tokenize(text)
          text.gsub(/[[:punct:]]/, ' ')
              .split(/\s+/)
              .reject(&:empty?)
        end

        def calculate_brevity_penalty(reference_tokens, candidate_tokens)
          ref_length = reference_tokens.length
          cand_length = candidate_tokens.length

          return 1.0 if cand_length >= ref_length

          Math.exp(1 - ref_length.to_f / cand_length)
        end

        def calculate_n_gram_precision(reference_tokens, candidate_tokens, n)
          return 0.0 if candidate_tokens.length < n

          reference_n_grams = extract_n_grams(reference_tokens, n)
          candidate_n_grams = extract_n_grams(candidate_tokens, n)

          return 0.0 if candidate_n_grams.empty?

          matches = 0
          candidate_n_grams.each do |n_gram|
            if reference_n_grams[n_gram] && reference_n_grams[n_gram] > 0
              matches += 1
              reference_n_grams[n_gram] -= 1
            end
          end

          matches.to_f / candidate_n_grams.length
        end

        def extract_n_grams(tokens, n)
          n_grams = Hash.new(0)
          (0..tokens.length - n).each do |i|
            n_gram = tokens[i, n].join(' ')
            n_grams[n_gram] += 1
          end
          n_grams
        end
      end
    end
  end
end