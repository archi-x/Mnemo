import SwiftUI

/// 闯关：四个学龄段各一套玩法，每段 12 关 × 三档难度
struct QuestMapView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var stage: SchoolStage = .primaryLow
    @State private var openedNode: StageNodeSpec?
    @State private var loaded = false

    private var nodes: [StageNodeSpec] { QuestBank.nodes(for: stage) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        stagePicker
                        gameCard
                        progressCard
                        nodeGrid
                        legend
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("闯关地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(item: $openedNode) { node in
                NodeLevelSheet(stage: stage, node: node)
                    .environmentObject(store)
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                stage = store.activeStage()
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-stage"), i + 1 < args.count,
                   let s = SchoolStage(rawValue: args[i + 1]) {
                    stage = s
                }
            }
        }
    }

    // MARK: 学龄段选择

    private var stagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SchoolStage.allCases) { s in
                    Button {
                        Haptic.tap()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            stage = s
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text(s.emoji)
                                    .font(.system(size: 13))
                                Text(s.shortTitle)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(stage == s ? Color.black.opacity(0.85) : Theme.text)
                            }
                            Text("\(s.grades) \(store.stageStars(s))★")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(stage == s ? Color.black.opacity(0.6) : Theme.textFaint)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(stage == s ? s.tint : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(stage == s ? .clear : Color.white.opacity(0.08),
                                                      lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.top, 2)
    }

    // MARK: 玩法卡

    private var gameCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: kindSymbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(stage.tint)
                Text(stage.gameName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(nodes.count) 关")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
            }
            Text(stage.tagline)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSub)

            HStack(spacing: 6) {
                ForEach(stage.levels) { spec in
                    VStack(spacing: 1) {
                        Text("L\(spec.level) \(spec.label)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(spec.detail)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textFaint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            }
        }
        .padding(15)
        .glass(radius: 18)
    }

    private var kindSymbol: String {
        switch stage.gameKind {
        case .flipMatch: return "rectangle.on.rectangle.angled"
        case .orderSteps: return "list.number"
        case .rushQuiz: return "bolt.fill"
        case .encodeLab: return "pencil.and.outline"
        }
    }

    // MARK: 进度

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: store.stageProgress(stage),
                                 lineWidth: 8, tint: stage.tint)
                        .frame(width: 62, height: 62)
                    Image(systemName: "star.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(stage.tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(store.stageStars(stage)) / \(nodes.count * 3) 星")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("全段 \(store.questTotalStars)/\(store.questMaxStars) 星 · \(store.learnerLevel.name)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
            }

            if let next = store.nextQuest(in: stage) {
                Button {
                    Haptic.tap(.medium)
                    openedNode = next.node
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("继续：\(next.node.title) · L\(next.level)")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.black.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(stage.tint)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Text("这一段全满了 · 换下一个学龄段挑战")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.success)
            }
        }
        .padding(15)
        .glass(radius: 18)
    }

    // MARK: 关卡网格

    private var nodeGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "关卡", trailing: "\(nodes.count) 关")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 9),
                                GridItem(.flexible(), spacing: 9),
                                GridItem(.flexible(), spacing: 9)], spacing: 9) {
                ForEach(nodes) { node in
                    nodeCard(node)
                }
            }
        }
    }

    private func nodeCard(_ node: StageNodeSpec) -> some View {
        let unlocked = store.nodeUnlocked(stage, node: node.index)
        let stars = store.nodeStars(stage, node: node.index)

        return Button {
            guard unlocked else {
                Haptic.failure()
                return
            }
            Haptic.tap(.medium)
            openedNode = node
        } label: {
            VStack(spacing: 5) {
                Text(node.emoji)
                    .font(.system(size: 20))
                Text(node.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .font(.system(size: 7.5))
                            .foregroundStyle(i < stars ? Theme.accent : Theme.textFaint.opacity(0.45))
                    }
                }
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(unlocked ? Color.white.opacity(0.06) : Color.white.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(stars == 3 ? Theme.accent.opacity(0.45)
                                          : Color.white.opacity(0.07),
                                          lineWidth: stars == 3 ? 1.2 : 0.8)
                    )
            )
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("规则")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSub)
            Text("· 每关三档，正确率 80% 得一颗星，三档满星")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
            Text("· 前一关拿到任意一星，才解锁下一关")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
            Text("· 四个学龄段玩法不同，进度独立记录")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.top, 4)
    }
}

// MARK: - 关卡详情（选难度）

struct NodeLevelSheet: View {
    let stage: SchoolStage
    let node: StageNodeSpec

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var launch: Launch?

    private struct Launch: Identifiable {
        let level: Int
        var id: Int { level }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 5) {
                            Text(node.emoji).font(.system(size: 32))
                            Text(node.title)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text("\(stage.title) · \(stage.gameName)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.textFaint)
                        }
                        .padding(.top, 8)

                        ForEach(stage.levels) { spec in
                            levelRow(spec)
                        }

                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textFaint)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("选难度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .fullScreenCover(item: $launch) { item in
                game(level: item.level)
            }
        }
    }

    private var note: String {
        switch stage.gameKind {
        case .flipMatch: return "配对靠图像编码：词变成图，位置也在帮你记。"
        case .orderSteps: return "排序练的是流程顺序，顺序错了回忆就会断。"
        case .rushQuiz: return "限时抢答练快速提取，连击越高越稳。"
        case .encodeLab: return "先选方法再选路径，最后合上材料自问一遍。"
        }
    }

    private func levelRow(_ spec: QuestLevelSpec) -> some View {
        let score = store.questScore(stage, node: node.index, level: spec.level)
        let cleared = score >= 0.8
        let best = Int((score * 100).rounded())

        return Button {
            Haptic.tap(.medium)
            launch = Launch(level: spec.level)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(cleared ? Theme.success.opacity(0.16) : Color.white.opacity(0.06))
                        .frame(width: 38, height: 38)
                    Text("L\(spec.level)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(cleared ? Theme.success : Theme.textSub)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(spec.label) · \(spec.detail)")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(best > 0 ? "最好 \(best)%" : "还没玩过")
                        .font(.system(size: 11))
                        .foregroundStyle(best > 0 ? Theme.textSub : Theme.textFaint)
                }
                Spacer(minLength: 0)
                Image(systemName: cleared ? "star.fill" : "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(cleared ? Theme.accent : stage.tint)
            }
            .padding(13)
            .glass(radius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func game(level: Int) -> some View {
        switch stage.gameKind {
        case .flipMatch:
            FlipMatchView(stage: stage, node: node, level: level).environmentObject(store)
        case .orderSteps:
            OrderStepsView(stage: stage, node: node, level: level).environmentObject(store)
        case .rushQuiz:
            RushQuizView(stage: stage, node: node, level: level).environmentObject(store)
        case .encodeLab:
            EncodeLabView(stage: stage, node: node, level: level).environmentObject(store)
        }
    }
}
