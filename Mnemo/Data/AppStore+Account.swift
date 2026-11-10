import Foundation
import SwiftUI

// MARK: - 档案与解锁

extension AppStore {
    var needsLogin: Bool { profile == nil || !isUnlocked }

    var isFirstRun: Bool { profile == nil }

    /// 创建档案（首次进入）。pin 传 nil 或空表示不设进入密码。
    func createProfile(nickname: String, avatar: String, pin: String?) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPin = (pin?.isEmpty == false) ? pin : nil
        profile = Profile(id: UUID().uuidString,
                          nickname: trimmed.isEmpty ? "练习者" : trimmed,
                          avatar: avatar,
                          pinHash: cleanPin.map(Profile.hash),
                          createdAt: Date())
        isUnlocked = true
        persist()
    }

    /// 校验密码并解锁
    @discardableResult
    func unlock(pin: String) -> Bool {
        guard let profile else {
            isUnlocked = true
            return true
        }
        guard let hash = profile.pinHash, !hash.isEmpty else {
            isUnlocked = true
            return true
        }
        let ok = Profile.hash(pin) == hash
        if ok {
            isUnlocked = true
            Haptic.success()
        } else {
            Haptic.failure()
        }
        return ok
    }

    /// 设置 / 清除 4 位进入密码
    func setPin(_ pin: String?) {
        guard var p = profile else { return }
        let clean = (pin?.isEmpty == false) ? pin : nil
        p.pinHash = clean.map(Profile.hash)
        profile = p
        persist()
    }

    func updateProfile(nickname: String? = nil, avatar: String? = nil) {
        guard var p = profile else { return }
        if let nickname {
            let t = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { p.nickname = t }
        }
        if let avatar { p.avatar = avatar }
        profile = p
        persist()
    }

    /// 手动锁定，回到解锁页
    func lock() {
        guard profile?.hasPin == true else { return }
        isUnlocked = false
    }

    /// 退出当前档案（保留训练数据，只清身份）
    func signOut() {
        profile = nil
        isUnlocked = false
        persist()
    }

    /// 忘记密码：清空档案与本机训练数据（选了 iCloud 的话，云上那份一并清掉）
    func eraseAccountAndData() {
        profile = nil
        isUnlocked = false
        resetAll()
        CloudStore.clear()
        storageMode = .local
        lastSyncedAt = nil
        cloudNote = nil
        persist()
    }

    /// 切换外观：深夜 / 白天 / 跟随系统
    func setAppearance(_ mode: Appearance) {
        guard appearance != mode else { return }
        appearance = mode
        persist()
    }
}
