import SwiftUI
import WeBoxCore

struct ContentView: View {
    @ObservedObject var model: InstanceListViewModel

    var body: some View {
        InstanceListView(model: model)
            .frame(minWidth: 760, minHeight: 430)
    }
}
