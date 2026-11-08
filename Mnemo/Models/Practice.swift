import Foundation

// MARK: - 练习题型

enum ExerciseKind: String, Codable, CaseIterable {
    case definition   // 概念配对：这条定义属于哪个方法
    case step         // 步骤定位：第 k 步做什么
    case material     // 材料适配：什么材料适合 / 不适合
    case pitfall      // 流程排除：哪一步不属于该方法
    case apply        // 应用编码：给真实材料，自评编码质量

    var title: String {
        switch self {
        case .definition: return "概念配对"
        case .step: return "步骤定位"
        case .material: return "材料适配"
        case .pitfall: return "流程排除"
        case .apply: return "应用编码"
        }
    }

    var symbol: String {
        switch self {
        case .definition: return "text.book.closed"
        case .step: return "list.number"
        case .material: return "shippingbox"
        case .pitfall: return "exclamationmark.triangle"
        case .apply: return "pencil.and.outline"
        }
    }

    var isOpen: Bool { self == .apply }
}

struct Exercise: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var kind: ExerciseKind
    var level: Int
    var methodId: Int
    var prompt: String
    var options: [String] = []
    var answerIndex: Int = -1
    var answerText: String
    var explain: String
    var selfCheckHint: String = ""

    var isChoice: Bool { !options.isEmpty }
    var correctAnswer: String {
        isChoice && options.indices.contains(answerIndex) ? options[answerIndex] : answerText
    }
    /// 用于错题去重的稳定标识
    var key: String { "\(methodId)-\(kind.rawValue)-\(prompt.prefix(28))" }
}

struct WrongItem: Identifiable, Codable, Hashable {
    var id: String
    var exercise: Exercise
    var mine: String
    var firstDate: Date
    var lastDate: Date
    var count: Int
    var resolvedCount: Int

    var mastered: Bool { resolvedCount >= 2 }
}

// MARK: - 每日统计

struct DayStat: Codable, Hashable {
    var sessions: Int = 0
    var correct: Int = 0
    var total: Int = 0
    var minutes: Int = 0

    var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }

    mutating func add(correct c: Int, total t: Int, seconds: Int) {
        sessions += 1
        correct += c
        total += t
        minutes += max(0, seconds / 60)
    }
}

// MARK: - 一次练习的结果

struct QuizOutcome {
    var correct: Int
    var total: Int
    var seconds: Int
    var wrong: [Exercise]
    var mine: [String: String] = [:]
}

// MARK: - 艾宾浩斯复习阶梯

enum ReviewLadder {
    /// 经典遗忘曲线节点：学完后的复习时间点
    struct Step: Identifiable, Hashable {
        var id: Int { index }
        let index: Int
        let title: String
        let hours: Double
    }

    static let steps: [Step] = [
        .init(index: 0, title: "5 分钟", hours: 5.0 / 60),
        .init(index: 1, title: "30 分钟", hours: 0.5),
        .init(index: 2, title: "12 小时", hours: 12),
        .init(index: 3, title: "1 天", hours: 24),
        .init(index: 4, title: "2 天", hours: 48),
        .init(index: 5, title: "4 天", hours: 96),
        .init(index: 6, title: "7 天", hours: 168),
        .init(index: 7, title: "15 天", hours: 360),
        .init(index: 8, title: "30 天", hours: 720)
    ]

    /// 艾宾浩斯无复习保持率：R = e^(-t / S)
    static func retention(dayOffset t: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        return min(1, max(0, exp(-t / stability)))
    }
}
