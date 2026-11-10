#if DEBUG
import Foundation

/// 调试用自检：验证「切到 iCloud → 云上有更新一份 → 取回来」这条链路真的通。
/// 只有带 `-storageSelfTest` 启动时才跑，结果写到 Documents/storage_selftest.txt。
/// 生产包里整段代码不参与编译。
@MainActor
enum StorageSelfTest {
    static func runIfRequested(_ store: AppStore) {
        guard ProcessInfo.processInfo.arguments.contains("-storageSelfTest") else { return }

        var lines: [String] = []
        var pass = 0, fail = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if ok { pass += 1 } else { fail += 1 }
            lines.append("\(ok ? "PASS" : "FAIL")  \(name)\(detail.isEmpty ? "" : "  → \(detail)")")
        }

        let originXP = store.xp
        let originMode = store.storageMode

        check("iCloud 可用（-cloudReady）", CloudStore.isAvailable)

        // 从本机起步再切，才测得到「切换即上传」这一步
        if store.storageMode == .iCloud { _ = store.switchStorage(to: .local) }
        store.lastSyncedAt = nil
        let message = store.switchStorage(to: .iCloud)
        check("切到 iCloud", store.storageMode == .iCloud, message)
        check("切换后立刻有一次同步", store.lastSyncedAt != nil)

        // 造一份「比本机更新」的云快照：把刚上传的字节换个未来时间戳再写回去
        store.xp = 4242
        store.persist()
        let uploaded = CloudStore.load()
        check("云上能读到刚写的快照", uploaded != nil)

        if let uploaded {
            _ = CloudStore.save(uploaded.data, savedAt: Date().addingTimeInterval(60))
            store.xp = 777                          // 本机故意写一个不同的值
            let adopted = store.adoptCloudIfNewer() // 应该被云上那份盖掉
            check("云上更新时会被采纳", adopted)
            check("采纳后取回云上的值", store.xp == 4242, "xp=\(store.xp)")
            check("采纳后本机也落了盘", FileManager.default.fileExists(atPath: store.fileURL.path))
        }

        let back = store.switchStorage(to: .local)
        check("能切回本机", store.storageMode == .local, back)

        // 复原，别把演示数据改坏
        store.xp = originXP
        if originMode == .iCloud {
            _ = store.switchStorage(to: .iCloud)
        } else {
            store.persist()
        }

        lines.append("结果：\(pass) 项通过，\(fail) 项失败")
        let text = lines.joined(separator: "\n") + "\n"
        let url = store.fileURL.deletingLastPathComponent().appendingPathComponent("storage_selftest.txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        print(text)
    }
}
#endif
