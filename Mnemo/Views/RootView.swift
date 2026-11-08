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
        }
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
