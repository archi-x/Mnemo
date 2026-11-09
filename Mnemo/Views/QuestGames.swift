import SwiftUI

// MARK: - 选项按钮（三套玩法共用）

enum QuestOptionState {
    case normal
    case correct
    case wrong
    case dimmed

    var border: Color {
        switch self {
        case .normal: return Theme.veil(0.08)
        case .correct: return Theme.success
        case .wrong: return Theme.danger
        case .dimmed: return Theme.veil(0.04)
        }
    }

    var fill: Color {
        switch self {
        case .normal: return Theme.veil(0.06)
        case .correct: return Theme.success.opacity(0.16)
        case .wrong: return Theme.danger.opacity(0.16)
        case .dimmed: return Theme.veil(0.02)
        }
    }
}

struct QuestOptionButton: View {
    let text: String
    var mark: String? = nil
    var state: QuestOptionState = .normal
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                if let mark {
                    Text(mark)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: 18)
                }
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(state == .dimmed ? Theme.textFaint : Theme.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.success)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(state.fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(state.border, lineWidth: state == .normal ? 0.8 : 1.2)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(state != .normal)
    }
}

// MARK: - 进度条

struct QuestProgressBar: View {
    let done: Int
    let total: Int
    var tint: Color = Theme.accent

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.veil(0.08))
                    Capsule().fill(tint)
                        .frame(width: max(3, geo.size.width * min(1, Double(done) / Double(max(1, total)))))
                }
            }
            .frame(height: 4)
            Text("\(min(done, total)) / \(total)")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textFaint)
        }
    }
}

// MARK: - 小学高年级 · 排排队

struct OrderStepsView: View {
    let stage: SchoolStage
    let node: StageNodeSpec
    let level: Int

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var round: OrderRound?
    @State private var pool: [String] = []
    @State private var placed: [String] = []
    @State private var mistakes = 0
    @State private var secondsLeft = 75
    @State private var finished = false
    @State private var result: QuestResult?
    @State private var star = false
    @State private var isBest = false
    @State private var shake: String?
    @State private var startedAt = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            if let result {
                QuestResultView(stage: stage, result: result, star: star, isBest: isBest,
                                onRetry: { reset() }, onNext: nil, onExit: { dismiss() })
            } else if let round {
                VStack(spacing: 12) {
                    QuestTopBar(stage: stage, title: node.title, level: level,
                                remaining: secondsLeft, onClose: { dismiss() })

                    VStack(spacing: 6) {
                        Text("按顺序点出步骤")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textSub)
                        Text("\(round.methodName) · 共 \(round.steps.count) 步")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.top, 2)

                    // 已排好的序列
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(placed.enumerated()), id: \.offset) { i, step in
                            HStack(spacing: 9) {
                                Text("\(i + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.onAccent)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(stage.tint))
                                Text(step)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glass(radius: 12)
                        }

                        // 还没排到的位置：画出空槽，说明一共有几步
                        if placed.count < round.steps.count {
                            ForEach(placed.count..<round.steps.count, id: \.self) { i in
                                HStack(spacing: 9) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.textFaint)
                                        .frame(width: 20, height: 20)
                                        .background(
                                            Circle().strokeBorder(Theme.veil(0.16), lineWidth: 1)
                                        )
                                    Text(i == placed.count ? "下一步…" : "待填")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.textFaint)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Theme.veil(0.07),
                                                      style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if placed.isEmpty {
                        Text("点错不算失败，只会计入正确率")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textFaint)
                            .padding(.top, 2)
                    }

                    Spacer(minLength: 6)

                    // 候选
                    VStack(spacing: 9) {
                        ForEach(pool, id: \.self) { step in
                            QuestOptionButton(text: step, state: placed.contains(step) ? .dimmed : .normal) {
                                tap(step)
                            }
                            .offset(x: shake == step ? 6 : 0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.4), value: shake)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .padding(.top, 4)
            }
        }
        .onAppear { build() }
        .onReceive(timer) { _ in tick() }
    }

    private func build() {
        guard let r = QuestBank.orderRound(node: node.index, level: level,
                                          methods: store.catalog.methods) else {
            dismiss()
            return
        }
        round = r
        pool = r.steps.shuffled()
        placed = []
        mistakes = 0
        secondsLeft = stage.timeLimit(level: level)
        startedAt = Date()
        finished = false
        result = nil
    }

    private func tap(_ step: String) {
        guard let round, !placed.contains(step) else { return }
        if step == round.steps[placed.count] {
            Haptic.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                placed.append(step)
            }
            if placed.count == round.steps.count { finish() }
        } else {
            Haptic.failure()
            mistakes += 1
            shake = step
            Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                await MainActor.run { shake = nil }
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
        let acc = max(0, 1 - Double(mistakes) * 0.2)
        let total = round?.steps.count ?? 3
        let res = QuestResult(stage: stage, nodeIndex: node.index, level: level,
                              correct: placed.count, total: total, accuracy: acc,
                              seconds: Int(Date().timeIntervalSince(startedAt)))
        result = res
        let outcome = store.recordQuest(res)
        star = outcome.star
        isBest = outcome.best
    }

    private func reset() {
        build()
    }
}

