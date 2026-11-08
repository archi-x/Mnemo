import Foundation
import SwiftUI

// MARK: - 学龄段

/// 四个学龄段：认知水平不同，玩法与题型也不同
enum SchoolStage: String, Codable, CaseIterable, Identifiable {
    case primaryLow    // 小学低年级 1–2
    case primaryHigh   // 小学高年级 3–6
    case junior        // 初中
    case senior        // 高中

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primaryLow: return "小学低年级"
        case .primaryHigh: return "小学高年级"
        case .junior: return "初中"
        case .senior: return "高中"
        }
    }

    var shortTitle: String {
        switch self {
        case .primaryLow: return "低年级"
        case .primaryHigh: return "高年级"
        case .junior: return "初中"
        case .senior: return "高中"
        }
    }

    var grades: String {
        switch self {
        case .primaryLow: return "1–2 年级"
        case .primaryHigh: return "3–6 年级"
        case .junior: return "7–9 年级"
        case .senior: return "10–12 年级"
        }
    }

    var emoji: String {
        switch self {
        case .primaryLow: return "🧸"
        case .primaryHigh: return "🎒"
        case .junior: return "📘"
        case .senior: return "🎓"
        }
    }

    var tintKey: String {
        switch self {
        case .primaryLow: return "code"
        case .primaryHigh: return "space"
        case .junior: return "seq"
        case .senior: return "deep"
        }
    }

    var tint: Color { Theme.tint(tintKey) }

    /// 玩法名（各段区别明确）
    var gameName: String {
        switch self {
        case .primaryLow: return "翻翻配对"
        case .primaryHigh: return "排排队"
        case .junior: return "限时抢答"
        case .senior: return "编码工坊"
        }
    }

    var gameKind: QuestGameKind {
        switch self {
        case .primaryLow: return .flipMatch
        case .primaryHigh: return .orderSteps
        case .junior: return .rushQuiz
        case .senior: return .encodeLab
        }
    }

    /// 一句话玩法说明（≤ 30 字）
    var tagline: String {
        switch self {
        case .primaryLow: return "翻开两张卡，把词和图配上"
        case .primaryHigh: return "把打乱的步骤按顺序点出来"
        case .junior: return "限时抢答，连击翻倍"
        case .senior: return "看材料选方法，再选编码路径"
        }
    }

    var levels: [QuestLevelSpec] {
        switch self {
        case .primaryLow:
            return [.init(level: 1, label: "3 对", detail: "6 张牌 · 60 秒"),
                    .init(level: 2, label: "4 对", detail: "8 张牌 · 55 秒"),
                    .init(level: 3, label: "5 对", detail: "10 张牌 · 50 秒")]
        case .primaryHigh:
            return [.init(level: 1, label: "3 步", detail: "排 3 步 · 75 秒"),
                    .init(level: 2, label: "4 步", detail: "排 4 步 · 70 秒"),
                    .init(level: 3, label: "5 步", detail: "排 5 步 · 65 秒")]
        case .junior:
            return [.init(level: 1, label: "6 题", detail: "60 秒 · 连击 ×2"),
                    .init(level: 2, label: "8 题", detail: "55 秒 · 连击 ×2"),
                    .init(level: 3, label: "10 题", detail: "50 秒 · 连击 ×3")]
        case .senior:
            return [.init(level: 1, label: "2 题", detail: "选方法 + 选路径"),
                    .init(level: 2, label: "3 题", detail: "选方法 + 选路径"),
                    .init(level: 3, label: "4 题", detail: "选方法 + 选路径")]
        }
    }

    func spec(level: Int) -> QuestLevelSpec {
        levels.first { $0.level == level } ?? levels[0]
    }

    /// 每关题量（用于评分与进度）
    func questionCount(level: Int) -> Int {
        switch self {
        case .primaryLow: return level + 2          // 3/4/5 对
        case .primaryHigh: return level + 2         // 3/4/5 步
        case .junior: return [6, 8, 10][level - 1]
        case .senior: return level + 1              // 2/3/4 题
        }
    }

    /// 限时（秒），0 表示不限时
    func timeLimit(level: Int) -> Int {
        switch self {
        case .primaryLow: return [60, 55, 50][level - 1]
        case .primaryHigh: return [75, 70, 65][level - 1]
        case .junior: return [60, 55, 50][level - 1]
        case .senior: return 0
        }
    }
}

enum QuestGameKind {
    case flipMatch
    case orderSteps
    case rushQuiz
    case encodeLab
}

struct QuestLevelSpec: Identifiable, Hashable {
    let level: Int
    let label: String
    let detail: String
    var id: Int { level }
}

// MARK: - 关卡节点

/// 一个学龄段里的一关（关卡内容由 QuestBank 生成）
struct StageNodeSpec: Identifiable, Hashable {
    let index: Int
    let title: String
    let subtitle: String
    let emoji: String
    var id: Int { index }
}

// MARK: - 四种玩法的运行数据

/// 低年级：词 ↔ 图
struct FlipPair: Identifiable, Hashable {
    let word: String
    let emoji: String
    var id: String { word }
}

/// 高年级：步骤排序
struct OrderRound: Identifiable, Hashable {
    let methodId: Int
    let methodName: String
    let steps: [String]
    var id: Int { methodId }
}

/// 初中：限时抢答
struct RushQuestion: Identifiable, Hashable {
    let id: String
    let prompt: String
    let options: [String]
    let answerIndex: Int
    let explain: String
    let tag: String
}

/// 高中：编码工坊
struct LabRound: Identifiable, Hashable {
    let id: String
    let subject: String
    let material: String
    let methodName: String
    let methodOptions: [String]
    let methodAnswer: Int
    let pathOptions: [String]
    let pathAnswer: Int
    let hint: String
}

// MARK: - 闯关结果

struct QuestResult {
    let stage: SchoolStage
    let nodeIndex: Int
    let level: Int
    let correct: Int
    let total: Int
    /// 计分依据：不同玩法有自己的算法（配对看翻错次数，抢答看答对数）
    let accuracy: Double
    let seconds: Int

    var earnedStar: Bool { total > 0 && accuracy >= 0.8 }
    var passed: Bool { total > 0 && accuracy >= 0.6 }
}
