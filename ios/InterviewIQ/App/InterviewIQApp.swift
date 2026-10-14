import SwiftUI

@main
struct InterviewIQApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.cyan)
                .onAppear { model.start() }
                .onOpenURL { url in Task { await model.handle(url: url) } }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.authState {
            case .loading:
                ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                SignInView()
            case .signedIn:
                MainTabView()
            }
        }
        .screenBackground()
        .animation(.easeInOut(duration: 0.25), value: model.authState)
    }
}

struct MainTabView: View {
    enum Tab: Hashable { case dashboard, history, pro, account }

    @State private var selection: Tab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(selectedTab: $selection)
                .tabItem { Label("Dashboard", systemImage: "bolt.fill") }
                .tag(Tab.dashboard)
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
                .tag(Tab.history)
            ProView()
                .tabItem { Label("Pro", systemImage: "sparkles") }
                .tag(Tab.pro)
            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(Tab.account)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
