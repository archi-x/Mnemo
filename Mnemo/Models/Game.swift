import Foundation

// MARK: - 学员等级（XP 驱动）

/// 用户等级：由累计 XP 决定，用于推荐题型与同级别排名分组。
struct LearnerLevel: Hashable {
    let index: Int
    let name: String
    let minXP: Int
    let nextXP: Int

    /// 达到第 level 级所需的累计 XP（1 级为 0）
    static func threshold(for level: Int) -> Int {
        guard level > 1 else { return 0 }
        var sum = 0
        for l in 1..<level { sum += 80 * l }
        return sum
    }

    static func level(forXP xp: Int) -> Int {
        var lv = 1
        while lv < 30 && xp >= threshold(for: lv + 1) { lv += 1 }
        return lv
    }

    private static let titles = ["记性新手", "图像学徒", "联想学徒", "路线行人", "宫殿门客",
                                 "编码熟手", "提取好手", "迁移能手", "记忆剑客", "自动化大师"]

    static func current(xp: Int) -> LearnerLevel {
        let lv = level(forXP: xp)
        let title = titles[min(lv - 1, titles.count - 1)]
        let base = threshold(for: lv)
        let next = threshold(for: lv + 1)
        return LearnerLevel(index: lv, name: title, minXP: base,
                            nextXP: max(next, base + 1))
    }
}

/// XP 进度（避免在 LearnerLevel 里存当前 xp）
struct XPProgress {
    let xp: Int
    let level: LearnerLevel

    init(xp: Int) {
        self.xp = max(0, xp)
        level = LearnerLevel.current(xp: self.xp)
    }

    var progress: Double {
        let span = max(1, level.nextXP - level.minXP)
        return min(1, max(0, Double(xp - level.minXP) / Double(span)))
    }

    var toNext: Int { max(0, level.nextXP - xp) }
}

// MARK: - 题型偏好（按学员等级推荐）

extension LearnerLevel {
    /// 低等级先练认得出、分得清；高等级直接上案例辨析与真材料编码
    var preferredKinds: [ExerciseKind] {
        switch index {
        case 1: return [.definition, .category, .step]
        case 2: return [.definition, .category, .step, .principle]
        case 3: return [.step, .material, .order, .category]
        case 4: return [.material, .pitfall, .order, .principle]
        default: return [.caseMatch, .apply, .order, .principle]
        }
    }

    /// 推荐练习的方法数量与每题难度
    var sessionSize: Int {
        switch index {
        case 1: return 5
        case 2: return 6
        case 3: return 7
        case 4: return 8
        default: return 9
        }
    }

    /// 这个等级适合从第几阶开始
    var startLevel: Int {
        switch index {
        case 1, 2: return 1
        case 3, 4: return 2
        default: return 3
        }
    }
}

// MARK: - 智能推荐

struct Recommendation: Identifiable, Hashable {
    enum Kind: String {
        case wrong      // 错题强化
        case review     // 到期复习
        case weak       // 薄弱补练
        case star       // 冲星
        case fresh      // 学新法
        case levelUp    // 升级挑战

        var label: String {
            switch self {
            case .wrong: return "错题优先"
            case .review: return "该复习了"
            case .weak: return "补漏洞"
            case .star: return "再拿一星"
            case .fresh: return "开新法"
            case .levelUp: return "升级挑战"
            }
        }

        var symbol: String {
            switch self {
            case .wrong: return "repeat.circle.fill"
            case .review: return "clock.badge.checkmark"
            case .weak: return "exclamationmark.triangle.fill"
            case .star: return "star.leadinghalf.filled"
            case .fresh: return "sparkles"
            case .levelUp: return "arrow.up.forward.circle.fill"
            }
        }
    }

    var id: String
    var kind: Kind
    var title: String
    var reason: String
    var methodId: Int?
    var level: Int
    var categoryId: String
    var priority: Int
}

// MARK: - 目标计划

