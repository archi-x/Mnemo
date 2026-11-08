import Foundation

// MARK: - 记忆法内容

struct Practice: Codable, Hashable, Identifiable {
    var id: String { level }
    let level: String
    let task: String
}

struct KidCase: Codable, Hashable {
    let title: String
    let material: String
    let steps: [String]
    let tip: String
    let mistakes: [String]
}

struct Method: Codable, Identifiable, Hashable {
    let id: Int
    let code: String
    let name: String
    let categoryId: String
    let categoryName: String
    let icon: String
    let definition: String
    let principle: String
    let bestFor: [String]
    let notFor: [String]
    let steps: [String]
    let caseTitle: String
    let caseLines: [String]
    let practice: [Practice]
    let mistakes: [String]
    let combo: String
    let kidLine: String
    let kidCase: KidCase?

    var shortName: String { name.replacingOccurrences(of: "记忆法", with: "") }
    var tint: Color2 { Color2(categoryId) }
}

/// 只为避免在 Model 层引入 SwiftUI，提供一个轻量色号包装。
struct Color2: Hashable {
    let categoryId: String
    init(_ id: String) { categoryId = id }
}

struct MethodCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let range: String
    let count: Int
}

struct DiagnoseItem: Codable, Identifiable, Hashable {
    var id: String { symptom }
    let symptom: String
    let methods: String
}

struct FixItem: Codable, Identifiable, Hashable {
    var id: String { symptom }
    let symptom: String
    let cause: String
    let fix: String
}

struct PlanDay: Codable, Identifiable, Hashable {
    var id: Int { day }
    let day: Int
    let theme: String
    let task: String
}

struct Catalog: Codable {
    let version: Int
    let source: String
    let categories: [MethodCategory]
    let methods: [Method]
    let diagnose: [DiagnoseItem]
    let fixes: [FixItem]
    let plan: [PlanDay]
}

// MARK: - 复习与训练记录

enum CardKind: String, Codable {
    case word      // 词表闪记
    case number    // 数字桩
    case palace    // 记忆宫殿
    case method    // 方法自述卡

    var label: String {
        switch self {
        case .word: return "词表"
        case .number: return "数字"
        case .palace: return "宫殿"
        case .method: return "方法"
        }
    }

    var symbol: String {
        switch self {
        case .word: return "text.word.spacing"
        case .number: return "number"
        case .palace: return "building.columns"
        case .method: return "book.closed"
        }
    }
}

struct ReviewCard: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var front: String
    var back: String
    var kind: CardKind
    var ease: Double = 2.5
    var intervalDays: Double = 0
    var reps: Int = 0
    var lapses: Int = 0
    var due: Date = Date()
    var methodId: Int?
    var lastReview: Date?

    var isDue: Bool { due <= Date() }
    var stageLabel: String {
        if reps == 0 { return "新卡" }
        if intervalDays < 1 { return "今天" }
        if intervalDays < 2 { return "明天" }
        return "\(Int(intervalDays.rounded())) 天后"
    }

    /// SM-2：quality 0…5
    mutating func grade(_ quality: Int) {
        let q = max(0, min(5, quality))
        lastReview = Date()
        if q < 3 {
            reps = 0
            intervalDays = 0
            lapses += 1
            // 未掌握：20 分钟后回到队列
            due = Date().addingTimeInterval(20 * 60)
        } else {
            reps += 1
            if reps == 1 {
                intervalDays = 1
            } else if reps == 2 {
                intervalDays = 3
            } else {
                intervalDays = max(1, (intervalDays * ease).rounded())
            }
            ease = min(3.0, max(1.3, ease + (0.1 - Double(5 - q) * 0.08)))
            due = Calendar.current.date(byAdding: .hour,
                                        value: Int(intervalDays * 24),
                                        to: Date()) ?? Date()
        }
    }
}

struct Stats: Codable {
    var sessions: Int = 0
    var correctItems: Int = 0
    var totalItems: Int = 0
    var days: [String] = []
    var lastDay: String = ""

    var accuracy: Double {
        totalItems == 0 ? 0 : Double(correctItems) / Double(totalItems)
    }
}

struct DrillRecord: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var date: Date = Date()
    var kind: CardKind
    var correct: Int
    var total: Int
    var seconds: Int

    var score: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

// MARK: - 精度等级（取自手册「记忆精度分级」）

struct PrecisionLevel {
    let index: Int
    let name: String
    let requirement: String

    static let all: [PrecisionLevel] = [
        .init(index: 1, name: "再认", requirement: "看到能认出"),
        .init(index: 2, name: "回忆", requirement: "无提示能想起"),
        .init(index: 3, name: "完整输出", requirement: "能准确写出"),
        .init(index: 4, name: "迁移", requirement: "能用到新例子"),
        .init(index: 5, name: "自动化", requirement: "不需刻意回忆")
    ]

    static func current(sessions: Int, accuracy: Double) -> PrecisionLevel {
        if sessions >= 30 && accuracy >= 0.95 { return all[4] }
        if sessions >= 20 && accuracy >= 0.88 { return all[3] }
        if sessions >= 12 && accuracy >= 0.8 { return all[2] }
        if sessions >= 4 && accuracy >= 0.6 { return all[1] }
        return all[0]
    }
}
