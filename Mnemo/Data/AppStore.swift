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
    @Published var xp: Int = 0
    @Published var xpByDay: [String: Int] = [:]
    @Published var goals: [Goal] = []
    @Published var methodStats: [String: DayStat] = [:]
    @Published var questStars: [String: Int] = [:]
    @Published var profile: Profile?
    @Published var appearance: Appearance = .night
    /// 数据放哪：本机 / iCloud（用户随时可切）
    @Published var storageMode: StorageMode = .local
    /// 最近一次成功推到 iCloud 的时间
    @Published var lastSyncedAt: Date?
    /// 同步遇到问题时的说明（配额超限等）
    @Published var cloudNote: String?
    @Published var isUnlocked = false
    @Published var pendingLevelUp: Int?
    @Published var snapshotVersion = 0

    /// 本机文件里那份快照的时间戳，用来和 iCloud 比较谁新
    var lastLocalSave: Date?

    /// 串行写盘队列：保证写入顺序，避免旧快照覆盖新快照
    private let saveQueue = DispatchQueue(label: "com.tal.mnemo.persist", qos: .utility)

    init() {
        catalog = Self.loadCatalog()
        words = Self.loadWords()
        CloudStore.prepare()
        load()
        seedDefaultGoals()
        restoreSession()
        startCloudObservers()
        verifyAppleCredential()
        // 上次已经选了 iCloud、这次启动还没同步过（换机后第一次打开就是这个状态）：补一次上传
        if storageMode == .iCloud, CloudStore.isAvailable, lastSyncedAt == nil {
            persist()
        }
    }

    /// 启动时的解锁策略：没有档案 → 登录页；有档案且设了密码 → 锁屏；否则直接进入
    private func restoreSession() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-day") { appearance = .day }
        if args.contains("-night") { appearance = .night }
        if args.contains("-autoTheme") { appearance = .auto }
        #endif
        #if DEBUG
        // 截图/联调用：假装 iCloud 已可用，并造一个 Apple 档案
        if args.contains("-cloudReady"), storageMode == .local { storageMode = .iCloud }
        if args.contains("-seedApple") {
            let id = AppleAccount.demoIdentity()
            if var p = profile {
                p.appleUserID = id.userID
                p.appleEmail = id.email
                profile = p
            } else {
                profile = Profile(id: UUID().uuidString, nickname: id.name ?? "练习者",
                                  avatar: Profile.avatars[0], pinHash: nil, createdAt: Date(),
                                  appleUserID: id.userID, appleEmail: id.email)
            }
        }
        // 只清 Apple 绑定、保留数据：用来看「已有记录时」的登录门长什么样
        if args.contains("-gate") {
            if var p = profile {
                p.appleUserID = nil
                p.appleEmail = nil
                profile = p
            }
            isUnlocked = false
            return
        }
        if args.contains("-skipLogin") {
            let demo = AppleAccount.demoIdentity()
            if profile == nil {
                profile = Profile(id: UUID().uuidString, nickname: "林小满",
                                  avatar: Profile.avatars[0], pinHash: nil, createdAt: Date(),
                                  appleUserID: demo.userID, appleEmail: demo.email)
            } else if profile?.isAppleAccount != true, var p = profile {
                // 没有 Apple 身份现在进不去，截图/联调也要补一个
                p.appleUserID = demo.userID
                p.appleEmail = demo.email
                profile = p
            }
            isUnlocked = true
            return
        }
        if args.contains("-demoLocked") {
            let demo = AppleAccount.demoIdentity()
            if profile == nil {
                profile = Profile(id: UUID().uuidString, nickname: "林小满",
                                  avatar: Profile.avatars[0],
                                  pinHash: Profile.hash("2468"),
                                  createdAt: Date(),
                                  appleUserID: demo.userID, appleEmail: demo.email)
            }
            isUnlocked = false
            return
        }
        #endif
        guard let profile else {
            isUnlocked = false
            return
        }
        isUnlocked = !profile.hasPin
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

        // 经验：答对 2 XP/题，整组完成 +6，正确率 ≥ 90% 再 +6
        let score = total == 0 ? 0 : Double(correct) / Double(total)
        var gained = correct * 2
        if total > 0 { gained += 6 }
        if score >= 0.9 && total >= 3 { gained += 6 }
        addXP(gained)
    }

    func grade(cardID: String, quality: Int) {
        guard let idx = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cards[idx].grade(quality)
        addXP(quality >= 4 ? 4 : 1)
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
        xp = 0
        xpByDay = [:]
        methodStats = [:]
        goals = []
        pendingLevelUp = nil
        persist()
        seedDefaultGoals()
    }

    // MARK: 持久化

    struct Snapshot: Codable {
        var cards: [ReviewCard]
        var stats: Stats
        var best: [String: Double]
        var records: [DrillRecord]
        var learnedMethods: [Int]
        var completedPlanDays: [Int]
        var wrongItems: [WrongItem]
        var dayStats: [String: DayStat]
        var xp: Int
        var xpByDay: [String: Int]
        var goals: [Goal]
        var methodStats: [String: DayStat]
        var questStars: [String: Int]
        var profile: Profile?
        var appearance: Appearance
        /// 这份快照写出去的时间，用来和 iCloud 上那份比谁新
        var savedAt: Date?
        var storageMode: StorageMode

        enum CodingKeys: String, CodingKey {
            case cards, stats, best, records, learnedMethods, completedPlanDays, wrongItems, dayStats
            case xp, xpByDay, goals, methodStats, questStars, profile, appearance
            case savedAt, storageMode
        }

        init(cards: [ReviewCard], stats: Stats, best: [String: Double], records: [DrillRecord],
             learnedMethods: [Int], completedPlanDays: [Int],
             wrongItems: [WrongItem], dayStats: [String: DayStat],
             xp: Int, xpByDay: [String: Int], goals: [Goal],
             methodStats: [String: DayStat], questStars: [String: Int], profile: Profile?,
             appearance: Appearance,
             savedAt: Date? = nil, storageMode: StorageMode = .local) {
            self.savedAt = savedAt
            self.storageMode = storageMode
            self.cards = cards
            self.stats = stats
            self.best = best
            self.records = records
            self.learnedMethods = learnedMethods
            self.completedPlanDays = completedPlanDays
            self.wrongItems = wrongItems
            self.dayStats = dayStats
            self.xp = xp
            self.xpByDay = xpByDay
            self.goals = goals
            self.methodStats = methodStats
            self.questStars = questStars
            self.profile = profile
            self.appearance = appearance
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
            xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
            xpByDay = try c.decodeIfPresent([String: Int].self, forKey: .xpByDay) ?? [:]
            goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
            methodStats = try c.decodeIfPresent([String: DayStat].self, forKey: .methodStats) ?? [:]
            questStars = try c.decodeIfPresent([String: Int].self, forKey: .questStars) ?? [:]
            profile = try c.decodeIfPresent(Profile.self, forKey: .profile)
            appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .night
            savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt)
            storageMode = try c.decodeIfPresent(StorageMode.self, forKey: .storageMode) ?? .local
        }
    }

    var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("mnemo_state.json")
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            apply(snap)
        }
        // 换设备后第一次打开：iCloud 上那份更新就以它为准
        if storageMode == .iCloud, CloudStore.isAvailable {
            _ = adoptCloudIfNewer()
        }
    }

    /// 把一份快照灌进内存（本机与 iCloud 共用同一入口）
    func apply(_ snap: Snapshot) {
        cards = snap.cards
        stats = snap.stats
        best = snap.best
        records = snap.records
        learnedMethods = Set(snap.learnedMethods)
        completedPlanDays = Set(snap.completedPlanDays)
        wrongItems = snap.wrongItems
        dayStats = snap.dayStats
        xp = snap.xp
        xpByDay = snap.xpByDay
        goals = snap.goals
        methodStats = snap.methodStats
        questStars = snap.questStars
        profile = snap.profile
        appearance = snap.appearance
        storageMode = snap.storageMode
        lastLocalSave = snap.savedAt
    }

    func persist() {
        let now = Date()
        let snap = Snapshot(cards: cards, stats: stats, best: best, records: records,
                            learnedMethods: Array(learnedMethods),
                            completedPlanDays: Array(completedPlanDays),
                            wrongItems: wrongItems,
                            dayStats: dayStats,
                            xp: xp, xpByDay: xpByDay, goals: goals,
                            methodStats: methodStats,
                            questStars: questStars,
                            profile: profile,
                            appearance: appearance,
                            savedAt: now,
                            storageMode: storageMode)
        writeLocal(snap)
        uploadToCloudIfNeeded(snap)
        snapshotVersion &+= 1
    }

    /// 只写本机。iCloud 上那份被采纳时也要走这里，离线才有数据可读。
    func writeLocal(_ snap: Snapshot) {
        let url = fileURL
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(snap) else { return }
            try? data.write(to: url, options: .atomic)
        }
        lastLocalSave = snap.savedAt
    }

    /// 选了 iCloud 时每次改动都推一份；压缩后仍超配额就只留本机，并在界面上说清
    private func uploadToCloudIfNeeded(_ snap: Snapshot) {
        guard storageMode == .iCloud, CloudStore.isAvailable else { return }
        guard let data = try? JSONEncoder().encode(snap) else { return }
        let stamp = snap.savedAt ?? Date()
        if CloudStore.save(data, savedAt: stamp) {
            lastSyncedAt = stamp
            cloudNote = nil
        } else {
            cloudNote = "数据超过 iCloud 单份上限，已只保留在本机"
        }
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
