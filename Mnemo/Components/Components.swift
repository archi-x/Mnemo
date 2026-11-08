import SwiftUI

// MARK: - 进度环

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.accent
    var track: Color = Color.white.opacity(0.08)

    var body: some View {
        ZStack {
            Circle().stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.55), tint, tint.opacity(0.9)],
                                    center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
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
            .foregroundStyle(filled ? Color.black.opacity(0.82) : tint)
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
            .foregroundStyle(Color.black.opacity(0.86))
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
