import SwiftUI

@main
struct TKTMasterApp: App {
    @StateObject private var store = ContentStore()
    @StateObject private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(progress)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .windowStyle(.titleBar)
    }
}

enum SidebarItem: Hashable {
    case dashboard
    case module(Int)
    case glossary
    case mockTests
    case celta
}

struct RootView: View {
    @EnvironmentObject var store: ContentStore
    @State private var selection: SidebarItem? = .dashboard
    @AppStorage("showFa") private var showFa = false
    @AppStorage("musicOn") private var musicOn = false
    @AppStorage("sfxOn") private var sfxOn = false
    @AppStorage("accent") private var accent = "en-GB"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Dashboard", systemImage: "square.grid.2x2.fill")
                    .tag(SidebarItem.dashboard)

                Section("Modules") {
                    ForEach(store.curriculum.modules) { m in
                        Label("Module \(m.number)", systemImage: "\(m.number).circle.fill")
                            .tag(SidebarItem.module(m.number))
                    }
                }

                Section("Study") {
                    Label("Glossary", systemImage: "character.book.closed.fill")
                        .tag(SidebarItem.glossary)
                    Label("Mock Tests", systemImage: "checkmark.seal.fill")
                        .tag(SidebarItem.mockTests)
                    Label("CELTA Course", systemImage: "graduationcap.fill")
                        .tag(SidebarItem.celta)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 252, ideal: 274, max: 330)
            .font(.title3)
            .tint(Theme.orange)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PREFERENCES").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(0.6)
                    toggleRow("Persian", "character.bubble", $showFa)
                    toggleRow("Music", "music.note", $musicOn)
                    toggleRow("Sound", "speaker.wave.2.fill", $sfxOn)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "globe").font(.body).frame(width: 22).foregroundStyle(Theme.orange)
                            Text("Pronunciation accent").font(.body).lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                        }
                        Picker("", selection: $accent) {
                            Text("British").tag("en-GB")
                            Text("American").tag("en-US")
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.05)))
                .padding(12)
            }
        } detail: {
            ZStack {
                PaperBackground()
                Group {
                    switch selection ?? .dashboard {
                    case .dashboard: DashboardView()
                    case .module(let n): ModuleView(moduleNumber: n)
                    case .glossary: GlossaryView()
                    case .mockTests: MockListView()
                    case .celta: CeltaView()
                    }
                }
            }
        }
        .tint(Theme.orange)
        .environment(\.dynamicTypeSize, .xxLarge)
        .onAppear { syncMusic() }
        .onChange(of: musicOn) { syncMusic() }
    }

    private func toggleRow(_ title: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.body).frame(width: 22).foregroundStyle(Theme.orange)
            Text(title).font(.body).lineLimit(1).fixedSize()
            Spacer(minLength: 8)
            Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch).tint(Theme.orange)
        }
    }

    private func syncMusic() {
        if musicOn { StudyAudio.shared.start() } else { StudyAudio.shared.stop() }
    }
}
