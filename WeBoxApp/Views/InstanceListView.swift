import SwiftUI
import WeBoxCore

@MainActor
final class InstanceListViewModel: ObservableObject {
    @Published var instances: [WeChatInstance] = []
    @Published var errorMessage: String?
    @Published var isCreating = false

    private let repository: InstanceRepository?
    private let detector = WeChatDetector()
    private let processManager = ProcessManager()

    init() {
        do {
            let database = try Database.defaultDatabase()
            repository = try InstanceRepository(database: database)
            refresh()
        } catch {
            repository = nil
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        do { instances = try repository?.all() ?? [] }
        catch { errorMessage = error.localizedDescription }
    }

    func createWorkInstance() {
        isCreating = true
        defer { isCreating = false }
        do {
            guard let repository else { throw WeBoxError.databaseUnavailable }
            let info = try detector.detect()
            let manager = InstanceManager(repository: repository)
            _ = try manager.createInstance(name: "工作微信", sourceInfo: info)
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func start(_ instance: WeChatInstance) {
        do { try processManager.start(instance: instance); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func stop(_ instance: WeChatInstance) {
        do { try processManager.stop(instance: instance); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func delete(_ instance: WeChatInstance) {
        do { try repository?.delete(id: instance.id); refresh() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct InstanceListView: View {
    @ObservedObject var model: InstanceListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("WeBox").font(.largeTitle.bold())
                Spacer()
                Button("创建工作微信") { model.createWorkInstance() }
                    .disabled(model.isCreating)
            }
            .padding(.horizontal)

            if model.instances.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "message")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("暂无微信实例").font(.title3)
                    Text("检测到微信后，可创建独立实例。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.instances) { instance in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(instance.name).font(.headline)
                            Text("版本 \(instance.version) · \(instance.status.displayName)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("启动") { model.start(instance) }
                        Button("关闭") { model.stop(instance) }
                        Button("删除", role: .destructive) { model.delete(instance) }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical)
        .alert("操作失败", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}
