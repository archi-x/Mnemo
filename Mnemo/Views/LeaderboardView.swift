import SwiftUI

/// 同级别排名：离线生成的同级同伴，按本周 XP 排序
struct LeaderboardView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var rows: [LeaderboardRow] { store.leaderboard() }
    private var mine: (rank: Int, total: Int, percentile: Int) { store.myRank() }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard
                        listCard
                        noteCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("同级别排名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var heroCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                TagChip(text: "Lv.\(store.learnerLevel.index) \(store.learnerLevel.name)",
                        tint: Theme.accent, filled: true)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("第 \(mine.rank)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                    Text("/ \(mine.total) 名")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textFaint)
                }
                Text("本周 \(store.weekXP) XP · 超过同级 \(mine.percentile)% 的人")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSub)
            }
            Spacer(minLength: 0)
            ZStack {
                ProgressRing(progress: Double(mine.percentile) / 100, lineWidth: 8, tint: Theme.accent)
                    .frame(width: 74, height: 74)
                VStack(spacing: 0) {
                    Text("\(mine.percentile)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                    Text("%")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .padding(16)
        .glass(radius: 22)
        .padding(.top, 4)
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                HStack(spacing: 11) {
                    rankBadge(row.rank)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(.system(size: 13.5, weight: row.isMe ? .bold : .medium))
                            .foregroundStyle(row.isMe ? Theme.accent : Theme.text)
                            .lineLimit(1)
                        Text("\(row.sessions) 关 · 正确率 \(Int(row.accuracy * 100))%")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                    Spacer()
                    Text("\(row.xp)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(row.isMe ? Theme.accent : Theme.textSub)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(row.isMe ? Theme.accent.opacity(0.09) : Color.clear)

                if i < rows.count - 1 {
                    Rectangle().fill(Theme.stroke).frame(height: 0.7).padding(.leading, 46)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glass(radius: 20)
    }

    private func rankBadge(_ rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(rank <= 3 ? medalTint(rank).opacity(0.16) : Color.white.opacity(0.05))
                .frame(width: 26, height: 26)
            if rank <= 3 {
                Image(systemName: "medal.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(medalTint(rank))
            } else {
                Text("\(rank)")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }

    private func medalTint(_ rank: Int) -> Color {
        switch rank {
        case 1: return Theme.accent
        case 2: return Color(hex: 0xC8CDD8)
        default: return Color(hex: 0xC08A5E)
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                Text("关于这份榜单")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textSub)
            }
            Text("这是离线模拟的同级别参照榜：同伴按你的等级段和本周 XP 区间生成，只用于判断自己的相对位置。App 不联网、不上传任何训练数据，也没有真实用户排行。等你练到更高等级，榜单会换成那个等级段的对手。")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(3)
        }
        .padding(15)
        .glass(radius: 18)
    }
}
