import SwiftUI

/// 闯关地图：40 法分成七个章节，每法三阶，拿星解锁下一关
struct QuestMapView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var practice: Method?
    @State private var practiceLevel = 1
    @State private var lockedHint: String?

    private var chapters: [QuestChapter] { store.questChapters() }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        progressCard
                        ForEach(chapters) { chapter in
                            chapterCard(chapter)
                        }
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
            .fullScreenCover(item: $practice) { m in
                MethodPracticeView(method: m, initialLevel: practiceLevel)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("七个章节 · \(store.catalog.methods.count) 关")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textFaint)
            Text("拿一星开下一关，三阶全满 80% 收满三星")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(3)
        }
        .padding(.top, 4)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: Double(store.totalStars) / Double(max(1, store.maxStars)),
                                 lineWidth: 8, tint: Theme.accent)
                        .frame(width: 64, height: 64)
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.totalStars) / \(store.maxStars) 星")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Lv.\(store.learnerLevel.index) \(store.learnerLevel.name) · \(store.xp) XP")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
            }

            if let next = store.nextQuest() {
                Button {
                    Haptic.tap(.medium)
                    practiceLevel = max(1, store.methodLevel(next.node.method.id))
                    practice = next.node.method
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "flag.fill").font(.system(size: 13, weight: .bold))
                        Text("继续闯关：\(next.node.method.name)")
                            .font(.system(size: 14.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.black.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.82)],
                                                 startPoint: .top, endPoint: .bottom))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Text("所有关卡都通了，去错题本收尾")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.success)
            }
        }
        .padding(16)
        .glass(radius: 20)
    }

    private func chapterCard(_ chapter: QuestChapter) -> some View {
        let nodes = store.questNodes(in: chapter)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: chapter.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tint(chapter.id))
                Text(chapter.name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9))
                    Text("\(chapter.stars)/\(chapter.maxStars)")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.accent.opacity(0.9))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
                      spacing: 9) {
                ForEach(nodes) { node in
                    nodeButton(node, chapter: chapter)
                }
            }
        }
        .padding(15)
        .glass(radius: 20)
    }

    private func nodeButton(_ node: QuestNode, chapter: QuestChapter) -> some View {
        let tint = Theme.tint(chapter.id)
        return Button {
            if node.unlocked {
                Haptic.tap(.medium)
                practiceLevel = max(1, store.methodLevel(node.method.id))
                practice = node.method
            } else {
                Haptic.failure()
                lockedHint = "先把「\(chapter.methods.first(where: { $0.id < node.method.id })?.name ?? "前一关")」拿到一星"
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(node.unlocked ? tint.opacity(0.16) : Color.white.opacity(0.05))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle().strokeBorder(node.unlocked ? tint.opacity(0.35) : Theme.stroke,
                                                  lineWidth: 1)
                        )
                    if node.unlocked {
                        Text("\(node.index)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(node.cleared ? tint : Theme.textSub)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                Text(node.method.shortName)
                    .font(.system(size: 10.5, weight: node.cleared ? .semibold : .regular))
                    .foregroundStyle(node.unlocked ? Theme.text : Theme.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < node.stars ? "star.fill" : "star")
                            .font(.system(size: 7.5))
                            .foregroundStyle(i < node.stars ? Theme.accent : Theme.textFaint.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(node.unlocked ? Color.white.opacity(0.04) : Color.white.opacity(0.02))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lockedHint {
                Text(lockedHint)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warn)
            }
            Text("星级判定：某一阶最好成绩 ≥ 80% 记一星。三星全满说明这一法已经能自动用出来，可以当工具使了。")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(3)
        }
        .padding(.top, 2)
    }
}
