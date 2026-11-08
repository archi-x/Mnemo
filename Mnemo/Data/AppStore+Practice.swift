import Foundation
import SwiftUI

// MARK: - 出题引擎

extension AppStore {

    /// 每个方法三阶练习：初阶认概念、中阶辨材料与流程、高阶真材料编码
    func buildExercises(for method: Method, level: Int, count: Int? = nil) -> [Exercise] {
        let others = catalog.methods.filter { $0.id != method.id }
        var pool: [ExerciseKind]

        switch level {
        case 1: pool = [.definition, .category, .step, .principle, .definition]
        case 2: pool = [.material, .pitfall, .order, .caseMatch, .step]
        default: pool = [.apply, .caseMatch, .order, .material, .apply]
        }

        var result: [Exercise] = []
        var stepCursor = 0
        for (i, kind) in pool.enumerated() {
            if let c = count, i >= c { break }
            switch kind {
            case .definition:
                result.append(definitionExercise(method, others))
            case .step:
                result.append(stepExercise(method, others, index: stepCursor))
                stepCursor += 1
            case .material:
                result.append(materialExercise(method, others))
            case .pitfall:
                result.append(pitfallExercise(method, others))
            case .apply:
                result.append(applyExercise(method, level: level, variant: i))
            case .category:
                result.append(categoryExercise(method))
            case .principle:
                result.append(principleExercise(method, others))
            case .caseMatch:
                result.append(caseMatchExercise(method, others))
            case .order:
                result.append(orderExercise(method, others, index: stepCursor))
                stepCursor += 1
            }
        }
        return result
    }

    /// 按学员等级挑题型：低等级多认概念，高等级直接上案例辨析
    func buildAdaptiveExercises(for method: Method, learnerLevel: Int, count: Int) -> [Exercise] {
        let kinds2 = preferredKinds(forLearnerLevel: learnerLevel)
        let others = catalog.methods.filter { $0.id != method.id }
        var result: [Exercise] = []
        var stepCursor = 0
        for (i, kind) in kinds2.enumerated() {
            if i >= count { break }
            switch kind {
            case .definition: result.append(definitionExercise(method, others))
            case .category: result.append(categoryExercise(method))
            case .principle: result.append(principleExercise(method, others))
            case .step:
                result.append(stepExercise(method, others, index: stepCursor))
                stepCursor += 1
            case .material: result.append(materialExercise(method, others))
            case .pitfall: result.append(pitfallExercise(method, others))
            case .caseMatch: result.append(caseMatchExercise(method, others))
            case .order:
                result.append(orderExercise(method, others, index: stepCursor))
                stepCursor += 1
            case .apply: result.append(applyExercise(method, level: 3, variant: i))
            }
        }
        return result
    }

    func preferredKinds(forLearnerLevel level: Int) -> [ExerciseKind] {
        let kinds: [ExerciseKind]
        switch level {
        case 1: kinds = [.definition, .category, .step]
        case 2: kinds = [.definition, .category, .step, .principle]
        case 3: kinds = [.step, .category, .material, .order]
        case 4: kinds = [.material, .pitfall, .order, .principle]
        default: kinds = [.caseMatch, .order, .apply, .principle]
        }
        // 拉长成 6 题，避免题型过于重复
        return Array((kinds + kinds).prefix(6))
    }

    /// 给当前方法推荐的下一个难度
    func suggestedLevel(for method: Method) -> Int {
        let wrongs = wrongItems.filter { $0.exercise.methodId == method.id }.count
        if wrongs >= 2 { return 1 }
        let score = best["method-\(method.id)"] ?? 0
        if learnedMethods.contains(method.id) { return min(3, 2 + (score >= 0.9 ? 1 : 0)) }
        return 1
    }

    // MARK: 各题型

    private func definitionExercise(_ m: Method, _ others: [Method]) -> Exercise {
        let correct = m.definition
        let distractors = others.shuffled().prefix(6).map(\.definition).filter { $0 != correct }
        let made = makeChoice(correct: correct, distractors: Array(distractors), limit: 3)
        return Exercise(kind: .definition, level: 1, methodId: m.id,
                        prompt: "哪一条是「\(m.name)」的定义？",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "\(m.name)　\(m.definition)\n原理：\(m.principle)")
    }

