import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var modal: Bool = false

    @State private var query = ""
    @State private var category: String?
    @State private var showDiagnose = false
    @State private var path = NavigationPath()
    @State private var practiceMethod: Method?

    private var filtered: [Method] {
        store.catalog.methods.filter { m in
            (category == nil || m.categoryId == category) &&
            (query.isEmpty ||
             m.name.contains(query) ||
             m.definition.contains(query) ||
             m.categoryName.contains(query) ||
             m.code == query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchField
                    diagnoseCard
                    categoryChips
                    methodList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Int.self) { id in
                if let m = store.method(id) {
                    MethodDetailView(method: m)
                }
            }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                guard let i = args.firstIndex(of: "-method"), i + 1 < args.count,
                      let id = Int(args[i + 1]) else { return }
                if args.contains("-practice"), let m = store.method(id) {
                    practiceMethod = m
                } else {
                    path.append(id)
                }
            }
            .fullScreenCover(item: $practiceMethod) { m in
                MethodPracticeView(method: m)
            }
            .sheet(isPresented: $showDiagnose) {
                DiagnoseView()
                    .presentationDetents([.large])
                    .presentationBackground(Theme.bg)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("方法库")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("\(store.catalog.methods.count) 个记忆法 · 7 类编码策略")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()
            if modal {
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
        }
        .padding(.top, 10)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
            TextField("", text: $query,
                      prompt: Text("搜方法、场景，如「顺序」「单词」").foregroundStyle(Theme.textFaint))
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glass(radius: 14)
    }

    private var diagnoseCard: some View {
        Button {
            Haptic.tap(.medium)
            showDiagnose = true
        } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: "stethoscope", tint: Theme.tint("deep"), size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("不知道用哪个？先诊断")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("10 种常见记忆症状，对号入座")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.tint("deep").opacity(0.14), Theme.veil(0.03)],
                                         startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("全部", id: nil, count: store.catalog.methods.count)
                ForEach(store.catalog.categories) { c in
                    chip(c.name, id: c.id, count: c.count)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        // 右侧留一道渐隐，暗示这一排还能横向滑动，而不是被裁掉
        .mask(alignment: .trailing) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.black)
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 22)
            }
        }
    }

    private func chip(_ title: String, id: String?, count: Int) -> some View {
        let selected = category == id
        let tint = id.map { Theme.tint($0) } ?? Theme.accent
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { category = id }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .opacity(0.65)
            }
            .foregroundStyle(selected ? Theme.onAccent : Theme.textSub)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? tint : Theme.veil(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    private var methodList: some View {
        LazyVStack(spacing: 8) {
            ForEach(filtered) { m in
                NavigationLink {
                    MethodDetailView(method: m)
                } label: {
                    row(m)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            if filtered.isEmpty {
                EmptyHint(symbol: "magnifyingglass",
                          title: "没有匹配的方法",
                          detail: "换个关键词试试，比如「定位」「笔记」")
            }
        }
    }

    private func row(_ m: Method) -> some View {
        HStack(spacing: 13) {
            Text(m.code)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.tint(m.categoryId))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(m.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    if DemoBank.hasDemo(for: m.id) {
                        Text("三例")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.tint(m.categoryId))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Theme.tint(m.categoryId).opacity(0.14)))
                    }
                    if store.learnedMethods.contains(m.id) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.success.opacity(0.85))
                    }
                }
                Text(m.definition)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSub)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textFaint.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glass(radius: 16)
    }
}

// MARK: - 选法诊断

struct DiagnoseView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("先诊断，再选法")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("同意的问题往往对应不同方法。先找到症状，再决定今天练什么。")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textSub)
                    }
                    .padding(.top, 18)

                    VStack(spacing: 8) {
                        ForEach(store.catalog.diagnose) { d in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(d.symptom)
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text(d.methods)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.tint("deep"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .glass(radius: 16)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("症状 · 原因 · 解法")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textFaint)
                        ForEach(store.catalog.fixes) { f in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(f.symptom)
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                    Text("原因：\(f.cause)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(Theme.textFaint)
                                }
                                Spacer(minLength: 6)
                                Text(f.fix)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Theme.success)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 120, alignment: .trailing)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Theme.veil(0.035))
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textSub)
                    }
                }
            }
        }
    }
}
