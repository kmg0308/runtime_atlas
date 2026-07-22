import SwiftUI

enum RuntimeAtlasTheme {
    enum Typography {
        static let screenTitle: CGFloat = 25
        static let modalTitle: CGFloat = 21
        static let sectionTitle: CGFloat = 17
        static let body: CGFloat = 14
        static let secondary: CGFloat = 13
        static let caption: CGFloat = 12
        static let technical: CGFloat = 12
        static let badge: CGFloat = 11
    }

    static let background = Color(red: 0.012, green: 0.016, blue: 0.024)
    static let sidebar = Color(red: 0.025, green: 0.032, blue: 0.043)
    static let surface = Color(red: 0.050, green: 0.063, blue: 0.082)
    static let elevatedSurface = Color(red: 0.066, green: 0.084, blue: 0.108)
    static let control = Color(red: 0.076, green: 0.095, blue: 0.122)
    static let selected = Color(red: 0.075, green: 0.157, blue: 0.205)
    static let border = Color.white.opacity(0.10)
    static let strongBorder = Color.white.opacity(0.17)
    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.64)
    static let tertiaryText = Color.white.opacity(0.43)
    static let accent = Color(red: 0.42, green: 0.78, blue: 0.96)
    static let mint = Color(red: 0.46, green: 0.88, blue: 0.68)
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.32)
    static let red = Color(red: 1.0, green: 0.40, blue: 0.42)
    static let slate = Color(red: 0.56, green: 0.63, blue: 0.72)

    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 6
    static let controlHeight: CGFloat = 36
    static let minimumWindowWidth: CGFloat = 640
    static let minimumWindowHeight: CGFloat = 720
}

struct AtlasSurfaceModifier: ViewModifier {
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: RuntimeAtlasTheme.cardRadius, style: .continuous)
        content
            .background(shape.fill(elevated ? RuntimeAtlasTheme.elevatedSurface : RuntimeAtlasTheme.surface))
            .overlay(shape.stroke(RuntimeAtlasTheme.border, lineWidth: 1))
    }
}

extension View {
    func atlasSurface(elevated: Bool = false) -> some View {
        modifier(AtlasSurfaceModifier(elevated: elevated))
    }
}

struct AtlasButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .medium))
            .foregroundStyle(RuntimeAtlasTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(height: RuntimeAtlasTheme.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: RuntimeAtlasTheme.controlRadius, style: .continuous)
                    .fill(
                        prominent
                            ? RuntimeAtlasTheme.selected.opacity(configuration.isPressed ? 0.75 : 1)
                            : RuntimeAtlasTheme.control.opacity(configuration.isPressed ? 0.72 : 1)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: RuntimeAtlasTheme.controlRadius, style: .continuous)
                    .stroke(prominent ? RuntimeAtlasTheme.accent.opacity(0.32) : RuntimeAtlasTheme.border)
            }
    }
}
