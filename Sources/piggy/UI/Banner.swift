import Foundation
import Darwin
import PiggyKit

// MARK: - Piggy Banner

enum Banner {
    private static let pink = TerminalStyle.ansi("38;5;211", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let blush = TerminalStyle.ansi("38;5;218", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let mauve = TerminalStyle.ansi("38;5;175", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let dim = TerminalStyle.ansi("38;5;238", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let bold = TerminalStyle.ansi("1", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let reset = TerminalStyle.ansi("0", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)

    static let art = #"""
\#(dim)╭────────────────────────────────────────────────────────────────────────╮
\#(pink)│  PIGGY                                                   \#(blush)(oo)\#(pink)          │
\#(pink)│  Find fat folders and files on your Mac.                               │
\#(dim)╰────────────────────────────────────────────────────────────────────────╯\#(reset)

"""#

    static let mini = #"""
\#(pink) PIGGY\#(reset)  \#(dim)Find fat folders and files on your Mac.\#(reset)

"""#

    static let micro = #"""
\#(pink) PIGGY\#(reset)  \#(dim)fat files\#(reset)

"""#

    static func printBanner() {
        let cols = currentTerminalWidth()
        if cols >= 78 {
            fputs(art + "\n", stdout)
        } else if cols >= 56 {
            fputs(mini + "\n", stdout)
        } else {
            fputs(micro + "\n", stdout)
        }
        fflush(stdout)
    }

    static func currentTerminalWidth() -> Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0, ws.ws_col > 0 {
            return max(40, Int(ws.ws_col))
        }
        if let columns = ProcessInfo.processInfo.environment["COLUMNS"],
           let width = Int(columns),
           width > 0 {
            return max(40, width)
        }
        return 80
    }
}

// MARK: - Animated Scan Scene

enum Spinner {
    private static let pink = TerminalStyle.ansi("38;5;211", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let blush = TerminalStyle.ansi("38;5;218", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let mauve = TerminalStyle.ansi("38;5;175", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let dim = TerminalStyle.ansi("38;5;238", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let bold = TerminalStyle.ansi("1", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)
    private static let reset = TerminalStyle.ansi("0", stdoutIsTTY: isatty(STDOUT_FILENO) != 0)

    private static let compactFaces = ["( . . )", "( o o )", "( O O )", "( - - )"]

    private static let scanFrames: [[String]] = [
        [
            "        ▄▄████████▄▄        ",
            "     ▄██▀ ◉      ◉ ▀██▄  ·  ",
            "    ██     ▄▄▄▄▄▄     ██ ·· ",
            "     ▀██▄  █ ▀██▀ █ ▄██▀ ···",
            "        ▀██▄▄▄▄▄▄██▀        ",
        ],
        [
            "         ▄▄████████▄▄       ",
            "      ▄██▀ ◉      ◉ ▀██▄ ·· ",
            "     ██     ▄▄▄▄▄▄     ██ · ",
            "      ▀██▄  █ ▀██▀ █ ▄██▀···",
            "       ▄▀▀██▄▄▄▄▄▄██▀▀▄     ",
        ],
        [
            "        ▄▄████████▄▄        ",
            "     ▄██▀ ◎      ◎ ▀██▄ ··· ",
            "    ██     ▄▄▄▄▄▄     ██ ·· ",
            "     ▀██▄  █ ▄██▄ █ ▄██▀ ·  ",
            "        ▀██▄▄▄▄▄▄██▀        ",
        ],
        [
            "         ▄▄████████▄▄       ",
            "      ▄██▀ -      - ▀██▄  · ",
            "     ██     ▄▄▄▄▄▄     ██   ",
            "      ▀██▄  █ ▀██▀ █ ▄██▀ · ",
            "       ▄▀▀██▄▄▄▄▄▄██▀▀▄     ",
        ],
    ]

    static func runDuringScan(closure: @escaping (@escaping (Int, Int, String) -> Void) -> Void) {
        let bgQueue = DispatchQueue(label: "piggy.scan")

        nonisolated(unsafe) var done = false
        nonisolated(unsafe) var current: Int = 0
        nonisolated(unsafe) var total: Int = 0
        nonisolated(unsafe) var currentApp: String = ""
        let lock = NSLock()

        let progress: (Int, Int, String) -> Void = { c, t, name in
            lock.lock()
            current = c
            total = t
            currentApp = name
            lock.unlock()
        }

        nonisolated(unsafe) let scanClosure = closure
        nonisolated(unsafe) let scanProgress = progress

        bgQueue.async {
            scanClosure(scanProgress)
            lock.lock()
            done = true
            lock.unlock()
        }

        guard isatty(STDOUT_FILENO) != 0 else {
            while true {
                lock.lock()
                let isDone = done
                lock.unlock()
                if isDone { break }
                Thread.sleep(forTimeInterval: 0.08)
            }
            return
        }

        var frameIndex = 0
        let cols = max(40, Banner.currentTerminalWidth())
        var renderedLineCount = 0

        while true {
            lock.lock()
            let isDone = done
            let c = current
            let t = total
            let name = currentApp
            lock.unlock()

            if isDone { break }

            let lines = renderFrame(index: frameIndex, current: c, total: t, appName: name, width: cols)
            if renderedLineCount > 0 {
                fputs("\u{1B}[\(renderedLineCount)A", stdout)
            }
            for line in lines {
                fputs("\r\u{1B}[2K\(line)\n", stdout)
            }
            fflush(stdout)

            renderedLineCount = lines.count
            frameIndex += 1
            Thread.sleep(forTimeInterval: 0.10)
        }

        if renderedLineCount > 0 {
            fputs("\u{1B}[\(renderedLineCount)A", stdout)
            for _ in 0..<renderedLineCount {
                fputs("\r\u{1B}[2K\n", stdout)
            }
            fputs("\u{1B}[\(renderedLineCount)A", stdout)
        }
        fflush(stdout)
    }

    static func renderFrame(index: Int, current: Int, total: Int, appName: String, width: Int) -> [String] {
        let barWidth = max(8, min(36, width - 38))
        let percent = total > 0 ? Double(current) / Double(total) : 0
        let filled = max(0, min(barWidth, Int(percent * Double(barWidth))))
        let empty = max(0, barWidth - filled)
        let bar = pink + String(repeating: "#", count: filled) + dim + String(repeating: "-", count: empty) + reset
        let shortName = appName.replacingOccurrences(of: ".app", with: "").prefix(width >= 90 ? 34 : 22)

        if width < 70 {
            let face = compactFaces[index % compactFaces.count]
            return ["  \(pink)\(face)\(reset) [\(bar)] \(blush)\(current)/\(total)\(reset)  \(mauve)\(shortName)\(reset)"]
        }

        let frame = scanFrames[index % scanFrames.count]
        var lines = frame.map { "  \(mauve)\($0)\(reset) \(dim)sniffing the Mac pile\(reset)" }
        lines.append("  \(bold)\(pink)PIGGY\(reset)  [\(bar)] \(blush)\(current)/\(total)\(reset)  \(mauve)\(shortName)\(reset)  \(dim)looks first\(reset)")
        return lines
    }
}

// MARK: - Lightweight CLI Activity

final class TerminalActivityIndicator {
    private let action: String
    private let doneLabel: String
    private let enabled: Bool
    private let colorEnabled: Bool
    private let frames = ["|", "/", "-", "\\"]

    private let startedAt = Date()
    private var lastRenderedAt = Date.distantPast
    private var renderCount = 0
    private var latestStatus: String?

    init(action: String, doneLabel: String = "Done") {
        self.action = action
        self.doneLabel = doneLabel

        let environment = ProcessInfo.processInfo.environment
        let progressValue = environment["PIGGY_PROGRESS"]?.lowercased()
        let forced = ["1", "true", "yes", "always"].contains(progressValue)
        let disabled = ["0", "false", "no", "never"].contains(progressValue)

        self.enabled = !disabled && (
            forced || (
                isatty(STDERR_FILENO) == 1 &&
                environment["TERM"] != "dumb"
            )
        )
        self.colorEnabled = TerminalStyle.colorsEnabled(environment: environment, stdoutIsTTY: isatty(STDERR_FILENO) == 1)
    }

    func start(_ status: String? = nil) {
        latestStatus = status
        render(status: status, force: true)
    }

    func update(_ status: String? = nil) {
        latestStatus = status ?? latestStatus
        render(status: latestStatus, force: false)
    }

    func finish(_ summary: String? = nil) {
        guard enabled else { return }
        let elapsed = formatElapsed(max(0.01, Date().timeIntervalSince(startedAt)))
        let status = summary ?? latestStatus
        let suffix = status.map { " - \(paint($0, "38;5;179"))" } ?? ""
        write("\r\u{001B}[2K\(paint(doneLabel, "38;5;151;1"))\(suffix) \(paint("in \(elapsed)", "38;5;240"))\n")
    }

    private func render(status: String?, force: Bool) {
        guard enabled else { return }

        let now = Date()
        guard force || renderCount == 0 || now.timeIntervalSince(lastRenderedAt) >= 0.08 else { return }

        lastRenderedAt = now
        let frame = frames[renderCount % frames.count]
        renderCount += 1

        let suffix = status.map { " - \(paint(Self.clipped($0, to: 72), "38;5;179"))" } ?? ""
        write("\r\u{001B}[2K\(paint(frame, "38;5;141")) \(paint(action, "38;5;175;1"))\(suffix)")
    }

    static func clipped(_ text: String, to maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        return "..." + text.suffix(max(0, maxLength - 3))
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        if seconds < 10 {
            return String(format: "%.1fs", seconds)
        }
        return "\(Int(seconds.rounded()))s"
    }

    private func write(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }

    private func paint(_ text: String, _ code: String) -> String {
        guard colorEnabled else { return text }
        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }
}
