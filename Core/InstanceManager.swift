import Foundation

public struct InstanceManager: Sendable {
    private let repository: InstanceRepository
    private let cloneEngine = CloneEngine(); private let bundleManager = BundleManager(); private let signatureManager = SignatureManager()
    public init(repository: InstanceRepository) { self.repository = repository }
    @discardableResult public func createInstance(name: String, sourceInfo: WeChatInfo, installDirectory: String = "/Applications") throws -> WeChatInstance {
        let (resolvedName, target) = try availableTarget(for: name, application: sourceInfo.application, installDirectory: installDirectory)
        let identifier = bundleManager.bundleIdentifier(for: resolvedName, application: sourceInfo.application)
        try cloneEngine.clone(sourceApp: sourceInfo.path, targetApp: target)
        do {
            try bundleManager.updateBundleIdentifier(appPath: target, bundleIdentifier: identifier)
            try signatureManager.sign(appPath: target)
            let instance = WeChatInstance(application: sourceInfo.application, name: resolvedName, bundleIdentifier: identifier, appPath: target, version: sourceInfo.version, status: .ready)
            try repository.save(instance)
            return instance
        } catch {
            try? FileManager.default.removeItem(atPath: target)
            throw error
        }
    }

    public func deleteInstance(_ instance: WeChatInstance) throws {
        try? ProcessManager().stop(instance: instance)
        let appURL = URL(fileURLWithPath: instance.appPath)
        if FileManager.default.fileExists(atPath: appURL.path) {
            try FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
        }
        try repository.delete(id: instance.id)
    }

    public func repairInstance(_ instance: WeChatInstance) throws {
        guard FileManager.default.fileExists(atPath: instance.appPath) else {
            throw WeBoxError.invalidAppBundle(instance.appPath)
        }
        guard ProcessManager().pid(instance: instance) == nil else {
            throw WeBoxError.instanceIsRunning(instance.name)
        }
        try bundleManager.updateBundleIdentifier(appPath: instance.appPath, bundleIdentifier: instance.bundleIdentifier)
        try signatureManager.sign(appPath: instance.appPath)
        try repository.updateStatus(id: instance.id, status: .ready)
    }

    public func repairLegacyBundleIdentifiers() throws {
        for instance in try repository.all() {
            let expectedIdentifier = bundleManager.bundleIdentifier(for: instance.name, application: instance.application)
            guard instance.bundleIdentifier != expectedIdentifier else { continue }

            var repaired = instance
            let appURL = URL(fileURLWithPath: instance.appPath)
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                repaired.status = .error
                try repository.save(repaired)
                continue
            }

            if ProcessManager().pid(instance: instance) != nil {
                repaired.status = .needUpdate
                try repository.save(repaired)
                continue
            }

            do {
                try bundleManager.updateBundleIdentifier(appPath: instance.appPath, bundleIdentifier: expectedIdentifier)
                try signatureManager.sign(appPath: instance.appPath)
                repaired.bundleIdentifier = expectedIdentifier
                repaired.status = .ready
                try repository.save(repaired)
            } catch {
                repaired.status = .error
                try? repository.save(repaired)
            }
        }
    }

    private func availableTarget(for name: String, application: ManagedApplication, installDirectory: String) throws -> (String, String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? "\(application.displayName)实例" : trimmedName.replacingOccurrences(of: "/", with: "-")
        let existingNames = Set(try repository.all().filter { $0.application == application }.map(\.name))
        var number = 1
        while true {
            let candidateName = number == 1 ? baseName : "\(baseName) \(number)"
            let target = URL(fileURLWithPath: installDirectory).appendingPathComponent("\(application.clonePrefix)_\(candidateName).app").path
            if !FileManager.default.fileExists(atPath: target) && !existingNames.contains(candidateName) {
                return (candidateName, target)
            }
            number += 1
        }
    }
}
