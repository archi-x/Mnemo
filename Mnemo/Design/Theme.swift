import SwiftUI

// MARK: - 外观

/// 两套配色 + 跟随系统。切换只改窗口的 colorScheme，所有令牌都是动态色，整屏即时生效。
enum Appearance: String, Codable, CaseIterable, Identifiable {
    case night
    case day
    case auto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .night: return "深夜"
        case .day: return "白天"
        case .auto: return "跟随系统"
        }
    }

    var detail: String {
        switch self {
        case .night: return "深夜书房 · 暖光"
        case .day: return "白天自习室 · 纸感"
        case .auto: return "随系统自动切换"
        }
    }

    var symbol: String {
        switch self {
        case .night: return "moon.stars.fill"
        case .day: return "sun.max.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .night: return .dark
        case .day: return .light
        case .auto: return nil
        }
    }
}

// MARK: - 视觉语言

/// 全局颜色令牌。全部是随 trait 解析的动态色：
/// 深夜 = 深夜书房 + 记忆宫殿的暖光；白天 = 纸感自习室 + 深琥珀。
enum Theme {
    // MARK: 动态色工厂

    private static func dyn(_ night: UInt32, _ day: UInt32,
                            nightAlpha: Double = 1, dayAlpha: Double = 1) -> Color {
        Color(uiColor: UIColor { trait in
            let isDark = trait.userInterfaceStyle != .light
            let hex = isDark ? night : day
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: CGFloat(isDark ? nightAlpha : dayAlpha))
        })
    }

    /// 白色叠层（深色）/ 黑色叠层（浅色）的等价体，用来替代写死的 `Color.white.opacity(x)`
    static func veil(_ value: Double) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor.black.withAlphaComponent(value * 0.82)
                : UIColor.white.withAlphaComponent(value)
        })
    }

    // MARK: 主色

    static let accent = dyn(0xF5B455, 0xB26A10)
    static let accentSoft = dyn(0xFFD79A, 0xE09A38)

    /// 强调色上的文字：深色用黑，浅色用白
    static let onAccent = dyn(0x000000, 0xFFFFFF, nightAlpha: 0.86, dayAlpha: 1)

    /// 图表里的次要柱 / 次要数据（浅色下要更实一点才看得见）
    static let accentMuted = dyn(0xF5B455, 0xB26A10, nightAlpha: 0.28, dayAlpha: 0.6)

    // MARK: 底色

    static let bg = dyn(0x0A0B10, 0xF4F1EA)
    static let bgLift = dyn(0x12141C, 0xFFFCF6)
    static let surface = dyn(0xFFFFFF, 0xFFFFFF, nightAlpha: 0.055, dayAlpha: 0.86)
    static let stroke = dyn(0xFFFFFF, 0x000000, nightAlpha: 0.09, dayAlpha: 0.08)
    static let strokeStrong = dyn(0xFFFFFF, 0x000000, nightAlpha: 0.16, dayAlpha: 0.16)

    /// 进度条轨道 / 细分隔线
    static let track = veil(0.10)

    // MARK: 文字

    static let text = dyn(0xF4F5F8, 0x1C1F27)
    static let textSub = dyn(0x9BA1AF, 0x5B6172)
    static let textFaint = dyn(0x6A7080, 0x8B91A0)

    // MARK: 语义色

    static let success = dyn(0x37D399, 0x0B8059)
    static let warn = dyn(0xFBBF24, 0xA06B00)
    static let danger = dyn(0xF26D6D, 0xC23F3A)

    // MARK: 阴影

    static let shadow = dyn(0x000000, 0x000000, nightAlpha: 0.5, dayAlpha: 0.16)
    /// 卡片投影：深色下透明（靠描边分层），浅色下给一点纸的厚度
    static let cardShadow = dyn(0x000000, 0x000000, nightAlpha: 0, dayAlpha: 0.07)

    /// 七类记忆法的强调色
    static func tint(_ categoryId: String) -> Color {
        switch categoryId {
        case "code": return dyn(0xF5B455, 0xA9610A)
        case "space": return dyn(0x4FD1C5, 0x0B7F76)
        case "seq": return dyn(0xA78BFA, 0x6444C9)
        case "lang": return dyn(0xF472B6, 0xB53476)
        case "struct": return dyn(0x60A5FA, 0x1F58BE)
        case "deep": return dyn(0x34D399, 0x0A7550)
        case "review": return dyn(0xFB923C, 0xBF5C0B)
        default: return accent
        }
    }

    // MARK: 画布

    static var canvas: some View {
        ZStack {
            LinearGradient(colors: [dyn(0x111524, 0xFDFBF6), bg, dyn(0x07080C, 0xEBE5D9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.15, y: 0.02), startRadius: 8, endRadius: 420)
            RadialGradient(colors: [tint("space").opacity(0.10), .clear],
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
                    .shadow(color: Theme.cardShadow, radius: 10, y: 3)
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
