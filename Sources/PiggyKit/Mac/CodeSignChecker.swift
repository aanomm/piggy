import Darwin
import Foundation
import Security

public enum CodeSignChecker {
    public static func isAppleSigned(appPath: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appPath as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return false }

        var cfDict: CFDictionary?
        let status = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &cfDict
        )
        guard status == errSecSuccess,
              let info = cfDict as? [String: Any],
              let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first,
              let summary = SecCertificateCopySubjectSummary(leaf) as String?
        else { return false }

        let lower = summary.lowercased()
        return lower == "software signing" ||
            lower.contains("apple mac os") ||
            lower.contains("apple system") ||
            lower.hasPrefix("apple ")
    }

    public static func detectArchitecture(appPath: URL) -> Architecture {
        let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
        let infoPlist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any]
        let executableName = infoPlist?["CFBundleExecutable"] as? String
        let exePath: URL
        if let name = executableName {
            exePath = appPath.appendingPathComponent("Contents/MacOS").appendingPathComponent(name)
        } else {
            exePath = appPath
        }

        guard FileManager.default.fileExists(atPath: exePath.path) else {
            return .unknown
        }

        return MachOArchitectureDetector.detect(path: exePath)
    }

    public static func isFromAppStore(appPath: URL) -> Bool {
        let receiptPath = appPath.appendingPathComponent("Contents/_MASReceipt")
        return FileManager.default.fileExists(atPath: receiptPath.path)
    }

    public static func isQuarantined(appPath: URL) -> Bool {
        hasExtendedAttribute(named: "com.apple.quarantine", at: appPath)
    }

    private static func hasExtendedAttribute(named name: String, at url: URL) -> Bool {
        getxattr(url.path, name, nil, 0, 0, 0) >= 0
    }
}

private enum MachOArchitectureDetector {
    private static let mhMagic: UInt32 = 0xfeedface
    private static let mhCigam: UInt32 = 0xcefaedfe
    private static let mhMagic64: UInt32 = 0xfeedfacf
    private static let mhCigam64: UInt32 = 0xcffaedfe
    private static let fatMagic: UInt32 = 0xcafebabe
    private static let fatCigam: UInt32 = 0xbebafeca
    private static let fatMagic64: UInt32 = 0xcafebabf
    private static let fatCigam64: UInt32 = 0xbfbafeca

    private static let cpuArchAbi64: UInt32 = 0x01000000
    private static let cpuTypeX86: UInt32 = 7
    private static let cpuTypeArm: UInt32 = 12
    private static let cpuTypePowerPC: UInt32 = 18

    static func detect(path: URL) -> Architecture {
        guard let handle = try? FileHandle(forReadingFrom: path) else { return .unknown }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: 64 * 1024)
        guard data.count >= 8 else { return .unknown }

        let magic = readUInt32(data, offset: 0, endian: .big)
        switch magic {
        case fatMagic, fatMagic64:
            return classify(cpuTypes: readFatCPUTypes(data, endian: .big, is64Bit: magic == fatMagic64))
        case fatCigam, fatCigam64:
            return classify(cpuTypes: readFatCPUTypes(data, endian: .little, is64Bit: magic == fatCigam64))
        default:
            return classify(cpuTypes: readThinCPUType(data).map { [$0] } ?? [])
        }
    }

    private static func readThinCPUType(_ data: Data) -> UInt32? {
        let bigMagic = readUInt32(data, offset: 0, endian: .big)
        let littleMagic = readUInt32(data, offset: 0, endian: .little)

        if littleMagic == mhMagic || littleMagic == mhMagic64 {
            return readUInt32(data, offset: 4, endian: .little)
        }
        if bigMagic == mhMagic || bigMagic == mhMagic64 {
            return readUInt32(data, offset: 4, endian: .big)
        }
        return nil
    }

    private static func readFatCPUTypes(_ data: Data, endian: Endian, is64Bit: Bool) -> [UInt32] {
        guard data.count >= 8 else { return [] }
        let count = min(Int(readUInt32(data, offset: 4, endian: endian)), 256)
        let archSize = is64Bit ? 32 : 20
        var types: [UInt32] = []

        for index in 0..<count {
            let offset = 8 + index * archSize
            guard offset + 4 <= data.count else { break }
            types.append(readUInt32(data, offset: offset, endian: endian))
        }
        return types
    }

    private static func classify(cpuTypes: [UInt32]) -> Architecture {
        guard !cpuTypes.isEmpty else { return .unknown }
        let normalized = Set(cpuTypes.map { $0 & ~cpuArchAbi64 })
        let has64Bit = Set(cpuTypes.map { $0 & cpuArchAbi64 }).contains(cpuArchAbi64)
        let hasArm64 = cpuTypes.contains(cpuTypeArm | cpuArchAbi64)
        let hasX8664 = cpuTypes.contains(cpuTypeX86 | cpuArchAbi64)
        let hasI386 = normalized.contains(cpuTypeX86) && !has64Bit
        let hasPowerPC = normalized.contains(cpuTypePowerPC)

        if hasArm64 && hasX8664 { return .universal }
        if hasArm64 { return .arm64 }
        if hasX8664 { return .x86_64 }
        if hasI386 || hasPowerPC { return .i386 }
        return .unknown
    }

    private enum Endian {
        case big
        case little
    }

    private static func readUInt32(_ data: Data, offset: Int, endian: Endian) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        switch endian {
        case .big:
            return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
        case .little:
            return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
        }
    }
}
