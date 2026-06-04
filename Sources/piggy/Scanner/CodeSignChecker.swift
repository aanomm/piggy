import Foundation
import Security

enum CodeSignChecker {
    static func isAppleSigned(appPath: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appPath as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return false }

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString("anchor apple" as CFString, SecCSFlags(rawValue: 0), &requirement) == errSecSuccess,
              let req = requirement else { return false }

        var cfDict: CFDictionary?
        let status = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: 0), &cfDict)
        if status != errSecSuccess { return false }

        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: 0), req) == errSecSuccess
    }

    static func detectArchitecture(appPath: URL) -> Architecture {
        let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
        let infoPlist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any]
        let executableName = infoPlist?["CFBundleExecutable"] as? String
        var exePath: URL
        if let name = executableName {
            exePath = appPath.appendingPathComponent("Contents/MacOS").appendingPathComponent(name)
        } else {
            exePath = appPath
        }

        if !FileManager.default.fileExists(atPath: exePath.path) {
            return .unknown
        }

        return parseLipoArch(path: exePath)
    }

    static func isFromAppStore(appPath: URL) -> Bool {
        let receiptPath = appPath.appendingPathComponent("Contents/_MASReceipt")
        return FileManager.default.fileExists(atPath: receiptPath.path)
    }

    static func isQuarantined(appPath: URL) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: appPath.path)
        return attrs?[.immutable] != nil
    }

    private static func parseLipoArch(path: URL) -> Architecture {
        let task = Process()
        task.launchPath = "/usr/bin/lipo"
        task.arguments = ["-info", path.path]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return .unknown
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else {
            return fallbackArch(path: path)
        }

        let lower = output.lowercased()

        if lower.contains("i386") || lower.contains("ppc") {
            return .i386
        }
        if lower.contains("arm64") && lower.contains("x86_64") {
            return .universal
        }
        if lower.contains("arm64") {
            return .arm64
        }
        if lower.contains("x86_64") {
            return .x86_64
        }
        return .unknown
    }

    private static func fallbackArch(path: URL) -> Architecture {
        let task = Process()
        task.launchPath = "/usr/bin/file"
        task.arguments = [path.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return .unknown
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.lowercased() else { return .unknown }

        if output.contains("i386") || output.contains("ppc") { return .i386 }
        if output.contains("arm64") && output.contains("x86_64") { return .universal }
        if output.contains("arm64") { return .arm64 }
        if output.contains("x86_64") { return .x86_64 }
        return .unknown
    }
}