    private func stepExercise(_ m: Method, _ others: [Method], index: Int) -> Exercise {
        guard m.steps.count > 1 else {
            return definitionExercise(m, others)
        }
        let pos = index % m.steps.count
        let correct = m.steps[pos]
        var distractors: [String] = []
        for other in others.shuffled() {
            if let s = other.steps.first(where: { $0 != correct }), !distractors.contains(s) {
                distractors.append(s)
            }
            if distractors.count >= 4 { break }
        }
        let made = makeChoice(correct: correct, distractors: distractors, limit: 3)
        return Exercise(kind: .step, level: 1, methodId: m.id,
                        prompt: "用「\(m.name)」时，第 \(pos + 1) 步应该做什么？",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "完整流程：" + m.steps.joined(separator: " → "))
    }

    private func materialExercise(_ m: Method, _ others: [Method]) -> Exercise {
        let correct = m.bestFor.first ?? "适合需要快速建立提取线索的材料"
        var distractors = m.notFor
        if distractors.count < 3 {
            for other in others.shuffled() where distractors.count < 3 {
                if let s = other.notFor.first, !distractors.contains(s) { distractors.append(s) }
            }
        }
        if distractors.count < 3 {
            distractors.append(contentsOf: ["完全没有顺序要求、也不需要回忆的长篇理论推导",
                                            "只需要读懂、不需要复述的休闲读物"])
        }
        let made = makeChoice(correct: correct, distractors: distractors, limit: 3)
        return Exercise(kind: .material, level: 2, methodId: m.id,
                        prompt: "下面哪种材料最适合用「\(m.name)」？",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "适合：\(m.bestFor.joined(separator: "；"))\n不适合：\(m.notFor.joined(separator: "；"))")
    }

    private func pitfallExercise(_ m: Method, _ others: [Method]) -> Exercise {
        let foreign = others.shuffled().compactMap { $0.steps.first }.first { !m.steps.contains($0) } ?? "把它当成阅读，看完就结束"
        let correct = foreign
        let real = Array(m.steps.shuffled().prefix(6)).filter { $0 != correct }
        let made = makeChoice(correct: correct, distractors: real, limit: 3)
        return Exercise(kind: .pitfall, level: 2, methodId: m.id,
                        prompt: "下面哪一步不属于「\(m.name)」的流程？",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "\(m.name)的流程只有：" + m.steps.joined(separator: " → "))
    }

    private func applyExercise(_ m: Method, level: Int, variant: Int) -> Exercise {
        let task = m.practice.first { $0.level == (level >= 3 ? "高阶" : "中阶") }?.task
            ?? m.practice.last?.task
            ?? "用这个方法记一段你正在学的内容"
        let material: String
        switch variant % 3 {
        case 0:
            material = store_words(5).joined(separator: "、")
        case 1:
            material = store_words(6).joined(separator: "、")
        default:
            material = "“\(m.caseTitle.isEmpty ? m.name : m.caseTitle)”"
        }
        let prompt = "【\(task)】\n材料：\(material)\n\n先用「\(m.name)」把它编码，然后合上材料默写一遍。"
        return Exercise(kind: .apply, level: level, methodId: m.id,
                        prompt: prompt,
                        options: [], answerIndex: -1,
                        answerText: "参考步骤：" + m.steps.joined(separator: " → ") + "\n\n写下来的内容能和原文对应上，就算过。",
                        explain: m.kidLine.isEmpty ? m.definition : m.kidLine,
                        selfCheckHint: "这一题靠自评：真的默写出来了才算「过了」，只是“感觉会”不算。")
    }

    private func categoryExercise(_ m: Method) -> Exercise {
        let correct = m.categoryName
        let others = catalog.categories.map(\.name).filter { $0 != correct }
        let made = makeChoice(correct: correct, distractors: Array(others.shuffled()), limit: 3)
        return Exercise(kind: .category, level: 1, methodId: m.id,
                        prompt: "「\(m.name)」属于下面哪一类记忆法？",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "\(m.name) 归在「\(m.categoryName)」。同类方法之间可以互相替代，跨类通常要组合使用。")
    }

    private func principleExercise(_ m: Method, _ others: [Method]) -> Exercise {
        let correct = m.principle
        var distractors: [String] = []
        for other in others.shuffled() where distractors.count < 4 {
            let p = other.principle
            if p != correct && !distractors.contains(p) { distractors.append(p) }
        }
        let made = makeChoice(correct: correct, distractors: distractors, limit: 3)
        return Exercise(kind: .principle, level: 2, methodId: m.id,
                        prompt: "「\(m.name)」之所以有效，靠的是什么？",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "原理：\(m.principle)\n\n同一原理下常配合：\(m.combo)")
    }

