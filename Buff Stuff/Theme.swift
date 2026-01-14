import SwiftUI

// MARK: - IRON Theme
// Industrial Athletic aesthetic - raw, functional, no wasted motion

struct Theme {
    // MARK: - Colors
    struct Colors {
        // Backgrounds
        static let background = Color(hex: "0A0A0A")
        static let surface = Color(hex: "1A1A1A")
        static let surfaceElevated = Color(hex: "252525")

        // Primary accent - Electric Lime for high visibility
        static let accent = Color(hex: "CCFF00")
        static let accentMuted = Color(hex: "CCFF00").opacity(0.2)

        // Text
        static let textPrimary = Color(hex: "F5F5F5")
        static let textSecondary = Color(hex: "8A8A8A")
        static let textMuted = Color(hex: "5A5A5A")

        // Semantic
        static let success = Color(hex: "34C759")
        static let warning = Color(hex: "FF9500")
        static let danger = Color(hex: "FF3B30")

        // Steel accents
        static let steel = Color(hex: "6B6B6B")
        static let steelLight = Color(hex: "9A9A9A")
    }

    // MARK: - Typography
    struct Typography {
        // Display numbers - big, bold, impactful
        static func displayLarge(_ size: CGFloat = 56) -> Font {
            .system(size: size, weight: .black, design: .rounded)
        }

        static func displayMedium(_ size: CGFloat = 42) -> Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }

        static func displaySmall(_ size: CGFloat = 32) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        // Headings
        static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let subheadline = Font.system(size: 15, weight: .medium, design: .default)

        // Body
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 16, weight: .semibold, design: .default)
        static let caption = Font.system(size: 13, weight: .medium, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .medium, design: .default)

        // Mono for numbers
        static func mono(_ size: CGFloat = 16) -> Font {
            .system(size: size, weight: .semibold, design: .monospaced)
        }
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    struct Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 100
    }

    // MARK: - Shadows
    struct Shadows {
        static let glow = Color(hex: "CCFF00").opacity(0.3)
        static let dark = Color.black.opacity(0.5)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(elevated ? Theme.Colors.surfaceElevated : Theme.Colors.surface)
            .cornerRadius(Theme.Radius.large)
    }
}

struct AccentButtonStyle: ButtonStyle {
    var isLarge: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isLarge ? Theme.Typography.headline : Theme.Typography.bodyBold)
            .foregroundColor(Theme.Colors.background)
            .padding(.horizontal, isLarge ? Theme.Spacing.xl : Theme.Spacing.lg)
            .padding(.vertical, isLarge ? Theme.Spacing.md : Theme.Spacing.sm + 4)
            .background(Theme.Colors.accent)
            .cornerRadius(isLarge ? Theme.Radius.medium : Theme.Radius.small)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodyBold)
            .foregroundColor(Theme.Colors.accent)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm + 4)
            .background(Theme.Colors.accentMuted)
            .cornerRadius(Theme.Radius.small)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(elevated: Bool = false) -> some View {
        modifier(CardStyle(elevated: elevated))
    }
}
