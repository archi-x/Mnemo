import Foundation

// MARK: - 方法演示（把方法本身讲清的三份实例）

/// 一门方法的演示包。一个演示 = 「浅 / 中 / 深」三份材料，逐步走一遍同一套步骤。
struct DemoDeck: Codable {
    let version: Int
    let demos: [MethodDemo]

    func demo(for methodId: Int) -> MethodDemo? {
        demos.first { $0.methodId == methodId }
    }
}

struct MethodDemo: Codable, Identifiable {
    let methodId: Int
    let methodName: String
    /// 这段演示想说什么
    let intro: String
    let cases: [DemoCase]

    var id: Int { methodId }
}

/// 一份走完整个流程的演示。逐行对应方法的步骤，只在同一份材料上。
struct DemoCase: Codable, Identifiable, Hashable {
    let id: String
    /// 浅 / 中 / 深
    let level: String
    /// 这一档在练什么，例如「4 个具体名词 · 只练一个词变一张图」
    let levelNote: String
    let title: String
    /// 原始材料，一行说完
    let material: String
    let items: [CaseItem]
    /// 逐步走：步骤名 + 这份材料上具体发生了什么
    let trace: [DemoStep]
    /// 走完得到的那幅画，可直接照读
    let built: String
    /// 这一档最容易走偏的地方
    let tip: String
}

struct DemoStep: Codable, Hashable {
    let step: String
    let text: String
}

enum DemoLevel {
    static func index(_ level: String) -> Int {
        switch level {
        case "浅": return 1
        case "中": return 2
        case "深": return 3
        default: return 0
        }
    }
}
