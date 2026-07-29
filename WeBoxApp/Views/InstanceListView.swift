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
            _ = try InstanceManager(repository: repository).createInstance(name: name, sourceInfo: info)
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
        } catch { errorMessage = error.localizedDescription }
    }
}

struct InstanceListView: View {
    @ObservedObject var model: InstanceListViewModel
    @State private var isShowingCreateSheet = false
    @State private var instancePendingDeletion: WeChatInstance?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()

                if model.instances.isEmpty {
                    EmptyInstanceView(createAction: { isShowingCreateSheet = true })
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 18)], spacing: 18) {
                            ForEach(model.instances) { instance in
                                InstanceCard(
                                    instance: instance,
                                    startAction: { model.start(instance) },
                                    stopAction: { model.stop(instance) },
                                    deleteAction: { instancePendingDeletion = instance }
                                )
                            }
                        }
                        .padding(28)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateInstanceSheet(isCreating: model.isCreating) { name in
                isShowingCreateSheet = false
                model.createInstance(named: name)
            }
        }
        .alert("操作失败", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("删除微信实例？", isPresented: Binding(get: { instancePendingDeletion != nil }, set: { if !$0 { instancePendingDeletion = nil } })) {
            Button("移入废纸篓并删除记录", role: .destructive) {
                if let instancePendingDeletion { model.delete(instancePendingDeletion) }
                instancePendingDeletion = nil
            }
            Button("取消", role: .cancel) { instancePendingDeletion = nil }
        } message: {
            Text("将关闭并把“\(instancePendingDeletion?.name ?? "")”移入废纸篓。")
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.accentColor.gradient)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("WeBox").font(.system(size: 26, weight: .bold))
                Text("微信实例管理").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(model.instances.count) 个实例")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
            Button { isShowingCreateSheet = true } label: {
                Label("创建实例", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isCreating)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }
}

private struct EmptyInstanceView: View {
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12))
                Image(systemName: "message.badge.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 132, height: 132)
            Text("还没有微信实例").font(.title2.bold())
            Text("创建独立副本后，可分别登录和管理多个微信账号。")
                .foregroundStyle(.secondary)
            Button(action: createAction) {
                Label("创建第一个实例", systemImage: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InstanceCard: View {
    let instance: WeChatInstance
    let startAction: () -> Void
    let stopAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(statusColor.opacity(0.14))
                    Image(systemName: instance.status == .running ? "message.fill" : "message")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                .frame(width: 76, height: 76)

                Spacer()
                StatusBadge(status: instance.status)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(instance.name).font(.title3.bold()).lineLimit(1)
                Text("微信 \(instance.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(instance.bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                IconActionButton(title: "启动", icon: "play.fill", tint: .green, action: startAction)
                IconActionButton(title: "关闭", icon: "stop.fill", tint: .orange, action: stopAction)
                IconActionButton(title: "删除", icon: "trash.fill", tint: .red, action: deleteAction)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.quaternary))
    }

    private var statusColor: Color {
        switch instance.status {
        case .running: .green
        case .needUpdate, .error: .red
        case .stopped: .orange
        default: .blue
        }
    }
}

private struct StatusBadge: View {
    let status: InstanceStatus
    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
    }
}

private struct IconActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3.weight(.semibold))
                Text(title).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .help(title)
    }
}

private struct CreateInstanceSheet: View {
    let isCreating: Bool
    let createAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("创建微信实例").font(.title2.bold())
                    Text("每个实例都是独立的微信应用副本。")
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("实例名称").font(.headline)
                TextField("例如：工作微信", text: $name)
                    .textFieldStyle(.roundedBorder)
                Text("同名时会自动添加编号，例如“工作微信 2”。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button {
                    createAction(name)
                } label: {
                    Label("创建实例", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
        }
        .padding(28)
        .frame(width: 460)
    }
}
