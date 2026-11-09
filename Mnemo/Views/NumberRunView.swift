import SwiftUI

struct NumberRunView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case ready, show, recall, result }

    @State private var phase: Phase = .ready
    @State private var length = 10
    @State private var digits = ""
    @State private var input = ""
    @State private var remaining = 0
    @State private var matched: [Bool] = []
    @State private var startedAt = Date()
    @State private var task: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var correct: Int { matched.filter { $0 }.count }
    private var score: Double { digits.isEmpty ? 0 : Double(correct) / Double(digits.count) }

    var body: some View {
        ZStack {
            Theme.canvas
            VStack(spacing: 0) {
                topBar
                Group {
                    switch phase {
                    case .ready: ready
                    case .show: showing
                    case .recall: recalling
                    case .result: result
                    }
                }
            }
        }
        .onDisappear { task?.cancel() }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptic.tap()
                task?.cancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSub)
                    .frame(width: 34, height: 34)
                    .glass(radius: 12)
            }
            Spacer()
            Text("数字桩")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Rectangle().fill(.clear).frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: 准备

    private var ready: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("看一组数字，\n按序写回来")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(4)
                Text("数字分两三位一组出现。把它们变成熟悉的形象：12 是婴儿，08 是眼镜。组块越多，一次能装的位数越多。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textSub)
                    .lineSpacing(3)
            }
            .padding(.top, 26)

            HStack(spacing: 10) {
                chip("10 位", 10)
                chip("14 位", 14)
                chip("20 位", 20)
            }

            Spacer()
            PrimaryButton(title: "开始", symbol: "play.fill") { start() }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    private func chip(_ label: String, _ value: Int) -> some View {
        let on = length == value
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { length = value }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Theme.onAccent : Theme.textSub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(on ? Theme.tint("seq") : Theme.veil(0.06))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: 记忆

    private var showing: some View {
        let total = length <= 10 ? 9 : (length <= 14 ? 12 : 16)
        return VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i < remaining ? Theme.tint("seq") : Theme.veil(0.12))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            Spacer()
            VStack(spacing: 22) {
                Text(grouped(digits))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("\(remaining) 秒")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()

            Button {
                task?.cancel()
                Haptic.tap(.medium)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { phase = .recall }
                focused = true
            } label: {
                Text("提前遮住")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.textSub)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .glass(radius: 14)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, 30)
        }
        .onAppear { remaining = total }
    }

    // MARK: 回忆

    private var recalling: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("依次输入 \(digits.count) 位数字")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("凭刚才的形象顺序写，位置对就算对。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
            }
            .padding(.top, 26)

            TextField("", text: $input, prompt: Text("在这里输入").foregroundStyle(Theme.textFaint))
                .keyboardType(.numberPad)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .padding(18)
                .glass(radius: 18)
                .focused($focused)
                .onChange(of: input) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered.count > digits.count { input = String(filtered.prefix(digits.count)) }
                    else if filtered != newValue { input = filtered }
                }

            HStack(spacing: 4) {
                ForEach(0..<digits.count, id: \.self) { i in
                    Capsule()
                        .fill(i < input.count ? Theme.tint("seq") : Theme.veil(0.1))
                        .frame(height: 4)
                }
            }

            Spacer()
            PrimaryButton(title: "提交", symbol: "checkmark") { submit() }
                .opacity(input.isEmpty ? 0.5 : 1)
                .disabled(input.isEmpty)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .onAppear { focused = true }
    }

    // MARK: 结果

    private var result: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    ZStack {
                        ProgressRing(progress: score, lineWidth: 11,
                                     tint: score >= 0.8 ? Theme.success : (score >= 0.5 ? Theme.warn : Theme.danger))
                            .frame(width: 110, height: 110)
                        Text("\(Int(score * 100))%")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                    }
                    Text("\(correct) / \(digits.count) 位正确")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(score >= 0.9 ? "组块很稳，可以挑战 20 位" : "对照下面的错位，检查是哪一段断了链")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("逐位对照")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 8) {
                        ForEach(Array(digits.enumerated()), id: \.offset) { i, ch in
                            VStack(spacing: 3) {
                                Text(String(ch))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.text)
                                Text(i < input.count ? String(Array(input)[i]) : "·")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(matched.indices.contains(i) && matched[i]
                                                     ? Theme.success : Theme.danger)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Theme.veil(0.04))
                            )
                        }
                    }
                }
                .padding(16)
                .glass(radius: 18)

                VStack(spacing: 10) {
                    PrimaryButton(title: "再来一次", symbol: "arrow.clockwise", tint: Theme.tint("seq")) {
                        start()
                    }
                    GhostButton(title: "完成并存入复习队列", symbol: "tray.and.arrow.down") { finish() }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 流程

    private func grouped(_ s: String) -> String {
        var out: [String] = []
        var i = 0
        let chars = Array(s)
        while i < chars.count {
            let size = (i / 3) % 2 == 0 ? 3 : 2
            let end = min(i + size, chars.count)
            out.append(String(chars[i..<end]))
            i = end
        }
        return out.joined(separator: " ")
    }

    private func start() {
        digits = store.randomDigits(length)
        input = ""
        matched = []
        startedAt = Date()
        task?.cancel()
        let total = length <= 10 ? 9 : (length <= 14 ? 12 : 16)
        remaining = total
        withAnimation { phase = .show }
        task = Task { @MainActor in
            for _ in 0..<total {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, phase == .show else { return }
                remaining -= 1
            }
            guard !Task.isCancelled, phase == .show else { return }
            Haptic.tap(.medium)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { phase = .recall }
            focused = true
        }
    }

    private func submit() {
        let chars = Array(digits)
        let typed = Array(input)
        matched = chars.indices.map { i in i < typed.count && chars[i] == typed[i] }
        focused = false
        if correct == chars.count { Haptic.success() } else { Haptic.tap(.medium) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .result }
    }

    private func finish() {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        var card = ReviewCard(front: "写出这串数字：\(grouped(digits))",
                              back: digits,
                              kind: .number,
                              due: Date().addingTimeInterval(3600),
                              methodId: 12)
        let quality = score >= 0.95 ? 5 : (score >= 0.8 ? 4 : (score >= 0.6 ? 3 : 1))
        card.grade(quality)
        store.finish(kind: .number, correct: correct, total: digits.count,
                     seconds: elapsed, cards: [card])
        Haptic.success()
        dismiss()
    }
}
