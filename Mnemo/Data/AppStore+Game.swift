import Foundation
import SwiftUI

// MARK: - 等级、星图、推荐、目标、报告、榜单

extension AppStore {

    // MARK: XP 与等级

    var xpProgress: XPProgress { XPProgress(xp: xp) }
    var learnerLevel: LearnerLevel { xpProgress.level }

    var todayXP: Int { xpByDay[Self.dayKey(Date())] ?? 0 }

    var weekXP: Int {
        let cal = Calendar.current
        return (0..<7).reduce(0) { acc, off in
            guard let d = cal.date(byAdding: .day, value: -off, to: Date()) else { return acc }
            return acc + (xpByDay[Self.dayKey(d)] ?? 0)
        }
    }

    /// 训练结算时统一加经验；跨级时置起升级提示
    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        let before = LearnerLevel.level(forXP: xp)
        xp += amount
        let key = Self.dayKey(Date())
        xpByDay[key, default: 0] += amount
        let after = LearnerLevel.level(forXP: xp)
        if after > before {
            pendingLevelUp = after
            Haptic.success()
        }
    }

    // MARK: 星星与闯关地图

    /// 单个方法拿到的星：每阶最好成绩 ≥ 80% 记一颗
    func stars(for methodId: Int) -> Int {
        (1...3).reduce(0) { acc, lv in
            acc + ((best["method-\(methodId)-L\(lv)"] ?? 0) >= 0.8 ? 1 : 0)
        }
    }

    /// 统一口径：星数按分学龄段闯关计
    var totalStars: Int { questTotalStars }

    var maxStars: Int { questMaxStars }

    /// 方法本身的掌握阶数（0–3），用于推荐难度
    func methodLevel(_ methodId: Int) -> Int {
        var lv = 0
        for l in 1...3 where (best["method-\(methodId)-L\(l)"] ?? 0) >= 0.6 { lv = l }
        if lv == 0 && learnedMethods.contains(methodId) { lv = 1 }
        return lv
    }

    // MARK: 智能推荐

    func recommendations(limit: Int = 4) -> [Recommendation] {
        var items: [Recommendation] = []
        let learner = learnerLevel.index

        // 1. 错题：按方法聚合，反复错的排更前
        let grouped = Dictionary(grouping: wrongItems, by: { $0.exercise.methodId })
        for (mid, list) in grouped {
            guard let m = method(mid) else { continue }
            let repeated = list.filter { $0.count >= 2 }.count
            items.append(Recommendation(
                id: "wrong-\(mid)",
                kind: .wrong,
                title: "重做「\(m.name)」的错题",
                reason: repeated > 0 ? "\(list.count) 题待强化，\(repeated) 题反复错" : "\(list.count) 题待强化",
                methodId: mid,
                level: max(1, methodLevel(mid)),
                categoryId: m.categoryId,
                priority: 120 + list.count * 12 + repeated * 18))
        }

        // 2. 到期复习
        let due = dueCards.count
        if due >= 3 {
            items.append(Recommendation(
                id: "review", kind: .review,
                title: "清掉 \(due) 张到期复习卡",
                reason: "间隔重复的窗口已经打开，现在复习成本最低",
                methodId: nil, level: learner, categoryId: "review",
                priority: 90 + min(40, due * 2)))
        }

        // 3. 薄弱方法（做过的题里正确率低的）
        for (key, stat) in methodStats {
            guard let mid = Int(key), stat.total >= 3, stat.accuracy < 0.75,
                  let m = method(mid) else { continue }
            items.append(Recommendation(
                id: "weak-\(mid)", kind: .weak,
                title: "补练「\(m.name)」",
                reason: "最近正确率 \(Int(stat.accuracy * 100))%，是该补的洞",
                methodId: mid, level: max(1, methodLevel(mid)),
                categoryId: m.categoryId,
                priority: 80 + Int((0.75 - stat.accuracy) * 100)))
        }

        // 4. 差一星就能收满的方法
        for m in catalog.methods {
            let s = stars(for: m.id)
            guard s > 0, s < 3 else { continue }
            items.append(Recommendation(
                id: "star-\(m.id)", kind: .star,
                title: "再拿一星：\(m.name)",
                reason: "已经 \(s) 星，把没满 80% 的那一阶补上",
                methodId: m.id, level: max(1, methodLevel(m.id)),
                categoryId: m.categoryId,
                priority: 60 + s))
        }

        // 5. 没学过的方法里，优先按学员等级挑
        if let m = catalog.methods.first(where: { !learnedMethods.contains($0.id) }) {
            items.append(Recommendation(
                id: "fresh-\(m.id)", kind: .fresh,
                title: "新开一法：\(m.name)",
                reason: "按你当前 Lv.\(learner) 的题型偏好出题",
                methodId: m.id,
                level: min(3, max(1, learnerLevel.startLevel)),
                categoryId: m.categoryId,
                priority: 50))
        }

        // 6. 快到升级线时给一个挑战
        let toNext = xpProgress.toNext
        if toNext > 0 && toNext <= 60 {
            items.append(Recommendation(
                id: "levelup", kind: .levelUp,
                title: "再拿 \(toNext) XP 升级",
                reason: "Lv.\(learner) → Lv.\(learner + 1)，挑一关稳的刷",
                methodId: catalog.methods.randomElement()?.id,
                level: min(3, max(1, learnerLevel.startLevel)),
                categoryId: catalog.methods.randomElement()?.categoryId ?? "code",
                priority: 55))
        }

        return Array(items.sorted { $0.priority > $1.priority }.prefix(limit))
    }

    // MARK: 目标

    func goalProgress(_ goal: Goal) -> GoalProgress {
        let current: Int
        switch goal.kind {
        case .dailySessions:
            current = todayDone
        case .weeklySessions:
            let cal = Calendar.current
            current = (0..<7).reduce(0) { acc, off in
                guard let d = cal.date(byAdding: .day, value: -off, to: Date()) else { return acc }
                return acc + (dayStats[Self.dayKey(d)]?.sessions ?? 0)
            }
        case .streak:
            current = streak
        case .stars:
            current = totalStars
        case .accuracy:
            current = Int(stats.accuracy * 100)
        case .methodCount:
            current = learnedMethods.count
        }
        return GoalProgress(goal: goal, current: current, target: goal.target)
    }

    func addGoal(_ kind: Goal.Kind, target: Int) {
        guard !goals.contains(where: { $0.kind == kind }) else { return }
        goals.append(Goal(kind: kind, target: target))
        persist()
    }

    func removeGoal(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        persist()
    }

    /// 首次进入时给三个默认目标
    func seedDefaultGoals() {
        guard goals.isEmpty else { return }
        goals = [Goal(kind: .dailySessions, target: 3),
                 Goal(kind: .weeklySessions, target: 15),
                 Goal(kind: .streak, target: 7)]
        persist()
    }

    // MARK: 学习报告

    func weekReport() -> WeekReport {
        let cal = Calendar.current
        let now = Date()
        var r = WeekReport()

        func statsRange(from offset: Int, days: Int) -> (sessions: Int, correct: Int, total: Int, minutes: Int, active: Int, xp: Int) {
            var s = 0, c = 0, t = 0, m = 0, active = 0, x = 0
            for i in offset..<(offset + days) {
                guard let d = cal.date(byAdding: .day, value: -i, to: now) else { continue }
                let key = Self.dayKey(d)
                if let stat = dayStats[key] {
                    s += stat.sessions
                    c += stat.correct
                    t += stat.total
                    m += stat.minutes
                    if stat.sessions > 0 { active += 1 }
                }
                x += xpByDay[key] ?? 0
            }
            return (s, c, t, m, active, x)
        }

        let cur = statsRange(from: 0, days: 7)
        let prev = statsRange(from: 7, days: 7)

        r.sessions = cur.sessions
        r.correct = cur.correct
        r.total = cur.total
        r.minutes = cur.minutes
        r.activeDays = cur.active
        r.xp = cur.xp
        r.prevSessions = prev.sessions
        r.prevAccuracy = prev.total == 0 ? 0 : Double(prev.correct) / Double(prev.total)
        r.prevXP = prev.xp
        r.stars = totalStars

        r.daily = (0..<14).reversed().compactMap { off in
            guard let d = cal.date(byAdding: .day, value: -off, to: now) else { return nil }
            let stat = dayStats[Self.dayKey(d)]
            return (d, stat?.sessions ?? 0, stat?.accuracy ?? 0)
        }

        // 类别正确率
        var byCategory: [String: (c: Int, t: Int)] = [:]
        for (key, stat) in methodStats {
            guard let mid = Int(key), let m = method(mid) else { continue }
            var acc = byCategory[m.categoryId] ?? (0, 0)
            acc.c += stat.correct
            acc.t += stat.total
            byCategory[m.categoryId] = acc
        }
        r.categories = byCategory.compactMap { key, value in
            guard value.t > 0, let cat = catalog.categories.first(where: { $0.id == key }) else { return nil }
            return (key, cat.name, Double(value.c) / Double(value.t), value.t)
        }
        .sorted { $0.accuracy < $1.accuracy }

        // 薄弱方法
        r.weakMethods = methodStats.compactMap { key, stat in
            guard let mid = Int(key), stat.total >= 2, let m = method(mid) else { return nil }
            return (mid, m.name, stat.accuracy, stat.total)
        }
        .sorted { $0.accuracy < $1.accuracy }

        return r
    }

    // MARK: 同级别排名

    /// 离线榜：同一等级段里的虚拟同伴，按本周 XP 排序。数据固定可复现，不联网。
    func leaderboard() -> [LeaderboardRow] {
        let lv = learnerLevel
        let mine = weekXP
        let seed = UInt64(lv.index) &* 7919 &+ UInt64(max(1, mine / 20)) &+ 20261108
        var rng = SeededRandom(seed: seed)

        var rows: [LeaderboardRow] = []
        let count = 8
        for i in 0..<count {
            let nameIndex = (Int(rng.next() % UInt64(PeerNames.pool.count)) + i * 3) % PeerNames.pool.count
            let factor = 0.35 + rng.double() * 1.55
            let peerXP = max(6, Int(Double(max(mine, 40)) * factor))
            let sessions = max(1, peerXP / 34)
            let accuracy = min(0.99, 0.55 + rng.double() * 0.42)
            rows.append(LeaderboardRow(id: "peer-\(i)", name: PeerNames.pool[nameIndex],
                                       xp: peerXP, sessions: sessions,
                                       accuracy: accuracy, isMe: false))
        }
        rows.append(LeaderboardRow(id: "me", name: "我（Lv.\(lv.index) \(lv.name)）",
                                   xp: mine, sessions: max(1, weekXP / 34),
                                   accuracy: stats.accuracy, isMe: true))
        rows.sort { $0.xp > $1.xp }
        for i in rows.indices { rows[i].rank = i + 1 }
        return rows
    }

    func myRank() -> (rank: Int, total: Int, percentile: Int) {
        let rows = leaderboard()
        guard let idx = rows.firstIndex(where: { $0.isMe }) else { return (0, rows.count, 0) }
        let pct = Int(Double(rows.count - idx) / Double(rows.count) * 100)
        return (idx + 1, rows.count, pct)
    }
}

// MARK: - 可复现随机数（离线榜与演示数据用）

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func double() -> Double { Double(next() % 1000) / 1000.0 }
}
