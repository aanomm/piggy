import Foundation
import ArgumentParser
import PiggyKit

nonisolated(unsafe) private var _splashTermios: termios?

private func handleSplashInterrupt(_ signalNumber: Int32) {
    if var t = _splashTermios {
        t.c_lflag |= tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        t.c_iflag |= tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        t.c_oflag |= tcflag_t(OPOST)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &t)
    }
    let pink = TerminalStyle.ansi("38;5;211", stdoutIsTTY: true)
    let reset = TerminalStyle.ansi("0", stdoutIsTTY: true)
    print("\n  \(pink)Oink!\(reset)\n")
    exit(0)
}

private let MENU_ITEMS: [(String, String, String)] = [
    ("1", "Sniff",   "See a simple view of fat folders and files"),
    ("2", "Snort",   "See a detailed view of fat folders and files"),
    ("3", "Search",  "See specific files, folders, apps / imgs / vids / docs"),
    ("4", "Mud map", "See a mud map of your folders"),
]

enum SplashMenu {
    static func run() {
        guard isatty(STDIN_FILENO) != 0, isatty(STDOUT_FILENO) != 0 else {
            printNonInteractiveHelp()
            return
        }

        signal(SIGINT, handleSplashInterrupt)

        var orig = termios()
        tcgetattr(STDIN_FILENO, &orig)
        _splashTermios = orig
        defer { tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig) }

        var raw = orig
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        raw.c_cflag |= tcflag_t(CS8)

        var selectedIndex = 0
        var isFirstRender = true

