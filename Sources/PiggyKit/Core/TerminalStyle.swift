import Foundation

public enum TerminalStyle {
    public static func colorsEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        stdoutIsTTY: Bool = true
    ) -> Bool {
        if let override = environment["PIGGY_COLOR"]?.lowercased() {
            if ["always", "1", "true", "yes", "on"].contains(override) { return true }
            if ["never", "0", "false", "no", "off"].contains(override) { return false }
        }

        if !stdoutIsTTY { return false }

        if let noColor = environment["NO_COLOR"], !noColor.isEmpty {
            return false
        }

        if environment["TERM"] == "dumb" {
            return false
        }

        return true
    }

    public static func ansi(
        _ code: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        stdoutIsTTY: Bool = true
    ) -> String {
        colorsEnabled(environment: environment, stdoutIsTTY: stdoutIsTTY) ? "\u{1B}[\(code)m" : ""
    }
}
