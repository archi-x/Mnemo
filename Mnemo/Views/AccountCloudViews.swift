import SwiftUI
import AuthenticationServices

// MARK: - Apple 登录按钮

/// Sign in with Apple 的官方按钮。配色跟着主题走：深夜给白底，白天给黑底，
/// 这样在两种主题下都能一眼认出这是 Apple 的按钮，而不是我们自绘的样式。
struct AppleSignInButton: View {
    @Environment(\.colorScheme) private var scheme
    /// 不传就跟随系统明暗；传了以 App 的主题为准（深夜主题下画布本身很暗，白底按钮才看得见）
    var style: SignInWithAppleButton.Style?
    var onIdentity: (AppleIdentity) -> Void
    var onError: (String) -> Void

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success:
                guard let identity = AppleAccount.identity(from: result) else {
                    onError("没有拿到 Apple 账号信息，请再试一次")
                    return
                }
                Haptic.success()
                onIdentity(identity)
            case .failure(let error):
                Haptic.failure()
                onError(AppleAccount.message(for: error))
            }
        }
        .signInWithAppleButtonStyle(style ?? (scheme == .dark ? .white : .black))
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - 我的 → 账号绑定

struct AppleBindCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var errorText: String?

    private var bound: Bool { store.profile?.isAppleAccount == true }
    private var emailText: String? {
        guard let email = store.profile?.appleEmail, !email.isEmpty else { return nil }
        return AppleIdentity(userID: "", name: nil, email: email).shortEmail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Apple 账号")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if bound {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold))
                        Text("已绑定").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.success)
                }
            }

            if bound {
                if let emailText {
                    Text(emailText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSub)
                        .lineLimit(1)
                }
                Text("忆境只能用 Apple 账号登录。换机登录同一个账号，再加 iCloud 存储就能接着练。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("要换账号，用下面的「退出登录」。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            } else {
                Text("用 Apple 登录才能进入忆境，也才能用 iCloud 把记录带到别的设备。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)

                AppleSignInButton(style: store.appleButtonStyle(for: scheme)) { identity in
                    store.signInWithApple(identity)
                    errorText = nil
                } onError: { message in
                    errorText = message
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 16)
    }
}

// MARK: - 我的 → 数据存储

struct StorageCard: View {
    @EnvironmentObject private var store: AppStore
    @State private var message: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: store.storageMode.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("数据存储")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(store.storageMode.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
            }

            HStack(spacing: 8) {
                ForEach(StorageMode.allCases) { mode in
                    button(for: mode)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(store.storageStatusLine)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSub)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if store.storageMode == .iCloud {
                Button {
                    Haptic.tap()
                    working = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        message = store.syncNow()
                        working = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text(working ? "同步中…" : "立即同步")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.veil(0.07)))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(working)
            }

            if let message {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSub)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            Text("切换不会删数据：本机文件一直在，iCloud 那份也保留。数据只走你自己的 iCloud，不经过我们的服务器。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 16)
    }

    private var statusColor: Color {
        guard store.storageMode == .iCloud else { return Theme.textFaint }
        if store.cloudNote != nil { return Theme.warn }
        return store.iCloudReady ? Theme.success : Theme.danger
    }

    private func button(for mode: StorageMode) -> some View {
        let selected = store.storageMode == mode
        let disabled = mode == .iCloud && !store.iCloudReady
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                message = store.switchStorage(to: mode)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(mode.title)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(selected ? Theme.onAccent : Theme.textSub)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Theme.accent : Theme.veil(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Color.clear : Theme.veil(0.08), lineWidth: 1)
                    )
            )
            .opacity(disabled && !selected ? 0.45 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(disabled)
    }
}
