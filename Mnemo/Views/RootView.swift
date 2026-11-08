import SwiftUI

enum RootTab: Int, CaseIterable, Identifiable {
    case today, drill, library, profile
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "今日"
        case .drill: return "训练"
        case .library: return "方法"
        case .profile: return "我的"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.horizon.fill"
        case .drill: return "bolt.fill"
        case .library: return "books.vertical.fill"
        case .profile: return "person.fill"
        }
    }

    var key: String {
        switch self {
        case .today: return "today"
        case .drill: return "drill"
        case .library: return "library"
        case .profile: return "profile"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab: RootTab

    init() {
        let args = ProcessInfo.processInfo.arguments
        var initial: RootTab = .today
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            initial = RootTab.allCases.first { $0.key == args[i + 1] } ?? .today
        }
        _tab = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            Theme.canvas

            Group {
                switch tab {
                case .today:
                    TodayView(tab: $tab)
                case .drill:
                    DrillHubView()
                case .library:
                    LibraryView()
                case .profile:
                    ProfileView()
                }
            }
            .transition(.opacity)

            if let level = store.pendingLevelUp {
                LevelUpToast(level: level, name: store.learnerLevel.name) {
                    store.pendingLevelUp = nil
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(9)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.pendingLevelUp)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(tab: $tab)
        }
    }
}

private struct TabBar: View {
    @Binding var tab: RootTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { item in
                let selected = tab == item
                Button {
                    guard tab != item else { return }
                    Haptic.select()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        tab = item
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 17, weight: selected ? .semibold : .regular))
                            .frame(height: 20)
                        Text(item.title)
                            .font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                    }
                    .foregroundStyle(selected ? Theme.accent : Theme.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.accent.opacity(0.10))
                                .matchedGeometryEffect(id: "tabPill", in: ns)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.stroke).frame(height: 0.7)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}


// MARK: - 升级提示

private struct LevelUpToast: View {
    let level: Int
    let name: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.16))
                    .frame(width: 62, height: 62)
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 4) {
                Text("升到 Lv.\(level)")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("新称号：\(name)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSub)
                Text("推荐题型已按新等级调整")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
            Button {
                Haptic.tap()
                onDismiss()
            } label: {
                Text("继续")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.bgLift)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 30, y: 12)
        )
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 3_200_000_000)
                await MainActor.run { onDismiss() }
            }
        }
    }
}
