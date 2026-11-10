import SwiftUI

struct PalaceDrillView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case pick, familiar, place, recall, result }

    @State private var phase: Phase = .pick
    @State private var route: PalaceRoute = PalaceRoute.all[0]
    @State private var words: [String] = []
    @State private var index = 0
    @State private var input = ""
    @State private var answers: [String] = []
    @State private var matched: [Bool] = []
    @State private var startedAt = Date()
    @FocusState private var focused: Bool

    private var correct: Int { matched.filter { $0 }.count }
    private var score: Double { words.isEmpty ? 0 : Double(correct) / Double(words.count) }

    var body: some View {
        ZStack {
            Theme.canvas
            VStack(spacing: 0) {
                topBar
                Group {
                    switch phase {
                    case .pick: pickView
                    case .familiar: familiarView
                    case .place: placeView
                    case .recall: recallView
                    case .result: resultView
                    }
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptic.tap()
                if phase == .pick { dismiss() }
                else if phase == .familiar { phase = .pick }
                else { dismiss() }
            } label: {
                Image(systemName: phase == .pick ? "xmark" : "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSub)
                    .frame(width: 34, height: 34)
                    .glass(radius: 12)
            }
            Spacer()
            Text("记忆宫殿")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Rectangle().fill(.clear).frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: 选路线

    private var pickView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选一条熟悉的路线")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("路线必须闭着眼也能走完。位置定下来后不要改，它是你以后所有清单的货架。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSub)
                        .lineSpacing(3)
                }
                .padding(.top, 24)

                ForEach(PalaceRoute.all) { r in
                    Button {
                        Haptic.select()
                        route = r
                    } label: {
                        HStack(spacing: 13) {
                            IconBadge(symbol: "mappin.and.ellipse", tint: Theme.tint("space"), size: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text(r.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSub)
                            }
                            Spacer()
                            Image(systemName: route.id == r.id ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(route.id == r.id ? Theme.tint("space") : Theme.textFaint)
                        }
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(route.id == r.id
                                      ? Theme.tint("space").opacity(0.13)
                                      : Theme.veil(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(route.id == r.id
                                                      ? Theme.tint("space").opacity(0.35)
                                                      : Theme.stroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                TipCard(title: "路线怎么选",
                        tint: Theme.tint("space"),
                        lines: [
                            TipLine("figure.walk", "闭眼能走完：选每天都经过的空间，顺序不用背"),
                            TipLine("mappin.and.ellipse", "位置要具体：沙发、茶几、电视柜，而不是「客厅」"),
                            TipLine("cube.fill", "一位一物：每个位置只放一个画面，别叠放")
                        ])
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "开始熟悉路线", symbol: "figure.walk", tint: Theme.tint("space")) {
                start()
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 0.7) }
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: 熟悉路线

    private var familiarView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("先把位置走一遍")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("按顺序点过去，注意每个位置的细节：颜色、材质、边缘。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 22)

            Spacer()

            VStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.tint("space"))
                Text(route.anchors[index])
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .id(index)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                            removal: .opacity))
                HStack(spacing: 5) {
                    ForEach(route.anchors.indices, id: \.self) { i in
                        Circle()
                            .fill(i <= index ? Theme.tint("space") : Theme.veil(0.14))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: index)

            Spacer()

            PrimaryButton(title: index + 1 < route.anchors.count ? "下一个位置" : "路线记住了，开始放东西",
                          symbol: "arrow.right", tint: Theme.tint("space")) {
                if index + 1 < route.anchors.count {
                    withAnimation { index += 1 }
                    Haptic.select()
                } else {
                    words = store.randomWords(route.anchors.count)
                    index = 0
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .place }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }

    // MARK: 放置

    private var placeView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("一个位置，一个词")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("让词和位置发生动作：撞上去、卡进去、流下来。越不合常理，越好记。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 22)

            Spacer()
            VStack(spacing: 16) {
                Text(route.anchors[index])
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSub)
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                    Text(words[index])
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Theme.tint("space"))
                }
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.tint("space").opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Theme.tint("space").opacity(0.25), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 22)
                .id(index)
                .transition(.asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity),
                                        removal: .opacity))

                Text("\(index + 1) / \(route.anchors.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: index)
            Spacer()

            PrimaryButton(title: index + 1 < words.count ? "下一个" : "开始回忆",
                          symbol: "arrow.right", tint: Theme.tint("space")) {
                Haptic.select()
                if index + 1 < words.count {
                    withAnimation { index += 1 }
                } else {
                    index = 0
                    input = ""
                    answers = []
                    startedAt = Date()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .recall }
                    focused = true
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }

    // MARK: 回忆

    private var recallView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(route.anchors.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? Theme.tint("space") : Theme.veil(0.12))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            Spacer()
            VStack(spacing: 14) {
                Text("第 \(index + 1) 个位置")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
                Text(route.anchors[index])
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.text)
                TextField("", text: $input, prompt: Text("这里放的是什么？").foregroundStyle(Theme.textFaint))
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.tint("space"))
                    .padding(14)
                    .glass(radius: 16)
                    .focused($focused)
                    .onSubmit { record() }
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
            }
            .id(index)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: index)
            Spacer()

            VStack(spacing: 10) {
                PrimaryButton(title: index + 1 < words.count ? "下一个位置" : "看结果",
                              symbol: "arrow.right", tint: Theme.tint("space")) { record() }
                Button {
                    Haptic.tap()
                    input = ""
                    record(skip: true)
                } label: {
                    Text("想不起来了")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .onAppear { focused = true }
    }

    // MARK: 结果

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    ZStack {
                        ProgressRing(progress: score, lineWidth: 11,
                                     tint: score >= 0.8 ? Theme.success : (score >= 0.5 ? Theme.warn : Theme.danger))
                            .frame(width: 108, height: 108)
                        Text("\(Int(score * 100))%")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                    }
                    Text("\(route.name) · \(correct) / \(words.count) 个位置")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                .padding(.top, 20)

                VStack(spacing: 8) {
                    ForEach(route.anchors.indices, id: \.self) { i in
                        let ok = matched.indices.contains(i) && matched[i]
                        HStack(spacing: 11) {
                            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.system(size: 15))
                                .foregroundStyle(ok ? Theme.success : Theme.danger.opacity(0.75))
                            Text(route.anchors[i])
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.textFaint)
                                .frame(width: 74, alignment: .leading)
                            Text(words[i])
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            if !ok {
                                Text(answers.indices.contains(i) && !answers[i].isEmpty ? answers[i] : "—")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.danger.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.veil(0.04))
                        )
                    }
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "换一组词再练", symbol: "arrow.clockwise", tint: Theme.tint("space")) {
                        words = store.randomWords(route.anchors.count)
                        index = 0
                        matched = []
                        answers = []
                        input = ""
                        startedAt = Date()
                        withAnimation { phase = .place }
                    }
                    GhostButton(title: "完成并存入复习队列", symbol: "tray.and.arrow.down") { finish() }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 流程

    private func start() {
        index = 0
        words = []
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .familiar }
    }

    private func record(skip: Bool = false) {
        let token = input.trimmingCharacters(in: .whitespacesAndNewlines)
        answers.append(skip ? "" : token)
        let ok = !skip && Judge.match([token], targets: [words[index]])[0]
        matched.append(ok)
        input = ""
        if ok { Haptic.select() } else { Haptic.tap(.heavy) }

        if index + 1 < words.count {
            index += 1
        } else {
            focused = false
            if correct == words.count { Haptic.success() }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .result }
        }
    }

    private func finish() {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let chain = zip(route.anchors, words).map { "\($0)：\($1)" }.joined(separator: "；")
        var card = ReviewCard(front: "\(route.name) 宫殿 · 按顺序说出 \(words.count) 个词",
                              back: chain,
                              kind: .palace,
                              due: Date().addingTimeInterval(3600),
                              methodId: 6)
        let quality = score >= 0.95 ? 5 : (score >= 0.8 ? 4 : (score >= 0.6 ? 3 : 1))
        card.grade(quality)
        store.finish(kind: .palace, correct: correct, total: words.count,
                     seconds: elapsed, cards: [card])
        Haptic.success()
        dismiss()
    }
}
