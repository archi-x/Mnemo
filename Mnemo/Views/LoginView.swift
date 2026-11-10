import SwiftUI
import AuthenticationServices

// MARK: - 数字键盘

/// 4 位密码用的自绘键盘：比系统键盘更符合深夜书房的气质，也不受输入法影响。
struct PinPad: View {
    var onDigit: (Int) -> Void
    var onDelete: () -> Void

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 9) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 9) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        let key = rows[r][c]
                        if key.isEmpty {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 54)
                        } else if key == "⌫" {
                            Button {
                                Haptic.tap()
                                onDelete()
                            } label: {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundStyle(Theme.textSub)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        } else {
                            Button {
                                Haptic.tap()
                                if let n = Int(key) { onDigit(n) }
                            } label: {
                                Text(key)
                                    .font(.system(size: 25, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Theme.veil(0.055))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(Theme.veil(0.07), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 密码圆点

struct PinDots: View {
    var filled: Int
    var shake: CGFloat = 0
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i < filled ? tint : Theme.veil(0.10))
                    .overlay(
                        Circle().strokeBorder(i < filled ? tint.opacity(0.9) : Theme.veil(0.14),
                                              lineWidth: 1)
                    )
                    .frame(width: 13, height: 13)
                    .scaleEffect(i < filled ? 1.06 : 1)
            }
        }
        .offset(x: shake)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: filled)
    }
}

// MARK: - 品牌头

private struct LoginBrand: View {
    var compact = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Theme.accent.opacity(0.14), lineWidth: 1)
                    .frame(width: compact ? 96 : 116)
                Circle()
                    .strokeBorder(Theme.accent.opacity(0.26), lineWidth: 1)
                    .frame(width: compact ? 74 : 90)
                Circle()
                    .fill(
                        RadialGradient(colors: [Theme.accent.opacity(0.36), Theme.accent.opacity(0.06)],
                                       center: .center, startRadius: 2, endRadius: 44)
                    )
                    .frame(width: compact ? 56 : 66)
                Text("忆")
                    .font(.system(size: compact ? 24 : 28, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 7) {
                Text("忆境")
                    .font(.system(size: compact ? 28 : 32, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .tracking(2)
                Text("M N E M O")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.textFaint)
                    .tracking(4)
            }
        }
    }
}

// MARK: - 登录页

