import SwiftUI

struct MethodDetailView: View {
    @EnvironmentObject private var store: AppStore
    let method: Method

    @State private var cardAdded = false
    @State private var showPractice = false

    private var tint: Color { Theme.tint(method.categoryId) }
    private var learned: Bool { store.learnedMethods.contains(method.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                if !method.kidLine.isEmpty { kidLineCard }
                section("原理", body: method.principle)
                stepsSection
                fitSection
                caseSection
                practiceSection
                if !method.mistakes.isEmpty { mistakeSection }
                if !method.combo.isEmpty { section("组合建议", body: method.combo) }
                if let kid = method.kidCase { kidCaseSection(kid) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(method.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
        }
    }

    // MARK: 顶部

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TagChip(text: method.categoryName, tint: tint, filled: true)
                Spacer()
                Text(method.code)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint.opacity(0.18))
            }
            Text(method.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(method.definition)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private var kidLineCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(method.kidLine)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text("儿童版一句话解释")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: 通用块

    private func section(_ title: String, body text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            blockTitle(title)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func blockTitle(_ title: String) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(tint).frame(width: 3, height: 13)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            blockTitle("使用步骤")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(method.steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Text("\(i + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(tint)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(tint.opacity(0.14)))
                            if i < method.steps.count - 1 {
                                Rectangle()
                                    .fill(Theme.veil(0.08))
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        Text(s)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.text)
                            .lineSpacing(2)
                            .padding(.top, 2)
                            .padding(.bottom, 14)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(14)
            .glass(radius: 16)
        }
    }

    private var fitSection: some View {
        HStack(alignment: .top, spacing: 10) {
            bulletCard(title: "最适合", items: method.bestFor, tint: Theme.success, symbol: "checkmark")
            bulletCard(title: "不适合", items: method.notFor, tint: Theme.danger, symbol: "minus")
        }
    }

    private func bulletCard(title: String, items: [String], tint c: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(c)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSub)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glass(radius: 16)
    }

    private var caseSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            blockTitle("案例")
            VStack(alignment: .leading, spacing: 8) {
                if !method.caseTitle.isEmpty {
                    Text(method.caseTitle)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(tint)
                }
                ForEach(Array(method.caseLines.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1)")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textFaint)
                            .padding(.top, 2)
                        Text(line)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.text)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: 16)
        }
    }

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            blockTitle("举一反三")
            ForEach(method.practice) { p in
                HStack(alignment: .top, spacing: 10) {
                    TagChip(text: p.level,
                            tint: p.level == "初阶" ? Theme.success
                                : (p.level == "中阶" ? Theme.warn : Theme.danger))
                    Text(p.task)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .glass(radius: 14)
            }
        }
    }

    private var mistakeSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            blockTitle("常见错误")
            VStack(alignment: .leading, spacing: 7) {
                ForEach(method.mistakes, id: \.self) { m in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.warn.opacity(0.85))
                            .padding(.top, 3)
                        Text(m)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textSub)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: 16)
        }
    }

    private func kidCaseSection(_ kid: KidCase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            blockTitle("给孩子讲：\(kid.title)")
            VStack(alignment: .leading, spacing: 8) {
                if !kid.material.isEmpty {
                    Text("材料：\(kid.material)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                }
                ForEach(Array(kid.steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1)")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textFaint)
                            .padding(.top, 2)
                        Text(s)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.text)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                if !kid.tip.isEmpty {
                    Text(kid.tip)
                        .font(.system(size: 12))
                        .foregroundStyle(tint.opacity(0.85))
                        .padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: 16)
        }
    }

    // MARK: 底部操作

    private var bottomBar: some View {
        HStack(spacing: 8) {
            iconAction(symbol: learned ? "checkmark.seal.fill" : "seal",
                       label: learned ? "已学" : "标记",
                       tint: learned ? Theme.success : Theme.textSub,
                       disabled: learned) {
                Haptic.success()
                store.markMethodLearned(method.id)
            }

            iconAction(symbol: cardAdded ? "checkmark" : "plus.rectangle.on.rectangle",
                       label: "复习卡",
                       tint: cardAdded ? Theme.success : Theme.textSub,
                       disabled: cardAdded) {
                guard !cardAdded else { return }
                let card = ReviewCard(front: "「\(method.name)」的核心动作是什么？\n适合什么材料？",
                                      back: "\(method.definition)\n步骤：\(method.steps.prefix(3).joined(separator: "→"))",
                                      kind: .method,
                                      due: Date().addingTimeInterval(600),
                                      methodId: method.id)
                store.addCard(card)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { cardAdded = true }
                Haptic.success()
            }

            PrimaryButton(title: "开始练习", symbol: "play.fill", tint: tint) {
                showPractice = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 0.7) }
                .ignoresSafeArea(edges: .bottom)
        )
        .fullScreenCover(isPresented: $showPractice) {
            MethodPracticeView(method: method).environmentObject(store)
        }
    }

    private func iconAction(symbol: String, label: String, tint: Color, disabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(width: 54, height: 52)
            .glass(radius: 14)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.75 : 1)
    }
}
