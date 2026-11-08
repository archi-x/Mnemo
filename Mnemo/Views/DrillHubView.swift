import SwiftUI

struct DrillHubView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showWordFlash = false
    @State private var showNumber = false
    @State private var showPalace = false
    @State private var showLibrary = false
    @State private var showWrongBook = false
    @State private var showCurve = false
    @State private var showCalendar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("训练场")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("六类关卡，从编码练到提取，练错自动进错题本")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                    .padding(.top, 10)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        DrillCard(title: "词表闪记", subtitle: "联想 · 故事链", symbol: "text.word.spacing",
                                  tint: Theme.tint("code"), best: store.best[CardKind.word.rawValue]) {
                            showWordFlash = true
                        }
                        DrillCard(title: "数字桩", subtitle: "组块 · 形象", symbol: "number",
                                  tint: Theme.tint("seq"), best: store.best[CardKind.number.rawValue]) {
                            showNumber = true
                        }
                        DrillCard(title: "记忆宫殿", subtitle: "定位 · 路线", symbol: "building.columns.fill",
                                  tint: Theme.tint("space"), best: store.best[CardKind.palace.rawValue]) {
                            showPalace = true
                        }
                        DrillCard(title: "方法练习", subtitle: "40 法 · 三阶题型", symbol: "book.closed.fill",
                                  tint: Theme.tint("struct"), best: nil) {
                            showLibrary = true
                        }
                        DrillCard(title: "错题强化", subtitle: store.wrongItems.isEmpty ? "暂无错题" : "\(store.wrongItems.count) 题待强化",
                                  symbol: "repeat.circle.fill", tint: Theme.tint("review"),
                                  best: nil) {
                            showWrongBook = true
                        }
                        DrillCard(title: "遗忘曲线", subtitle: "艾宾浩斯排期", symbol: "chart.line.downtrend.xyaxis",
                                  tint: Theme.tint("deep"), best: nil) {
                            showCurve = true
                        }
                    }

                    weekCard

                    recordsSection

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "训练建议")
                        Text("每个关卡都是「看完立刻回忆」：先编码（把信息变成图像或位置），再遮住材料主动提取。答错的词不要重看，先猜，再核对——猜测本身就是提取练习。\n\n方法练习里的选择题答错会自动进错题本，答对两次才出库；每张卡按艾宾浩斯阶梯排下一次复习。")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSub)
                            .lineSpacing(3)
                            .padding(16)
                            .glass(radius: 18)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showWordFlash) { WordFlashView() }
            .fullScreenCover(isPresented: $showNumber) { NumberRunView() }
            .fullScreenCover(isPresented: $showPalace) { PalaceDrillView() }
            .fullScreenCover(isPresented: $showLibrary) { LibraryView(modal: true) }
            .fullScreenCover(isPresented: $showWrongBook) { WrongBookView() }
            .fullScreenCover(isPresented: $showCurve) { ForgettingCurveView() }
            .sheet(isPresented: $showCalendar) { CalendarView() }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return }
                switch args[i + 1] {
                case "number": showNumber = true
                case "palace": showPalace = true
                case "wrong": showWrongBook = true
                case "curve": showCurve = true
                case "calendar": showCalendar = true
                default: break
                }
            }
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "最近 7 天", trailing: "日历") { showCalendar = true }
            WeekStrip(onTap: { showCalendar = true })
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近记录")
            if store.records.isEmpty {
                EmptyHint(symbol: "chart.line.uptrend.xyaxis",
                          title: "还没有训练记录",
                          detail: "从上面挑一关，3 分钟就能留下第一条曲线")
                    .glass(radius: 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.records.prefix(5).enumerated()), id: \.element.id) { i, r in
                        HStack(spacing: 12) {
                            Image(systemName: r.kind.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(r.kind.label) · \(r.correct)/\(r.total)")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Text(r.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textFaint)
                            }
                            Spacer()
                            Text("\(Int(r.score * 100))%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(r.score >= 0.8 ? Theme.success
                                                 : (r.score >= 0.5 ? Theme.warn : Theme.danger))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        if i < min(4, store.records.count - 1) {
                            Rectangle().fill(Theme.stroke).frame(height: 0.7).padding(.leading, 53)
                        }
                    }
                }
                .glass(radius: 18)
            }
        }
    }
}

private struct DrillCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let best: Double?
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap(.medium)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    IconBadge(symbol: symbol, tint: tint, size: 38)
                    Spacer()
                    if let best {
                        Text("\(Int(best * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.16), Color.white.opacity(0.03)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(tint.opacity(0.20), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