        while true {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
            render(selectedIndex: selectedIndex, isFirstRender: isFirstRender)

            guard let key = readMenuKey() else { continue }

            switch key {
            case .up:
                selectedIndex = max(0, selectedIndex - 1)
            case .down:
                selectedIndex = min(MENU_ITEMS.count - 1, selectedIndex + 1)
            case .enter:
                if !executeMenuItem(selectedIndex, termOrig: &orig) {
                    return
                }
                isFirstRender = false
            case .char(let ch):
                switch ch {
                case "1":
                    if !executeMenuItem(0, termOrig: &orig) { return }
                    isFirstRender = false
                case "2":
                    if !executeMenuItem(1, termOrig: &orig) { return }
                    isFirstRender = false
                case "3":
                    if !executeMenuItem(2, termOrig: &orig) { return }
                    isFirstRender = false
                case "4":
                    if !executeMenuItem(3, termOrig: &orig) { return }
                    isFirstRender = false
                case "q":
                    restoreTerm()
                    print("  \(PINK)Oink!\(RESET)\n")
                    return
                case "h":
                    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig)
                    printHelp()
                    waitForEnter()
                    isFirstRender = false
                default:
                    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig)
                    let remaining = readLine(strippingNewline: true) ?? ""
                    let fullInput = (String(ch) + remaining).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !fullInput.isEmpty else { continue }

                    switch fullInput {
                    case "audit", "a", "mac audit":
                        let auditCmd = Audit.parseOrExit([])
                        try? auditCmd.run()
                        waitForEnter()
                        isFirstRender = false
                    case "folders", "folder", "f":
                        let foldersCmd = Folders.parseOrExit([])
                        try? foldersCmd.run()
                        waitForEnter()
                        isFirstRender = false
                    case "snort", "snort big", "big", "list", "l":
                        let snortCmd = Snort.parseOrExit([])
                        try? snortCmd.run()
                        waitForEnter()
                        isFirstRender = false
                    case "snort small", "small":
                        let snortCmd = Snort.parseOrExit(["small"])
                        try? snortCmd.run()
                        waitForEnter()
                        isFirstRender = false
                    case "snort new", "new":
                        let snortCmd = Snort.parseOrExit(["new"])
                        try? snortCmd.run()
                        waitForEnter()
                        isFirstRender = false
                    case "snort old", "old":
                        let snortCmd = Snort.parseOrExit(["old"])
                        try? snortCmd.run()
                        waitForEnter()
                        isFirstRender = false
                    case "info", "i":
                        print("  App name or bundle ID: ", terminator: "")
                        fflush(stdout)
                        if let name = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            let infoCmd = Info.parseOrExit([name])
                            try? infoCmd.run()
                            waitForEnter()
                        } else {
                            print("  🐽 No problem. Piggy did not do anything.\n")
                        }
                        isFirstRender = false
                    case "search", "s":
                        print("  Search query: ", terminator: "")
                        fflush(stdout)
                        if let query = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                            let searchCmd = Search.parseOrExit([query])
                            try? searchCmd.run()
                            waitForEnter()
                        } else {
                            print("  🐽 No problem. Piggy did not do anything.\n")
                        }
                        isFirstRender = false
                    case "export", "e":
                        let exportCmd = Export.parseOrExit([])
                        try? exportCmd.run()
                        waitForEnter()
                        isFirstRender = false
                    case "tui", "t":
                        AppTUI.run()
                        return
                case "quit", "exit":
                    restoreTerm()
                    print("  \(PINK)Oink!\(RESET)\n")
                    return
                    case "help", "?":
                        printHelp()
                        waitForEnter()
                        isFirstRender = false
                    default:
                        let pig = ["(\(PINK)°\(RESET)o\(PINK)°\(RESET))", "(\(PINK)•\(RESET)˕\(PINK)•\(RESET))", "(\(PINK)⇀\(RESET)↼\(PINK)⇀\(RESET))"]
                        let pigface = pig[Int.random(in: 0..<pig.count)]
                        print("  \(pigface)  Piggy does not know '\(fullInput)' yet. Press 1-4 or h for help.\n")
                    }
                }
            }
        }
    }

    private static func executeMenuItem(_ idx: Int, termOrig: inout termios) -> Bool {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &termOrig)

        switch idx {
        case 0:
            let sniffCmd = Sniff.parseOrExit([])
            try? sniffCmd.run()
            waitForEnter()
            return true
        case 1:
            let snortCmd = Snort.parseOrExit([])
            try? snortCmd.run()
            waitForEnter()
            return true
        case 2:
            print("  Search what? Try \(PINK)docs tax ~/Documents\(RESET) or \(PINK)apps xcode\(RESET): piggy search ", terminator: "")
            fflush(stdout)
            if let query = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                let searchCmd = Search.parseOrExit(splitCommandLine(query))
                try? searchCmd.run()
                waitForEnter()
            } else {
                print("  🐽 No problem. Piggy did not do anything.\n")
            }
            return true
        case 3:
            print("  Where should Piggy draw the mud map? \(PINK)(blank = this folder)\(RESET): ", terminator: "")
            fflush(stdout)
            let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let mudMapCmd = MudMap.parseOrExit(raw.isEmpty ? [] : splitCommandLine(raw))
            try? mudMapCmd.run()
            waitForEnter()
            return true
        default:
            return true
        }
    }

    private static func waitForEnter() {
        print("\n  \(MAUVE)Press Enter to return to menu...\(RESET)", terminator: "")
        fflush(stdout)
        _ = readLine()
    }

    private static func restoreTerm() {
        var orig = termios()
        tcgetattr(STDIN_FILENO, &orig)
        orig.c_lflag |= tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        orig.c_iflag |= tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        orig.c_oflag |= tcflag_t(OPOST)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig)
    }

    // MARK: - Rendering

    private static let DIM = TerminalStyle.ansi("2", stdoutIsTTY: true)
    private static let BOLD = TerminalStyle.ansi("1", stdoutIsTTY: true)
    private static let RESET = TerminalStyle.ansi("0", stdoutIsTTY: true)
    private static let WHITE = TerminalStyle.ansi("38;5;255", stdoutIsTTY: true)
    private static let PINK = TerminalStyle.ansi("38;5;211", stdoutIsTTY: true)
    private static let MAUVE = TerminalStyle.ansi("38;5;175", stdoutIsTTY: true)
    private static let BORDER = TerminalStyle.ansi("38;5;240", stdoutIsTTY: true)

    private static func render(selectedIndex: Int, isFirstRender: Bool) {
        print(CLEAR + CURSOR_HOME, terminator: "")
        fflush(stdout)

        let w = Banner.currentTerminalWidth()
        let boxW = min(76, max(44, w - 4))
        let pad = "  "

        printTopBorder(width: boxW, pad: pad)
        printBoxLine("  \(PINK)Find fat folders and files on your Mac.\(RESET)", width: boxW, pad: pad)
        printBoxLine("", width: boxW, pad: pad)

        for (idx, item) in MENU_ITEMS.enumerated() {
            let (num, label, desc) = item
            let labelField = label.padding(toLength: 8, withPad: " ", startingAt: 0)

            if idx == selectedIndex {
                let prefix = "  ▸  \(num)  \(labelField) "
                let clippedDesc = fitPlain(desc, width: max(0, boxW - prefix.count))
                let row = "  \(PINK)▸\(RESET)  \(PINK)\(num)\(RESET)  \(BOLD)\(WHITE)\(labelField)\(RESET) \(WHITE)\(clippedDesc)\(RESET)"
                printBoxLine(row, width: boxW, pad: pad)
            } else {
                let prefix = "     \(num)  \(labelField) "
                let clippedDesc = fitPlain(desc, width: max(0, boxW - prefix.count))
                let row = "     \(MAUVE)\(num)\(RESET)  \(WHITE)\(labelField)\(RESET) \(DIM)\(clippedDesc)\(RESET)"
                printBoxLine(row, width: boxW, pad: pad)
            }
        }

        printBoxLine("", width: boxW, pad: pad)
        printBoxLine("  \(DIM)piggy [action] [what] [where]\(RESET)", width: boxW, pad: pad)
        printBoxLine("  \(DIM)what = apps, imgs, vids, or docs\(RESET)", width: boxW, pad: pad)
        printBoxLine("", width: boxW, pad: pad)
        printBoxLine("  \(MAUVE)↑↓\(RESET) move   \(MAUVE)↵\(RESET) choose   \(MAUVE)1-4\(RESET) pick   \(MAUVE)h\(RESET) help   \(MAUVE)q\(RESET) leave", width: boxW, pad: pad)
        print("\(pad)\(BORDER)╰\(String(repeating: "─", count: boxW))╯\(RESET)")
        print("")
        fflush(stdout)
    }

    private static func printTopBorder(width: Int, pad: String) {
        let title = " PIGGY "
        let face = " (oo) "
        let fill = String(repeating: "─", count: max(0, width - visibleLength(title) - visibleLength(face)))
        print("\(pad)\(BORDER)╭\(PINK)\(title)\(BORDER)\(fill)\(MAUVE)\(face)\(BORDER)╮\(RESET)")
    }

    private static func printBoxLine(_ text: String, width: Int, pad: String) {
        print("\(pad)\(BORDER)│\(RESET)\(padVisible(text, width: width))\(BORDER)│\(RESET)")
    }

    private static func padVisible(_ text: String, width: Int) -> String {
        text + String(repeating: " ", count: max(0, width - visibleLength(text)))
    }

    private static func fitPlain(_ text: String, width: Int) -> String {
        guard text.count > width else { return text }
        guard width > 1 else { return String(text.prefix(max(0, width))) }
        return String(text.prefix(width - 1)) + "…"
    }

    private static func visibleLength(_ text: String) -> Int {
        text.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression).count
    }

    // MARK: - Key Reading

    private enum MenuKey: Equatable {
        case up
        case down
        case enter
        case char(Character)
    }

    private static func readMenuKey() -> MenuKey? {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        guard n > 0 else { return nil }

        if byte == 27 {
            if readTimeout() > 0 {
                var next: UInt8 = 0
                let n2 = read(STDIN_FILENO, &next, 1)
                if n2 > 0, next == 91 {
                    var third: UInt8 = 0
                    let n3 = read(STDIN_FILENO, &third, 1)
                    if n3 > 0 {
                        switch third {
                        case 65: return .up
                        case 66: return .down
                        default: return nil
                        }
                    }
                }
            }
            return nil
        }

        if byte == 10 || byte == 13 {
            return .enter
        }

        let ch = Character(UnicodeScalar(byte))
        guard ch.isASCII else { return nil }
        return .char(ch)
    }

    private static func readTimeout() -> Int {
        var tv = timeval(tv_sec: 0, tv_usec: 30000)
        var fds = fd_set(fds_bits: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        fds.fds_bits.0 = 1 << STDIN_FILENO
        return Int(select(STDIN_FILENO + 1, &fds, nil, nil, &tv))
    }

    // MARK: - Help

    private static func printNonInteractiveHelp() {
        print("PIGGY")
        print("Find fat folders and files on your Mac.")
        print("")
        print("  1  Sniff    See a simple view of fat folders and files")
        print("  2  Snort    See a detailed view of fat folders and files")
        print("  3  Search   See specific files, folders, apps / imgs / vids / docs")
        print("  4  Mud map  See a mud map of your folders")
        print("")
        print("piggy [action] [what] [where]")
        print("what = apps, imgs, vids, or docs")
        print("")
        print("Try:")
        print("  piggy sniff")
        print("  piggy sniff apps")
        print("  piggy sniff imgs ~/Pictures")
        print("  piggy search docs tax ~/Documents")
        print("  piggy mudmap ~/Downloads")
        print("")
        print("Use `piggy --help` for the full list.")
    }

    private static func printHelp() {
        print("")
        print("  \(BOLD)piggy - a gentle terminal playground for finding space\(RESET)")
        print("")
        print("  \(PINK)Safety promise:\(RESET)")
        print("    Piggy looks first. It does not move, edit, or trash files unless a Trash command asks and you say yes.")
        print("")
        print("  \(PINK)Friendly architecture:\(RESET)")
        print("    piggy [action] [what] [where]")
        print("")
        print("  \(PINK)Actions:\(RESET) sniff, snort, search, mudmap")
        print("  \(PINK)What:\(RESET)    apps, imgs, vids, docs")
        print("")
        print("  \(PINK)Examples:\(RESET)")
        print("    piggy sniff                         Quick look in this folder")
        print("    piggy sniff apps                    Quick look at apps")
        print("    piggy sniff imgs ~/Pictures         Image pile")
        print("    piggy snort docs ~/Documents        Detailed document pile")
        print("    piggy search docs tax ~/Documents   Find document stuff")
        print("    piggy mudmap ~/Downloads            See the mud map")
        print("    piggy delete \"Slack\"                Ask before moving an app to Trash")
        print("")
    }

    private static func splitCommandLine(_ input: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false

        for ch in input {
            if escaping {
                current.append(ch)
                escaping = false
                continue
            }
            if ch == "\\" {
                escaping = true
                continue
            }
            if ch == "\"" || ch == "'" {
                if quote == ch { quote = nil }
                else if quote == nil { quote = ch }
                else { current.append(ch) }
                continue
            }
            if ch.isWhitespace && quote == nil {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    // MARK: - Helpers

    private static let CLEAR = "\u{1B}[2J"
    private static let CURSOR_HOME = "\u{1B}[H"
}
