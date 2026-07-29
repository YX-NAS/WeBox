import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("WeBox").font(.largeTitle.bold())
            Text("暂无微信实例").foregroundStyle(.secondary)
        }
        .frame(minWidth: 680, minHeight: 420)
    }
}
