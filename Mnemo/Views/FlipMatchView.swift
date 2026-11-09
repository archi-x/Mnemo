import SwiftUI

// MARK: - 通用顶栏

struct QuestTopBar: View {
    let stage: SchoolStage
    let title: String
    let level: Int
    let remaining: Int
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Haptic.tap()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSub)
                    .frame(width: 32, height: 32)
                    .glass(radius: 11)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(stage.emoji) \(stage.gameName)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(stage.tint)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if remaining >= 0 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(remaining)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(remaining <= 10 ? Theme.danger : Theme.textSub)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.veil(0.07)))
            }

            Text("L\(level)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(stage.tint))
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }
}

// MARK: - 结算页

struct QuestResultView: View {
    let stage: SchoolStage
    let result: QuestResult
    let star: Bool
    let isBest: Bool
    let onRetry: () -> Void
    let onNext: (() -> Void)?
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                ProgressRing(progress: result.accuracy, lineWidth: 10,
                             tint: star ? Theme.success : stage.tint)
                    .frame(width: 132, height: 132)
                VStack(spacing: 2) {
                    Text("\(Int(result.accuracy * 100))%")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("\(result.correct)/\(result.total) \(unit)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i == 0 && star ? "star.fill" : "star")
                        .font(.system(size: i == 0 && star ? 20 : 14, weight: .semibold))
                        .foregroundStyle(i == 0 && star ? Theme.accent : Theme.textFaint.opacity(0.5))
                }
            }

            VStack(spacing: 5) {
                Text(headline)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(subline)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 34)

            Spacer()

            VStack(spacing: 9) {
                if let onNext {
                    PrimaryButton(title: "下一关", symbol: "arrow.right", tint: stage.tint,
                                  action: onNext)
                }
                HStack(spacing: 9) {
                    GhostButton(title: "再来一次", symbol: "arrow.counterclockwise",
                                action: onRetry)
                    GhostButton(title: "返回", symbol: "chevron.left", action: onExit)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
    }

    private var unit: String {
        switch stage.gameKind {
        case .flipMatch: return "对"
        case .rushQuiz: return "题"
        case .orderSteps: return "步"
        case .encodeLab: return "空"
        }
    }

    private var headline: String {
        if result.accuracy >= 0.95 { return "完美通关" }
        if star { return "拿到一颗星" }
        if result.passed { return "过关了，差一点满星" }
        return "再练一次"
    }

    private var subline: String {
        if !star { return "正确率到 80% 就能拿星，低于 60% 要重来" }
        if isBest { return "刷新了最好成绩 · 用时 \(result.seconds) 秒" }
        return "已经很稳了 · 用时 \(result.seconds) 秒"
    }
}

// MARK: - 小学低年级 · 翻翻配对

struct FlipMatchView: View {
    let stage: SchoolStage
    let node: StageNodeSpec
    let level: Int

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private struct Card: Identifiable {
        let id: Int
        let pairId: Int
        let text: String
        let isEmoji: Bool
        var flipped = false
        var matched = false
    }