// MARK: - 初中 · 限时抢答

struct RushQuizView: View {
    let stage: SchoolStage
    let node: StageNodeSpec
    let level: Int

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var questions: [RushQuestion] = []
    @State private var index = 0
    @State private var correct = 0
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var picked: Int?
    @State private var secondsLeft = 60
    @State private var finished = false
    @State private var result: QuestResult?
    @State private var star = false
    @State private var isBest = false
    @State private var startedAt = Date()
    @State private var flash: Color?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: RushQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            if let result {
                QuestResultView(stage: stage, result: result, star: star, isBest: isBest,
                                onRetry: { build() }, onNext: nil, onExit: { dismiss() })
            } else {
                VStack(spacing: 12) {
                    QuestTopBar(stage: stage, title: node.title, level: level,
                                remaining: secondsLeft, onClose: { dismiss() })

                    HStack(spacing: 8) {
                        QuestProgressBar(done: index, total: questions.count, tint: stage.tint)
                        if combo >= 2 {
                            Text("连击 ×\(combo)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.accent.opacity(0.15)))
                        }
                        Text("✓ \(correct)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.success)
                    }
                    .padding(.horizontal, 20)

                    if let q = current {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(q.tag)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(stage.tint)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(stage.tint.opacity(0.15)))
                                Text("第 \(index + 1) 题")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.textFaint)
                                Spacer()
                            }
                            Text(q.prompt)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glass(radius: 18)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(flash ?? .clear, lineWidth: 2)
                                .padding(.horizontal, 20)
                        )

                        VStack(spacing: 8) {
                            ForEach(Array(q.options.enumerated()), id: \.offset) { i, opt in
                                QuestOptionButton(text: opt, mark: letter(i),
                                                  state: optionState(i, q: q)) {
                                    choose(i, q: q)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
        }
        .onAppear { build() }
        .onReceive(timer) { _ in tick() }
    }

    private func letter(_ i: Int) -> String {
        ["A", "B", "C", "D"][safe: i] ?? "•"
    }

    private func optionState(_ i: Int, q: RushQuestion) -> QuestOptionState {
        guard let picked else { return .normal }
        if i == q.answerIndex { return .correct }
        if i == picked { return .wrong }
        return .dimmed
    }

    private func build() {
        let count = stage.questionCount(level: level)
        questions = QuestBank.rushQuestions(node: node.index, level: level, count: count,
                                           methods: store.catalog.methods)
        index = 0
        correct = 0
        combo = 0
        bestCombo = 0
        picked = nil
        secondsLeft = stage.timeLimit(level: level)
        finished = false
        result = nil
        startedAt = Date()
    }

    private func choose(_ i: Int, q: RushQuestion) {
        guard picked == nil, !finished else { return }
        picked = i
        if i == q.answerIndex {
            correct += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
            Haptic.success()
            flash = Theme.success.opacity(0.5)
        } else {
            combo = 0
            Haptic.failure()
            flash = Theme.danger.opacity(0.5)
        }
        Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            await MainActor.run {
                flash = nil
                picked = nil
                if index + 1 >= questions.count {
                    finish()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { index += 1 }
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
        let total = max(1, questions.count)
        let res = QuestResult(stage: stage, nodeIndex: node.index, level: level,
                              correct: correct, total: total,
                              accuracy: Double(correct) / Double(total),
                              seconds: Int(Date().timeIntervalSince(startedAt)))
        result = res
        let outcome = store.recordQuest(res)
        star = outcome.star
        isBest = outcome.best
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}

// MARK: - 高中 · 编码工坊

struct EncodeLabView: View {
    let stage: SchoolStage
    let node: StageNodeSpec
    let level: Int

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private enum Step { case method, path, check }

    @State private var rounds: [LabRound] = []
    @State private var roundIndex = 0
    @State private var step: Step = .method
    @State private var methodPicked: Int?
    @State private var pathPicked: Int?
    @State private var hits = 0
    @State private var finished = false
    @State private var result: QuestResult?
    @State private var star = false
    @State private var isBest = false
    @State private var startedAt = Date()
    @State private var showHint = false

    private var current: LabRound? {
        rounds.indices.contains(roundIndex) ? rounds[roundIndex] : nil
    }

    private var totalChoices: Int { rounds.count * 2 }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            if let result {
                QuestResultView(stage: stage, result: result, star: star, isBest: isBest,
                                onRetry: { build() }, onNext: nil, onExit: { dismiss() })
            } else if let r = current {
                ScrollView {
                    VStack(spacing: 12) {
                        QuestTopBar(stage: stage, title: node.title, level: level,
                                    remaining: -1, onClose: { dismiss() })

                        QuestProgressBar(done: roundIndex, total: max(1, rounds.count),
                                         tint: stage.tint)
                            .padding(.horizontal, 20)

                        // 材料卡
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(r.subject)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(stage.tint)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(stage.tint.opacity(0.15)))
                                Text("材料 \(roundIndex + 1)/\(rounds.count)")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.textFaint)
                                Spacer()
                                Button {
                                    Haptic.tap()
                                    withAnimation { showHint.toggle() }
                                } label: {
                                    Image(systemName: showHint ? "lightbulb.fill" : "lightbulb")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            Text(r.material)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .lineSpacing(4)
                            if showHint {
                                Text(r.hint)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSub)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glass(radius: 18)
                        .padding(.horizontal, 20)

                        // 第一步：选方法
                        if step == .method {
                            questionBlock(title: "第一步 · 用什么法？",
                                          options: r.methodOptions,
                                          answer: r.methodAnswer,
                                          picked: methodPicked) { i in
                                methodPicked = i
                                if i == r.methodAnswer { hits += 1 }
                                Haptic.tap()
                                Task {
                                    try? await Task.sleep(nanoseconds: 380_000_000)
                                    await MainActor.run {
                                        withAnimation(.easeInOut(duration: 0.2)) { step = .path }
                                    }
                                }
                            }
                        }

                        // 第二步：选路径
                        if step == .path || step == .check {
                            questionBlock(title: "第二步 · 走哪条路？",
                                          options: r.pathOptions,
                                          answer: r.pathAnswer,
                                          picked: pathPicked) { i in
                                pathPicked = i
                                if i == r.pathAnswer { hits += 1 }
                                Haptic.tap()
                                Task {
                                    try? await Task.sleep(nanoseconds: 380_000_000)
                                    await MainActor.run {
                                        withAnimation(.easeInOut(duration: 0.2)) { step = .check }
                                    }
                                }
                            }
                        }

                        if step == .check {
                            selfCheck(r)
                        }

                        Spacer(minLength: 10)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear { build() }
    }

    private func questionBlock(title: String, options: [String], answer: Int,
                               picked: Int?, onPick: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.textSub)
            ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                QuestOptionButton(text: opt, state: state(i, answer: answer, picked: picked)) {
                    onPick(i)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func state(_ i: Int, answer: Int, picked: Int?) -> QuestOptionState {
        guard let picked else { return .normal }
        if i == answer { return .correct }
        if i == picked { return .wrong }
        return .dimmed
    }

    private func selfCheck(_ r: LabRound) -> some View {
        VStack(spacing: 9) {
            Text("合上材料，能说出编码顺序吗？")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSub)
            HStack(spacing: 9) {
                Button {
                    Haptic.tap(.medium)
                    advance()
                } label: {
                    Text("记住了")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(stage.tint))
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    Haptic.tap()
                    Haptic.failure()
                    advance()
                } label: {
                    Text("还不熟")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glass(radius: 13)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func build() {
        rounds = QuestBank.labRounds(node: node.index, level: level,
                                     methods: store.catalog.methods)
        roundIndex = 0
        step = .method
        methodPicked = nil
        pathPicked = nil
        hits = 0
        finished = false
        result = nil
        showHint = false
        startedAt = Date()
    }

    private func advance() {
        if roundIndex + 1 >= rounds.count {
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            roundIndex += 1
            step = .method
            methodPicked = nil
            pathPicked = nil
            showHint = false
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let total = max(1, totalChoices)
        let res = QuestResult(stage: stage, nodeIndex: node.index, level: level,
                              correct: hits, total: total,
                              accuracy: Double(hits) / Double(total),
                              seconds: Int(Date().timeIntervalSince(startedAt)))
        result = res
        let outcome = store.recordQuest(res)
        star = outcome.star
        isBest = outcome.best
    }
}
