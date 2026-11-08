import SwiftUI
import Charts

/// 学习报告：本周 vs 上周、逐日训练量、类别强弱、需要补的方法
struct ReportView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var report: WeekReport { store.weekReport() }

    private struct DayPoint: Identifiable {
        let id: String
        let date: Date
        let count: Int
        let accuracy: Double
        let week: Int   // 0 = 上周, 1 = 本周
    }

    private var points: [DayPoint] {
        let cal = Calendar.current
        let cutoff = cal.startOfDay(for: Date())
        return report.daily.map { item in
            let isThisWeek = item.date >= cutoff
            let week = isThisWeek ? 1 : 0
            return DayPoint(id: AppStore.dayKey(item.date), date: item.date,
                            count: item.count, accuracy: item.accuracy, week: week)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        compareCard
                        volumeCard
                        accuracyCard
                        categoryCard
                        weakCard
                        adviceCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("学习报告")
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

    // MARK: 本周对比

    private var compareCard: some View {
        let r = report
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本周训练")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textFaint)
                    Text("\(r.sessions) 次 · \(r.activeDays) 天")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                TagChip(text: deltaText(r.sessionsDelta, unit: "次"),
                        tint: r.sessionsDelta >= 0 ? Theme.success : Theme.warn)
            }

            HStack(spacing: 10) {
                miniStat(title: "正确率", value: "\(Int(r.accuracy * 100))%",
                         delta: r.accuracyDelta, isPercent: true)
                miniStat(title: "经验值", value: "\(r.xp) XP",
                         delta: Double(r.xp - r.prevXP), isPercent: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text("星星").font(.system(size: 10.5)).foregroundStyle(Theme.textFaint)
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 9))
                        Text("\(r.stars)/\(store.maxStars)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glass(radius: 20)
        .padding(.top, 4)
    }

    private func deltaText(_ v: Int, unit: String) -> String {
        if v == 0 { return "与上周持平" }
        return v > 0 ? "比上周 +\(v) \(unit)" : "比上周 \(v) \(unit)"
    }

    private func miniStat(title: String, value: String, delta: Double, isPercent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
            Text(isPercent
                 ? String(format: "%+.0f%%", delta * 100)
                 : (delta >= 0 ? "+\(Int(delta))" : "\(Int(delta))"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(delta >= 0 ? Theme.success : Theme.danger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 逐日训练量

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近 14 天训练量")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("上周 / 本周")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
            Chart(points) { p in
                BarMark(
                    x: .value("日期", p.date, unit: .day),
                    y: .value("次数", p.count),
                    width: .fixed(9)
                )
                .foregroundStyle(p.week == 1 ? Theme.accent : Theme.accent.opacity(0.28))
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel()
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .frame(height: 118)
        }
        .padding(16)
        .glass(radius: 20)
    }

    // MARK: 正确率趋势

    private var accuracyCard: some View {
        let pts = points.filter { $0.accuracy > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("正确率趋势")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(pts.isEmpty ? "样本不足" : "\(Int(report.accuracy * 100))% 本周均值")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
            if pts.isEmpty {
                EmptyHint(symbol: "chart.xyaxis.line", title: "还没有足够数据",
                          detail: "做完几组练习，这里会出现正确率曲线")
                    .frame(height: 100)
            } else {
                Chart(pts) { p in
                    AreaMark(
                        x: .value("日期", p.date, unit: .day),
                        y: .value("正确率", p.accuracy * 100)
                    )
                    .foregroundStyle(LinearGradient(colors: [Theme.success.opacity(0.28), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                    LineMark(
                        x: .value("日期", p.date, unit: .day),
                        y: .value("正确率", p.accuracy * 100)
                    )
                    .foregroundStyle(Theme.success)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    PointMark(
                        x: .value("日期", p.date, unit: .day),
                        y: .value("正确率", p.accuracy * 100)
                    )
                    .foregroundStyle(Theme.success)
                    .symbolSize(18)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                .frame(height: 120)
            }
        }
        .padding(16)
        .glass(radius: 20)
    }

    // MARK: 类别强弱

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("按类别看掌握")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("正确率低的排前面")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
            if report.categories.isEmpty {
                Text("做过方法练习后，这里会按七大类拆分强弱。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            } else {
                ForEach(report.categories, id: \.id) { cat in
                    VStack(spacing: 5) {
                        HStack {
                            Text(cat.name)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(Int(cat.accuracy * 100))% · \(cat.total) 题")
                                .font(.system(size: 11, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textFaint)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.07))
                                Capsule()
                                    .fill(Theme.tint(cat.id))
                                    .frame(width: max(4, geo.size.width * cat.accuracy))
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
        .padding(16)
        .glass(radius: 20)
    }

    // MARK: 需要补的方法

    private var weakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("该补的方法")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            if report.weakMethods.isEmpty {
                Text("暂时没有明显薄弱的环节。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            } else {
                ForEach(report.weakMethods.prefix(4), id: \.methodId) { item in
                    HStack(spacing: 10) {
                        Text("\(Int(item.accuracy * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(item.accuracy < 0.6 ? Theme.danger : Theme.warn)
                            .frame(width: 42, alignment: .leading)
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.total) 题")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
            }
        }
        .padding(16)
        .glass(radius: 20)
    }

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text("这周先做这件事")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            Text(advice)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(4)
        }
        .padding(16)
        .glass(radius: 18)
    }

    private var advice: String {
        let r = report
        if let weak = r.weakMethods.first, weak.accuracy < 0.7 {
            return "「\(weak.name)」正确率只有 \(Int(weak.accuracy * 100))%，把它当本周主攻目标：先重做错题，再用 L1 刷到 90%，最后上 L3 编码。"
        }
        if r.sessions == 0 {
            return "本周还没有训练。先设一个每日 1 关的下限，比立志每天 10 关更管用——门槛低才容易连续。"
        }
        if r.sessionsDelta < 0 {
            return "比上周少了 \(abs(r.sessionsDelta)) 次。把训练挂在已有习惯后面（早咖啡、通勤、睡前），比单靠意志力靠得住。"
        }
        if r.accuracy < 0.8 {
            return "训练量够了，但正确率只有 \(Int(r.accuracy * 100))%。降低难度、把错题吃透，比刷更多新题有效。"
        }
        return "节奏稳、正确率也高。可以开始冲星：挑两个已学的方法把没满 80% 的那一阶补上，或去闯关地图开新章。"
    }
}
