import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showReset = false
    @State private var showCalendar = false
    @State private var showWrongBook = false
    @State private var showCurve = false
    @State private var showQuest = false
    @State private var showGoals = false
    @State private var showReport = false
    @State private var showRank = false
    @State private var showPinSetup = false

    private var accuracyText: String {
        store.stats.totalItems == 0 ? "—" : "\(Int(store.stats.accuracy * 100))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    precisionCard
                    statGrid
                    calendarCard
                    entryRows
                    planCard
                    badgeSection
                    accountSection
                    resetRow
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCalendar) { CalendarView() }
            .fullScreenCover(isPresented: $showWrongBook) { WrongBookView() }
            .fullScreenCover(isPresented: $showCurve) { ForgettingCurveView() }
            .fullScreenCover(isPresented: $showQuest) { QuestMapView() }
            .fullScreenCover(isPresented: $showGoals) { GoalsView() }
            .fullScreenCover(isPresented: $showReport) { ReportView() }
            .fullScreenCover(isPresented: $showRank) { LeaderboardView() }
            .sheet(isPresented: $showPinSetup) { PinSetupSheet() }
            .confirmationDialog("清空所有训练数据？", isPresented: $showReset, titleVisibility: .visible) {
                Button("清空并重置", role: .destructive) {
                    Haptic.failure()
                    store.resetAll()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("打卡、复习卡、成绩都会删除，无法恢复。")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: store.profile?.avatar ?? "brain.head.profile")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.accent.opacity(0.22), Color.white.opacity(0.04)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
                        )
                )
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(store.profile?.displayName ?? "练习者")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    TagChip(text: "Lv.\(store.learnerLevel.index) · \(store.learnerLevel.name)",
                            tint: Theme.accent, filled: true)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.09))
                        Capsule().fill(Theme.accent)
                            .frame(width: max(4, geo.size.width * store.xpProgress.progress))
                    }
                }
                .frame(height: 5)
                .padding(.trailing, 6)
                Text("\(store.xp) XP · 距 Lv.\(store.learnerLevel.index + 1) 还差 \(store.xpProgress.toNext) · 连续 \(store.streak) 天")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()
        }
        .padding(.top, 14)
    }

    private var precisionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("记忆精度")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(store.precision.requirement)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
            }
            HStack(spacing: 5) {
                ForEach(PrecisionLevel.all, id: \.index) { level in
                    let reached = level.index <= store.precision.index
                    let current = level.index == store.precision.index
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(reached ? Theme.accent.opacity(current ? 1 : 0.55)
                                  : Color.white.opacity(0.09))
                            .frame(height: current ? 6 : 4)
                        Text(level.name)
                            .font(.system(size: 9.5, weight: current ? .semibold : .regular))
                            .foregroundStyle(reached ? Theme.text : Theme.textFaint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            Text("从「看到能认出」到「不需刻意回忆」，训练次数与正确率决定等级。")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(2)
        }
        .padding(16)
        .glass(radius: 20)
    }

    private var statGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(value: "\(store.stats.sessions)", unit: "次", label: "累计训练")
                StatTile(value: accuracyText, unit: "%", label: "平均正确率",
                         tint: store.stats.accuracy >= 0.8 ? Theme.success : Theme.text)
            }
            HStack(spacing: 10) {
                StatTile(value: "\(store.cards.count)", unit: "张", label: "复习卡")
                StatTile(value: "\(store.learnedMethods.count)", unit: "法", label: "已学方法",
                         tint: Theme.tint("space"))
            }
        }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "学习日历", trailing: "查看") { showCalendar = true }
            WeekStrip(onTap: { showCalendar = true })
        }
    }

    private var entryRows: some View {
        VStack(spacing: 8) {
            entryRow(symbol: "repeat.circle.fill", tint: Theme.tint("review"),
                     title: "错题本",
                     detail: store.wrongItems.isEmpty ? "答错的题会自动收进来" : "\(store.wrongItems.count) 题待强化") {
                showWrongBook = true
            }
            entryRow(symbol: "chart.line.downtrend.xyaxis", tint: Theme.tint("deep"),
                     title: "遗忘曲线与复习排期",
                     detail: "平均保持率 \(Int(store.averageRetention() * 100))%") {
                showCurve = true
            }
            entryRow(symbol: "map.fill", tint: Theme.tint("code"),
                     title: "闯关地图",
                     detail: "四学龄段 · 已收 \(store.totalStars)/\(store.maxStars) 星") {
                showQuest = true
            }
            entryRow(symbol: "target", tint: Theme.tint("deep"),
                     title: "目标计划",
                     detail: "\(store.goals.filter { store.goalProgress($0).done }.count)/\(store.goals.count) 项达成") {
                showGoals = true
            }
            entryRow(symbol: "chart.bar.doc.horizontal.fill", tint: Theme.tint("struct"),
                     title: "学习报告",
                     detail: "本周 \(store.weekReport().sessions) 次 · 正确率 \(Int(store.weekReport().accuracy * 100))%") {
                showReport = true
            }
            entryRow(symbol: "list.number", tint: Theme.tint("seq"),
                     title: "同级别排名",
                     detail: "同级第 \(store.myRank().rank)/\(store.myRank().total) 名 · 超过 \(store.myRank().percentile)%") {
                showRank = true
            }
        }
    }

    private func entryRow(symbol: String, tint: Color, title: String, detail: String,
                          action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: symbol, tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(13)
            .glass(radius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var planCard: some View {
        let total = max(1, store.catalog.plan.count)
        let done = store.completedPlanDays.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("30 天训练计划")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(done)/\(total) 天")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accent.opacity(0.7), Theme.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * (Double(done) / Double(total)))
                }
            }
            .frame(height: 7)

            VStack(spacing: 6) {
                ForEach(nextDays, id: \.day) { d in
                    HStack(spacing: 9) {
                        Text("D\(d.day)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textFaint)
                            .frame(width: 26, alignment: .leading)
                        Text(d.theme)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .frame(width: 62, alignment: .leading)
                        Text(d.task)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSub)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .glass(radius: 20)
    }

    private var nextDays: [PlanDay] {
        let done = store.completedPlanDays.count
        return Array(store.catalog.plan.dropFirst(done).prefix(3))
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "徽章")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(badges, id: \.title) { b in
                    VStack(spacing: 7) {
                        Image(systemName: b.symbol)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(b.unlocked ? b.tint : Theme.textFaint.opacity(0.5))
                        Text(b.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(b.unlocked ? Theme.text : Theme.textFaint)
                        Text(b.hint)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textFaint)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(b.unlocked ? b.tint.opacity(0.10) : Color.white.opacity(0.035))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(b.unlocked ? b.tint.opacity(0.25) : Theme.stroke,
                                                  lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private struct Badge: Hashable {
        let title: String
        let hint: String
        let symbol: String
        let tint: Color
        let unlocked: Bool
    }

    private var badges: [Badge] {
        [
            .init(title: "开张", hint: "完成首次训练", symbol: "flag.fill",
                  tint: Theme.tint("code"), unlocked: store.stats.sessions >= 1),
            .init(title: "三日不断", hint: "连续 3 天", symbol: "flame.fill",
                  tint: Theme.tint("review"), unlocked: store.streak >= 3),
            .init(title: "一周成习", hint: "连续 7 天", symbol: "calendar.badge.checkmark",
                  tint: Theme.tint("deep"), unlocked: store.streak >= 7),
            .init(title: "十次打磨", hint: "训练 10 次", symbol: "hammer.fill",
                  tint: Theme.tint("struct"), unlocked: store.stats.sessions >= 10),
            .init(title: "宫殿建成", hint: "宫殿关 ≥ 80%", symbol: "building.columns.fill",
                  tint: Theme.tint("space"), unlocked: (store.best[CardKind.palace.rawValue] ?? 0) >= 0.8),
            .init(title: "法有十得", hint: "学满 10 法", symbol: "books.vertical.fill",
                  tint: Theme.tint("lang"), unlocked: store.learnedMethods.count >= 10),
            .init(title: "摘星十枚", hint: "收满 10 星", symbol: "star.circle.fill",
                  tint: Theme.accent, unlocked: store.totalStars >= 10),
            .init(title: "进阶三级", hint: "达到 Lv.3", symbol: "arrow.up.forward.circle.fill",
                  tint: Theme.tint("seq"), unlocked: store.learnerLevel.index >= 3)
        ]
    }

    private var accountSection: some View {
        VStack(spacing: 8) {
            Button {
                Haptic.tap()
                showPinSetup = true
            } label: {
                accountRow(symbol: "lock.fill",
                           title: "进入密码",
                           value: store.profile?.hasPin == true ? "已开启" : "未设置")
            }
            .buttonStyle(ScaleButtonStyle())

            if store.profile?.hasPin == true {
                Button {
                    Haptic.tap()
                    store.lock()
                } label: {
                    accountRow(symbol: "lock.rotation", title: "锁定忆境", value: nil)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Button {
                Haptic.tap()
                store.signOut()
            } label: {
                accountRow(symbol: "person.crop.circle.badge.arrow.forward",
                           title: "切换身份",
                           value: store.profile?.joinedText)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func accountRow(symbol: String, title: String, value: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSub)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.text)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(15)
        .glass(radius: 16)
    }

    private var resetRow: some View {
        Button {
            Haptic.tap()
            showReset = true
        } label: {
            HStack {
                Text("清空训练数据")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.danger.opacity(0.9))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(15)
            .glass(radius: 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
