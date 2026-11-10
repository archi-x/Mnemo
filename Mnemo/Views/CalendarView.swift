import SwiftUI

// MARK: - 学习日历

struct CalendarView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var monthOffset = 0
    @State private var selected: Date = Date()

    private let cal = Calendar.current
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    private var monthAnchor: Date {
        cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: monthAnchor)
    }

    private var days: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor),
              let firstWeekday = cal.dateComponents([.weekday], from: interval.start).weekday
        else { return [] }
        // 周一为第一列
        let leading = (firstWeekday + 5) % 7
        let dayCount = cal.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<dayCount {
            cells.append(cal.date(byAdding: .day, value: d, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var monthTrainedDays: Int {
        let prefix = "\(cal.component(.year, from: monthAnchor))-"
        let month = String(format: "%02d", cal.component(.month, from: monthAnchor))
        return store.dayStats.keys.filter { $0.hasPrefix(prefix + month) }.count
    }

    /// 当月汇总：天数、累计关数、单日峰值
    private var monthTotals: (days: Int, sessions: Int, peak: Int) {
        let prefix = "\(cal.component(.year, from: monthAnchor))-"
        let month = String(format: "%02d", cal.component(.month, from: monthAnchor))
        let stats = store.dayStats.filter { $0.key.hasPrefix(prefix + month) }.map(\.value)
        return (stats.count, stats.reduce(0) { $0 + $1.sessions }, stats.map(\.sessions).max() ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                monthCard
                legend
                dayDetail
                monthSummary
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas)
    }

    private var monthSummary: some View {
        let totals = monthTotals
        return HStack(spacing: 0) {
            summaryItem("训练天数", "\(totals.days) 天")
            Rectangle().fill(Theme.stroke).frame(width: 1, height: 26)
            summaryItem("累计训练", "\(totals.sessions) 次")
            Rectangle().fill(Theme.stroke).frame(width: 1, height: 26)
            summaryItem("单日最多", "\(totals.peak) 次")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glass(radius: 18)
    }

    private func summaryItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("学习日历")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("连续 \(store.streak) 天 · 本月已练 \(monthTrainedDays) 天")
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

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    Haptic.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { monthOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSub)
                        .frame(width: 30, height: 30)
                }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button {
                    Haptic.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { monthOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(monthOffset >= 0 ? Theme.textFaint.opacity(0.4) : Theme.textSub)
                        .frame(width: 30, height: 30)
                }
                .disabled(monthOffset >= 0)
            }

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.textFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(14)
        .glass(radius: 20)
    }

    private func dayCell(_ day: Date) -> some View {
        let stat = store.stat(on: day)
        let sessions = stat?.sessions ?? 0
        let isToday = cal.isDateInToday(day)
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let future = day > Date()
        let intensity = min(4, sessions)

        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { selected = day }
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(future ? Theme.textFaint.opacity(0.35) : (sessions > 0 ? Theme.text : Theme.textSub))
                Circle()
                    .fill(sessions > 0 ? Theme.accent.opacity(0.35 + Double(intensity) * 0.16) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(background(day, sessions: sessions, isToday: isToday, isSelected: isSelected))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(isSelected ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func background(_ day: Date, sessions: Int, isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return Theme.accent.opacity(0.16) }
        if sessions > 0 { return Theme.veil(0.05 + Double(min(3, sessions)) * 0.025) }
        if isToday { return Theme.veil(0.06) }
        return Color.clear
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("训练量")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
            ForEach(1...4, id: \.self) { i in
                Circle()
                    .fill(Theme.accent.opacity(0.35 + Double(i) * 0.16))
                    .frame(width: 6, height: 6)
            }
            Spacer()
            Text("点某一天看明细")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, 4)
    }

    private var dayDetail: some View {
        let stat = store.stat(on: selected)
        let list = store.records(on: selected)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(dateTitle(selected))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if let stat {
                    Text("\(stat.sessions) 次 · 正确率 \(Int(stat.accuracy * 100))%")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                }
            }

            if stat == nil {
                Text("这天没有训练记录。复习和练习都会记在这里。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
            } else if list.isEmpty {
                Text("有训练记录，但明细已超出最近 60 条，只保留统计。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, r in
                        HStack(spacing: 10) {
                            Image(systemName: r.kind.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 22)
                            Text("\(r.kind.label) \(r.correct)/\(r.total)")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text(r.date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textFaint)
                            Text("\(Int(r.score * 100))%")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(r.score >= 0.8 ? Theme.success : (r.score >= 0.5 ? Theme.warn : Theme.danger))
                        }
                        .padding(.vertical, 9)
                        if i < list.count - 1 {
                            Rectangle().fill(Theme.stroke).frame(height: 0.6)
                        }
                    }
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 18)
    }

    private func dateTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 EEE"
        return f.string(from: date)
    }
}

// MARK: - 最近七天条（首页 / 我的 共用）

struct WeekStrip: View {
    @EnvironmentObject private var store: AppStore
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(store.recentDays(7), id: \.date) { item in
                let sessions = item.stat?.sessions ?? 0
                let isToday = Calendar.current.isDateInToday(item.date)
                VStack(spacing: 5) {
                    Text(weekday(item.date))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.textFaint)
                    Text("\(Calendar.current.component(.day, from: item.date))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(sessions > 0 ? Theme.text : Theme.textFaint)
                    // 有训练就是一个实心点；没有就留一颗浅色小点，保持节奏不断行
                    Circle()
                        .fill(sessions > 0 ? Theme.accent : Theme.veil(0.14))
                        .frame(width: sessions > 0 ? 6 : 4, height: sessions > 0 ? 6 : 4)
                        .frame(height: 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isToday ? Theme.accent.opacity(0.14) : Theme.veil(0.03))
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.tap()
            onTap?()
        }
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }
}
