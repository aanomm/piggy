import Foundation
import ArgumentParser

nonisolated(unsafe) private var _splashTermios: termios?

private let MENU_ITEMS: [(String, String, String)] = [
    ("1", "Audit",   "read-only Mac bloat/risk summary"),
    ("2", "Folders", "rank folders by size + file count"),
    ("3", "Snort",   "list all apps, sorted by size"),
    ("4", "Sniff",   "search apps by name"),
    ("5", "Dig",     "deep info on one app"),
    ("6", "Crumbs",  "leftover files from deleted apps"),
    ("7", "Stash",   "export to CSV/JSON"),
    ("8", "Pig",     "interactive terminal browser"),
]

enum SplashMenu {
    static func run() {
        signal(SIGINT) { _ in
            if var t = _splashTermios {
                t.c_lflag |= tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
                t.c_iflag |= tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
                t.c_oflag |= tcflag_t(OPOST)
                tcsetattr(STDIN_FILENO, TCSAFLUSH, &t)
            }
            print("\n  \u{1B}[38;5;211mOink!\u{1B}[0m\n")
            exit(0)
        }

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
                case "5":
                    if !executeMenuItem(4, termOrig: &orig) { return }
                    isFirstRender = false
                case "6":
                    if !executeMenuItem(5, termOrig: &orig) { return }
                    isFirstRender = false
                case "7":
                    if !executeMenuItem(6, termOrig: &orig) { return }
                    isFirstRender = false
                case "8":
                    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig)
                    print("")
                    fflush(stdout)
                    AppTUI.run()
                    return
                case "q":
                    restoreTerm()
                    print("  \u{1B}[38;5;211mOink!\u{1B}[0m\n")
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
                            print("  Cancelled.\n")
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
                            print("  Cancelled.\n")
                        }
                        isFirstRender = false
                    case "orphans", "o":
                        let orphansCmd = Orphans.parseOrExit([])
                        try? orphansCmd.run()
                        waitForEnter()
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
                    print("  \u{1B}[38;5;211mOink!\u{1B}[0m\n")
                    return
                    case "help", "?":
                        printHelp()
                        waitForEnter()
                        isFirstRender = false
                    default:
                        let pig = ["(\u{1B}[38;5;211m°\u{1B}[0mo\u{1B}[38;5;211m°\u{1B}[0m)", "(\u{1B}[38;5;211m•\u{1B}[0m˕\u{1B}[38;5;211m•\u{1B}[0m)", "(\u{1B}[38;5;211m⇀\u{1B}[0m↼\u{1B}[38;5;211m⇀\u{1B}[0m)"]
                        let pigface = pig[Int.random(in: 0..<pig.count)]
                        print("  \(pigface)  Unknown: '\(fullInput)'. Press 1-8 or h for help.\n")
                    }
                }
            }
        }
    }

    private static func executeMenuItem(_ idx: Int, termOrig: inout termios) -> Bool {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &termOrig)

        switch idx {
        case 0:
            let auditCmd = Audit.parseOrExit([])
            try? auditCmd.run()
            waitForEnter()
            return true
        case 1:
            let foldersCmd = Folders.parseOrExit([])
            try? foldersCmd.run()
            waitForEnter()
            return true
        case 2:
            let listCmd = Snort.parseOrExit([])
            try? listCmd.run()
            waitForEnter()
            return true
        case 3:
            print("  Search query: ", terminator: "")
            fflush(stdout)
            if let query = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                let searchCmd = Search.parseOrExit([query])
                try? searchCmd.run()
                waitForEnter()
            } else {
                print("  Cancelled.\n")
            }
            return true
        case 4:
            print("  App name or bundle ID: ", terminator: "")
            fflush(stdout)
            if let name = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                let infoCmd = Info.parseOrExit([name])
                try? infoCmd.run()
                waitForEnter()
            } else {
                print("  Cancelled.\n")
            }
            return true
        case 5:
            let orphansCmd = Orphans.parseOrExit([])
            try? orphansCmd.run()
            waitForEnter()
            return true
        case 6:
            let exportCmd = Export.parseOrExit([])
            try? exportCmd.run()
            waitForEnter()
            return true
        case 7:
            print("")
            fflush(stdout)
            AppTUI.run()
            return false
        default:
            return true
        }
    }

    private static func waitForEnter() {
        print("\n  \u{1B}[38;5;175mPress Enter to return to menu...\u{1B}[0m", terminator: "")
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

    private static let DIM = "\u{1B}[2m"
    private static let BOLD = "\u{1B}[1m"
    private static let RESET = "\u{1B}[0m"
    private static let BLUE = "\u{1B}[38;5;33m"
    private static let WHITE = "\u{1B}[38;5;255m"
    private static let GRAY = "\u{1B}[38;5;240m"
    private static let PINK = "\u{1B}[38;5;211m"
    private static let MAUVE = "\u{1B}[38;5;175m"
    private static let SELECT_BG = "\u{1B}[48;5;53m"
    private static let SELECT_FG = "\u{1B}[38;5;255m"
    private static let SEP = "\u{1B}[38;5;238m"
    private static let BORDER = "\u{1B}[38;5;240m"

    private static func render(selectedIndex: Int, isFirstRender: Bool) {
        print(CLEAR + CURSOR_HOME, terminator: "")
        fflush(stdout)

        let w = Banner.currentTerminalWidth()
        let boxW = min(74, max(44, w - 4))
        let pad = "  "

        Banner.printBanner()

        let title = " choose your trail "
        print("\(pad)\(BORDER)╭\(PINK)\(title)\(BORDER)\(String(repeating: "─", count: max(0, boxW - visibleLength(title))))╮\(RESET)")
        printBoxLine("", width: boxW, pad: pad)

        for (idx, item) in MENU_ITEMS.enumerated() {
            let (num, label, desc) = item
            let labelField = label.padding(toLength: 9, withPad: " ", startingAt: 0)

            if idx == selectedIndex {
                let row = "  ▸  \(num)  \(labelField)  \(desc)"
                printBoxLine(SELECT_BG + SELECT_FG + padVisible(row, width: boxW) + RESET, width: boxW, pad: pad)
            } else {
                let row = "     \(PINK)\(num)\(RESET)  \(BOLD)\(WHITE)\(labelField)\(RESET)  \(DIM)\(desc)\(RESET)"
                printBoxLine(row, width: boxW, pad: pad)
            }
        }

        printBoxLine("", width: boxW, pad: pad)
        printBoxLine("  \(MAUVE)↑↓\(RESET) navigate   \(MAUVE)↵\(RESET) select   \(MAUVE)1-8\(RESET) jump   \(MAUVE)q\(RESET) quit   \(MAUVE)h\(RESET) help", width: boxW, pad: pad)
        print("\(pad)\(BORDER)╰\(String(repeating: "─", count: boxW))╯\(RESET)")
        print("")
        print("\(pad)\(DIM)type a command or pick a trail:\(RESET) ", terminator: "")
        fflush(stdout)
    }

    private static func printBoxLine(_ text: String, width: Int, pad: String) {
        print("\(pad)\(BORDER)│\(RESET)\(padVisible(text, width: width))\(BORDER)│\(RESET)")
    }

    private static func padVisible(_ text: String, width: Int) -> String {
        text + String(repeating: " ", count: max(0, width - visibleLength(text)))
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

    private static func printHelp() {
        print("")
        print("  \u{1B}[1mpiggy — sniff out disk hogs\u{1B}[0m")
        print("")
        print("  \u{1B}[38;5;211mCommands:\u{1B}[0m")
        print("    piggy audit         Read-only Mac app bloat/risk summary")
        print("    piggy folders       Rank folders by size with file counts")
        print("    piggy folders ~/Downloads --limit 25")
        print("    piggy folders ~/Library --min-size 1gb")
        print("    piggy snort         List all apps, biggest first")
        print("    piggy snort small   List all apps, smallest first")
        print("    piggy snort new     Newest installed apps first")
        print("    piggy snort old     Oldest installed apps first")
        print("    piggy snort --fresh Force a new scan and refresh cache")
        print("    piggy info <app>    Full details on one app + related files")
        print("    piggy search <q>    Find apps by name, bundle ID, or purpose")
        print("    piggy delete <app>  Delete app + leftovers (prefs, caches)")
        print("    piggy orphans       Find leftover files from deleted apps")
        print("    piggy export        Export app list to CSV or JSON")
        print("    piggy               Open this menu")
        print("    piggy --help        Full help with all flags")
        print("")
        print("  \u{1B}[38;5;211mSort keys:\u{1B}[0m size, name, created, modified, used, arch, version, store, agents")
        print("  \u{1B}[38;5;211mExamples:\u{1B}[0m")
        print("    piggy snort big                    Biggest apps first")
        print("    piggy snort new                    Newest installed apps first")
        print("    piggy snort new --fresh            Rescan before sorting")
        print("    piggy list --sort size              Advanced list sorting")
        print("    piggy list --rosetta                 Find Intel apps on Apple Silicon")
        print("    piggy list --flag32bit              Find dead 32-bit apps")
        print("    piggy delete \"Slack\" --with-related  Full uninstall")
        print("")
    }

    // MARK: - Helpers

    private static let CLEAR = "\u{1B}[2J"
    private static let CURSOR_HOME = "\u{1B}[H"
}
