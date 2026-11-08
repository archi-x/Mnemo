import SwiftUI

/// 全局视觉语言：深夜书房 + 记忆宫殿的暖光。
enum Theme {
    static let accent = Color(hex: 0xF5B455)
    static let accentSoft = Color(hex: 0xFFD79A)

    static let bg = Color(hex: 0x0A0B10)
    static let bgLift = Color(hex: 0x12141C)
    static let surface = Color.white.opacity(0.055)
    static let stroke = Color.white.opacity(0.09)
    static let strokeStrong = Color.white.opacity(0.16)

    static let text = Color(hex: 0xF4F5F8)
    static let textSub = Color(hex: 0x9BA1AF)
    static let textFaint = Color(hex: 0x6A7080)

    static let success = Color(hex: 0x37D399)
    static let warn = Color(hex: 0xFBBF24)
    static let danger = Color(hex: 0xF26D6D)

    /// 七类记忆法的强调色
    static func tint(_ categoryId: String) -> Color {
        switch categoryId {
        case "code": return Color(hex: 0xF5B455)
        case "space": return Color(hex: 0x4FD1C5)
        case "seq": return Color(hex: 0xA78BFA)
        case "lang": return Color(hex: 0xF472B6)
        case "struct": return Color(hex: 0x60A5FA)
        case "deep": return Color(hex: 0x34D399)
        case "review": return Color(hex: 0xFB923C)
        default: return accent
        }
    }

    static var canvas: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x111524), bg, Color(hex: 0x07080C)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.15, y: 0.02), startRadius: 8, endRadius: 420)
            RadialGradient(colors: [Color(hex: 0x4FD1C5).opacity(0.10), .clear],
                           center: UnitPoint(x: 0.95, y: 0.85), startRadius: 8, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - 组件样式

struct GlassCard: ViewModifier {
    var radius: CGFloat = 22
    var strokeColor: Color = Theme.stroke
    var fill: Color = Theme.surface

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(strokeColor, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glass(radius: CGFloat = 22, stroke: Color = Theme.stroke, fill: Color = Theme.surface) -> some View {
        modifier(GlassCard(radius: radius, strokeColor: stroke, fill: fill))
    }

    func pageTitle() -> some View {
        font(.system(size: 30, weight: .bold))
    }
}

// MARK: - 触感

enum Haptic {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
