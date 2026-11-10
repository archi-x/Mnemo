import Foundation
import AuthenticationServices

/// Sign in with Apple 拿回来的身份。只保留本地判断需要的最小字段。
struct AppleIdentity {
    /// Apple 侧稳定不变的用户标识（同一个 Apple 账号、同一个 App 永远一致）
    let userID: String
    /// 只有第一次授权才会返回姓名，之后要自己存
    let name: String?
    /// 可能是 @privaterelay.appleid.com 的转发地址
    let email: String?

    var isPrivateEmail: Bool {
        email?.hasSuffix("@privaterelay.appleid.com") ?? false
    }

    /// 界面上显示用：保留转发地址的辨识度，但缩短长度
    var shortEmail: String? {
        guard let email, !email.isEmpty else { return nil }
        if isPrivateEmail {
            let head = email.split(separator: "@").first.map(String.init) ?? ""
            return "\(head.prefix(12))…@私密转发"
        }
        return email
    }
}

/// Apple 登录的纯函数部分：解析授权结果、翻译错误、查凭证状态。
/// 真正的按钮与控制器在 `AppleSignInButton` 里，这里只做「不依赖 UI」的那一半。
enum AppleAccount {
    static func identity(from result: Result<ASAuthorization, Error>) -> AppleIdentity? {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential
        else { return nil }
        let full = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined()
        return AppleIdentity(userID: credential.user,
                             name: full.isEmpty ? nil : full,
                             email: credential.email)
    }

    /// 把 ASAuthorizationError 翻成人话，避免直接把 NSError 丢到界面上
    static func message(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == ASAuthorizationError.errorDomain,
           let code = ASAuthorizationError.Code(rawValue: ns.code) {
            switch code {
            case .canceled: return "已经取消了"
            case .failed: return "Apple 登录没有完成，请稍后再试一次"
            case .invalidResponse: return "Apple 返回的数据不对，请重试"
            case .notHandled: return "系统没有处理这次请求"
            case .unknown:
                return "这台设备暂时无法完成 Apple 登录（模拟器或开发者账号未开启该能力）"
            case .notInteractive: return "当前状态不能弹出登录，请回到前台重试"
            case .matchedExcludedCredential: return "这个 Apple 账号被排除了"
            case .credentialImport: return "凭证导入失败"
            case .credentialExport: return "凭证导出失败"
            @unknown default: return "Apple 登录暂时不可用"
            }
        }
        return "Apple 登录暂时不可用：\(ns.localizedDescription)"
    }

    /// 是否还绑着：用户可能已经在 设置 → Apple 账号 里把这个 App 的授权撤销了
    static func credentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { cont in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                cont.resume(returning: state)
            }
        }
    }

    /// 调试：`-seedApple` 直接造一个 Apple 档案，用来截界面
    @MainActor
    static func demoIdentity() -> AppleIdentity {
        AppleIdentity(userID: "000123.demo.apple.user",
                      name: "林小满",
                      email: "x8k2m4q@privaterelay.appleid.com")
    }
}
