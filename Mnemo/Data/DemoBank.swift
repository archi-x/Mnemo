import Foundation

/// 方法演示加载器。静态内容，跟 App 一起打包。
enum DemoBank {
    static let deck: DemoDeck = load()

    private static func load() -> DemoDeck {
        guard let url = Bundle.main.url(forResource: "methoddemos", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let d = try? JSONDecoder().decode(DemoDeck.self, from: data)
        else {
            return DemoDeck(version: 0, demos: [])
        }
        return d
    }

    static func demo(for methodId: Int) -> MethodDemo? {
        deck.demo(for: methodId)
    }

    static func hasDemo(for methodId: Int) -> Bool {
        guard let d = demo(for: methodId) else { return false }
        return !d.cases.isEmpty
    }

    /// 已配好演示的方法数，用于「其余方法陆续补上」这类文案
    static var methodCount: Int { deck.demos.count }
}
