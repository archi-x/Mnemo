import Foundation

// MARK: - 闯关题库内容

struct QuestContent: Decodable {
    struct KidTheme: Decodable {
        let theme: String
        let emoji: String
        let pairs: [[String]]
    }

    struct OrderNode: Decodable {
        let methodId: Int
        let emoji: String
    }

    struct RushTheme: Decodable {
        let theme: String
        let emoji: String
        let methodIds: [Int]
    }

    struct LabSubject: Decodable {
        let subject: String
        let emoji: String
        let items: [LabItem]
    }

    struct LabItem: Decodable {
        let material: String
        let methodId: Int
    }

    let kid: [KidTheme]
    let order: [OrderNode]
    let rush: [RushTheme]
    let lab: [LabSubject]

    static let empty = QuestContent(kid: [], order: [], rush: [], lab: [])
}

// MARK: - 题库

enum QuestBank {
    static let content: QuestContent = load()

    private static func load() -> QuestContent {
        guard let url = Bundle.main.url(forResource: "quest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(QuestContent.self, from: data)
        else { return .empty }
        return c
    }

    // MARK: 关卡列表

    static func nodes(for stage: SchoolStage) -> [StageNodeSpec] {
        switch stage {
        case .primaryLow:
            return content.kid.enumerated().map { i, t in
                StageNodeSpec(index: i, title: t.theme, subtitle: "\(t.pairs.count) 组词图",
                              emoji: t.emoji)
            }
        case .primaryHigh:
            return content.order.enumerated().map { i, o in
                StageNodeSpec(index: i, title: methodName(o.methodId), subtitle: "三步排排队",
                              emoji: o.emoji)
            }
        case .junior:
            return content.rush.enumerated().map { i, t in
                StageNodeSpec(index: i, title: t.theme, subtitle: "\(t.methodIds.count) 个方法",
                              emoji: t.emoji)
            }
        case .senior:
            return content.lab.enumerated().map { i, s in
                StageNodeSpec(index: i, title: s.subject, subtitle: "\(s.items.count) 份材料",
                              emoji: s.emoji)
            }
        }
    }

    static func methodName(_ id: Int) -> String {
        names[id] ?? "方法 \(id)"
    }

    private static var names: [Int: String] {
        AppDataNames.shared.names
    }

    // MARK: 低年级 · 翻翻配对

    static func flipPairs(node: Int, level: Int) -> [FlipPair] {
        guard content.kid.indices.contains(node) else { return [] }
        let theme = content.kid[node]
        let n = level + 2
        return theme.pairs.prefix(n).compactMap { p in
            guard p.count >= 2 else { return nil }
            return FlipPair(word: p[0], emoji: p[1])
        }
    }

    static func kidThemeTitle(node: Int) -> String {
        content.kid.indices.contains(node) ? content.kid[node].theme : "配对"
    }

    // MARK: 高年级 · 排排队

    static func orderRound(node: Int, level: Int, methods: [Method]) -> OrderRound? {
        guard content.order.indices.contains(node) else { return nil }
        let id = content.order[node].methodId
        guard let m = methods.first(where: { $0.id == id }) else { return nil }
        let steps = Array(m.steps.prefix(level + 2))
        guard steps.count >= 3 else { return nil }
        return OrderRound(methodId: m.id, methodName: m.name, steps: steps)
    }

    // MARK: 初中 · 限时抢答

    static func rushQuestions(node: Int, level: Int, count: Int, methods: [Method]) -> [RushQuestion] {
        guard content.rush.indices.contains(node) else { return [] }
        let theme = content.rush[node]
        let pool = theme.methodIds.compactMap { id in methods.first { $0.id == id } }
        guard !pool.isEmpty else { return [] }

        var out: [RushQuestion] = []
        var cursor = 0
        while out.count < count {
            let m = pool[cursor % pool.count]
            let kind = cursor % 4
            cursor += 1
            switch kind {
            case 0:
                if let q = categoryQuestion(m, methods: methods) { out.append(q) }
            case 1:
                if let q = firstStepQuestion(m, methods: methods) { out.append(q) }
            case 2:
                if let q = pitfallQuestion(m, methods: methods) { out.append(q) }
            default:
                if let q = orderQuestion(m, methods: methods, index: cursor) { out.append(q) }
            }
            if cursor > pool.count * 8 { break }
        }
        return out
    }

    private static func categoryQuestion(_ m: Method, methods: [Method]) -> RushQuestion? {
        let correct = m.categoryName
        let others = Set(methods.map(\.categoryName)).filter { $0 != correct }
        guard others.count >= 2 else { return nil }
        let made = choice(correct: correct, distractors: Array(others).shuffled(), limit: 3)
        // 「编码基础」这类四字类名，题干保持极短
        return RushQuestion(id: "cat-\(m.id)", prompt: "「\(m.name)」属于哪类？",
                            options: made.options, answerIndex: made.index,
                            explain: "\(m.name) 属「\(correct)」。", tag: "归类")
    }

    private static func firstStepQuestion(_ m: Method, methods: [Method]) -> RushQuestion? {
        guard let first = m.steps.first else { return nil }
        let dist = methods.shuffled().compactMap { $0.steps.first }.filter { $0 != first }
        guard dist.count >= 2 else { return nil }
        let made = choice(correct: trim(first), distractors: dist.map { trim($0) }, limit: 3)
        return RushQuestion(id: "first-\(m.id)", prompt: "「\(m.name)」先做什么？",
                            options: made.options, answerIndex: made.index,
                            explain: "第一步就是它。", tag: "步骤")
    }

    private static func pitfallQuestion(_ m: Method, methods: [Method]) -> RushQuestion? {
        let own = m.steps.map { trim($0) }
        guard own.count >= 3 else { return nil }
        let foreign = methods.shuffled()
            .filter { $0.id != m.id }
            .compactMap { other in other.steps.first.map { trim($0) } }
            .first { !own.contains($0) }
        guard let bad = foreign else { return nil }
        var options = Array(own.prefix(3))
        options.append(bad)
        options.shuffle()
        guard let idx = options.firstIndex(of: bad) else { return nil }
        return RushQuestion(id: "pit-\(m.id)", prompt: "哪步不属于「\(m.name)」？",
                            options: options, answerIndex: idx,
                            explain: "这句是别的方法的步骤。", tag: "辨析")
    }

    private static func orderQuestion(_ m: Method, methods: [Method], index: Int) -> RushQuestion? {
        guard m.steps.count > 2 else { return nil }
        let pos = index % (m.steps.count - 1)
        let prev = trim(m.steps[pos])
        let correct = trim(m.steps[pos + 1])
        let dist = methods.shuffled()
            .filter { $0.id != m.id }
            .compactMap { $0.steps.first.map { trim($0) } }
            .filter { $0 != correct && $0 != prev }
        guard dist.count >= 2 else { return nil }
        let made = choice(correct: correct, distractors: dist, limit: 3)
        return RushQuestion(id: "ord-\(m.id)-\(pos)", prompt: "做完「\(prev)」后？",
                            options: made.options, answerIndex: made.index,
                            explain: "顺序是固定的。", tag: "顺序")
    }

    // MARK: 高中 · 编码工坊

    static func labRounds(node: Int, level: Int, methods: [Method]) -> [LabRound] {
        guard content.lab.indices.contains(node) else { return [] }
        let subject = content.lab[node]
        let n = min(level + 1, subject.items.count)
        return subject.items.prefix(n).compactMap { item in
            guard let m = methods.first(where: { $0.id == item.methodId }) else { return nil }
            return labRound(subject: subject.subject, material: item.material,
                            method: m, methods: methods)
        }
    }

    private static func labRound(subject: String, material: String,
                                 method m: Method, methods: [Method]) -> LabRound? {
        let nameOptions = choice(correct: m.name,
                                 distractors: methods.shuffled().map(\.name), limit: 3)
        guard let path = makePath(m.steps), nameOptions.options.count == 4 else { return nil }
        var paths: [String] = []
        for other in methods.shuffled() where paths.count < 4 {
            guard other.id != m.id, let p = makePath(other.steps), !paths.contains(p) else { continue }
            paths.append(p)
        }
        guard paths.count >= 3 else { return nil }
        paths.insert(path, at: 0)
        paths = Array(paths.prefix(4)).shuffled()
        guard let pathIdx = paths.firstIndex(of: path) else { return nil }

        return LabRound(id: "\(subject)-\(material.prefix(8))", subject: subject,
                        material: material, methodName: m.name,
                        methodOptions: nameOptions.options, methodAnswer: nameOptions.index,
                        pathOptions: paths, pathAnswer: pathIdx,
                        hint: trim(m.definition, limit: 28))
    }

    private static func makePath(_ steps: [String]) -> String? {
        guard steps.count >= 3 else { return nil }
        let a = trim(steps[1], limit: 9)
        let b = trim(steps[2], limit: 9)
        guard !a.isEmpty, !b.isEmpty else { return nil }
        return "\(a) → \(b)"
    }

    // MARK: 工具

    struct Choice {
        let options: [String]
        let index: Int
    }

    /// 正确答案 + 干扰项打乱，去重后补足 4 个选项
    static func choice(correct: String, distractors: [String], limit: Int) -> Choice {
        var opts: [String] = [correct]
        for d in distractors where d != correct && !opts.contains(d) {
            if opts.count > limit { break }
            opts.append(d)
        }
        opts = Array(opts.prefix(limit + 1))
        let shuffled = opts.shuffled()
        return Choice(options: shuffled, index: shuffled.firstIndex(of: correct) ?? 0)
    }

    static func trim(_ s: String, limit: Int = 14) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "。", with: "")
        if t.count > limit {
            t = String(t.prefix(limit)) + "…"
        }
        return t
    }
}

// MARK: - 方法名缓存（避免每次翻找目录）

final class AppDataNames {
    static let shared = AppDataNames()
    let names: [Int: String]

    private init() {
        guard let url = Bundle.main.url(forResource: "methods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cat = try? JSONDecoder().decode(Catalog.self, from: data)
        else {
            names = [:]
            return
        }
        names = Dictionary(uniqueKeysWithValues: cat.methods.map { ($0.id, $0.name) })
    }
}
