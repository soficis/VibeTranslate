import SwiftUI

/// Core design tokens and styles for VibeTranslate
/// Adheres to rigorous minimalist, Steve Jobs-inspired aesthetic.
/// Dark mode by default, 8pt grid system, strict typography scale.

// MARK: - Spacing (8pt Grid System)
enum Spacing {
    static let micro: CGFloat = 4
    static let small: CGFloat = 8
    static let standard: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 32
    static let xLarge: CGFloat = 44
    static let huge: CGFloat = 64
}

// MARK: - Radii
enum Radii {
    static let small: CGFloat = 4
    static let standard: CGFloat = 8
    static let large: CGFloat = 12
    static let xLarge: CGFloat = 16
}

// MARK: - Colors (Semantic & Native)
extension Color {
    static let themeBackground = Color(nsColor: .windowBackgroundColor)
    static let themeSurface = Color(nsColor: .controlBackgroundColor)
    static let themeSurfaceSecondary = Color(nsColor: .underPageBackgroundColor)
    
    static let themeText = Color.primary
    static let themeTextSecondary = Color.secondary
    
    static let themeAccent = Color.blue // Refined, standard Apple blue accent
    static let themeDestructive = Color.red
    static let themeSuccess = Color.green
    
    static let themeBorder = Color.gray.opacity(0.15)
}

// MARK: - Typography & Fonts
extension Font {
    static let themeTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let themeHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let themeBody = Font.system(size: 15, weight: .regular, design: .default)
    static let themeCaption = Font.system(size: 13, weight: .regular, design: .default)
    static let themeMonospaced = Font.system(size: 14, weight: .regular, design: .monospaced)
}

// MARK: - View Modifiers (Premium Components)

/// Applies a subtle, glass-like or clean surface background suitable for dark mode
struct ThemeSurfaceModifier: ViewModifier {
    var padding: CGFloat = Spacing.standard
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.themeSurface)
            .cornerRadius(Radii.standard)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.standard)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
    }
}

extension View {
    func themeSurface(padding: CGFloat = Spacing.standard) -> some View {
        self.modifier(ThemeSurfaceModifier(padding: padding))
    }
}

/// Styled TextEditor modifier for inputs
struct PremiumTextEditorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.themeBody)
            .padding(Spacing.small)
            .background(Color.themeSurface)
            .cornerRadius(Radii.standard)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.standard)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
    }
}

extension View {
    func premiumTextEditor() -> some View {
        self.modifier(PremiumTextEditorModifier())
    }
}
