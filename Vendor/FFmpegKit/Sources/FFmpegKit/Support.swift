import Darwin
import Foundation

public enum ArchDetect {
    public static func getCpuArch() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    public static func getArch() -> String { getCpuArch() }
}

public enum Packages {
    public static func getPackageName() -> String { "custom" }
    public static func getExternalLibraries() -> [String] { [] }
}
