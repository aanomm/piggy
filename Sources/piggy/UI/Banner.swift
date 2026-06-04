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
\#(pink)│  ██████╗ ██╗ ██████╗  ██████╗ ██╗   ██╗   \#(blush)macOS bloat radar\#(dim)            │
\#(pink)│  ██╔══██╗██║██╔════╝ ██╔════╝ ╚██╗ ██╔╝   \#(mauve)apps • agents • crumbs\#(dim)       │
\#(pink)│  ██████╔╝██║██║  ███╗██║  ███╗ ╚████╔╝                                 │
\#(pink)│  ██╔═══╝ ██║██║   ██║██║   ██║  ╚██╔╝                                  │
\#(pink)│  ██║     ██║╚██████╔╝╚██████╔╝   ██║        \#(bold)\#(pink)SNIFF. SORT. SAFELY CLEAN.\#(reset)\#(dim) │
\#(pink)│  ╚═╝     ╚═╝ ╚═════╝  ╚═════╝    ╚═╝                                   │
\#(dim)│                                                                        │
\#(mauve)│              .·°¯°·.        \#(dim)╭───────╮\#(mauve)        .·°¯°·.                   │
\#(mauve)│          ▄▓██████████▓▄     \#(dim)│  GB   │\#(mauve)     ▄▓██████████▓▄               │
\#(mauve)│        ▄██▀  \#(blush)◖◗\#(mauve)      \#(blush)◖◗\#(mauve)  ▀██▄   \#(dim)╰─┬─┬─╯\#(mauve)   ▄██▀  \#(blush)✦\#(mauve)       ▀██▄           │
\#(mauve)│       ██      ▄████▄      ██    \#(dim)  │ │\#(mauve)    ██   cache crumbs  ██         │
\#(mauve)│       ██   ▄▄█  ▐▌  █▄▄   ██    \#(dim)  │ │\#(mauve)    ██   old helpers   ██         │
\#(mauve)│        ▀██▄ ▀█▄▄▐▌▄▄█▀ ▄██▀     \#(dim)  │ │\#(mauve)     ▀██▄           ▄██▀          │
\#(mauve)│           ▀▀▓██▄▄▄▄██▓▀▀        \#(dim) ▄┴─┴▄\#(mauve)       ▀▀▓███████▓▀▀             │
\#(dim)│                    \#(blush)╰─ a tiny terminal truffle hound for your disk ─╯\#(dim)   │
\#(dim)╰────────────────────────────────────────────────────────────────────────╯\#(reset)

"""#

    static let mini = #"""
\#(pink) ██████╗ ██╗ ██████╗  ██████╗ ██╗   ██╗
\#(pink) ██╔══██╗██║██╔════╝ ██╔════╝ ╚██╗ ██╔╝
\#(pink) ██████╔╝██║██║  ███╗██║  ███╗ ╚████╔╝
\#(pink) ██╔═══╝ ██║██║   ██║██║   ██║  ╚██╔╝
\#(pink) ██║     ██║╚██████╔╝╚██████╔╝   ██║
\#(pink) ╚═╝     ╚═╝ ╚═════╝  ╚═════╝    ╚═╝
\#(mauve)       ▄▓████████▓▄      \#(dim)╭────╮\#(reset)
\#(mauve)     ▄██▀ \#(blush)◖◗\#(mauve)    \#(blush)◖◗\#(mauve) ▀██▄    \#(dim)│ GB │\#(reset)
\#(mauve)    ██    ▄████▄    ██   \#(pink)macOS bloat radar\#(reset)
\#(mauve)     ▀██▄ ▀█▐▌█▀ ▄██▀    \#(mauve)sniff • sort • clean safely\#(reset)
\#(mauve)        ▀▓██▄▄██▓▀

"""#

    static let micro = #"""
\#(pink)  PIGGY\#(reset)  \#(dim)macOS bloat radar\#(reset)
\#(mauve)  ▄▓██▓▄   \#(dim)╭──╮\#(reset)
\#(mauve) ██ \#(blush)◖◗◖◗\#(mauve) ██  \#(dim)│GB│\#(reset)
\#(mauve)  ▀█ ▐▌ █▀  \#(pink)sniff • sort • clean safely\#(reset)
\#(mauve)    ▀██▀

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
        var lines = frame.map { "  \(mauve)\($0)\(reset) \(dim)searching /Applications\(reset)" }
        lines.append("  \(bold)\(pink)PIGGY\(reset)  [\(bar)] \(blush)\(current)/\(total)\(reset)  \(mauve)\(shortName)\(reset)")
        return lines
    }
}
