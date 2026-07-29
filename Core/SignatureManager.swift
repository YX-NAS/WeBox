import Foundation

public struct SignatureManager: Sendable {
    public init() {}
    public func sign(appPath: String) throws {
        let runner = CommandRunner()
        _ = try? runner.run("/usr/bin/codesign", arguments: ["--remove-signature", appPath])
        _ = try runner.run("/usr/bin/codesign", arguments: ["--force", "--deep", "--sign", "-", appPath])
        try verify(appPath: appPath)
    }
    public func verify(appPath: String) throws {
        _ = try CommandRunner().run("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", appPath])
    }
}
