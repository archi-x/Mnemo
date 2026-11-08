import SwiftUI

/// 通用答题引擎：方法练习与错题强化共用
struct QuizRunnerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let title: String
    let methodId: Int?
    let level: Int
    let mode: QuizMode
    let exercises: [Exercise]
    var onRestart: (() -> Void)? = nil

    private enum Phase { case asking, feedback, result }

    @State private var phase: Phase = .asking
    @State private var index = 0
    @State private var selected: Int?
    @State private var openText = ""
    @State private var selfPassed: Bool?
    @State private var correctCount = 0
    @State private var wrong: [Exercise] = []
    @State private var mine: [String: String] = [:]
    @State private var startedAt = Date()
    @State private var committed = false
    @FocusState private var focused: Bool

    private var current: Exercise? {
        exercises.indices.contains(index) ? exercises[index] : nil
    }

    private var score: Double {
        exercises.isEmpty ? 0 : Double(correctCount) / Double(exercises.count)
    }

    var body: some View {
        ZStack {
            Theme.canvas
            VStack(spacing: 0) {
                topBar
                switch phase {
                case .asking, .feedback:
                    if let ex = current { questionView(ex) }
                case .result:
                    resultView
                }
            }
        }
    }

    // MARK: 顶栏

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    Haptic.tap()
                    finish()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSub)
                        .frame(width: 34, height: 34)
                        .glass(radius: 12)
                }
                Spacer()
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(min(index + 1, exercises.count))/\(exercises.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 34)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Theme.accent)
                        .frame(width: geo.size.width *
                               (phase == .result ? 1 : Double(index) / Double(max(1, exercises.count))))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: 题目

    private func questionView(_ ex: Exercise) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 7) {
                    TagChip(text: ex.kind.title, tint: Theme.accent)
                    TagChip(text: "L\(ex.level)", tint: Theme.tint("space"))
                    if let m = store.method(ex.methodId) {
                        Text(m.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                    Spacer()
                }

                Text(ex.prompt)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                if ex.isChoice {
                    choiceList(ex)
                } else {
                    openAnswer(ex)
                }

                if phase == .feedback {
                    feedbackCard(ex)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            if phase == .feedback {
                PrimaryButton(title: index + 1 < exercises.count ? "下一题" : "看结果",
                              symbol: "arrow.right") { advance() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private func choiceList(_ ex: Exercise) -> some View {
        VStack(spacing: 9) {
            ForEach(ex.options.indices, id: \.self) { i in
                let isAnswer = i == ex.answerIndex
                let isPicked = selected == i
                let revealed = phase == .feedback
                Button {
                    guard phase == .asking else { return }
                    pick(i, in: ex)
                } label: {
                    HStack(alignment: .top, spacing: 11) {
                        Text(letter(i))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(labelColor(isAnswer: isAnswer, isPicked: isPicked, revealed: revealed))
                            .frame(width: 22, height: 22)
                            .background(
                                Circle().fill(strokeColor(isAnswer: isAnswer, isPicked: isPicked, revealed: revealed)
                                              .opacity(0.16))
                            )
                        Text(ex.options[i])
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if revealed && isAnswer {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.success)
                        } else if revealed && isPicked {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.danger)
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(strokeColor(isAnswer: isAnswer, isPicked: isPicked, revealed: revealed).opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(strokeColor(isAnswer: isAnswer, isPicked: isPicked, revealed: revealed),
                                                  lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func labelColor(isAnswer: Bool, isPicked: Bool, revealed: Bool) -> Color {
        if !revealed { return isPicked ? Theme.accent : Theme.textSub }
        if isAnswer { return Theme.success }
        if isPicked { return Theme.danger }
        return Theme.textFaint
    }

    private func strokeColor(isAnswer: Bool, isPicked: Bool, revealed: Bool) -> Color {
        if !revealed { return isPicked ? Theme.accent : Theme.stroke }
        if isAnswer { return Theme.success }
        if isPicked { return Theme.danger }
        return Theme.stroke
    }

    private func letter(_ i: Int) -> String {
        ["A", "B", "C", "D", "E"][min(i, 4)]
    }

    private func openAnswer(_ ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if phase == .asking {
                TextField("", text: $openText,
                          prompt: Text("写下你编码出的画面 / 位置 / 口诀，或者默写的内容").foregroundStyle(Theme.textFaint),
                          axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.text)
                    .lineLimit(5...9)
                    .focused($focused)
                    .padding(15)
                    .glass(radius: 16)

                Text(ex.selfCheckHint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
                    .lineSpacing(2)

                HStack(spacing: 10) {
                    Button {
                        selfAssess(passed: false, in: ex)
                    } label: {
                        Text("卡住了")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.danger.opacity(0.12))
                            )
                    }
                    Button {
                        selfAssess(passed: true, in: ex)
                    } label: {
                        Text("默写出来了")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.success)
                            )
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("你写的")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                    Text(openText.isEmpty ? "（没有写）" : openText)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textSub)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glass(radius: 16)
            }
        }
    }

    private func feedbackCard(_ ex: Exercise) -> some View {
        let ok = selfPassed ?? (selected == ex.answerIndex)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 14))
                Text(ok ? "答对了" : "这题记进错题本")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(ok ? Theme.success : Theme.danger)

            Text(ex.explain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !ok {
                Text("正确：\(ex.correctAnswer)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill((ok ? Theme.success : Theme.danger).opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder((ok ? Theme.success : Theme.danger).opacity(0.22), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: 结果

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    ZStack {
                        ProgressRing(progress: score, lineWidth: 11,
                                     tint: score >= 0.8 ? Theme.success : (score >= 0.5 ? Theme.warn : Theme.danger))
                            .frame(width: 116, height: 116)
                        VStack(spacing: 0) {
                            Text("\(correctCount)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.text)
                            Text("/ \(exercises.count)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    Text(resultTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(resultSub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 22)

                if !wrong.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("错题")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(wrong.count) 题已加入错题本")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.danger.opacity(0.9))
                        }
                        ForEach(wrong) { ex in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(ex.prompt)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.textSub)
                                    .lineLimit(3)
                                Text("正解：\(ex.correctAnswer)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(3)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                        }
                    }
                }

                VStack(spacing: 10) {
                    if let onRestart {
                        PrimaryButton(title: "再来一组", symbol: "arrow.clockwise") {
                            onRestart()
                            reset()
                        }
                    }
                    GhostButton(title: "完成", symbol: "checkmark") { dismiss() }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    private var resultTitle: String {
        switch score {
        case 0.99...: return "全对，这一阶过了"
        case 0.8..<0.99: return "基本掌握"
        case 0.5..<0.8: return "有印象，但还不稳"
        default: return "先回看方法，再练一次"
        }
    }

    private var resultSub: String {
        switch score {
        case 0.99...: return "可以挑战下一阶，或者去错题本清一遍旧账"
        case 0.8..<0.99: return "错的题 20 分钟后会作为复习卡回来"
        default: return "错题已进错题本，强化两轮就能记住"
        }
    }

    // MARK: 流程

    private func pick(_ i: Int, in ex: Exercise) {
        selected = i
        let ok = i == ex.answerIndex
        if ok {
            correctCount += 1
            Haptic.success()
        } else {
            wrong.append(ex)
            mine[ex.id] = ex.options[i]
            Haptic.failure()
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { phase = .feedback }
    }

    private func selfAssess(passed: Bool, in ex: Exercise) {
        selfPassed = passed
        if passed {
            correctCount += 1
            Haptic.success()
        } else {
            wrong.append(ex)
            mine[ex.id] = openText.isEmpty ? "（卡住了）" : openText
            Haptic.failure()
        }
        focused = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { phase = .feedback }
    }

    private func advance() {
        if index + 1 < exercises.count {
            index += 1
            selected = nil
            selfPassed = nil
            openText = ""
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { phase = .asking }
        } else {
            commit()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .result }
        }
    }

    private func commit() {
        guard !committed else { return }
        committed = true
        let outcome = QuizOutcome(correct: correctCount, total: exercises.count,
                                  seconds: Int(Date().timeIntervalSince(startedAt)),
                                  wrong: wrong, mine: mine)
        store.recordQuiz(outcome: outcome, methodId: methodId, level: level, mode: mode)
        if mode == .reinforcement {
            for ex in exercises {
                guard let item = store.wrongItems.first(where: { $0.id == ex.key }) else { continue }
                store.resolveWrong(item, correct: !wrong.contains { $0.key == ex.key })
            }
        }
    }

    private func finish() {
        if phase != .result { commit() }
        dismiss()
    }

    private func reset() {
        index = 0
        selected = nil
        selfPassed = nil
        openText = ""
        correctCount = 0
        wrong = []
        mine = [:]
        startedAt = Date()
        committed = false
        phase = .asking
    }
}
