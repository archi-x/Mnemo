import Foundation

// MARK: - 分学龄段闯关：星级、解锁、结算

extension AppStore {

    // MARK: 键与查询

    func questKey(_ stage: SchoolStage, _ node: Int, _ level: Int) -> String {
        "q-\(stage.rawValue)-\(node)-L\(level)"
    }

    /// 该关该档的历史最好正确率（0…1）
    func questScore(_ stage: SchoolStage, node: Int, level: Int) -> Double {
        Double(questStars[questKey(stage, node, level)] ?? 0) / 100
    }

    /// 该关某档是否已拿星（正确率 ≥ 80%）
    func questCleared(_ stage: SchoolStage, node: Int, level: Int) -> Bool {
        questScore(stage, node: node, level: level) >= 0.8
    }

    /// 一关拿到的星数（0–3，按三档）
    func nodeStars(_ stage: SchoolStage, node: Int) -> Int {
        (1...3).reduce(0) { $0 + (questCleared(stage, node: node, level: $1) ? 1 : 0) }
    }

    func stageStars(_ stage: SchoolStage) -> Int {
        (0..<QuestBank.nodes(for: stage).count).reduce(0) { $0 + nodeStars(stage, node: $1) }
    }

    var questMaxStars: Int {
        SchoolStage.allCases.reduce(0) { acc, stage in
            acc + QuestBank.nodes(for: stage).count * 3
        }
    }

    var questTotalStars: Int {
        SchoolStage.allCases.reduce(0) { $0 + stageStars($1) }
    }

    /// 第一关常开；前一关拿到任意一星就解锁下一关
    func nodeUnlocked(_ stage: SchoolStage, node: Int) -> Bool {
        guard node > 0 else { return true }
        return nodeStars(stage, node: node - 1) >= 1
    }

    /// 该学龄段下一个要打的关与难度
    func nextQuest(in stage: SchoolStage) -> (node: StageNodeSpec, level: Int)? {
        let nodes = QuestBank.nodes(for: stage)
        for spec in nodes where nodeUnlocked(stage, node: spec.index) {
            for lv in 1...3 where !questCleared(stage, node: spec.index, level: lv) {
                return (spec, lv)
            }
        }
        return nil
    }

    /// 最近在练的学龄段（有星且没打完的优先），否则从低年级开始
    func activeStage() -> SchoolStage {
        for stage in SchoolStage.allCases
        where stageStars(stage) > 0 && nextQuest(in: stage) != nil {
            return stage
        }
        return .primaryLow
    }

    /// 各学龄段完成度（用于主页卡片）
    func stageProgress(_ stage: SchoolStage) -> Double {
        let maxStars = QuestBank.nodes(for: stage).count * 3
        guard maxStars > 0 else { return 0 }
        return Double(stageStars(stage)) / Double(maxStars)
    }

    // MARK: 结算

    /// 记录一次闯关；返回是否拿到星、是否刷新该档最好成绩
    @discardableResult
    func recordQuest(_ r: QuestResult) -> (star: Bool, best: Bool) {
        let key = questKey(r.stage, r.nodeIndex, r.level)
        let pct = Int((r.accuracy * 100).rounded())
        let old = questStars[key] ?? -1
        let isBest = pct > old
        if isBest { questStars[key] = pct }

        // 经验：答对 2 XP + 过关奖励，闯关比普通练习略高
        var gain = r.correct * 2
        if r.passed { gain += 8 }
        if r.earnedStar && isBest { gain += 6 }
        addXP(gain)

        // 计入当日统计，日历与报告能看到闯关量
        let dayKey = Self.dayKey(Date())
        var stat = dayStats[dayKey] ?? DayStat()
        stat.add(correct: r.correct, total: r.total, seconds: r.seconds)
        dayStats[dayKey] = stat
        if !stats.days.contains(dayKey) { stats.days.append(dayKey) }

        Haptic.success()
        persist()
        return (r.earnedStar, isBest)
    }
}
