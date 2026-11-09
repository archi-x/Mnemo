import SwiftUI

// MARK: - 判分

enum Judge {
    /// 按目标逐词判定：精确匹配，或用户输入包含目标（允许“一只灯塔”这类描述）
    static func match(_ inputs: [String], targets: [String]) -> [Bool] {
        var used = Array(repeating: false, count: targets.count)
        var result = Array(repeating: false, count: targets.count)

        for raw in inputs {
            let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: " 、,，.。;；:：\n\t"))
            guard !token.isEmpty else { continue }
            if let i = targets.indices.first(where: { !used[$0] && targets[$0] == token }) {
                used[i] = true
                result[i] = true
            } else if let i = targets.indices.first(where: {
                !used[$0] && (token.contains(targets[$0]) || targets[$0].contains(token))
            }) {
                used[i] = true
                result[i] = true
            }
        }
        return result
    }

    static func split(_ text: String) -> [String] {
        text.split(whereSeparator: { " 、,，.。;；:：\n\t".contains($0) }).map(String.init)
    }
}

// MARK: - 词表闪记

struct WordFlashView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case ready, countdown, memorize, recall, result
    }

    @State private var phase: Phase = .ready
    @State private var countdown = 3
    @State private var words: [String] = []
    @State private var index = 0
    @State private var input = ""
    @State private var matched: [Bool] = []
    @State private var startedAt = Date()
    @State private var timerTask: Task<Void, Never>?
    @State private var recallTask: Task<Void, Never>?
    @FocusState private var focused: Bool
    @State private var count = 10

    // 回忆倒计时（随词数伸缩）
    @State private var recallLeft = 0
    @State private var timedOut = false
    @State private var usedSeconds = 0
    @State private var wordDrain: Double = 1

    private var correct: Int { matched.filter { $0 }.count }
    private var score: Double { words.isEmpty ? 0 : Double(correct) / Double(words.count) }

    /// 回忆限时：每词 4 秒 + 8 秒缓冲
    private var recallLimit: Int { count * 4 + 8 }
    private var recallRatio: Double {
        recallLimit <= 0 ? 0 : max(0, min(1, Double(recallLeft) / Double(recallLimit)))
    }
    private var recallTint: Color {
        recallLeft <= 10 ? Theme.danger : (recallRatio <= 0.34 ? Theme.warn : Theme.accent)
    }
    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    var body: some View {
        ZStack {
            Theme.canvas
            VStack(spacing: 0) {
                topBar
                switch phase {
                case .ready: readyView
                case .countdown: countdownView
                case .memorize: memorizeView
                case .recall: recallView
                case .result: resultView
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
            recallTask?.cancel()
        }
    }

    // MARK: 顶栏

    private var topBar: some View {
        HStack {
            Button {
                Haptic.tap()
                timerTask?.cancel()
                recallTask?.cancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSub)
                    .frame(width: 34, height: 34)
                    .glass(radius: 12)
            }
            Spacer()
            Text("词表闪记")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Rectangle().fill(.clear).frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: 准备

    private var readyView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("记一组词，\n再凭记忆写回来")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(4)
                Text("先用故事链或记忆宫殿把词串起来，每个词只闪现 1.4–1.9 秒。合上材料后立刻回忆，倒计时到点自动交卷。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textSub)
                    .lineSpacing(3)
            }
            .padding(.top, 26)

            VStack(alignment: .leading, spacing: 10) {
                Text("难度")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textFaint)
                HStack(spacing: 10) {
                    levelChip("初 · 5 词", value: 5)
                    levelChip("中 · 10 词", value: 10)
                    levelChip("高 · 15 词", value: 15)
                }
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .semibold))
                    Text("回忆限时 \(recallLimit) 秒 · 每词 4 秒 + 8 秒缓冲")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 2)
            }

            Spacer()
            PrimaryButton(title: "开始记忆", symbol: "play.fill") { start() }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    private func levelChip(_ label: String, value: Int) -> some View {
        let selected = count == value
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { count = value }
        } label: {
            VStack(spacing: 2) {
                Text(label.replacingOccurrences(of: " · ", with: "\n"))
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selected ? Theme.onAccent : Theme.textSub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Theme.accent : Theme.veil(0.06))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: 倒数

    private var countdownView: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("\(countdown)")
                .font(.system(size: 108, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .id(countdown)
                .transition(.scale(scale: 1.4).combined(with: .opacity))
            Text("把注意力收回来")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSub)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: countdown)
    }

    // MARK: 记忆

    private var memorizeView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(words.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? Theme.accent : Theme.veil(0.12))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            Spacer()
            VStack(spacing: 16) {
                Text(words.indices.contains(index) ? words[index] : "")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .id(index)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.86).combined(with: .opacity),
                        removal: .opacity))
                    .animation(.spring(response: 0.34, dampingFraction: 0.8), value: index)
                Text("\(index + 1) / \(words.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)

                // 单词语速条：显示这个词还剩多少时间
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.veil(0.10)).frame(width: 132, height: 3)
                    Capsule().fill(Theme.accent.opacity(0.85))
                        .frame(width: max(1, 132 * wordDrain), height: 3)
                }
            }
            Spacer()

            VStack(spacing: 12) {
                Text("每个词 \(String(format: "%.1f", perWordSeconds)) 秒 · 给它加动作、颜色，或挂到熟悉的位置上")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
                Button {
                    Haptic.tap(.medium)
                    beginRecall()
                } label: {
                    Text("提前开始回忆")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.textSub)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .glass(radius: 14)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.bottom, 30)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
    }

    // MARK: 回忆

    private var recallView: some View {
        VStack(alignment: .leading, spacing: 16) {
            recallTimer
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 6) {
                Text("写回刚才的 \(words.count) 个词")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("顺序不重要，用顿号或空格分隔。想不起来的时候先猜一个，时间到会自动交卷。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
            }

            TextField("", text: $input, prompt: Text("例如：灯塔、齿轮、雨伞").foregroundStyle(Theme.textFaint),
                      axis: .vertical)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(4...7)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .padding(16)
                .glass(radius: 18)

            HStack(spacing: 6) {
                Text("已写 \(Judge.split(input).count) 个")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
                Spacer()
            }

            Spacer()
            PrimaryButton(title: "提交判分", symbol: "checkmark") { submit() }
                .opacity(Judge.split(input).isEmpty ? 0.5 : 1)
                .disabled(Judge.split(input).isEmpty)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .onAppear { focused = true }
    }

    /// 回忆倒计时条：数字 + 进度，剩余 10 秒内转红
    private var recallTimer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: recallLeft <= 10 ? "timer" : "hourglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(recallTint)
                Text(clock(recallLeft))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(recallTint)
                    .contentTransition(.numericText())
                Spacer()
                Text("限时 \(recallLimit) 秒")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.veil(0.10))
                    Capsule()
                        .fill(recallTint)
                        .frame(width: max(2, geo.size.width * recallRatio))
                        .animation(.linear(duration: 0.9), value: recallRatio)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glass(radius: 16)
        .animation(.easeInOut(duration: 0.3), value: recallTint)
    }

    // MARK: 结果

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    ZStack {
                        ProgressRing(progress: score,
                                     lineWidth: 11,
                                     tint: score >= 0.8 ? Theme.success : (score >= 0.5 ? Theme.warn : Theme.danger))
                            .frame(width: 118, height: 118)
                        VStack(spacing: 0) {
                            Text("\(correct)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.text)
                            Text("/ \(words.count)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    Text(headline)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(subhead)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        TagChip(text: "用时 \(usedSeconds) 秒", tint: Theme.textSub)
                        if timedOut {
                            TagChip(text: "时间到自动交卷", tint: Theme.danger, filled: true)
                        } else {
                            TagChip(text: "限时 \(recallLimit) 秒", tint: Theme.textFaint)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                        HStack(spacing: 10) {
                            Image(systemName: matched.indices.contains(i) && matched[i]
                                  ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.system(size: 15))
                                .foregroundStyle(matched.indices.contains(i) && matched[i]
                                                 ? Theme.success : Theme.danger.opacity(0.75))
                            Text(w)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(matched.indices.contains(i) && matched[i]
                                                 ? Theme.text : Theme.textSub)
                            Spacer()
                            if !(matched.indices.contains(i) && matched[i]) {
                                Text("漏掉")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.danger.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Theme.veil(0.04))
                        )
                    }
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "再来一组", symbol: "arrow.clockwise") {
                        withAnimation { reset() }
                        start()
                    }
                    GhostButton(title: "完成并存入复习队列", symbol: "tray.and.arrow.down") {
                        finish()
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    private var headline: String {
        if timedOut && score < 0.5 { return "时间到，检索速度还没跟上" }
        switch score {
        case 0.99...: return "全对，编码已经很稳"
        case 0.8..<0.99: return "记忆牢固"
        case 0.5..<0.8: return "记住了大部分"
        default: return "这组偏难，值得重来"
        }
    }

    private var subhead: String {
        if timedOut {
            return "时间到了还没写够，说明检索速度跟不上：先练少一点的词，把词串成一条固定路线"
        }
        switch score {
        case 0.99...: return "在限时内全部取出，试着换更长的词表，或者练倒序提取"
        case 0.8..<0.99: return "漏掉的词明天会再出现一次，间隔重复会补上"
        case 0.5..<0.8: return "把没记住的词编进一个夸张故事，再练一遍"
        default: return "先用 5 个词建立信心：位置固定、图像具体"
        }
    }

    // MARK: 流程

    private func start() {
        words = store.randomWords(count)
        matched = []
        input = ""
        index = 0
        countdown = 3
        timedOut = false
        usedSeconds = 0
        recallLeft = recallLimit
        startedAt = Date()
        timerTask?.cancel()
        recallTask?.cancel()
        withAnimation { phase = .countdown }
        timerTask = Task { await runCountdown() }
    }

    private func reset() {
        phase = .ready
        words = []
        matched = []
        input = ""
        timedOut = false
        usedSeconds = 0
        recallLeft = recallLimit
        timerTask?.cancel()
        recallTask?.cancel()
    }

    @MainActor
    private func runCountdown() async {
        for n in stride(from: 3, through: 1, by: -1) {
            guard !Task.isCancelled else { return }
            countdown = n
            Haptic.tap()
            try? await Task.sleep(nanoseconds: 620_000_000)
        }
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .memorize }
        index = 0
        await runMemorize()
    }

    @MainActor
    private func runMemorize() async {
        while index < count {
            wordDrain = 1
            withAnimation(.linear(duration: perWordSeconds)) { wordDrain = 0 }
            try? await Task.sleep(nanoseconds: UInt64(perWordSeconds * 1_000_000_000))
            guard !Task.isCancelled, phase == .memorize else { return }
            advance()
        }
    }

    /// 单个词的停留时长：词越少给得越宽裕
    private var perWordSeconds: Double {
        count <= 5 ? 1.9 : (count <= 10 ? 1.6 : 1.4)
    }

    private func advance() {
        timerTask?.cancel()
        Haptic.select()
        if index + 1 < words.count {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { index += 1 }
            wordDrain = 1
        } else {
            beginRecall()
        }
    }

    private func beginRecall() {
        timerTask?.cancel()
        recallTask?.cancel()
        recallLeft = recallLimit
        timedOut = false
        withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { phase = .recall }
        focused = true
        recallTask = Task { await runRecallCountdown() }
    }

    @MainActor
    private func runRecallCountdown() async {
        let limit = recallLimit
        var left = limit
        while left > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, phase == .recall else { return }
            left -= 1
            recallLeft = left
            if left == 10 { Haptic.tap(.medium) }
        }
        guard !Task.isCancelled, phase == .recall else { return }
        timedOut = true
        Haptic.failure()
        submit()
    }

    private func submit() {
        recallTask?.cancel()
        usedSeconds = max(0, recallLimit - recallLeft)
        matched = Judge.match(Judge.split(input), targets: words)
        focused = false
        if correct == words.count { Haptic.success() } else { Haptic.tap(.medium) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .result }
    }

    private func finish() {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let hints = words.compactMap { $0.first }.map(String.init).joined(separator: " · ")
        let card = ReviewCard(front: "回忆这组 \(words.count) 个词\n首字提示：\(hints)",
                              back: words.joined(separator: "、"),
                              kind: .word,
                              due: Date().addingTimeInterval(60 * 60))
        let quality = score >= 0.95 ? 5 : (score >= 0.8 ? 4 : (score >= 0.6 ? 3 : 1))
        var graded = card
        graded.grade(quality)
        store.finish(kind: .word, correct: correct, total: words.count,
                     seconds: elapsed, cards: [graded])
        Haptic.success()
        dismiss()
    }
}
