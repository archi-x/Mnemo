import SwiftUI

struct ReviewSessionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [String] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var done = 0
    @State private var loaded = false
    @State private var failed = 0
    @State private var startedAt = Date()
    @State private var logged = false

    private var card: ReviewCard? {
        guard index < queue.count else { return nil }
        return store.cards.first { $0.id == queue[index] }
    }

    var body: some View {
        ZStack {
            Theme.canvas
            VStack(spacing: 0) {
                if queue.isEmpty {
                    emptyState
                } else if index >= queue.count {
                    finishedState
                } else if let card {
                    session(card)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("复习队列")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            queue = store.dueCards.map(\.id)
        }
    }

    // MARK: 主流程

    private func session(_ card: ReviewCard) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(min(index + 1, queue.count))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(Theme.accent)
                            .frame(width: geo.size.width * (Double(index) / Double(max(1, queue.count))))
                    }
                }
                .frame(height: 4)
                Text("\(queue.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()
            flipCard(card)
            Spacer()

            if flipped {
                gradeButtons(card)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 10) {
                    Text("先在心里回答，再翻面核对")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textFaint)
                    PrimaryButton(title: "翻面看答案", symbol: "arrow.triangle.2.circlepath") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { flipped = true }
                        Haptic.tap(.medium)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }

    private func flipCard(_ card: ReviewCard) -> some View {
        ZStack {
            // 正面
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: card.kind.symbol)
                        .font(.system(size: 11, weight: .semibold))
                    Text(card.kind.label)
                        .font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    Text(card.stageLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textFaint)
                }
                .foregroundStyle(Theme.accent)

                Text(card.front)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
                if card.methodId != nil, let m = card.methodId.flatMap({ store.method($0) }) {
                    Text("出自 \(m.name)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glass(radius: 26, stroke: Theme.strokeStrong)
            .opacity(flipped ? 0 : 1)

            // 背面
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("答案")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.success)
                    Spacer()
                    Text("当前保持率 \(Int(store.retention(for: card) * 100))%")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textFaint)
                }
                Text(card.back)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glass(radius: 26, stroke: Theme.success.opacity(0.28))
            .opacity(flipped ? 1 : 0)
            .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 420)
        .padding(.horizontal, 22)
        .rotation3DEffect(.degrees(flipped ? 0 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: flipped)
        .onTapGesture {
            guard !flipped else { return }
            Haptic.tap()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { flipped = true }
        }
        .id(card.id)
    }

    private func gradeButtons(_ card: ReviewCard) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                gradeButton("忘了", sub: "20 分钟", quality: 1, tint: Theme.danger)
                gradeButton("吃力", sub: "1 天", quality: 3, tint: Theme.warn)
                gradeButton("记得", sub: "3 天", quality: 4, tint: Theme.success)
                gradeButton("秒答", sub: "更久", quality: 5, tint: Theme.accent)
            }
            Text("评价会决定下次出现的时间：SM-2 间隔重复")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    private func gradeButton(_ title: String, sub: String, quality: Int, tint: Color) -> some View {
        Button {
            store.grade(cardID: card?.id ?? "", quality: quality)
            if quality >= 4 { Haptic.success() } else { Haptic.tap(.medium) }
            if quality < 3 { failed += 1 }
            done += 1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                index += 1
                flipped = false
            }
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(sub)
                    .font(.system(size: 9.5))
                    .opacity(0.7)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(tint.opacity(0.26), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: 收尾

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            IconBadge(symbol: "checkmark.seal.fill", tint: Theme.success, size: 64)
            Text("今天没有到期的卡")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("复习卡会在到期的当天自动出现。\n现在去练一关新的，给明天留张卡。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer()
            GhostButton(title: "返回", symbol: "chevron.left") { dismiss() }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
        }
    }

    private var finishedState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                ProgressRing(progress: 1, lineWidth: 10, tint: Theme.success)
                    .frame(width: 96, height: 96)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.success)
            }
            Text("复习完成")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("处理了 \(done) 张卡，下一批会按记忆强度自动排期")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSub)
            Spacer()
            PrimaryButton(title: "回到今日", symbol: "house.fill") { dismiss() }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
        }
        .onAppear {
            guard !logged, done > 0 else { return }
            logged = true
            store.logSession(correct: max(0, done - failed), total: done,
                             seconds: Int(Date().timeIntervalSince(startedAt)))
            store.persist()
        }
    }
}
