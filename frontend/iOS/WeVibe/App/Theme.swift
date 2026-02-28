import SwiftUI

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

struct AppTheme {

    // MARK: - Primary Colors
    static let primaryBackground = Color(hex: "#0D2329")
    static let primaryButton     = Color(hex: "#4DC778")
    static let primaryText       = Color.white
    static let smallText     = Color(hex: "#05664F")

    // MARK: - Secondary Colors
    static let secondaryText       = Color.white.opacity(0.6)
    static let secondaryButton     = Color(hex: "#1a4a3a")
    static let secondaryBackground = Color(hex: "#122F36")

    // MARK: - Input Fields
    static let fieldBackground = Color.white.opacity(0.08)
    static let fieldBorder     = Color.white.opacity(0.15)
    static let fieldText       = Color.white

    // MARK: - Accent / Icon
    static let iconColor = Color(hex: "#D1FF5D")

    // MARK: - Gradients
    static let buttonGradient = LinearGradient(
        colors: [secondaryButton, primaryButton],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let logoGradient = LinearGradient(
        colors: [Color(hex: "#4DB870"), Color(hex: "#80DD8E")],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    // MARK: - Fonts
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular)
    }

    static func label(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium)
    }
}
