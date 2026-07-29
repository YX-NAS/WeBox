import Foundation

public struct BundleManager: Sendable {
    public init() {}
    public func bundleIdentifier(for name: String) -> String {
        let slug = name.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined().split(separator: "-").filter { !$0.isEmpty }.joined(separator: "-")
        return "com.webox.wechat.\(slug.isEmpty ? "instance" : slug)"
    }
    public func updateBundleIdentifier(appPath: String, bundleIdentifier: String) throws {
        let plist = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist").path
        try CommandRunner().run("/usr/libexec/PlistBuddy", arguments: ["-c", "Set :CFBundleIdentifier \(bundleIdentifier)", plist])
    }
}
