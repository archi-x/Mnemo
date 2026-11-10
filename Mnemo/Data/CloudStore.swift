import Foundation

/// 数据存放位置。选择一次即长期生效，随时可切回本机。
enum StorageMode: String, Codable, CaseIterable, Identifiable {
    case local
    case iCloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "本机"
        case .iCloud: return "iCloud"
        }
    }

    var symbol: String {
        switch self {
        case .local: return "iphone"
        case .iCloud: return "icloud.fill"
        }
    }

    var detail: String {
        switch self {
        case .local: return "只写在这台设备，换手机不会带走"
        case .iCloud: return "走你的私人 iCloud，换设备登录同一个 Apple 账号就能接着练"
        }
    }
}

/// iCloud 键值存储的薄封装。
///
/// 为什么不走 CloudKit：这个 App 的状态本来就是「一份整体快照」（卡片、错题、星星、档案全在一个 JSON 里），
/// 用 KV 存一份压缩后的快照最直接，不需要维护 record 类型、不需要处理字段级冲突。
/// 代价是**不做多端并发合并**：两台设备都改过时，按 `savedAt` 取新的那一份整体覆盖，旧的被丢掉。
/// 这对「一个人、一台主力机、偶尔换机」的场景够用，也是这里刻意选择的简单语义。
enum CloudStore {
    private static let payloadKey = "mnemo.snapshot.v1"
    private static let savedAtKey = "mnemo.savedAt.v1"

    /// NSUbiquitousKeyValueStore 总配额 1MB，留出余量
    static let byteLimit = 620_000

    /// 调试用：模拟器上通常没有有效的 iCloud entitlement，
    /// 传 `-cloudReady` 把读写切到 UserDefaults，用来验证整条链路与界面。
    private(set) static var debugForced = false

    static func prepare() {
        #if DEBUG
        debugForced = ProcessInfo.processInfo.arguments.contains("-cloudReady")
        #endif
    }

    /// 真机上等价于「iCloud 已登录且 entitlement 有效」
    static var isAvailable: Bool {
        if debugForced { return true }
        return FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: 读

    static func load() -> (data: Data, savedAt: Date)? {
        guard let packed = string(forKey: payloadKey), !packed.isEmpty else { return nil }
        let stamp = number(forKey: savedAtKey).map { Date(timeIntervalSince1970: $0) } ?? .distantPast
        guard let data = unpack(packed) else { return nil }
        return (data, stamp)
    }

    // MARK: 写

    @discardableResult
    static func save(_ data: Data, savedAt: Date) -> Bool {
        guard let packed = pack(data), packed.utf8.count <= byteLimit else { return false }
        setString(packed, forKey: payloadKey)
        setNumber(savedAt.timeIntervalSince1970, forKey: savedAtKey)
        if !debugForced { NSUbiquitousKeyValueStore.default.synchronize() }
        return true
    }

    static func clear() {
        removeObject(forKey: payloadKey)
        removeObject(forKey: savedAtKey)
        if !debugForced { NSUbiquitousKeyValueStore.default.synchronize() }
    }

    // MARK: 底层读写（真机 / 调试两套后端）

    private static func string(forKey key: String) -> String? {
        if debugForced { return UserDefaults.standard.string(forKey: "cloud." + key) }
        return NSUbiquitousKeyValueStore.default.string(forKey: key)
    }

    private static func number(forKey key: String) -> Double? {
        if debugForced {
            guard UserDefaults.standard.object(forKey: "cloud." + key) != nil else { return nil }
            return UserDefaults.standard.double(forKey: "cloud." + key)
        }
        guard NSUbiquitousKeyValueStore.default.object(forKey: key) != nil else { return nil }
        return NSUbiquitousKeyValueStore.default.double(forKey: key)
    }

    private static func setString(_ value: String, forKey key: String) {
        if debugForced {
            UserDefaults.standard.set(value, forKey: "cloud." + key)
        } else {
            NSUbiquitousKeyValueStore.default.set(value, forKey: key)
        }
    }

    private static func setNumber(_ value: Double, forKey key: String) {
        if debugForced {
            UserDefaults.standard.set(value, forKey: "cloud." + key)
        } else {
            NSUbiquitousKeyValueStore.default.set(value, forKey: key)
        }
    }

    private static func removeObject(forKey key: String) {
        if debugForced {
            UserDefaults.standard.removeObject(forKey: "cloud." + key)
        } else {
            NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
        }
    }

    // MARK: 压缩

    /// zlib + base64：错题和打卡记录会一直长，压缩后通常只有原体积的三分之一
    static func pack(_ data: Data) -> String? {
        let compressed = (try? (data as NSData).compressed(using: .zlib)) as Data?
        let source = compressed ?? data
        return source.base64EncodedString()
    }

    static func unpack(_ packed: String) -> Data? {
        guard let raw = Data(base64Encoded: packed) else { return nil }
        if let plain = try? (raw as NSData).decompressed(using: .zlib) as Data {
            return plain
        }
        return raw
    }
}
