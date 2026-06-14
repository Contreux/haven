import Foundation

enum DeviceIdentity {
    /// Stable per-install id. DEBUG uses the seeded id so the simulator sees demo data.
    static var current: String {
        #if DEBUG
        return "sim-device"
        #else
        let key = "haven.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
        #endif
    }
}
