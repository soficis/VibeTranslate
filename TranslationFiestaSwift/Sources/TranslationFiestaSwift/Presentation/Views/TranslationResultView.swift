import SwiftUI

/// View for displaying back-translation results.
struct TranslationResultView: View {
    let result: BackTranslationResult

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.standard) {
                // Translating from Source -> Target
                resultCard(
                    title: "Forward Translation",
                    sourceLang: result.forwardTranslation.sourceLanguage,
                    sourceText: result.forwardTranslation.originalText,
                    targetLang: result.forwardTranslation.targetLanguage,
                    targetText: result.forwardTranslation.translatedText,
                    color: .themeAccent
                )
                
                // Translating back from Target -> Source
                resultCard(
                    title: "Back Translation",
                    sourceLang: result.backwardTranslation.sourceLanguage,
                    sourceText: result.backwardTranslation.originalText,
                    targetLang: result.backwardTranslation.targetLanguage,
                    targetText: result.backwardTranslation.translatedText,
                    color: .themeSuccess
                )
            }
            .padding(Spacing.small)
        }
    }
    
    private func resultCard(title: String, sourceLang: Language, sourceText: String, targetLang: Language, targetText: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(.themeCaption)
                .foregroundColor(.themeTextSecondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(alignment: .top) {
                    Text(sourceLang.flag)
                        .font(.themeBody)
                    Text(sourceText)
                        .font(.themeBody)
                        .foregroundColor(.themeTextSecondary)
                        .lineLimit(nil)
                }
                
                Image(systemName: "arrow.down")
                    .foregroundColor(color.opacity(0.8))
                    .padding(.leading, Spacing.small)
                
                HStack(alignment: .top) {
                    Text(targetLang.flag)
                        .font(.themeBody)
                    Text(targetText)
                        .font(.themeBody)
                        .foregroundColor(color)
                        .lineLimit(nil)
                }
            }
            .padding(Spacing.standard)
            .background(color.opacity(0.1))
            .cornerRadius(Radii.standard)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.standard)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
