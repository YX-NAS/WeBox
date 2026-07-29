import Foundation

public struct BundleManager: Sendable {
    public init() {}
    public func bundleIdentifier(for name: String) -> String {
        let slug = name.lowercased().unicodeScalars.map { scalar -> String in
            switch scalar.value {
            case 48...57, 97...122: String(scalar)
            case 0x4E00...0x9FFF: "u" + String(scalar.value, radix: 16)
            default: "-"
            }
        }.joined().split(separator: "-").filter { !$0.isEmpty }.joined(separator: "-")
        return "com.webox.wechat.\(slug.isEmpty ? "instance" : slug)"
    }
    public func updateBundleIdentifier(appPath: String, bundleIdentifier: String) throws {
        let plist = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist").path
        try CommandRunner().run("/usr/libexec/PlistBuddy", arguments: ["-c", "Set :CFBundleIdentifier \(bundleIdentifier)", plist])
    }
}
