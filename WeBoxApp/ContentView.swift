import SwiftUI
import WeBoxCore

struct ContentView: View {
    @StateObject private var model = InstanceListViewModel()

    var body: some View {
        InstanceListView(model: model)
            .frame(minWidth: 860, minHeight: 580)
    }
}
