import SwiftUI

/// 目标追踪：可增删的目标 + 进度 + 本周达成情况
struct GoalsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAdd = false
    @State private var pickKind: Goal.Kind = .dailySessions
    @State private var pickTarget = 3

    private var totalProgress: Double {
        guard !store.goals.isEmpty else { return 0 }
        let sum = store.goals.map { store.goalProgress($0).ratio }.reduce(0, +)
        return sum / Double(store.goals.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summary
                        if store.goals.isEmpty {
                            EmptyHint(symbol: "target", title: "还没有目标",
                                      detail: "加一个每日训练目标，App 会把进度自动算好")
                                .glass(radius: 20)
                        } else {
                            ForEach(store.goals) { goal in
                                goalCard(goal)
                            }
                        }
                        addButton
                        tipCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("目标计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(isPresented: $showAdd) { addSheet }
        }
    }

    private var summary: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: totalProgress, lineWidth: 9, tint: Theme.accent)
                    .frame(width: 78, height: 78)
                Text("\(Int(totalProgress * 100))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("目标完成度")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(store.goals.filter { store.goalProgress($0).done }.count.description
                     + " / \(store.goals.count) 项已达成")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSub)
                Text("每日 \(store.todayDone) 关 · 本周 \(store.weekXP) XP")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()
        }
        .padding(16)
        .glass(radius: 20)
        .padding(.top, 4)
    }

    private func goalCard(_ goal: Goal) -> some View {
        let p = store.goalProgress(goal)
        let tint = tint(for: goal.kind)
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                IconBadge(symbol: goal.symbol, tint: tint, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(p.done ? "已达成" : "还差 \(p.remaining) \(goal.unit)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(p.done ? Theme.success : Theme.textSub)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(p.current)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(p.done ? Theme.success : tint)
                    Text("/ \(p.target)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.veil(0.08))
                    Capsule()
                        .fill(p.done ? Theme.success : tint)
                        .frame(width: max(6, geo.size.width * p.ratio))
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                if p.done {
                    Label("保持住", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.success)
                } else {
                    Text(hint(for: goal.kind, p: p))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }
                Spacer()
                Button {
                    Haptic.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        store.removeGoal(goal)
                    }
                } label: {
                    Text("删除")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.danger.opacity(0.85))
                }
            }
        }
        .padding(15)
        .glass(radius: 18)
    }

    private func hint(for kind: Goal.Kind, p: GoalProgress) -> String {
        switch kind {
        case .dailySessions: return "今天再练 \(p.remaining) 关就达标"
        case .weeklySessions: return "本周还差 \(p.remaining) 关"
        case .streak: return "连续 \(store.streak) 天，别断"
        case .stars: return "每阶 ≥80% 拿一颗星"
        case .accuracy: return "目前 \(p.current)%，错题重做能拉回来"
        case .methodCount: return "标记已学或练到 60% 都算掌握"
        }
    }

    private func tint(for kind: Goal.Kind) -> Color {
        switch kind {
        case .dailySessions: return Theme.accent
        case .weeklySessions: return Theme.tint("struct")
        case .streak: return Theme.tint("review")
        case .stars: return Theme.tint("code")
        case .accuracy: return Theme.tint("deep")
        case .methodCount: return Theme.tint("space")
        }
    }

    private var addButton: some View {
        Button {
            Haptic.tap()
            pickKind = availableKind
            pickTarget = pickKind.presets[1]
            showAdd = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                Text("新增目标").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .glass(radius: 15)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var availableKind: Goal.Kind {
        Goal.Kind.allCases.first { kind in
            !store.goals.contains { $0.kind == kind }
        } ?? .dailySessions
    }

    private var addSheet: some View {
        NavigationStack {
            ZStack {
                Theme.canvas
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("挑一个维度")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSub)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                                  spacing: 10) {
                            ForEach(Goal.Kind.allCases, id: \.self) { kind in
                                let used = store.goals.contains { $0.kind == kind }
                                Button {
                                    guard !used else { return }
                                    Haptic.select()
                                    pickKind = kind
                                    pickTarget = kind.presets[1]
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        IconBadge(symbol: kind.symbol,
                                                  tint: used ? Theme.textFaint : tint(for: kind),
                                                  size: 30)
                                        Text(kind.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(used ? Theme.textFaint : Theme.text)
                                        Text(used ? "已添加" : kind.unit)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(Theme.textFaint)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(pickKind == kind && !used
                                                  ? Theme.accent.opacity(0.16)
                                                  : Theme.veil(0.04))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(pickKind == kind && !used
                                                                  ? Theme.accent.opacity(0.5)
                                                                  : Theme.stroke, lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }

                        Text("目标值")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSub)

                        HStack(spacing: 9) {
                            ForEach(pickKind.presets, id: \.self) { v in
                                Button {
                                    Haptic.select()
                                    pickTarget = v
                                } label: {
                                    Text("\(v)\(pickKind == .accuracy ? "%" : "")")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(pickTarget == v ? Theme.onAccent : Theme.text)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(pickTarget == v ? Theme.accent : Theme.veil(0.05))
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("新增目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showAdd = false }
                        .foregroundStyle(Theme.textSub)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加") {
                        Haptic.success()
                        store.addGoal(pickKind, target: pickTarget)
                        showAdd = false
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var tipCard: some View {
        Text("目标不要一次设太多。同时追 5 个以上，注意力会散——挑 2 到 3 个真正想要的，其余用默认的每周量兜底。")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.textFaint)
            .lineSpacing(3)
    }
}
