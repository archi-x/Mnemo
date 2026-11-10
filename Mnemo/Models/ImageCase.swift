import Foundation

// MARK: - 图解案例

/// 一门记忆法的图解案例库。一个案例 = 一份真实材料 + 一组成对的图像 + 三条不同思路。
struct CaseDeck: Codable {
    let version: Int
    let methodId: Int
    let methodName: String
    let intro: String
    let tiers: [CaseTier]
    let cases: [ImageCase]

    func cases(in tierId: String) -> [ImageCase] {
        cases.filter { $0.tier == tierId }
    }
}

struct CaseTier: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
}

struct ImageCase: Codable, Identifiable, Hashable {
    let id: String
    /// 对应 CaseTier.id：basic / mid / deep
    let tier: String
    let title: String
    /// 要记住的原始材料，一行说完
    let material: String
    let items: [CaseItem]
    let paths: [MemoryPath]

    var count: Int { items.count }
}

/// 一个待记元素和它的图像符号（emoji 作为一种零依赖的图形资源）
struct CaseItem: Codable, Identifiable, Hashable {
    let text: String
    let emoji: String

    var id: String { text }
}

/// 一种记忆思路：为什么有效 → 怎么做 → 串好的成品 → 提取时靠什么
struct MemoryPath: Codable, Identifiable, Hashable {
    let name: String
    /// 思路类型：尺寸 / 动作 / 空间 / 颜色 / 故事 / 拟人 / 数据 …
    let kind: String
    let why: String
    let steps: [String]
    let built: String
    let tip: String

    var id: String { name }
}
