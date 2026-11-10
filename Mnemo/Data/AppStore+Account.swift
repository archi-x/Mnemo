import Foundation
import SwiftUI

// MARK: - 档案与解锁

extension AppStore {
    /// 是否已经用 Apple 登录过。没有它就不放行，任何内容都看不到。
    var hasAppleIdentity: Bool { profile?.isAppleAccount == true }

    /// 进入 App 的条件：Apple 身份 + 通过可选的进入密码
    var needsLogin: Bool { !hasAppleIdentity || !isUnlocked }

    /// 还停在 Apple 登录这一步（档案可能已经有，只是没绑 Apple）
    var needsAppleLogin: Bool { !hasAppleIdentity }

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

    /// 退出登录：只断开 Apple 身份，档案与训练数据都留着。
    /// 下次用同一个账号登录时 `signInWithApple` 会把它重新绑上，昵称、头像、进度都还在。
    func signOut() {
        if var p = profile {
            p.appleUserID = nil
            p.appleEmail = nil
            profile = p
        }
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
