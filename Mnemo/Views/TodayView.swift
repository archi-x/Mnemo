import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var tab: RootTab

    @State private var showReview = false
    @State private var showWordFlash = false
    @State private var showWrongBook = false
    @State private var practiceRec: Recommendation?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<23: return "晚上好"
        default: return "夜深了"
        }
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    goalCard
                    smartCard
                    reviewCard
                    if !store.wrongItems.isEmpty { wrongCard }
                    planCard
                    recommended
                    quickStart
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showReview) {
                ReviewSessionView()
            }
            .fullScreenCover(isPresented: $showWordFlash) {
                WordFlashView()
            }
            .fullScreenCover(isPresented: $showWrongBook) {
                WrongBookView()
            }
            .sheet(item: $practiceRec) { rec in
                if let id = rec.methodId, let m = store.method(id) {
                    MethodPracticeView(method: m, initialLevel: rec.level)
                        .environmentObject(store)
                }
            }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-screen"), i + 1 < args.count {
                    switch args[i + 1] {
                    case "flash": showWordFlash = true
                    case "review": showReview = true
                    default: break
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(dateText) · \(greeting)，\(store.profile?.displayName ?? "练习者")")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
                Text("记忆训练")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text("\(store.streak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                Text("天")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSub)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glass(radius: 14)
        }
        .padding(.top, 4)
    }

    private var goalCard: some View {
        let done = min(store.todayDone, store.dailyGoal)
        let progress = Double(done) / Double(store.dailyGoal)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日目标")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(done >= store.dailyGoal ? "今日已完成" : "还差 \(store.dailyGoal - done) 关")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(done >= store.dailyGoal
                     ? "保持节奏，明天同一时间见"
                     : "每关约 3 分钟，先做最难的")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ZStack {
                ProgressRing(progress: progress, lineWidth: 9)
                    .frame(width: 84, height: 84)
                VStack(spacing: 0) {
                    Text("\(done)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                    Text("/ \(store.dailyGoal)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.17), Color.white.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var smartCard: some View {
        let recs = Array(store.recommendations(limit: 3))
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
                Text("按 Lv.\(store.learnerLevel.index) 推荐")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSub)
                Spacer()
                Text("\(store.weekXP) XP · 距下一级 \(store.xpProgress.toNext)")
                    .font(.system(size: 10.5, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }

            if recs.isEmpty {
                Text("先随便练一关，系统会开始按你的正确率和错题给建议。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass(radius: 16)
            } else {
                ForEach(recs) { rec in
                    Button {
                        open(rec)
                    } label: {
                        HStack(spacing: 11) {
                            IconBadge(symbol: rec.kind.symbol,
                                      tint: recTint(rec), size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(rec.kind.label)
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundStyle(recTint(rec))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Capsule().fill(recTint(rec).opacity(0.14)))
                                    Text(rec.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                }
                                Text(rec.reason)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textFaint)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.textFaint)
                        }
                        .padding(12)
                        .glass(radius: 16)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func recTint(_ rec: Recommendation) -> Color {
        switch rec.kind {
        case .wrong: return Theme.tint("review")
        case .review: return Theme.accent
        case .weak: return Theme.danger
        case .star: return Theme.accent
        case .fresh: return Theme.tint("space")
        case .levelUp: return Theme.tint("deep")
        }
    }

    private func open(_ rec: Recommendation) {
        Haptic.tap(.medium)
        switch rec.kind {
        case .wrong:
            showWrongBook = true
        case .review:
            showReview = true
        default:
            practiceRec = rec
        }
    }

    private var reviewCard: some View {
        let due = store.dueCards
        return Button {
            guard !due.isEmpty else { return }
            Haptic.tap(.medium)
            showReview = true
        } label: {
            HStack(spacing: 13) {
                IconBadge(symbol: "arrow.triangle.2.circlepath",
                          tint: due.isEmpty ? Theme.textFaint : Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("复习队列")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(due.isEmpty
                         ? "已经清空，明天会有新卡到期"
                         : "\(due.count) 张卡片到期 · 间隔重复")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
                if due.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.success.opacity(0.85))
                } else {
                    Text("开始")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accent))
                }
            }
            .padding(15)
            .glass(radius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var wrongCard: some View {
        let items = store.wrongItems
        let repeated = items.filter { $0.count > 1 }.count
        return Button {
            Haptic.tap(.medium)
            showWrongBook = true
        } label: {
            HStack(spacing: 13) {
                IconBadge(symbol: "repeat.circle.fill", tint: Theme.tint("review"))
                VStack(alignment: .leading, spacing: 3) {
                    Text("错题强化")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(repeated > 0
                         ? "\(items.count) 题待强化，其中 \(repeated) 题反复错"
                         : "\(items.count) 题待强化 · 答对两次出库")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
                Text("去练")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.tint("review")))
            }
            .padding(15)
            .glass(radius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var planCard: some View {
        let day = store.todayPlanDay
        let finished = day.map { store.completedPlanDays.contains($0.day) } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("30 天训练计划")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSub)
                Spacer()
                Text("\(store.completedPlanDays.count)/\(store.catalog.plan.count)")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textFaint)
            }
            if let day {
                HStack(spacing: 9) {
                    Text("第 \(day.day) 天")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
                    TagChip(text: day.theme, tint: Theme.tint("code"))
                    Spacer()
                }
                Text(day.task)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSub)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptic.success()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        store.completePlanDay(day.day)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: finished ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 15, weight: .semibold))
                        Text(finished ? "已完成，明天继续" : "标记完成")
                            .font(.system(size: 13.5, weight: .medium))
                    }
                    .foregroundStyle(finished ? Theme.success : Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.white.opacity(finished ? 0.04 : 0.08))
                    )
                }
                .disabled(finished)
            }
        }
        .padding(16)
        .glass(radius: 20)
    }

    private var recommended: some View {
        let method = nextMethod
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "今天学一法", trailing: "全部 40 法") {
                tab = .library
            }
            if let method {
                NavigationLink {
                    MethodDetailView(method: method)
                } label: {
                    HStack(spacing: 13) {
                        IconBadge(symbol: method.icon, tint: Theme.tint(method.categoryId), size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(method.name)
                                    .font(.system(size: 15.5, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                if store.learnedMethods.contains(method.id) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.success.opacity(0.9))
                                }
                            }
                            Text(method.definition)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.textSub)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textFaint)
                    }
                    .padding(15)
                    .glass(radius: 20)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var quickStart: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "开始词表闪记", symbol: "bolt.fill") {
                showWordFlash = true
            }
            HStack(spacing: 10) {
                GhostButton(title: "数字桩", symbol: "number") { tab = .drill }
                GhostButton(title: "记忆宫殿", symbol: "building.columns") { tab = .drill }
            }
        }
    }

    private var nextMethod: Method? {
        store.catalog.methods.first { !store.learnedMethods.contains($0.id) }
    }
}
