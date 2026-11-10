import SwiftUI

/// 方法详情页里的「三例看懂」：同一套步骤，在浅 / 中 / 深三份材料上各走一遍。
/// 目的是让「解释」落到具体材料上，而不是停在原理。
struct MethodDemoSection: View {
    let method: Method
    let tint: Color

    private var demo: MethodDemo? { DemoBank.demo(for: method.id) }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "浅": return Theme.success
        case "中": return Theme.warn
        case "深": return Theme.danger
        default: return tint
        }
    }

    var body: some View {
        if let demo, !demo.cases.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                header(count: demo.cases.count)
                Text(demo.intro)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(Array(demo.cases.enumerated()), id: \.element.id) { i, c in
                        DemoCaseCard(caseItem: c,
                                     index: i + 1,
                                     total: demo.cases.count,
                                     tint: tint,
                                     levelColor: levelColor(c.level))
                            .id("demo-\(i + 1)")
                        if i < demo.cases.count - 1 {
                            ladder
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("其余方法的三例正在陆续补上，同样的结构。")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Theme.textFaint)
            }
            .id("demo")
        }
    }

    private func header(count: Int) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(tint).frame(width: 3, height: 13)
            Text("三例看懂")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
            Text("\(count) 例 · 由浅到深")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textFaint)
        }
    }

    /// 卡片之间的阶梯，暗示「浅 → 深」
    private var ladder: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.veil(0.10))
                .frame(width: 1, height: 18)
                .padding(.leading, 30)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .leading) {
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.textFaint)
                .padding(.leading, 26.5)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 单份演示

private struct DemoCaseCard: View {
    let caseItem: DemoCase
    let index: Int
    let total: Int
    let tint: Color
    let levelColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Text("\(index)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(levelColor))
                Text(caseItem.level)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(levelColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(levelColor.opacity(0.14)))
                Text(caseItem.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Text("\(caseItem.items.count) 项")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }

            Text(caseItem.levelNote)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)

            material
            imageGrid
            trace
            built
            tip
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 18, stroke: levelColor.opacity(0.20))
    }

    private var material: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("材料")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textFaint)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(Theme.veil(0.07)))
                .padding(.top, 1)
            Text(caseItem.material)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// 元素 → 图像 的对照网格
    private var imageGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 6)], spacing: 6) {
            ForEach(caseItem.items) { item in
                VStack(spacing: 3) {
                    Text(item.emoji)
                        .font(.system(size: 20))
                    Text(item.text)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.textSub)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.veil(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.veil(0.06), lineWidth: 1)
                )
            }
        }
    }

    private var trace: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(caseItem.trace.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top, spacing: 9) {
                    VStack(spacing: 0) {
                        Text("\(i + 1)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .frame(width: 17, height: 17)
                            .background(Circle().fill(tint.opacity(0.12)))
                        if i < caseItem.trace.count - 1 {
                            Rectangle()
                                .fill(Theme.veil(0.08))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.step)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(tint)
                        Text(s.text)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSub)
                            .lineSpacing(2.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 9)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var built: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(levelColor.opacity(0.7))
                .frame(width: 2.5)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .semibold))
                    Text("走完是这样")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(levelColor)
                Text(caseItem.built)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 9)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            Spacer(minLength: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(levelColor.opacity(0.07))
        )
    }

    private var tip: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 2)
            Text(caseItem.tip)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
