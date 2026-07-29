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

    func createInstance(named name: String) {
        isCreating = true
        defer { isCreating = false }
        do {
            guard let repository else { throw WeBoxError.databaseUnavailable }
            let info = try detector.detect()
            let manager = InstanceManager(repository: repository)
            _ = try manager.createInstance(name: name, sourceInfo: info)
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
        do {
            guard let repository else { throw WeBoxError.databaseUnavailable }
            try InstanceManager(repository: repository).deleteInstance(instance)
            refresh()
        }
        catch { errorMessage = error.localizedDescription }
    }
}

struct InstanceListView: View {
    @ObservedObject var model: InstanceListViewModel
    @State private var isShowingCreateDialog = false
    @State private var newInstanceName = ""
    @State private var instancePendingDeletion: WeChatInstance?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("WeBox").font(.largeTitle.bold())
                Spacer()
                Button("创建微信实例") { isShowingCreateDialog = true }
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
                        Button("删除", role: .destructive) { instancePendingDeletion = instance }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical)
        .alert("操作失败", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("创建微信实例", isPresented: $isShowingCreateDialog) {
            TextField("例如：工作微信", text: $newInstanceName)
            Button("取消", role: .cancel) { newInstanceName = "" }
            Button("创建") {
                model.createInstance(named: newInstanceName)
                newInstanceName = ""
            }
        } message: {
            Text("相同名称会自动添加编号，例如“工作微信 2”。")
        }
        .confirmationDialog("删除微信实例？", isPresented: Binding(get: { instancePendingDeletion != nil }, set: { if !$0 { instancePendingDeletion = nil } })) {
            Button("移入废纸篓并删除记录", role: .destructive) {
                if let instancePendingDeletion { model.delete(instancePendingDeletion) }
                instancePendingDeletion = nil
            }
            Button("取消", role: .cancel) { instancePendingDeletion = nil }
        } message: {
            Text("将把对应的微信副本移入废纸篓。")
        }
    }
}
