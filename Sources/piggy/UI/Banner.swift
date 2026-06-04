import Foundation
import Darwin

// MARK: - Piggy Banner

enum Banner {
    private static let pink = "\u{1B}[38;5;211m"
    private static let blush = "\u{1B}[38;5;218m"
    private static let mauve = "\u{1B}[38;5;175m"
    private static let dim = "\u{1B}[38;5;238m"
    private static let bold = "\u{1B}[1m"
    private static let reset = "\u{1B}[0m"

    static let art = #"""
\#(dim)╭────────────────────────────────────────────────────────────────────────╮
\#(pink)│ ██████╗ ██╗ ██████╗  ██████╗ ██╗   ██╗                                │
\#(pink)│ ██╔══██╗██║██╔════╝ ██╔════╝ ╚██╗ ██╔╝                                │
\#(pink)│ ██████╔╝██║██║  ███╗██║  ███╗ ╚████╔╝                                 │
\#(pink)│ ██╔═══╝ ██║██║   ██║██║   ██║  ╚██╔╝                                  │
\#(pink)│ ██║     ██║╚██████╔╝╚██████╔╝   ██║                                   │
\#(pink)│ ╚═╝     ╚═╝ ╚═════╝  ╚═════╝    ╚═╝                                   │
\#(dim)│                                                                        │
\#(mauve)│              ▄▄████████████████▄▄                                      │
\#(mauve)│           ▄██▀  \#(blush)◉\#(mauve)              \#(blush)◉\#(mauve)  ▀██▄       \#(bold)\#(pink)SPACE HOG RADAR\#(reset)\#(dim)      │
\#(mauve)│          ██        ▄▄▄▄▄▄▄▄        ██      \#(mauve)sniff out disk hogs\#(dim)    │
\#(mauve)│          ██      ▄█  ▄██▄  █▄      ██                                │
\#(mauve)│           ▀██▄   █   ▀██▀   █   ▄██▀       \#(blush)● ● ●\#(dim)                    │
\#(mauve)│              ▀██▄▀█▄▄____▄▄█▀▄██▀                                  │
\#(mauve)│                 ▀██▄▄▄▄▄▄▄▄██▀                                      │
\#(dim)╰────────────────────────────────────────────────────────────────────────╯\#(reset)

"""#

    static let mini = #"""
\#(pink) ██████╗ ██╗ ██████╗  ██████╗ ██╗   ██╗
\#(pink) ██╔══██╗██║██╔════╝ ██╔════╝ ╚██╗ ██╔╝
\#(pink) ██████╔╝██║██║  ███╗██║  ███╗ ╚████╔╝
\#(pink) ██╔═══╝ ██║██║   ██║██║   ██║  ╚██╔╝
\#(pink) ██║     ██║╚██████╔╝╚██████╔╝   ██║
\#(pink) ╚═╝     ╚═╝ ╚═════╝  ╚═════╝    ╚═╝
\#(mauve)        ▄▄████████▄▄
\#(mauve)     ▄██▀ \#(blush)◉\#(mauve)      \#(blush)◉\#(mauve) ▀██▄
\#(mauve)    ██     ▄▄▄▄▄▄     ██   \#(pink)SPACE HOG RADAR\#(reset)
\#(mauve)     ▀██▄  █ ▀██▀ █ ▄██▀   \#(mauve)sniff out disk hogs\#(reset)
\#(mauve)        ▀██▄▄▄▄▄▄██▀

"""#

    static let micro = #"""
\#(pink)  PIGGY\#(reset)
\#(mauve)  ▄████▄
\#(mauve) ██ \#(blush)◉  ◉\#(mauve) ██
\#(mauve)  ▀█ ▀▀ █▀   \#(pink)SPACE HOG RADAR\#(reset)
\#(mauve)    ▀██▀     \#(mauve)sniff out disk hogs\#(reset)

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
    private static let pink = "\u{1B}[38;5;211m"
    private static let blush = "\u{1B}[38;5;218m"
    private static let mauve = "\u{1B}[38;5;175m"
    private static let dim = "\u{1B}[38;5;238m"
    private static let bold = "\u{1B}[1m"
    private static let reset = "\u{1B}[0m"

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
