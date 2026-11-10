import SwiftUI

// MARK: - 进度环

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.accent
    var track: Color = Theme.veil(0.08)

    var body: some View {
        ZStack {
            Circle().stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: min(1, progress))
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.55), tint, tint.opacity(0.9)],
                                    center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0.004 ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - 标签与胶囊

struct TagChip: View {
    let text: String
    var tint: Color = Theme.textSub
    var filled = false

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(filled ? Theme.onAccent : tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule().fill(filled ? tint : tint.opacity(0.12))
                    .overlay(Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.25), lineWidth: 1))
            )
    }
}

struct IconBadge: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                            .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                    )
            )
    }
}

struct StatTile: View {
    let value: String
    let unit: String
    let label: String
    var tint: Color = Theme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glass(radius: 18)
    }
}

// MARK: - 区块标题

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            if let trailing {
                Button {
                    Haptic.tap()
                    action?()
                } label: {
                    HStack(spacing: 3) {
                        Text(trailing)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textSub)
                }
                .disabled(action == nil)
            }
        }
    }
}

// MARK: - 提示卡

/// 提示卡里的一行：小图标 + 一句话
struct TipLine: Identifiable {
    let id = UUID()
    let symbol: String
    let text: String

    init(_ symbol: String, _ text: String) {
        self.symbol = symbol
        self.text = text
    }
}

/// 卡片式提示：「XX 怎么选 / 怎么算过关」这类说明，统一成一块玻璃卡
struct TipCard: View {
    let title: String
    var tint: Color = Theme.accent
    let lines: [TipLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.text)
            ForEach(lines) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: line.symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.85))
                        .frame(width: 15)
                        .padding(.top, 1)
                    Text(line.text)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSub)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 18)
    }
}

// MARK: - 主按钮

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap(.medium)
            action()
        } label: {
            HStack(spacing: 7) {
                if let symbol { Image(systemName: symbol).font(.system(size: 14, weight: .bold)) }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.82)],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: tint.opacity(0.28), radius: 14, y: 6)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct GhostButton: View {
    let title: String
    var symbol: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .glass(radius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 外观预览

/// 一小块迷你界面，用来在「我的」里预览两套配色。色值写死，不跟随当前主题。
struct ThemePreviewSwatch: View {
    let mode: Appearance
    var body: some View {
        ZStack {
            switch mode {
            case .night:
                mini(bg: 0x0E1119, card: 0xFFFFFF, cardAlpha: 0.10, accent: 0xF5B455)
            case .day:
                mini(bg: 0xF6F2EA, card: 0xFFFFFF, cardAlpha: 0.95, accent: 0xB26A10)
            case .auto:
                HStack(spacing: 0) {
                    mini(bg: 0x0E1119, card: 0xFFFFFF, cardAlpha: 0.10, accent: 0xF5B455)
                    mini(bg: 0xF6F2EA, card: 0xFFFFFF, cardAlpha: 0.95, accent: 0xB26A10)
                }
            }
        }
        .frame(width: 44, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(hex: 0x888888).opacity(0.22), lineWidth: 0.8)
        )
    }

    private func mini(bg: UInt32, card: UInt32, cardAlpha: Double, accent: UInt32) -> some View {
        ZStack(alignment: .topLeading) {
            Color(hex: bg)
            VStack(alignment: .leading, spacing: 3) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: card).opacity(cardAlpha))
                    .frame(width: 22, height: 9)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: accent))
                    .frame(width: 14, height: 4)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: card).opacity(cardAlpha * 0.7))
                    .frame(width: 18, height: 3)
            }
            .padding(5)
        }
        .frame(width: 22, height: 32)
    }
}

// MARK: - 空状态

struct EmptyHint: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textFaint)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}


// MARK: - 入口行

struct EntryRow: View {
    let symbol: String
    var tint: Color = Theme.accent
    let title: String
    let detail: String
    var trailing: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: symbol, tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSub)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(tint)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(13)
            .glass(radius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
