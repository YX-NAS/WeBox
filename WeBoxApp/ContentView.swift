import SwiftUI
import WeBoxCore

struct ContentView: View {
    @StateObject private var model = InstanceListViewModel()

    var body: some View {
        InstanceListView(model: model)
            .frame(minWidth: 680, minHeight: 420)
    }
}
