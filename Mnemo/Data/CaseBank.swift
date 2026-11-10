import Foundation

/// 图解案例库加载器。数据是静态内容，跟着 App 打包。
enum CaseBank {
    static let deck: CaseDeck = load()

    private static func load() -> CaseDeck {
        guard let url = Bundle.main.url(forResource: "imagecases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let d = try? JSONDecoder().decode(CaseDeck.self, from: data)
        else {
            return CaseDeck(version: 0, methodId: 1, methodName: "图像记忆法",
                            intro: "", tiers: [], cases: [])
        }
        return d
    }

    /// 某门方法是否已配好图解案例
    static func hasDeck(for methodId: Int) -> Bool {
        deck.methodId == methodId && !deck.cases.isEmpty
    }

    static func tier(_ id: String) -> CaseTier? {
        deck.tiers.first { $0.id == id }
    }

    static func cases(in tierId: String) -> [ImageCase] {
        deck.cases(in: tierId)
    }

    static var totalPaths: Int { deck.cases.reduce(0) { $0 + $1.paths.count } }

    /// 按难度从浅到深排好的全部案例，用于「下一条」
    static var ordered: [ImageCase] {
        let order = deck.tiers.map(\.id)
        return deck.cases.sorted {
            (order.firstIndex(of: $0.tier) ?? 0, $0.id) < (order.firstIndex(of: $1.tier) ?? 0, $1.id)
        }
    }

    static func next(after id: String) -> ImageCase? {
        let list = ordered
        guard let i = list.firstIndex(where: { $0.id == id }), i + 1 < list.count else { return nil }
        return list[i + 1]
    }

    static func previous(before id: String) -> ImageCase? {
        let list = ordered
        guard let i = list.firstIndex(where: { $0.id == id }), i > 0 else { return nil }
        return list[i - 1]
    }
}
