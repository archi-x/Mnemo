import Foundation
import SwiftUI
import AuthenticationServices

// MARK: - iCloud 存储与 Apple 身份

extension AppStore {
    var iCloudReady: Bool { CloudStore.isAvailable }

    /// 「我的 → 存储」里那行状态字
    var storageStatusLine: String {
        guard storageMode == .iCloud else { return "只在这台设备上保存" }
        guard CloudStore.isAvailable else { return "iCloud 不可用：未登录 Apple 账号或未开启 iCloud" }
        if let cloudNote { return cloudNote }
        if let lastSyncedAt { return "已同步 · \(Self.relative(lastSyncedAt))" }
        return "等待第一次同步"
    }

    /// 切换存放位置。返回一句给用户看的结果说明（失败时说明原因）。
    @discardableResult
    func switchStorage(to mode: StorageMode) -> String {
        guard mode != storageMode else { return "" }
        guard mode == .iCloud else {
            storageMode = .local
            persist()
            return "已切回本机。云上那份仍然保留，随时可以再切回来"
        }
        guard CloudStore.isAvailable else {
            return "这台设备连不上 iCloud。先在 系统设置 → Apple 账号 登录，并确认 App 有 iCloud 权限"
        }
        // 先看云上有没有比本机更新的记录（换设备时就是这一步把进度带回来）
        let restored = adoptCloudIfNewer()
        storageMode = .iCloud
        persist()
        return restored ? "已切到 iCloud，并取回了云上更新的记录" : "已切到 iCloud，当前记录已上传"
    }

    /// 云上那份比本机新就整体采纳，并写回本机一份（离线也能读）
    @discardableResult
    func adoptCloudIfNewer() -> Bool {
        guard CloudStore.isAvailable, let cloud = CloudStore.load() else { return false }
        guard let snap = try? JSONDecoder().decode(Snapshot.self, from: cloud.data) else { return false }
        let local = lastLocalSave ?? .distantPast
        guard cloud.savedAt > local else { return false }

        let keepMode = storageMode
        apply(snap)
        storageMode = keepMode
        lastSyncedAt = cloud.savedAt

        var copy = snap
        copy.storageMode = keepMode
        writeLocal(copy)
        return true
    }

    /// 「立即同步」：先试拉取，没有再推上去
    func syncNow() -> String {
        guard storageMode == .iCloud else { return "当前存储位置是本机，先切到 iCloud" }
        guard CloudStore.isAvailable else { return "iCloud 当前不可用" }
        if adoptCloudIfNewer() { return "已拉取云上更新的记录" }
        persist()
        return cloudNote ?? "已把当前记录推到 iCloud"
    }

    /// Apple 官方按钮的配色：深夜给白底、白天给黑底，跟随系统时按系统明暗走
    func appleButtonStyle(for scheme: ColorScheme) -> SignInWithAppleButton.Style {
        switch appearance {
        case .night: return .white
        case .day: return .black
        case .auto: return scheme == .dark ? .white : .black
        }
    }

    // MARK: Apple 身份

    /// 用 Apple 身份建立或绑定档案。首次授权才会拿到姓名，之后靠本地存档。
    func signInWithApple(_ identity: AppleIdentity) {
        let name = (identity.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if var p = profile {
            p.appleUserID = identity.userID
            if let email = identity.email { p.appleEmail = email }
            let placeholder = p.nickname.trimmingCharacters(in: .whitespaces).isEmpty || p.nickname == "练习者" || p.nickname == "访客"
            if !name.isEmpty, placeholder { p.nickname = name }
            profile = p
        } else {
            profile = Profile(id: UUID().uuidString,
                              nickname: name.isEmpty ? "练习者" : name,
                              avatar: Profile.avatars[0],
                              pinHash: nil,
                              createdAt: Date(),
                              appleUserID: identity.userID,
                              appleEmail: identity.email)
        }
        isUnlocked = true
        // Apple 登录后默认存 iCloud（用户随时可切回本机）
        if CloudStore.isAvailable, storageMode == .local {
            storageMode = .iCloud
        }
        persist()
    }

    /// 解除 Apple 绑定，退回本机档案（训练数据不动）
    func unbindApple() {
        guard var p = profile else { return }
        p.appleUserID = nil
        p.appleEmail = nil
        profile = p
        persist()
    }

    /// 启动时核对授权是否还在：用户可能在 设置 里撤销了
    func verifyAppleCredential() {
        #if DEBUG
        // 截图/联调时不要因为模拟器查不到凭证状态就把绑定摘掉
        if ProcessInfo.processInfo.arguments.contains("-seedApple") { return }
        #endif
        guard let userID = profile?.appleUserID, !userID.isEmpty else { return }
        Task { @MainActor in
            let state = await AppleAccount.credentialState(for: userID)
            // 只有用户真的在 设置 里撤销了才解除绑定；
            // .notFound / 查询失败在模拟器、离线、首次安装时都可能出现，不动档案
            guard state == .revoked else { return }
            unbindApple()
            cloudNote = "Apple 授权已失效，已退回本机档案"
        }
    }

    // MARK: 小工具

    /// 监听云上变化：另一台设备写过之后，App 在前台也能取回来
    func startCloudObservers() {
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.storageMode == .iCloud, self.isUnlocked else { return }
                if self.adoptCloudIfNewer() {
                    self.cloudNote = "已取回另一台设备上的更新"
                }
            }
        }
        NotificationCenter.default.addObserver(forName: .NSUbiquityIdentityDidChange,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.storageMode == .iCloud, self.isUnlocked, self.CloudAvailableAfterLogin {
                    if self.adoptCloudIfNewer() { self.cloudNote = "iCloud 已恢复，取回了云上记录" }
                }
            }
        }
    }

    private var CloudAvailableAfterLogin: Bool { CloudStore.isAvailable }

    static func relative(_ date: Date) -> String {
        let secs = Date().timeIntervalSince(date)
        if secs < 60 { return "刚刚" }
        if secs < 3600 { return "\(Int(secs / 60)) 分钟前" }
        if secs < 86_400 { return "\(Int(secs / 3600)) 小时前" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 HH:mm"
        return f.string(from: date)
    }
}
