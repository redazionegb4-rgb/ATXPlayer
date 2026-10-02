import Foundation

enum DeviceIdentity {
    private static let key = "atx.device.code.v1"
    static func code() -> String {
        if let existing = KeychainStore.read(key), !existing.isEmpty { return existing }
        let raw = UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
        let code = "ATX-\(raw.prefix(4))-\(raw.dropFirst(4).prefix(4))-\(raw.dropFirst(8).prefix(4))"
        KeychainStore.save(code, for: key)
        return code
    }
}
