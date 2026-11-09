import SwiftUI

struct WrongBookView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var running = false
    @State private var queue: [Exercise] = []
    @State private var filterMethod: Int?

    private var items: [WrongItem] {
        guard let filterMethod else { return store.reinforcementQueue }
        return store.reinforcementQueue.filter { $0.exercise.methodId == filterMethod }
    }

    private var involvedMethods: [Method] {
        let ids = Set(store.wrongItems.map(\.exercise.methodId))
        return store.catalog.methods.filter { ids.contains($0.id) }
    }

    var body: some View {
        ZStack {
            Theme.canvas
            if running {
                QuizRunnerView(title: "错题强化",
                               methodId: nil,
                               level: 0,
                               mode: .reinforcement,
                               exercises: queue,
                               onRestart: {
                                   queue = Array(store.reinforcementQueue.prefix(10)).map(\.exercise).shuffled()
                               })
            } else {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if store.wrongItems.isEmpty {
                    emptyState
                } else {
                    summary
                    startCard
                    filterChips
                    list
                    clearRow
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("错题本")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("答错的题会自动进来，答对两次才出库")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()
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
            .padding(.top, 4)
        }
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            IconBadge(symbol: "checkmark.seal.fill", tint: Theme.success, size: 62)
            Text("还没有错题")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("去方法库做一组练习，答错的题会带着正确答案和分析出现在这里。")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var summary: some View {
        let total = store.wrongItems.count
        let repeats = store.wrongItems.filter { $0.count > 1 }.count
        return HStack(spacing: 10) {
            StatTile(value: "\(total)", unit: "题", label: "待强化", tint: Theme.danger)
            StatTile(value: "\(repeats)", unit: "题", label: "反复错", tint: Theme.warn)
            StatTile(value: "\(involvedMethods.count)", unit: "法", label: "涉及方法")
        }
    }

    private var startCard: some View {
        let count = min(10, store.wrongItems.count)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconBadge(symbol: "repeat.circle.fill", tint: Theme.tint("review"), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("错题强化")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("按错误次数排序，抽 \(count) 题重做")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
            }
            PrimaryButton(title: "开始强化", symbol: "bolt.fill", tint: Theme.tint("review")) {
                queue = Array(store.reinforcementQueue.prefix(10)).map(\.exercise).shuffled()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { running = true }
            }
        }
        .padding(15)
        .glass(radius: 20)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("全部", id: nil)
                ForEach(involvedMethods) { m in
                    chip(m.name, id: m.id)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, id: Int?) -> some View {
        let on = filterMethod == id
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { filterMethod = id }
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(on ? Theme.onAccent : Theme.textSub)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(on ? Theme.accent : Theme.veil(0.05)))
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        VStack(spacing: 9) {
            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func row(_ item: WrongItem) -> some View {
        let method = store.method(item.exercise.methodId)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                TagChip(text: item.exercise.kind.title, tint: Theme.accent)
                if let method {
                    Text(method.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
                if item.count > 1 {
                    Text("错 \(item.count) 次")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.danger.opacity(0.14)))
                }
                Button {
                    Haptic.tap()
                    store.removeWrong(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textFaint)
                }
                .buttonStyle(.plain)
            }

            Text(item.exercise.prompt)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineSpacing(3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !item.mine.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Text("你答：")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textFaint)
                    Text(item.mine)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.danger.opacity(0.9))
                        .lineLimit(2)
                }
            }
            HStack(alignment: .top, spacing: 5) {
                Text("正解：")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
                Text(item.exercise.correctAnswer)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.success.opacity(0.95))
                    .lineLimit(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 16)
    }

    private var clearRow: some View {
        Button {
            Haptic.tap()
            store.clearWrongBook()
        } label: {
            HStack {
                Text("清空错题本")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.danger.opacity(0.9))
                Spacer()
                Text("\(store.wrongItems.count) 题")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(14)
            .glass(radius: 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
