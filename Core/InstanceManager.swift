import Foundation

public struct InstanceManager: Sendable {
    private let repository: InstanceRepository
    private let cloneEngine = CloneEngine(); private let bundleManager = BundleManager(); private let signatureManager = SignatureManager()
    public init(repository: InstanceRepository) { self.repository = repository }
    @discardableResult public func createInstance(name: String, sourceInfo: WeChatInfo, installDirectory: String = "/Applications") throws -> WeChatInstance {
        let (resolvedName, target) = try availableTarget(for: name, installDirectory: installDirectory)
        let identifier = bundleManager.bundleIdentifier(for: resolvedName)
        try cloneEngine.clone(sourceApp: sourceInfo.path, targetApp: target)
        do {
            try bundleManager.updateBundleIdentifier(appPath: target, bundleIdentifier: identifier)
            try signatureManager.sign(appPath: target)
            let instance = WeChatInstance(name: resolvedName, bundleIdentifier: identifier, appPath: target, version: sourceInfo.version, status: .ready)
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

    public func repairLegacyBundleIdentifiers() throws {
        for instance in try repository.all() {
            let expectedIdentifier = bundleManager.bundleIdentifier(for: instance.name)
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

    private func availableTarget(for name: String, installDirectory: String) throws -> (String, String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? "微信实例" : trimmedName.replacingOccurrences(of: "/", with: "-")
        let existingNames = Set(try repository.all().map(\.name))
        var number = 1
        while true {
            let candidateName = number == 1 ? baseName : "\(baseName) \(number)"
            let target = URL(fileURLWithPath: installDirectory).appendingPathComponent("WeBox_\(candidateName).app").path
            if !FileManager.default.fileExists(atPath: target) && !existingNames.contains(candidateName) {
                return (candidateName, target)
            }
            number += 1
        }
    }
}
