import Foundation

public struct CloneEngine: Sendable {
    public init() {}
    public func clone(sourceApp: String, targetApp: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sourceApp) else { throw WeBoxError.invalidAppBundle(sourceApp) }
        guard !fm.fileExists(atPath: targetApp) else { throw WeBoxError.instanceAlreadyExists(targetApp) }
        try fm.copyItem(atPath: sourceApp, toPath: targetApp)
    }
}
