import Foundation

public enum ByteFormat {
    public static func string(_ bytes: Int64) -> String {
        let absSize = abs(bytes)

        switch absSize {
        case 0..<1_024:
            return "\(bytes) B"
        case 1_024..<1_048_576:
            return String(format: "%.1f KB", Double(absSize) / 1_024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1f MB", Double(absSize) / 1_048_576)
        default:
            return String(format: "%.2f GB", Double(absSize) / 1_073_741_824)
        }
    }
}
