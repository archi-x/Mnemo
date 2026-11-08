import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var catalog: Catalog
    @Published private(set) var words: [String]
    @Published var cards: [ReviewCard] = []
    @Published var stats = Stats()
    @Published var best: [String: Double] = [:]
    @Published var records: [DrillRecord] = []
    @Published var learnedMethods: Set<Int> = []
    @Published var completedPlanDays: Set<Int> = []
    @Published var wrongItems: [WrongItem] = []
    @Published var dayStats: [String: DayStat] = [:]
    @Published var snapshotVersion = 0

    private var saveTask: Task<Void, Never>?

    init() {
        catalog = Self.loadCatalog()
        words = Self.loadWords()
        load()
    }

    // MARK: 内容加载

    private static func loadCatalog() -> Catalog {
        guard let url = Bundle.main.url(forResource: "methods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cat = try? JSONDecoder().decode(Catalog.self, from: data)
        else {
            return Catalog(version: 0, source: "", categories: [], methods: [],
                           diagnose: [], fixes: [], plan: [])
        }
        return cat
    }

    private static func loadWords() -> [String] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else { return ["灯塔", "齿轮", "雨伞", "陶罐", "地图"] }
        return list
    }

    // MARK: 查询

    func method(_ id: Int) -> Method? { catalog.methods.first { $0.id == id } }

    func methods(in category: String?) -> [Method] {
        guard let category else { return catalog.methods }
        return catalog.methods.filter { $0.categoryId == category }
    }

    var dueCards: [ReviewCard] {
        cards.filter { $0.isDue }.sorted { $0.due < $1.due }
    }

    var todayPlanDay: PlanDay? {
        let done = completedPlanDays.count
        return catalog.plan.first { $0.day == done + 1 } ?? catalog.plan.last
    }

    var streak: Int {
        let cal = Calendar.current
        let set = Set(stats.days)
        var day = Date()
        if !set.contains(Self.dayKey(day)) {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var count = 0
        while set.contains(Self.dayKey(day)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var precision: PrecisionLevel {
        PrecisionLevel.current(sessions: stats.sessions, accuracy: stats.accuracy)
    }

    var todayDone: Int {
        records.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    var dailyGoal: Int { 3 }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: 训练记录

    func finish(kind: CardKind, correct: Int, total: Int, seconds: Int, cards newCards: [ReviewCard]) {
        logSession(correct: correct, total: total, seconds: seconds)
        let score = total == 0 ? 0 : Double(correct) / Double(total)
        if score > (best[kind.rawValue] ?? -1) { best[kind.rawValue] = score }
        records.insert(DrillRecord(kind: kind, correct: correct, total: total, seconds: seconds), at: 0)
        if records.count > 60 { records.removeLast(records.count - 60) }
        cards.append(contentsOf: newCards)
        persist()
    }

    /// 统一的打卡与统计入口（各关卡、练习、复习都走这里）
    func logSession(correct: Int, total: Int, seconds: Int) {
        stats.sessions += 1
        stats.correctItems += correct
        stats.totalItems += total
        let key = Self.dayKey(Date())
        if stats.lastDay != key {
            stats.lastDay = key
            if !stats.days.contains(key) { stats.days.append(key) }
        }
        var stat = dayStats[key] ?? DayStat()
        stat.add(correct: correct, total: total, seconds: seconds)
        dayStats[key] = stat
    }

    func grade(cardID: String, quality: Int) {
        guard let idx = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cards[idx].grade(quality)
        let key = Self.dayKey(Date())
        if stats.lastDay != key {
            stats.lastDay = key
            if !stats.days.contains(key) { stats.days.append(key) }
        }
        persist()
    }

    func addCard(_ card: ReviewCard) {
        cards.append(card)
        persist()
    }

    func markMethodLearned(_ id: Int) {        guard !learnedMethods.contains(id) else { return }
        learnedMethods.insert(id)
        persist()
    }

    func completePlanDay(_ day: Int) {
        completedPlanDays.insert(day)
        persist()
    }

    func resetAll() {
        cards = []
        stats = Stats()
        best = [:]
        records = []
        learnedMethods = []
        completedPlanDays = []
        wrongItems = []
        dayStats = [:]
        persist()
    }

    // MARK: 持久化

    private struct Snapshot: Codable {
        var cards: [ReviewCard]
        var stats: Stats
        var best: [String: Double]
        var records: [DrillRecord]
        var learnedMethods: [Int]
        var completedPlanDays: [Int]
        var wrongItems: [WrongItem]
        var dayStats: [String: DayStat]

        enum CodingKeys: String, CodingKey {
            case cards, stats, best, records, learnedMethods, completedPlanDays, wrongItems, dayStats
        }

        init(cards: [ReviewCard], stats: Stats, best: [String: Double], records: [DrillRecord],
             learnedMethods: [Int], completedPlanDays: [Int],
             wrongItems: [WrongItem], dayStats: [String: DayStat]) {
            self.cards = cards
            self.stats = stats
            self.best = best
            self.records = records
            self.learnedMethods = learnedMethods
            self.completedPlanDays = completedPlanDays
            self.wrongItems = wrongItems
            self.dayStats = dayStats
        }

        /// 兼容旧版本存档：缺字段时用空值补齐
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            cards = try c.decodeIfPresent([ReviewCard].self, forKey: .cards) ?? []
            stats = try c.decodeIfPresent(Stats.self, forKey: .stats) ?? Stats()
            best = try c.decodeIfPresent([String: Double].self, forKey: .best) ?? [:]
            records = try c.decodeIfPresent([DrillRecord].self, forKey: .records) ?? []
            learnedMethods = try c.decodeIfPresent([Int].self, forKey: .learnedMethods) ?? []
            completedPlanDays = try c.decodeIfPresent([Int].self, forKey: .completedPlanDays) ?? []
            wrongItems = try c.decodeIfPresent([WrongItem].self, forKey: .wrongItems) ?? []
            dayStats = try c.decodeIfPresent([String: DayStat].self, forKey: .dayStats) ?? [:]
        }
    }

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("mnemo_state.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        cards = snap.cards
        stats = snap.stats
        best = snap.best
        records = snap.records
        learnedMethods = Set(snap.learnedMethods)
        completedPlanDays = Set(snap.completedPlanDays)
        wrongItems = snap.wrongItems
        dayStats = snap.dayStats
    }

    func persist() {
        let snap = Snapshot(cards: cards, stats: stats, best: best, records: records,
                            learnedMethods: Array(learnedMethods),
                            completedPlanDays: Array(completedPlanDays),
                            wrongItems: wrongItems,
                            dayStats: dayStats)
        let url = fileURL
        saveTask?.cancel()
        saveTask = Task.detached(priority: .background) {
            guard let data = try? JSONEncoder().encode(snap) else { return }
            try? data.write(to: url, options: .atomic)
        }
        snapshotVersion &+= 1
    }

    // MARK: 出题

    func randomWords(_ count: Int) -> [String] {
        Array(words.shuffled().prefix(count))
    }

    func randomDigits(_ count: Int) -> String {
        (0..<count).map { _ in String(Int.random(in: 0...9)) }.joined()
    }

    /// 词表判分：忽略标点与空格，允许写成近义片段
    static func judge(input: [String], target: [String]) -> (correct: Int, hits: [Bool]) {
        var pool = target
        var hits: [Bool] = []
        for raw in input {
            let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: " 、,，.。;；\n\t"))
            guard !token.isEmpty else { hits.append(false); continue }
            if let idx = pool.firstIndex(of: token) {
                pool.remove(at: idx)
                hits.append(true)
            } else {
                hits.append(false)
            }
        }
        return (hits.filter { $0 }.count, hits)
    }
}

// MARK: - 记忆宫殿路线

struct PalaceRoute: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let anchors: [String]

    static let all: [PalaceRoute] = [
        .init(id: "home", name: "我的家", subtitle: "10 个位置 · 最适合日常清单", anchors:
                ["玄关地毯", "鞋柜", "沙发", "茶几", "电视柜", "餐桌", "冰箱", "书桌", "衣柜", "阳台"]),
        .init(id: "commute", name: "上班路", subtitle: "8 个位置 · 适合流程与提纲", anchors:
                ["小区门口", "便利店", "地铁闸机", "站台", "车厢", "公司大堂", "电梯", "工位"]),
        .init(id: "classroom", name: "教室", subtitle: "6 个位置 · 适合课文与单词", anchors:
                ["讲台", "第一排课桌", "黑板", "窗台", "图书角", "后门"])
    ]
}