    @State private var cards: [Card] = []
    @State private var openIDs: [Int] = []
    @State private var mistakes = 0
    @State private var matched = 0
    @State private var secondsLeft = 60
    @State private var finished = false
    @State private var result: QuestResult?
    @State private var star = false
    @State private var isBest = false
    @State private var lock = false
    @State private var startedAt = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var pairs: [FlipPair] { QuestBank.flipPairs(node: node.index, level: level) }
    private var totalPairs: Int { max(1, pairs.count) }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            if let result {
                QuestResultView(stage: stage, result: result, star: star, isBest: isBest,
                                onRetry: { reset() },
                                onNext: nil,
                                onExit: { dismiss() })
            } else {
                VStack(spacing: 14) {
                    QuestTopBar(stage: stage, title: node.title, level: level,
                                remaining: secondsLeft, onClose: { dismiss() })

                    Text("翻开两张，把词和图配上")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)

                    Spacer(minLength: 6)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)],
                              spacing: 10) {
                        ForEach(cards) { card in
                            cardView(card)
                        }
                    }
                    .padding(.horizontal, 20)

                    HStack(spacing: 14) {
                        statChip("配对", "\(matched)/\(totalPairs)")
                        statChip("翻错", "\(mistakes)")
                    }
                    .padding(.top, 4)
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            build()
            autoFinishIfNeeded()
        }
        .onReceive(timer) { _ in tick() }
    }

    private func statChip(_ title: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glass(radius: 12)
    }

    private func cardView(_ card: Card) -> some View {
        Button {
            flip(card)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(card.matched
                          ? stage.tint.opacity(0.18)
                          : (card.flipped ? Theme.bgLift : Theme.veil(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(card.matched ? stage.tint.opacity(0.55)
                                          : Theme.veil(0.08),
                                          lineWidth: 1)
                    )

                if card.flipped || card.matched {
                    Text(card.text)
                        .font(.system(size: card.isEmoji ? 34 : 17,
                                      weight: card.isEmoji ? .regular : .semibold))
                        .foregroundStyle(Theme.text)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                        .padding(6)
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .frame(height: 96)
            .scaleEffect(card.matched ? 0.96 : 1)
            .opacity(card.matched ? 0.75 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: card.flipped)
        }
        .buttonStyle(.plain)
        .disabled(card.matched || card.flipped || lock)
    }

    // MARK: 逻辑

    private func build() {
        let list = pairs
        var built: [Card] = []
        for (i, p) in list.enumerated() {
            built.append(Card(id: i * 2, pairId: i, text: p.word, isEmoji: false))
            built.append(Card(id: i * 2 + 1, pairId: i, text: p.emoji, isEmoji: true))
        }
        cards = built.shuffled()
        secondsLeft = stage.timeLimit(level: level)
        startedAt = Date()
    }

    private func flip(_ card: Card) {
        guard !lock, let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        guard !cards[idx].flipped, !cards[idx].matched else { return }
        Haptic.tap()
        cards[idx].flipped = true
        openIDs.append(card.id)
        guard openIDs.count == 2 else { return }

        let a = openIDs[0]
        let b = openIDs[1]
        guard let ia = cards.firstIndex(where: { $0.id == a }),
              let ib = cards.firstIndex(where: { $0.id == b }) else { return }

        if cards[ia].pairId == cards[ib].pairId {
            cards[ia].matched = true
            cards[ib].matched = true
            matched += 1
            openIDs = []
            Haptic.success()
            if matched == totalPairs { finish() }
        } else {
            mistakes += 1
            lock = true
            openIDs = []
            Task {
                try? await Task.sleep(nanoseconds: 480_000_000)
                await MainActor.run {
                    if let ja = cards.firstIndex(where: { $0.id == a }) { cards[ja].flipped = false }
                    if let jb = cards.firstIndex(where: { $0.id == b }) { cards[jb].flipped = false }
                    lock = false
                }
            }
        }
    }

    private func tick() {
        guard !finished, secondsLeft > 0 else { return }
        secondsLeft -= 1
        if secondsLeft == 0 { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let acc = max(0, 1 - Double(mistakes) * 0.15)
        let res = QuestResult(stage: stage, nodeIndex: node.index, level: level,
                              correct: matched, total: totalPairs, accuracy: acc,
                              seconds: Int(Date().timeIntervalSince(startedAt)))
        result = res
        let outcome = store.recordQuest(res)
        star = outcome.star
        isBest = outcome.best
    }

    /// 调试：-autoFinish 直接走结算，验证结果页与记星
    private func autoFinishIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-autoFinish") else { return }
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                matched = totalPairs
                finish()
            }
        }
    }

    private func reset() {
        finished = false
        result = nil
        mistakes = 0
        matched = 0
        openIDs = []
        lock = false
        build()
    }
}
