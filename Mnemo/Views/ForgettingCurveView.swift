import SwiftUI
import Charts

struct ForgettingCurveView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private struct Point: Identifiable {
        let id = UUID()
        let day: Double
        let retention: Double
        let series: String
    }

    /// 不复习：稳定性 1 天
    private var decayPoints: [Point] {
        stride(from: 0.0, through: 30.0, by: 0.5).map { t in
            Point(day: t, retention: ReviewLadder.retention(dayOffset: t, stability: 1.0), series: "不复习")
        }
    }

    /// 按阶梯复习：每次复习后稳定性翻倍
    private var reviewedPoints: [Point] {
        let reviews: [Double] = [0, 0.02, 0.5, 1, 2, 4, 7, 15, 30]
        var result: [Point] = []
        for (i, start) in reviews.enumerated() {
            let end = i + 1 < reviews.count ? reviews[i + 1] : 31
            let stability = pow(2.4, Double(i)) * 0.8
            var t = start
            while t < end {
                result.append(Point(day: t,
                                    retention: ReviewLadder.retention(dayOffset: t - start, stability: stability),
                                    series: "按阶梯复习"))
                t += 0.25
            }
        }
        return result
    }

    private var reviewMarks: [Point] {
        [0, 1, 2, 4, 7, 15].map { d in
            Point(day: Double(d), retention: 1, series: "复习点")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                curveCard
                retentionCard
                ladderCard
                dueCard
                noteCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("遗忘曲线")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("艾宾浩斯：遗忘先快后慢，复习要卡在快忘的时候")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()
            Button {
                Haptic.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSub)
                    .frame(width: 34, height: 34)
                    .glass(radius: 12)
            }
            .padding(.top, 4)
        }
        .padding(.top, 12)
    }

    private var curveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                legendDot("不复习", color: Theme.danger.opacity(0.8))
                legendDot("按阶梯复习", color: Theme.success)
                Spacer()
            }
            Chart {
                ForEach(decayPoints) { p in
                    LineMark(x: .value("天", p.day), y: .value("保持率", p.retention),
                             series: .value("曲线", p.series))
                        .foregroundStyle(by: .value("曲线", p.series))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
                ForEach(reviewedPoints) { p in
                    LineMark(x: .value("天", p.day), y: .value("保持率", p.retention),
                             series: .value("曲线", p.series))
                        .foregroundStyle(by: .value("曲线", p.series))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.4))
                }
                ForEach(reviewMarks) { p in
                    PointMark(x: .value("天", p.day), y: .value("保持率", p.retention))
                        .foregroundStyle(Theme.accent)
                        .symbolSize(28)
                }
            }
            .chartForegroundStyleScale(["不复习": Theme.danger.opacity(0.8), "按阶梯复习": Theme.success])
            .chartLegend(.hidden)
            .chartYScale(domain: 0...1.05)
            .chartYAxis {
                AxisMarks(values: [0, 0.5, 1]) { value in
                    AxisGridLine().foregroundStyle(Theme.veil(0.06))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v * 100))%")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 1, 2, 4, 7, 15, 30]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v == 0 ? "学完" : "\(Int(v)) 天")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
            }
            .frame(height: 200)

            Text("虚线是“学完就不管”，一天后只剩三成；实线是每到一个节点就复习一次，同样的内容能拖到一个月后仍在八成以上。")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(3)
        }
        .padding(15)
        .glass(radius: 20)
    }

    private func legendDot(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSub)
        }
    }

    private var retentionCard: some View {
        let avg = store.averageRetention()
        return HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: avg, lineWidth: 8, tint: avg >= 0.7 ? Theme.success : Theme.warn)
                    .frame(width: 74, height: 74)
                Text("\(Int(avg * 100))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("当前平均保持率")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(avg >= 0.7
                     ? "记忆还在高温区，按现在的节奏复习就行"
                     : "已经滑到快忘的区间，今天优先清复习队列")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSub)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("基于每张卡的复习间隔与上次复习时间估算")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .glass(radius: 20)
    }

    private var ladderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("复习阶梯")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("新学的卡片按这条阶梯排期，答得越稳，下一次间隔越长。")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSub)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(ReviewLadder.steps) { s in
                        VStack(spacing: 3) {
                            Text(s.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.text)
                            Text("第\(s.index + 1)次")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.textFaint)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Theme.accent.opacity(0.10 + Double(s.index) * 0.012))
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(15)
        .glass(radius: 20)
    }

    private var dueCard: some View {
        let buckets = store.dueBuckets()
        let maxCount = max(1, buckets.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("复习到期分布")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("共 \(store.cards.count) 张卡")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
            }
            ForEach(buckets, id: \.label) { b in
                HStack(spacing: 10) {
                    Text(b.label)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textSub)
                        .frame(width: 46, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.veil(0.06))
                            Capsule()
                                .fill(b.tint.opacity(0.8))
                                .frame(width: max(3, geo.size.width * Double(b.count) / Double(maxCount)))
                        }
                    }
                    .frame(height: 6)
                    Text("\(b.count)")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(b.count > 0 ? Theme.text : Theme.textFaint)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(15)
        .glass(radius: 20)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                Text("怎么用这套机制")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            Text("① 新学的当天一定要回看一次（5 分钟 / 30 分钟节点）；② 隔天再提取一次，比当天多读三遍更有效；③ 答不出来的卡会自动缩短间隔，回到队列里；④ 别在疲劳时硬刷，睡眠本身是巩固过程。")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 18)
    }
}