    private func caseMatchExercise(_ m: Method, _ others: [Method]) -> Exercise {
        let correct = m.name
        let material: String
        if !m.caseTitle.isEmpty {
            material = m.caseTitle + "：" + m.caseLines.prefix(2).joined(separator: " ")
        } else {
            material = m.caseLines.prefix(2).joined(separator: " ")
        }
        var distractors: [String] = []
        for other in others.shuffled() where distractors.count < 5 {
            if !distractors.contains(other.name) { distractors.append(other.name) }
        }
        let made = makeChoice(correct: correct, distractors: distractors, limit: 3)
        return Exercise(kind: .caseMatch, level: 3, methodId: m.id,
                        prompt: "下面这段记录用的是哪种记忆法？\n「\(material.isEmpty ? m.definition : material)」",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "\(m.name)：\(m.definition)")
    }

    private func orderExercise(_ m: Method, _ others: [Method], index: Int) -> Exercise {
        guard m.steps.count > 1 else { return definitionExercise(m, others) }
        let pos = index % (m.steps.count - 1)
        let prev = m.steps[pos]
        let correct = m.steps[pos + 1]
        var distractors: [String] = []
        for other in others.shuffled() where distractors.count < 4 {
            if let s = other.steps.first(where: { $0 != correct && $0 != prev }),
               !distractors.contains(s) {
                distractors.append(s)
            }
        }
        let made = makeChoice(correct: correct, distractors: distractors, limit: 3)
        return Exercise(kind: .order, level: 2, methodId: m.id,
                        prompt: "用「\(m.name)」时，做完「\(prev)」之后紧接着要做什么？",
                        options: made.options, answerIndex: made.index,
                        answerText: correct,
                        explain: "完整流程：" + m.steps.joined(separator: " → "))
    }

    private func store_words(_ n: Int) -> [String] {
        randomWords(n)
    }

    private func makeChoice(correct: String, distractors: [String], limit: Int) -> (options: [String], index: Int) {
        var opts: [String] = []
        for d in distractors where d != correct && !opts.contains(d) {
            if opts.count >= limit { break }
            opts.append(d)
        }
        var all = opts
        let index = Int.random(in: 0...opts.count)
        all.insert(correct, at: index)
        return (all, index)
    }

    // MARK: 记录练习结果

    /// 练习结束：更新统计、写入错题本、给错题和方法本身生成复习卡
    func recordQuiz(outcome: QuizOutcome, methodId: Int?, level: Int, mode: QuizMode) {
        logSession(correct: outcome.correct, total: outcome.total, seconds: outcome.seconds)

        if let mid = methodId {
            let score = outcome.total == 0 ? 0 : Double(outcome.correct) / Double(outcome.total)
            let key = "method-\(mid)-L\(level)"
            if score > (best[key] ?? -1) { best[key] = score }

            // 方法维度的正确率，用于薄弱诊断与报告
            var stat = methodStats["\(mid)"] ?? DayStat()
            stat.add(correct: outcome.correct, total: outcome.total, seconds: outcome.seconds)
            methodStats["\(mid)"] = stat
        }

        guard mode == .practice else {
            // 强化模式：错题由 resolveWrong 单独结算，避免重复累加
            persist()
            return
        }

        // 错题入库
        for ex in outcome.wrong {
            upsertWrong(exercise: ex, mine: outcome.mine[ex.id] ?? "")
        }

        // 错题本身也要进复习队列（低质量 → 20 分钟后到期）
        if mode == .practice {
            for ex in outcome.wrong.prefix(6) {
                var card = ReviewCard(front: ex.prompt,
                                      back: "正确答案：\(ex.correctAnswer)\n\n\(ex.explain)",
                                      kind: .method,
                                      due: Date().addingTimeInterval(20 * 60),
                                      methodId: methodId)
                card.grade(2)
                cards.append(card)
            }
        }
        persist()
    }

