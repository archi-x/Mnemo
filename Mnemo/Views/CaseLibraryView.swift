import SwiftUI

// MARK: - 图解案例库

/// 一门记忆法的图解案例：按难度分档，每条案例给三种思路。
struct CaseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var tierId: String = CaseBank.deck.tiers.first?.id ?? "basic"
    @State private var selected: ImageCase?

    private var tint: Color { Theme.tint("code") }

    var body: some View {
        ZStack {
            Theme.canvas

            if let selected {
                CaseDetailView(
                    item: selected,
                    tint: tint,
                    onBack: {
                        Haptic.tap()
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            self.selected = nil
                        }
                    },
                    onJump: { next in
                        Haptic.select()
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            self.selected = next
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
            } else {
                list
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(store.appearance.colorScheme)
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-case"), i + 1 < args.count,
               let idx = Int(args[i + 1]) {
                let all = CaseBank.ordered
                if all.indices.contains(idx) {
                    tierId = all[idx].tier
                    selected = all[idx]
                }
            }
        }
        #endif
    }

    // MARK: 列表

    private var list: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    tierPicker
                    VStack(spacing: 10) {
                        ForEach(CaseBank.cases(in: tierId)) { c in
                            Button {
                                Haptic.tap()
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                    selected = c
                                }
                            } label: {
                                CaseRowCard(caseItem: c, tint: tint)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    footnote
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("图解案例")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("\(CaseBank.deck.methodName) · \(CaseBank.deck.cases.count) 例 · \(CaseBank.totalPaths) 条思路")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSub)
            }
            Spacer()
            Button {
                Haptic.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSub)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.veil(0.06)))
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var introCard: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "eye.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 2)
            Text(CaseBank.deck.intro)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 16)
    }

    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(CaseBank.deck.tiers) { t in
                    let on = tierId == t.id
                    let count = CaseBank.cases(in: t.id).count
                    Button {
                        guard tierId != t.id else { return }
                        Haptic.select()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) { tierId = t.id }
                    } label: {
                        VStack(spacing: 2) {
                            Text(t.name)
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(count) 例")
                                .font(.system(size: 10, weight: .medium))
                                .opacity(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(on ? Theme.onAccent : Theme.textSub)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(on ? tint : Theme.veil(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(on ? .clear : Theme.stroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            if let t = CaseBank.tier(tierId) {
                Text(t.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }

    private var footnote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill").font(.system(size: 9))
            Text("同一份材料有三种解法，先挑最顺手的，熟练后再换另一种重做一遍。")
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.textFaint)
        .padding(.top, 4)
    }
}

// MARK: - 列表卡片

private struct CaseRowCard: View {
    let caseItem: ImageCase
    let tint: Color

    private var tierName: String { CaseBank.tier(caseItem.tier)?.name ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                ForEach(caseItem.items.prefix(5)) { item in
                    Text(item.emoji)
                        .font(.system(size: 15))
                        .frame(width: 27, height: 27)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.veil(0.06))
                        )
                }
                Spacer(minLength: 0)
                Text("\(caseItem.count) 项")
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }

            Text(caseItem.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)

            Text(caseItem.material)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSub)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                ForEach(Array(caseItem.paths.enumerated()), id: \.offset) { i, p in
                    HStack(spacing: 3) {
                        Text("\(i + 1)")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                        Text(p.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.textSub)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule().fill(tint.opacity(0.10))
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 18)
    }
}

// MARK: - 案例详情

private struct CaseDetailView: View {
    let item: ImageCase
    let tint: Color
    let onBack: () -> Void
    let onJump: (ImageCase) -> Void

    @State private var pathIndex = 0
    @State private var masked = false
    @State private var revealed: Set<Int> = []

    private var path: MemoryPath? {
        item.paths.indices.contains(pathIndex) ? item.paths[pathIndex] : item.paths.first
    }

    private var order: (Int, Int) {
        let all = CaseBank.ordered
        let i = all.firstIndex { $0.id == item.id } ?? 0
        return (i + 1, all.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    materialCard
                    imageSection
                    pathSection
                    if let path { pathCard(path) }
                    navigationRow
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var navBar: some View {
        HStack(spacing: 10) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                    Text("案例")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Theme.textSub)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            Text("\(order.0) / \(order.1)")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                TagChip(text: CaseBank.tier(item.tier)?.name ?? "", tint: tint, filled: true)
                TagChip(text: "\(item.count) 个元素", tint: Theme.textSub)
                TagChip(text: "3 种思路", tint: Theme.textSub)
            }
            Text(item.title)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Theme.text)
        }
    }

    private var materialCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill").font(.system(size: 10))
                Text("要记住的材料").font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(tint)
            Text(item.material)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 18)
    }

    // MARK: 图像对照

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                blockTitle("图像对照")
                Spacer()
                Button {
                    Haptic.tap()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        masked.toggle()
                        revealed.removeAll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: masked ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(masked ? "已遮住 · 点卡片翻开" : "遮住图自测")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(masked ? tint : Theme.textFaint)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
                      spacing: 9) {
                ForEach(Array(item.items.enumerated()), id: \.offset) { i, it in
                    let hidden = masked && !revealed.contains(i)
                    Button {
                        guard masked else { return }
                        Haptic.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            _ = revealed.insert(i)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(hidden ? "?" : it.emoji)
                                .font(.system(size: hidden ? 22 : 28, weight: .bold))
                                .foregroundStyle(hidden ? Theme.textFaint : Theme.text)
                                .frame(height: 34)
                            Text(hidden ? "第 \(i + 1) 个" : it.text)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(hidden ? Theme.textFaint : Theme.textSub)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hidden ? Theme.veil(0.03) : Theme.veil(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(hidden ? Theme.stroke : .clear, lineWidth: 1)
                                )
                        )
                        .overlay(alignment: .topLeading) {
                            Text("\(i + 1)")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textFaint)
                                .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func blockTitle(_ t: String) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(tint).frame(width: 3, height: 12)
            Text(t)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
        }
    }

    // MARK: 三条思路

    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            blockTitle("三种记忆思路")
            HStack(spacing: 7) {
                ForEach(Array(item.paths.enumerated()), id: \.offset) { i, p in
                    let on = pathIndex == i
                    Button {
                        guard pathIndex != i else { return }
                        Haptic.select()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) { pathIndex = i }
                    } label: {
                        VStack(spacing: 1) {
                            Text(p.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(p.kind)
                                .font(.system(size: 9.5))
                                .opacity(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(on ? Theme.onAccent : Theme.textSub)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(on ? tint : Theme.veil(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(on ? .clear : Theme.stroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func pathCard(_ p: MemoryPath) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            // 为什么有效
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(tint)
                    .padding(.top, 2)
                Text(p.why)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 操作步骤
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(p.steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Text("\(i + 1)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(tint)
                                .frame(width: 19, height: 19)
                                .background(Circle().fill(tint.opacity(0.14)))
                            if i < p.steps.count - 1 {
                                Rectangle()
                                    .fill(Theme.veil(0.08))
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        Text(s)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text)
                            .lineSpacing(2)
                            .padding(.top, 1)
                            .padding(.bottom, i < p.steps.count - 1 ? 11 : 0)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            // 串好的成品
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "text.append")
                        .font(.system(size: 9, weight: .semibold))
                    Text("串起来是这样")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(tint)
                Text(p.built)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                    )
            )

            // 提取钩子
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "key.fill")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.warn)
                    .padding(.top, 2)
                Text(p.tip)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 18)
    }

    // MARK: 上下条

    private var navigationRow: some View {
        HStack(spacing: 9) {
            if let prev = CaseBank.previous(before: item.id) {
                Button {
                    onJump(prev)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                        Text("上一例").font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(Theme.textSub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glass(radius: 14)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            if let next = CaseBank.next(after: item.id) {
                Button {
                    onJump(next)
                } label: {
                    HStack(spacing: 4) {
                        Text("下一例：\(next.title)").font(.system(size: 12.5, weight: .semibold))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}
