import SwiftUI

/// View for displaying back-translation results.
struct TranslationResultView: View {
    let result: BackTranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Forward Translation
            VStack(alignment: .leading, spacing: 8) {
                Text("Forward Translation")
                    .font(.headline)

                HStack {
                    Text(result.forwardTranslation.sourceLanguage.flag)
                    Text(result.forwardTranslation.originalText)
                        .font(.body)
                        .lineLimit(3)
                }

                Image(systemName: "arrow.down")
                    .foregroundColor(.blue)

                HStack {
                    Text(result.forwardTranslation.targetLanguage.flag)
                    Text(result.forwardTranslation.translatedText)
                        .font(.body)
                        .foregroundColor(.blue)
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Back Translation
            VStack(alignment: .leading, spacing: 8) {
                Text("Back Translation")
                    .font(.headline)

                HStack {
                    Text(result.backwardTranslation.sourceLanguage.flag)
                    Text(result.backwardTranslation.originalText)
                        .font(.body)
                        .lineLimit(3)
                }

                Image(systemName: "arrow.down")
                    .foregroundColor(.green)

                HStack {
                    Text(result.backwardTranslation.targetLanguage.flag)
                    Text(result.backwardTranslation.translatedText)
                        .font(.body)
                        .foregroundColor(.green)
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