struct Goal: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case dailySessions   // 每日训练关数
        case weeklySessions  // 每周训练关数
        case streak          // 连续天数
        case stars           // 收集星数
        case accuracy        // 平均正确率
        case methodCount     // 掌握方法数

        var title: String {
            switch self {
            case .dailySessions: return "每日训练"
            case .weeklySessions: return "每周训练"
            case .streak: return "连续打卡"
            case .stars: return "收集星星"
            case .accuracy: return "正确率"
            case .methodCount: return "掌握方法"
            }
        }

        var unit: String {
            switch self {
            case .dailySessions: return "关/天"
            case .weeklySessions: return "关/周"
            case .streak: return "天"
            case .stars: return "颗"
            case .accuracy: return "%"
            case .methodCount: return "个"
            }
        }

        var symbol: String {
            switch self {
            case .dailySessions: return "bolt.fill"
            case .weeklySessions: return "calendar"
            case .streak: return "flame.fill"
            case .stars: return "star.fill"
            case .accuracy: return "target"
            case .methodCount: return "books.vertical.fill"
            }
        }

        var presets: [Int] {
            switch self {
            case .dailySessions: return [1, 3, 5]
            case .weeklySessions: return [5, 15, 25]
            case .streak: return [3, 7, 21]
            case .stars: return [10, 30, 60]
            case .accuracy: return [70, 80, 90]
            case .methodCount: return [5, 10, 20]
            }
        }
    }

    var id: String = UUID().uuidString
    var kind: Kind
    var target: Int
    var createdAt: Date = Date()

    var title: String { kind.title }
    var unit: String { kind.unit }
    var symbol: String { kind.symbol }
}

struct GoalProgress {
    let goal: Goal
    let current: Int
    let target: Int

    var ratio: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(current) / Double(target))
    }

    var done: Bool { current >= target }
    var remaining: Int { max(0, target - current) }

    var displayCurrent: String {
        goal.kind == .accuracy ? "\(current)" : "\(current)"
    }
}

// MARK: - 学习报告

struct WeekReport {
    var sessions: Int = 0
    var correct: Int = 0
    var total: Int = 0
    var minutes: Int = 0
    var activeDays: Int = 0
    var xp: Int = 0

    var prevSessions: Int = 0
    var prevAccuracy: Double = 0
    var prevXP: Int = 0

    var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }
    var sessionsDelta: Int { sessions - prevSessions }
    var accuracyDelta: Double { accuracy - prevAccuracy }

    /// 每日训练量（近 14 天：前 7 天对照 + 后 7 天本周）
    var daily: [(date: Date, count: Int, accuracy: Double)] = []
    /// 类别正确率（薄弱优先）
    var categories: [(id: String, name: String, accuracy: Double, total: Int)] = []
    /// 需要补的方法
    var weakMethods: [(methodId: Int, name: String, accuracy: Double, total: Int)] = []
    /// 本周拿到的星
    var stars: Int = 0
}

// MARK: - 同级别排名

struct LeaderboardRow: Identifiable, Hashable {
    var id: String
    var name: String
    var xp: Int
    var sessions: Int
    var accuracy: Double
    var isMe: Bool
    var rank: Int = 0
}

// MARK: - 演示用昵称池

enum PeerNames {
    static let pool = [
        "杏仁核打工人", "海马体不睡", "遗忘曲线本人", "宫殿看门人", "联想小卖部",
        "七秒记忆鱼", "背了就忘", "记忆面包屑", "图像派阿May", "路线规划师",
        "桩子不歪", "编码小工", "复述狂人", "间隔重复君", "夜读的三三",
        "把书合上", "默写小队长", "记忆宫殿保洁", "脑内电影院", "联想永动机",
        "记性慢慢", "单词钉子户", "背多分", "碎片收纳师", "睡前过一遍",
        "小步快跑", "今日事今日背", "回忆触发点", "编号控", "一分钟先生"
    ]
}
