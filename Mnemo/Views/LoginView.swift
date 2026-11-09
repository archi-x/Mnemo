import SwiftUI

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
                                            .fill(Color.white.opacity(0.055))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
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
                    .fill(i < filled ? tint : Color.white.opacity(0.10))
                    .overlay(
                        Circle().strokeBorder(i < filled ? tint.opacity(0.9) : Color.white.opacity(0.14),
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

    @State private var nickname = ""
    @State private var avatar = Profile.avatars[0]
    @State private var pin = ""
    @State private var shake: CGFloat = 0
    @State private var errorText: String?
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    private var isCreate: Bool { store.profile == nil }
    /// 昵称留空时用默认名，按钮始终可点
    private var resolvedName: String {
        let t = nickname.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "练习者" : t
    }

    var body: some View {
        ZStack {
            Theme.canvas
            decorativeGlow

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        if isCreate {
                            createContent
                        } else {
                            unlockContent
                        }
                        Spacer(minLength: 18)
                        if isCreate {
                            featureRow
                                .padding(.bottom, 22)
                        }
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
        .onAppear {
            guard !appeared else { return }
            appeared = true
            #if DEBUG
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-loginName"),
               i + 1 < ProcessInfo.processInfo.arguments.count {
                nickname = ProcessInfo.processInfo.arguments[i + 1]
                return
            }
            #endif
            if isCreate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nameFocused = true }
            }
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
                    .fill(Color(hex: 0x4FD1C5).opacity(0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: geo.size.width - 120, y: geo.size.height - 200)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 首次进入：建立档案

    private var createContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            LoginBrand()

            Text("40 个记忆法 · 每天练一次")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSub)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("建立训练档案")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("档案只写在这台设备，不联网，也不会上传。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                }

                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                    TextField("", text: $nickname, prompt: Text("给自己起个名字").foregroundStyle(Theme.textFaint))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { submit() }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)
                .glass(radius: 15)

                VStack(alignment: .leading, spacing: 10) {
                    Text("选个头像")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textFaint)
                    HStack(spacing: 10) {
                        ForEach(Profile.avatars, id: \.self) { symbol in
                            avatarButton(symbol)
                        }
                    }
                }
            }
            .padding(18)
            .glass(radius: 22)
            .padding(.top, 24)

            VStack(spacing: 10) {
                PrimaryButton(title: "进入忆境", symbol: "arrow.right") { submit() }

                Button {
                    Haptic.tap()
                    store.createProfile(nickname: "访客", avatar: Profile.avatars[2], pin: nil)
                } label: {
                    Text("先用访客身份逛逛")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSub)
                        .padding(.vertical, 8)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.top, 22)
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

    private func avatarButton(_ symbol: String) -> some View {
        let selected = avatar == symbol
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { avatar = symbol }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(selected ? Color.black.opacity(0.85) : Theme.textSub)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(selected ? Theme.accent : Color.white.opacity(0.055))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
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
                Text("切换身份")
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
            Text("本地存储 · 无需注册 · 无广告")
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

    private func submit() {
        Haptic.success()
        store.createProfile(nickname: resolvedName, avatar: avatar, pin: nil)
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
                     ? "每次打开忆境时用它解锁，忘记只能清空本机档案。"
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
