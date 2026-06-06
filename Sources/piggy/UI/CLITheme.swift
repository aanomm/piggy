import Darwin
import Foundation
import PiggyKit

enum CLITheme {
    static func title(_ text: String) -> String { paint(text, "38;5;175;1") }
    static func section(_ text: String) -> String { paint(text, "38;5;183;1") }
    static func label(_ text: String) -> String { paint(text, "38;5;248") }
    static func dim(_ text: String) -> String { paint(text, "38;5;240") }
    static func path(_ text: String) -> String { paint(text, "38;5;103") }
    static func command(_ text: String) -> String { paint(text, "38;5;116") }
    static func gold(_ text: String) -> String { paint(text, "38;5;179") }
    static func blue(_ text: String) -> String { paint(text, "38;5;110") }
    static func green(_ text: String) -> String { paint(text, "38;5;114") }
    static func purple(_ text: String) -> String { paint(text, "38;5;141") }
    static func warning(_ text: String) -> String { paint(text, "38;5;215;1") }
    static func danger(_ text: String) -> String { paint(text, "38;5;203;1") }
    static func ok(_ text: String) -> String { paint(text, "38;5;151") }
    static func bold(_ text: String) -> String { paint(text, "1") }

    static func separator(_ text: String) -> String {
        paint(text, "38;5;238")
    }

    static func rank(_ text: String, index: Int) -> String {
        switch index {
        case 0: return purple(text)
        case 1: return gold(text)
        case 2: return blue(text)
        default: return label(text)
        }
    }

    static func treeGuide(_ text: String) -> String { paint(text, "38;5;250") }
    static func mudMapFolderIcon(_ text: String) -> String { paint(text, "38;5;221") }

    static func mudMapName(_ text: String, depth: Int, isDirectory: Bool) -> String {
        guard isDirectory else { return label(text) }
        switch depth {
        case 0: return purple(text)
        case 1: return gold(text)
        case 2: return blue(text)
        default: return green(text)
        }
    }

    static func mudMapSummary(_ text: String, isFolders: Bool) -> String {
        isFolders ? blue(text) : label(text)
    }

    static func size(_ text: String, bytes: Int64) -> String {
        let absSize = abs(bytes)
        if absSize >= 10_737_418_240 { return purple(text) }
        if absSize >= 1_073_741_824 { return gold(text) }
        if absSize >= 104_857_600 { return blue(text) }
        return label(text)
    }

    static func flag(_ text: String) -> String {
        switch text.trimmingCharacters(in: .whitespaces) {
        case "!": return danger(text)
        case "R", "~": return warning(text)
        default: return label(text)
        }
    }

    static func bar(value: Int64, max maxValue: Int64, width: Int, index: Int) -> String {
        guard width > 0 else { return "" }
        let ratio = maxValue > 0 ? Double(value) / Double(maxValue) : 0
        let filled = min(width, Swift.max(1, Int((ratio * Double(width)).rounded())))
        let empty = Swift.max(0, width - filled)
        let filledText = String(repeating: "█", count: filled)
        let emptyText = empty > 0 ? String(repeating: "░", count: empty) : ""

        let coloredFilled: String
        switch index {
        case 0: coloredFilled = gold(filledText)
        case 1: coloredFilled = blue(filledText)
        case 2: coloredFilled = green(filledText)
        default: coloredFilled = paint(filledText, "38;5;65")
        }

        return coloredFilled + (emptyText.isEmpty ? "" : dim(emptyText))
    }

    private static func paint(_ text: String, _ code: String) -> String {
        let start = TerminalStyle.ansi(code, stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
        guard !start.isEmpty else { return text }
        return start + text + TerminalStyle.ansi("0", stdoutIsTTY: true)
    }
}
