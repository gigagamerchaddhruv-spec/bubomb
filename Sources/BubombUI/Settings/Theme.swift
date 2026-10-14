import SwiftUI

public enum BubombTheme {
    public static let windowBackground = Color(red: 0.08, green: 0.08, blue: 0.10)
    public static let surface = Color(red: 0.12, green: 0.12, blue: 0.15)
    public static let surfaceElevated = Color(red: 0.16, green: 0.16, blue: 0.20)
    public static let border = Color(red: 0.22, green: 0.22, blue: 0.28)
    public static let borderSubtle = Color(red: 0.18, green: 0.18, blue: 0.23)

    public static let accentOrange = Color(red: 1.0, green: 0.42, blue: 0.0)
    public static let accentAmber = Color(red: 1.0, green: 0.65, blue: 0.0)
    public static let accentPurple = Color(red: 0.52, green: 0.40, blue: 0.95)
    public static let successGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
    public static let failureRed = Color(red: 1.0, green: 0.27, blue: 0.23)

    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textMuted = Color.white.opacity(0.40)
}

public struct CardModifier: ViewModifier {
    var padding: CGFloat = 14

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BubombTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BubombTheme.borderSubtle, lineWidth: 1)
            )
    }
}

public extension View {
    func bubombCard(padding: CGFloat = 14) -> some View {
        self.modifier(CardModifier(padding: padding))
    }
}