struct LoginView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme

    @State private var pin = ""
    @State private var shake: CGFloat = 0
    @State private var errorText: String?
    @State private var appleError: String?

    /// 没有 Apple 身份就不放行：这是进入 App 的唯一入口
    private var needsApple: Bool { !store.hasAppleIdentity }
    /// 这台设备上已经有本地记录（老版本建的档案），登录后接上
    private var hasLocalRecord: Bool { store.profile != nil }

    var body: some View {
        ZStack {
            Theme.canvas
            decorativeGlow

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        if needsApple {
                            appleGate
                        } else {
                            unlockContent
                        }
                        Spacer(minLength: 18)
                        localNote
                            .padding(.bottom, 14)
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: geo.size.height - 20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onChange(of: store.needsAppleLogin) { _, needs in
            if needs { appleError = nil }
        }
        .onAppear {
            #if DEBUG
            // 联调：走一遍「按钮回调 → 建档 → 进入主界面」，不用真的点（模拟器没有签名能力）
            if ProcessInfo.processInfo.arguments.contains("-autoApple"), needsApple {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    store.signInWithApple(AppleAccount.demoIdentity())
                }
            }
            #endif
        }
    }

    private var decorativeGlow: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -60, y: -120)
                Circle()
                    .fill(Theme.tint("space").opacity(0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: geo.size.width - 120, y: geo.size.height - 200)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 必须先过 Apple 登录

    private var appleGate: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            LoginBrand()

            Text("40 个记忆法 · 每天练一次")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSub)
                .padding(.top, 16)

            VStack(spacing: 9) {
                AppleSignInButton(style: store.appleButtonStyle(for: scheme)) { identity in
                    appleError = nil
                    store.signInWithApple(identity)
                } onError: { message in
                    withAnimation(.easeInOut(duration: 0.2)) { appleError = message }
                }
                Text(appleError ?? "用 Apple 登录后进入 · 记录存进你自己的 iCloud")
                    .font(.system(size: 11))
                    .foregroundStyle(appleError == nil ? Theme.textSub : Theme.danger.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
            .padding(.top, 24)

            if hasLocalRecord {
                localRecordNote
                    .padding(.top, 16)
            }

            VStack(alignment: .leading, spacing: 11) {
                reasonRow(symbol: "apple.logo",
                          text: "Apple 只用来确认「你是你」，姓名与邮箱留在本机，不经过我们的服务器")
                reasonRow(symbol: "icloud.fill",
                          text: "训练记录默认写进你自己的 iCloud，换台手机登录同一个账号就能接着练")
                reasonRow(symbol: "lock.shield.fill",
                          text: "不订阅、不投放广告，也不需要再填一张注册表")
            }
            .padding(.top, 22)

            Spacer(minLength: 16)

            featureRow
                .padding(.bottom, 20)
        }
    }

    /// 老版本留下的本机记录：先说清楚登录不会丢数据，再让人点按钮
    private var localRecordNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("这台设备上已有训练记录")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("用 Apple 登录后会自动接上，打卡、错题、星星都不会丢。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSub)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func reasonRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent.opacity(0.9))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSub)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 底部三连，撑住登录页下半屏的留白
    private var featureRow: some View {
        HStack(alignment: .top, spacing: 0) {
            feature(symbol: "books.vertical.fill", title: "40 个记忆法", sub: "原理 · 步骤 · 案例")
            divider
            feature(symbol: "clock.arrow.circlepath", title: "间隔重复", sub: "按遗忘曲线排期")
            divider
            feature(symbol: "flag.checkered", title: "四段闯关", sub: "45 关 135 星")
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 34)
            .padding(.horizontal, 4)
    }

    private func feature(symbol: String, title: String, sub: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent.opacity(0.9))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSub)
            Text(sub)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 已设密码：解锁

    private var unlockContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            LoginBrand(compact: true)
                .padding(.bottom, 24)

            if let profile = store.profile {
                VStack(spacing: 8) {
                    Image(systemName: profile.avatar)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 58, height: 58)
                        .background(
                            Circle().fill(Theme.accent.opacity(0.12))
                                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1))
                        )
                    Text(profile.displayName)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Lv.\(store.learnerLevel.index) · \(store.learnerLevel.name) · \(store.xp) XP")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            VStack(spacing: 16) {
                Text("输入 4 位进入密码")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSub)

                PinDots(filled: pin.count,
                        shake: shake,
                        tint: errorText == nil ? Theme.accent : Theme.danger)

                Text(errorText ?? " ")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.danger.opacity(0.9))
                    .opacity(errorText == nil ? 0 : 1)
            }
            .padding(.top, 26)

            PinPad(onDigit: append, onDelete: deleteLast)
                .padding(.top, 10)

            Button {
                Haptic.tap()
                store.signOut()
            } label: {
                Text("退出登录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSub)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 10)

            Spacer(minLength: 16)
        }
    }

    private var localNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 10.5))
            Text("Apple 登录 · 记录在本机或你的 iCloud · 无广告")
                .font(.system(size: 11))
        }
        .foregroundStyle(Theme.textFaint)
    }

    // MARK: 交互

    private func append(_ n: Int) {
        guard pin.count < 4 else { return }
        errorText = nil
        pin.append(String(n))
        if pin.count == 4 {
            let input = pin
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { attempt(input) }
        }
    }

    private func deleteLast() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
        errorText = nil
    }

    private func attempt(_ input: String) {
        if store.unlock(pin: input) {
            pin = ""
        } else {
            errorText = "密码不对，再试一次"
            withAnimation(.spring(response: 0.28, dampingFraction: 0.35)) { shake = 9 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shake = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { pin = "" }
        }
    }

}

// MARK: - 设置进入密码

struct PinSetupSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var first: String?
    @State private var input = ""
    @State private var errorText: String?

    private var step: Int { first == nil ? 1 : 2 }

    var body: some View {
        ZStack {
            Theme.canvas

            VStack(spacing: 0) {
                HStack {
                    Button {
                        Haptic.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textSub)
                            .frame(width: 34, height: 34)
                            .glass(radius: 12)
                    }
                    Spacer()
                    Text("进入密码")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Rectangle().fill(.clear).frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer(minLength: 10)

                Text(step == 1 ? "设置 4 位密码" : "再输一次确认")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(step == 1
                     ? "每次打开忆境时用它解锁。忘记密码只能清空训练数据重新开始。"
                     : "两次输入需要一致。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                PinDots(filled: input.count, tint: errorText == nil ? Theme.accent : Theme.danger)
                    .padding(.top, 26)

                Text(errorText ?? " ")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.danger.opacity(0.9))
                    .padding(.top, 10)

                Spacer(minLength: 8)

                PinPad(onDigit: append, onDelete: deleteLast)
                    .padding(.horizontal, 24)

                Button {
                    Haptic.tap()
                    store.setPin(nil)
                    dismiss()
                } label: {
                    Text("不设密码")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSub)
                        .padding(.vertical, 10)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        }
        .onAppear { input = "" }
    }

    private func append(_ n: Int) {
        guard input.count < 4 else { return }
        input.append(String(n))
        guard input.count == 4 else { return }
        let value = input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { advance(value) }
    }

    private func deleteLast() {
        guard !input.isEmpty else { return }
        input.removeLast()
    }

    private func advance(_ value: String) {
        if let first {
            if first == value {
                store.setPin(value)
                Haptic.success()
                dismiss()
            } else {
                Haptic.failure()
                errorText = "两次输入不一致，重新设置"
                self.first = nil
                input = ""
            }
        } else {
            Haptic.select()
            first = value
            input = ""
        }
    }
}