    /// 错题强化：答对累计两次移出错题本，答错次数 +1
    func resolveWrong(_ item: WrongItem, correct: Bool) {
        guard let idx = wrongItems.firstIndex(where: { $0.id == item.id }) else { return }
        if correct {
            wrongItems[idx].resolvedCount += 1
            wrongItems[idx].lastDate = Date()
            if wrongItems[idx].mastered {
                wrongItems.remove(at: idx)
            }
        } else {
            wrongItems[idx].count += 1
            wrongItems[idx].resolvedCount = 0
            wrongItems[idx].lastDate = Date()
        }
        persist()
    }

    private func upsertWrong(exercise: Exercise, mine: String) {
        if let idx = wrongItems.firstIndex(where: { $0.id == exercise.key }) {
            wrongItems[idx].count += 1
            wrongItems[idx].lastDate = Date()
            wrongItems[idx].mine = mine
            wrongItems[idx].exercise = exercise
            wrongItems[idx].resolvedCount = 0
        } else {
            wrongItems.append(WrongItem(id: exercise.key, exercise: exercise, mine: mine,
                                        firstDate: Date(), lastDate: Date(), count: 1, resolvedCount: 0))
        }
        // 只保留最近 120 条，避免无限增长
        if wrongItems.count > 120 {
            wrongItems.sort { $0.lastDate > $1.lastDate }
            wrongItems = Array(wrongItems.prefix(120))
        }
    }

    func clearWrongBook() {
        wrongItems = []
        persist()
    }

    func removeWrong(_ item: WrongItem) {
        wrongItems.removeAll { $0.id == item.id }
        persist()
    }

    var reinforcementQueue: [WrongItem] {
        wrongItems.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.lastDate < $1.lastDate
        }
    }

    // MARK: 记忆保持率

    /// 单张卡的当前保持率（艾宾浩斯：R = e^(-t/S)）
    func retention(for card: ReviewCard) -> Double {
        let stabilityDays = max(card.intervalDays > 0 ? card.intervalDays : 0.02, 0.02)
        let from = card.lastReview ?? card.due.addingTimeInterval(-stabilityDays * 86_400)
        let elapsedDays = max(0, Date().timeIntervalSince(from) / 86_400)
        return ReviewLadder.retention(dayOffset: elapsedDays, stability: stabilityDays * 1.4)
    }

    func averageRetention() -> Double {
        guard !cards.isEmpty else { return 0 }
        let live = cards.filter { $0.intervalDays > 0 }
        guard !live.isEmpty else { return 0 }
        return live.map { retention(for: $0) }.reduce(0, +) / Double(live.count)
    }

    /// 到期分布：今天 / 明天 / 3 天内 / 本周 / 以后
    func dueBuckets() -> [(label: String, count: Int, tint: Color)] {
        let cal = Calendar.current
        let now = Date()
        var today = 0, tomorrow = 0, threeDays = 0, week = 0, later = 0
        for c in cards {
            let due = c.due
            if due <= now { today += 1 }
            else if cal.isDateInTomorrow(due) { tomorrow += 1 }
            else if let d3 = cal.date(byAdding: .day, value: 3, to: now), due <= d3 { threeDays += 1 }
            else if let d7 = cal.date(byAdding: .day, value: 7, to: now), due <= d7 { week += 1 }
            else { later += 1 }
        }
        return [("今天", today, Theme.danger), ("明天", tomorrow, Theme.warn),
                ("3 天内", threeDays, Theme.accent), ("本周", week, Theme.tint("space")),
                ("以后", later, Theme.textFaint)]
    }

    func stat(on date: Date) -> DayStat? {
        dayStats[Self.dayKey(date)]
    }

    func records(on date: Date) -> [DrillRecord] {
        records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// 最近 n 天的训练量，用于日历与趋势
    func recentDays(_ n: Int) -> [(date: Date, stat: DayStat?)] {
        let cal = Calendar.current
        return (0..<n).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (d, dayStats[Self.dayKey(d)])
        }
    }
}

enum QuizMode {
    case practice
    case reinforcement
}

// MARK: - 演示数据（仅启动参数 -seedDemo 时使用）

