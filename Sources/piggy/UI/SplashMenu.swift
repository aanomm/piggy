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
    ("1", "Peek",    "look at your apps without touching anything"),
    ("2", "Folders", "find the biggest folders in a place you choose"),
    ("3", "Apps",    "see your fattest apps"),
    ("4", "Find",    "search for an app by name"),
    ("5", "Explain", "plain-English notes for one app"),
    ("6", "Pack",    "save the app list as CSV or JSON"),
    ("7", "Play",    "open the interactive Piggy browser"),
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
                case "5":
                    if !executeMenuItem(4, termOrig: &orig) { return }
                    isFirstRender = false
                case "6":
                    if !executeMenuItem(5, termOrig: &orig) { return }
                    isFirstRender = false
                case "7":
                    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig)
                    print("")
                    fflush(stdout)
                    AppTUI.run()
                    return
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
                        print("  \(pigface)  Piggy does not know '\(fullInput)' yet. Press 1-7 or h for help.\n")
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
                print("  🐽 No problem. Piggy did not do anything.\n")
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
                print("  🐽 No problem. Piggy did not do anything.\n")
            }
            return true
        case 5:
            let exportCmd = Export.parseOrExit([])
            try? exportCmd.run()
            waitForEnter()
            return true
        case 6:
            print("")
            fflush(stdout)
            AppTUI.run()
            return false
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
    private static let BLUE = TerminalStyle.ansi("38;5;33", stdoutIsTTY: true)
    private static let WHITE = TerminalStyle.ansi("38;5;255", stdoutIsTTY: true)
    private static let GRAY = TerminalStyle.ansi("38;5;240", stdoutIsTTY: true)
    private static let PINK = TerminalStyle.ansi("38;5;211", stdoutIsTTY: true)
    private static let MAUVE = TerminalStyle.ansi("38;5;175", stdoutIsTTY: true)
    private static let SELECT_BG = TerminalStyle.ansi("48;5;53", stdoutIsTTY: true)
    private static let SELECT_FG = TerminalStyle.ansi("38;5;255", stdoutIsTTY: true)
    private static let SEP = TerminalStyle.ansi("38;5;238", stdoutIsTTY: true)
    private static let BORDER = TerminalStyle.ansi("38;5;240", stdoutIsTTY: true)

    private static func render(selectedIndex: Int, isFirstRender: Bool) {
        print(CLEAR + CURSOR_HOME, terminator: "")
        fflush(stdout)

        let w = Banner.currentTerminalWidth()
        let boxW = min(74, max(44, w - 4))
        let pad = "  "

        Banner.printBanner()

        let title = " choose a gentle Piggy trail "
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
        printBoxLine("  \(MAUVE)↑↓\(RESET) move   \(MAUVE)↵\(RESET) choose   \(MAUVE)1-7\(RESET) quick pick   \(MAUVE)q\(RESET) leave   \(MAUVE)h\(RESET) help", width: boxW, pad: pad)
        print("\(pad)\(BORDER)╰\(String(repeating: "─", count: boxW))╯\(RESET)")
        print("")
        print("\(pad)\(DIM)type a command, or pick a trail above:\(RESET) ", terminator: "")
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

    private static func printNonInteractiveHelp() {
        print("Piggy - friendly Mac tidy helper")
        print("")
        print("Piggy mostly looks and explains. Trash commands ask before moving anything.")
        print("")
        print("Try a gentle command:")
        print("  piggy mac audit")
        print("  piggy folders ~/Downloads --limit 25")
        print("  piggy mac list --sort size")
        print("  piggy mac list --json")
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
        print("  \(PINK)Friendly commands:\(RESET)")
        print("    piggy audit         Piggy checks your apps and explains what looks big or old")
        print("    piggy folders       Piggy weighs folders in the place you choose")
        print("    piggy folders ~/Downloads --limit 25")
        print("    piggy folders ~/Library --min-size 1gb")
        print("    piggy snort         Piggy shows your app pile, biggest first")
        print("    piggy snort small   Smallest apps first")
        print("    piggy snort new     Newest apps first")
        print("    piggy snort old     Oldest apps first")
        print("    piggy snort --fresh Piggy takes a fresh look instead of using recent notes")
        print("    piggy info <app>    Piggy explains one app")
        print("    piggy search <q>    Piggy finds apps by name or description")
        print("    piggy delete <app>  Piggy asks, then moves an app to the Mac Trash")
        print("    piggy export        Piggy packs the app list as CSV or JSON")
        print("    piggy               Open this menu")
        print("    piggy --help        Full help with all options")
        print("")
        print("  \(PINK)Sorting words:\(RESET) size, name, created, modified, used, arch, version, store, agents")
        print("  \(PINK)Examples:\(RESET)")
        print("    piggy snort big                    Biggest apps first")
        print("    piggy snort new                    Newest apps first")
        print("    piggy snort new --fresh            Fresh app sniff")
        print("    piggy list --sort size             More sorting options")
        print("    piggy list --rosetta               Find older Intel-style apps")
        print("    piggy list --flag32bit             Find very old apps")
        print("    piggy delete \"Slack\" --with-related  Ask before moving app + safe crumbs to Trash")
        print("")
    }

    // MARK: - Helpers

    private static let CLEAR = "\u{1B}[2J"
    private static let CURSOR_HOME = "\u{1B}[H"
}
