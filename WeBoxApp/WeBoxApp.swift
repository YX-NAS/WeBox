import SwiftUI

@main
struct WeBoxApp: App {
    @StateObject private var model = InstanceListViewModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(model: model)
        }
        .windowStyle(.titleBar)

        MenuBarExtra {
            StatusBarView(model: model)
        } label: {
            Label(statusBarTitle, systemImage: statusBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }

    private var statusBarTitle: String {
        let running = model.instances.filter { $0.status == .running }.count
        return running == 0 ? "WeBox" : "WeBox \(running)"
    }

    private var statusBarSymbol: String {
        model.instances.contains(where: { $0.status == .running }) ? "message.badge.filled.fill" : "message.badge.fill"
    }
}
