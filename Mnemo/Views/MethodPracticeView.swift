import SwiftUI

/// 单个记忆法的分阶练习入口
struct MethodPracticeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let method: Method

    @State private var level: Int
    @State private var exercises: [Exercise] = []
    @State private var started = false

    init(method: Method, initialLevel: Int? = nil) {
        self.method = method
        _level = State(initialValue: initialLevel ?? MethodPracticeView.suggested(method: method))
    }

    /// 没传等级时按方法自身掌握度给个起点
    private static func suggested(method: Method) -> Int { 1 }

    private var tint: Color { Theme.tint(method.categoryId) }

    private func autostartIfNeeded() {
        guard !started, ProcessInfo.processInfo.arguments.contains("-autostart") else { return }
        exercises = store.buildExercises(for: method, level: level)
        started = true
    }
    private var bestScore: Double? { store.best["method-\(method.id)-L\(level)"] }

    var body: some View {
        ZStack {
            Theme.canvas
            if started {
                QuizRunnerView(title: "\(method.name) · L\(level)",
                               methodId: method.id,
                               level: level,
                               mode: .practice,
                               exercises: exercises,
                               onRestart: { exercises = store.buildExercises(for: method, level: level) })
            } else {
                setup
                    .onAppear { autostartIfNeeded() }
            }
        }
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                    Text("方法练习")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Rectangle().fill(.clear).frame(width: 34, height: 34)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(method.name)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("同一方法拆成三阶，题型从认得→分辨→真刀真枪地编码。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSub)
                        .lineSpacing(3)
                }

                VStack(spacing: 10) {
                    levelRow(1, "初阶 · 认得它",
                             detail: "把方法和它的定义、类别、流程对上号",
                             kinds: "概念配对 · 方法归类 · 步骤定位")
                    levelRow(2, "中阶 · 分得清",
                             detail: "知道什么该用、什么不该用，步骤顺序不串",
                             kinds: "材料适配 · 流程排除 · 步骤衔接 · 原理溯源")
                    levelRow(3, "高阶 · 用得上",
                             detail: "看案例认方法，给真实材料现场编码并默写",
                             kinds: "案例归属 · 应用编码 · 流程排除")
                }

                if let bestScore {
                    HStack(spacing: 7) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 11))
                        Text("L\(level) 最好成绩 \(Int(bestScore * 100))%")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(tint.opacity(0.12)))
                }

                PrimaryButton(title: "开始 L\(level) 练习", symbol: "play.fill", tint: tint) {
                    exercises = store.buildExercises(for: method, level: level)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { started = true }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    private func levelRow(_ value: Int, _ title: String, detail: String, kinds: String) -> some View {
        let on = level == value
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { level = value }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(on ? Theme.text : Theme.textSub)
                    if store.suggestedLevel(for: method) == value {
                        TagChip(text: "建议", tint: tint, filled: true)
                    }
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(on ? tint : Theme.textFaint)
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                Text(kinds)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(tint.opacity(0.85))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(on ? tint.opacity(0.12) : Theme.veil(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(on ? tint.opacity(0.35) : Theme.stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