extension AppStore {
    func seedDemoIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return }
        guard stats.sessions == 0 else { return }

        let cal = Calendar.current
        // 过去 9 天的训练记录
        let pattern: [(Int, Int)] = [(4, 5), (3, 3), (5, 6), (2, 2),
                                     (4, 5), (3, 5), (6, 7), (3, 4), (3, 4)]
        for (offset, ct) in pattern.enumerated() {
            let (c, t) = ct
            guard let day = cal.date(byAdding: .day, value: -(pattern.count - offset), to: Date()) else { continue }
            let key = Self.dayKey(day)
            var stat = dayStats[key] ?? DayStat()
            stat.add(correct: c, total: t, seconds: 60 * (2 + offset % 3))
            dayStats[key] = stat
            if !stats.days.contains(key) { stats.days.append(key) }
            stats.sessions += 1
            stats.correctItems += c
            stats.totalItems += t
            records.insert(DrillRecord(date: day, kind: offset % 2 == 0 ? .word : .palace,
                                       correct: c, total: t, seconds: 120), at: 0)
        }
        stats.lastDay = Self.dayKey(Date())

        // 复习卡：不同间隔，构成到期分布
        let specs: [(Int, Double, Int)] = [(1, 0.5, 1), (6, 3, 2), (12, 7, 3), (21, 15, 4), (35, 1, 1), (37, 30, 5)]
        for (mid, interval, reps) in specs {
            guard let m = method(mid) else { continue }
            var card = ReviewCard(front: "「\(m.name)」的核心动作是什么？\n适合什么材料？",
                                  back: "\(m.definition)\n步骤：\(m.steps.prefix(3).joined(separator: "→"))",
                                  kind: .method,
                                  methodId: mid)
            card.intervalDays = interval
            card.reps = reps
            card.ease = 2.5
            card.lastReview = Date().addingTimeInterval(-interval * 0.6 * 86_400)
            card.due = Date().addingTimeInterval(interval > 1 ? 86_400 * 0.5 : -3600)
            cards.append(card)
        }

        // 错题：真的从题目里生成，保证和练习一致
        if let m = method(2) {
            let exs = buildExercises(for: m, level: 2)
            for ex in exs.prefix(2) where ex.isChoice {
                let wrongIdx = ex.options.indices.first { $0 != ex.answerIndex } ?? 0
                let item = WrongItem(id: ex.key, exercise: ex, mine: ex.options[wrongIdx],
                                     firstDate: Date().addingTimeInterval(-86_400 * 2),
                                     lastDate: Date().addingTimeInterval(-3600), count: 2, resolvedCount: 0)
                wrongItems.append(item)
            }
        }
        if let m = method(6) {
            let exs = buildExercises(for: m, level: 1)
            for ex in exs.prefix(2) where ex.isChoice {
                let wrongIdx = ex.options.indices.first { $0 != ex.answerIndex } ?? 0
                let item = WrongItem(id: ex.key, exercise: ex, mine: ex.options[wrongIdx],
                                     firstDate: Date().addingTimeInterval(-86_400),
                                     lastDate: Date().addingTimeInterval(-600), count: 1, resolvedCount: 0)
                wrongItems.append(item)
            }
        }

        learnedMethods = [1, 2, 6, 12]
        best["method-6-L1"] = 0.8
        best["method-2-L2"] = 0.6
        best["method-1-L1"] = 1.0
        best["method-1-L2"] = 0.9
        best["method-1-L3"] = 0.85
        best["method-12-L1"] = 0.9
        best["method-12-L2"] = 0.75
        completedPlanDays = [1, 2, 3, 4, 5, 6]

        // XP 与逐日经验
        xp = 640
        for (offset, ct) in pattern.enumerated() {
            guard let day = cal.date(byAdding: .day, value: -(pattern.count - offset), to: Date()) else { continue }
            xpByDay[Self.dayKey(day)] = ct.0 * 2 + 12
        }
        xpByDay[Self.dayKey(Date())] = 46

        // 方法维度正确率（含一个明显薄弱项）
        methodStats["2"] = DayStat(sessions: 2, correct: 3, total: 8, minutes: 4)
        methodStats["6"] = DayStat(sessions: 3, correct: 8, total: 10, minutes: 6)
        methodStats["1"] = DayStat(sessions: 2, correct: 9, total: 10, minutes: 5)
        methodStats["12"] = DayStat(sessions: 1, correct: 4, total: 6, minutes: 3)
        methodStats["21"] = DayStat(sessions: 1, correct: 2, total: 5, minutes: 3)

        goals = [Goal(kind: .dailySessions, target: 3),
                 Goal(kind: .weeklySessions, target: 15),
                 Goal(kind: .streak, target: 7),
                 Goal(kind: .stars, target: 30)]
        persist()
    }
}
