import Foundation
import Darwin
import AppKit
import PiggyKit

// MARK: - ANSI Helpers

private let CSI = "\u{1B}["
private let BOLD = TerminalStyle.ansi("1", stdoutIsTTY: true)
private let DIM = TerminalStyle.ansi("2", stdoutIsTTY: true)
private let RESET = TerminalStyle.ansi("0", stdoutIsTTY: true)
private let CLEAR = CSI + "2J"
private let CURSOR_HOME = CSI + "H"
private let CURSOR_HIDE = CSI + "?25l"
private let CURSOR_SHOW = CSI + "?25h"
private let ALT_SCREEN = CSI + "?1049h"
private let MAIN_SCREEN = CSI + "?1049l"

private func fg(_ code: Int) -> String { TerminalStyle.ansi("38;5;\(code)", stdoutIsTTY: true) }
private func bg(_ code: Int) -> String { TerminalStyle.ansi("48;5;\(code)", stdoutIsTTY: true) }

private func cursorTo(_ row: Int, _ col: Int) -> String {
    CSI + "\(row);\(col)H"
}

private func clearToEOL() -> String { CSI + "K" }
private func clearToEOS() -> String { CSI + "0J" }

// MARK: - Color palette

private let COLOR_APPLE      = 39
private let COLOR_APPSTORE   = 33
private let COLOR_DIRECT     = 252
private let COLOR_UNSIGNED   = 208
private let COLOR_32BIT      = 196
private let COLOR_ROSETTA    = 214
private let COLOR_SELECTED   = 24
private let COLOR_MARKED     = 220
private let COLOR_HEADER_FG  = 15
private let COLOR_HEADER_BG  = 25
private let COLOR_STATUSBAR  = 236
private let COLOR_DETAIL_FG  = 37
private let COLOR_DIVIDER    = 240

// MARK: - TUI State

private enum TUIMode {
    case browse
    case filter(String)
    case confirmDelete(Int)
}

// MARK: - AppTUI

enum AppTUI {
    static func run() {
        guard isTerminal() else {
            print("piggy: TUI requires a terminal. Use subcommands (piggy list, piggy info, etc.) instead.")
            return
        }

        var term = TermState()
        term.enableRawMode()
        defer { term.restore() }

        print(ALT_SCREEN + CURSOR_HIDE, terminator: "")
        defer { print(MAIN_SCREEN + CURSOR_SHOW + RESET, terminator: "") }

        setupSignalHandlers()

        var state = TUIState()
        state.terminalWidth = term.width
        state.terminalHeight = term.height

        showSplash(term: term)

        showScanAnimation(&state, term: term)
        var scanFrameIndex = 0
        state.apps = AppScanner.scan(progress: { current, total, name in
            let w = term.width
            let lines = Spinner.renderFrame(index: scanFrameIndex, current: current, total: total, appName: name, width: w)
            scanFrameIndex += 1

            var buf = CLEAR + CURSOR_HOME
            let topPad = max(0, (term.height - lines.count) / 2)
            for _ in 0..<topPad { buf += "\r\n" }
            for line in lines {
                buf += padLine(line, w) + "\r\n"
            }
            write(buf)
            fflush(stdout)
        })
        applySortAndFilter(&state)

        var running = true
        while running {
            render(state, term: term)
            guard let key = readKey(term) else { continue }
            running = handleKey(key, state: &state, term: term)
        }
    }

    private static func isTerminal() -> Bool {
        isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0
    }

    private static func showSplash(term: TermState) {
        let w = term.width
        let h = term.height
        let bannerLines = Banner.art.components(separatedBy: "\n").filter { !$0.isEmpty }

        var buf = CLEAR + CURSOR_HOME

        let topPad = max(1, (h - bannerLines.count - 4) / 2)

        for _ in 0..<topPad { buf += "\r\n" }

        for line in bannerLines {
            let clean = line
                .replacingOccurrences(of: "\u{1B}[38;5;211m", with: "")
                .replacingOccurrences(of: "\u{1B}[38;5;218m", with: "")
                .replacingOccurrences(of: "\u{1B}[38;5;175m", with: "")
                .replacingOccurrences(of: "\u{1B}[1m", with: "")
                .replacingOccurrences(of: "\u{1B}[0m", with: "")
            var displayLen = 0
            var i = clean.startIndex
            while i < clean.endIndex {
                if clean[i...].hasPrefix("\u{1B}") {
                    if let end = clean[i...].firstIndex(of: "m") { i = clean.index(after: end); continue }
                } else { displayLen += 1; i = clean.index(after: i) }
            }
            let padding = max(0, (w - displayLen) / 2)
            buf += String(repeating: " ", count: padding)
            buf += line
            buf += "\r\n"
        }

        let tagline = "\(fg(175))  ~ sniff out disk hogs ~\(RESET)"
        let tagClean = tagline.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
        let tagDisplayLen = tagClean.count
        buf += String(repeating: " ", count: max(0, (w - tagDisplayLen) / 2)) + tagline + "\r\n"

        write(buf)
        fflush(stdout)

        usleep(1_800_000)
    }

    private static func showScanAnimation(_ state: inout TUIState, term: TermState) {
        let w = term.width
        var buf = CLEAR + CURSOR_HOME
        let topPad = term.height / 2 - 2
        for _ in 0..<topPad { buf += "\r\n" }
        buf += fg(15)
        buf += padLine("  ⠋ Sniffing around...", w)
        buf += "\r\n" + padLine("  This may take a moment.", w) + RESET
        write(buf)
        fflush(stdout)
    }
}

// MARK: - TermState

private struct TermState {
    var origTermios = termios()
    var width: Int = 80
    var height: Int = 24

    mutating func enableRawMode() {
        tcgetattr(STDIN_FILENO, &origTermios)
        var raw = origTermios
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        raw.c_oflag &= ~tcflag_t(OPOST)
        raw.c_cflag |= tcflag_t(CS8)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        updateSize()
    }

    mutating func updateSize() {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 {
            width = Int(ws.ws_col)
            height = Int(ws.ws_row)
        }
        if width < 40 { width = 40 }
        if height < 10 { height = 10 }
    }

    mutating func restore() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &origTermios)
    }
}

// MARK: - TUI State

private struct TUIState {
    var apps: [AppInfo] = []
    var filteredApps: [Int] = []
    var selectedIndex = 0
    var markedIndices = Set<Int>()
    var sortKey: SortKey = .size
    var ascending: Bool = false
    var scrollOffset = 0
    var mode: TUIMode = .browse
    var showDetailPane = true
    var terminalWidth = 80
    var terminalHeight = 24
    var needsRescan = false

    var visibleCount: Int {
        var used = 3
        if showDetailPane { used += 10 }
        return max(3, terminalHeight - used)
    }

    var selectedOriginalIndex: Int? {
        guard selectedIndex >= 0, selectedIndex < filteredApps.count else { return nil }
        return filteredApps[selectedIndex]
    }

    var selectedApp: AppInfo? {
        guard let idx = selectedOriginalIndex, idx < apps.count else { return nil }
        return apps[idx]
    }
}

// MARK: - Rendering

private func render(_ state: TUIState, term: TermState) {
    var buf = ""
    buf += CURSOR_HOME

    buf += fg(COLOR_HEADER_FG) + bg(COLOR_HEADER_BG)
    buf += padLine(titleBar(state), term.width)
    buf += RESET + "\r\n"

    var mutState = state
    let visCount = mutState.visibleCount
    adjustScroll(&mutState, visCount: visCount)

    buf += RESET
    for row in 0..<visCount {
        let actualIndex = mutState.scrollOffset + row
        if actualIndex < mutState.filteredApps.count {
            buf += renderAppRow(mutState, actualIndex: actualIndex, row: row, term: term)
        } else {
            buf += padLine("", term.width)
        }
        buf += "\r\n"
    }

    if mutState.showDetailPane, let app = mutState.selectedApp {
        buf += fg(COLOR_DIVIDER)
        buf += String(repeating: "─", count: term.width) + RESET + "\r\n"
        buf += renderDetailPane(app, state: mutState, term: term)
    }

    buf += "\r\n"
    buf += fg(15) + bg(COLOR_STATUSBAR)
    buf += padLine(statusBar(mutState), term.width)
    buf += RESET

    write(buf)
    fflush(stdout)
}

private func adjustScroll(_ state: inout TUIState, visCount: Int) {
    let maxScroll = max(0, state.filteredApps.count - visCount)
    if state.selectedIndex < state.scrollOffset {
        state.scrollOffset = state.selectedIndex
    } else if state.selectedIndex >= state.scrollOffset + visCount {
        state.scrollOffset = max(0, state.selectedIndex - visCount + 1)
    }
    state.scrollOffset = min(state.scrollOffset, maxScroll)
}

private func titleBar(_ state: TUIState) -> String {
    let count = state.filteredApps.count
    let totalSize = state.filteredApps.compactMap { aidx -> Int64? in
        guard aidx < state.apps.count else { return nil }
        return state.apps[aidx].size
    }.reduce(0, +)
    let sizeStr: String = {
        let absSize = abs(totalSize)
        if absSize >= 1_073_741_824 { return String(format: "%.2f GB", Double(absSize) / 1_073_741_824) }
        return String(format: "%.1f MB", Double(absSize) / 1_048_576)
    }()

    let arrow = state.ascending ? "▲" : "▼"
    var parts: [String] = [
        "piggy",
        "[\(state.sortKey.label) \(arrow)]",
        "\(count) apps",
        "\(sizeStr)",
    ]
    if case .filter(let txt) = state.mode, !txt.isEmpty {
        parts.append("filter: \"\(txt)\"")
    }
    parts.append(contentsOf: ["[q]uit", "[?]help", "[j↓] [k↑]"])

    let joined = parts.joined(separator: "  ")
    return "  " + joined
}

private func renderAppRow(_ state: TUIState, actualIndex: Int, row: Int, term: TermState) -> String {
    guard actualIndex < state.filteredApps.count else { return "" }

    let originalIndex = state.filteredApps[actualIndex]
    guard originalIndex < state.apps.count else { return "" }

    let app = state.apps[originalIndex]
    let isSelected = actualIndex == state.selectedIndex
    let isMarked = state.markedIndices.contains(originalIndex)

    let w = term.width - 1
    let nameW = min(28, w - 42)
    let sizeW = 10
    let archW = 7
    let srcW = 11
    let origW = 9

    let num = "\(originalIndex + 1)".padding(toLength: 4, withPad: " ", startingAt: 0)
    let name = String(app.displayName.prefix(nameW)).padding(toLength: nameW, withPad: " ", startingAt: 0)
    let size = app.formattedSize.padding(toLength: sizeW, withPad: " ", startingAt: 0)
    let arch = app.architecture.shortLabel.padding(toLength: archW, withPad: " ", startingAt: 0)
    let src = app.sourceLabel.padding(toLength: srcW, withPad: " ", startingAt: 0)
    let origin = app.originLabel.padding(toLength: origW, withPad: " ", startingAt: 0)

    var line = ""

    if isSelected {
        line += bg(COLOR_SELECTED) + fg(15)
    } else if isMarked {
        line += bg(COLOR_MARKED) + fg(0)
    } else {
        let color = appColor(app)
        line += fg(color)
    }

    let marker = isMarked ? " ◆" : (isSelected ? " ▸" : "  ")
    line += "  \(marker)\(num)\(name)  \(size)  \(arch)  \(src)  \(origin)"

    if app.isQuarantined {
        line += " ~q"
    }

    let remaining = w - 60
    if remaining > 10, let purpose = app.purpose {
        line += "  " + String(purpose.prefix(remaining))
    }

    line += RESET
    line = padLine(line, w)

    return line
}

private func appColor(_ app: AppInfo) -> Int {
    if app.architecture == .i386 { return COLOR_32BIT }
    if app.isAppleSigned { return COLOR_APPLE }
    if app.isFromAppStore { return COLOR_APPSTORE }
    if app.isQuarantined { return COLOR_UNSIGNED }
    if app.architecture == .x86_64 { return COLOR_ROSETTA }
    return COLOR_DIRECT
}

private func renderDetailPane(_ app: AppInfo, state: TUIState, term: TermState) -> String {
    let w = term.width

    var lines: [String] = []
    lines.append(fg(15) + BOLD + "  " + app.displayName + RESET)

    let pathText = String("    \(app.path.path)".prefix(max(0, w - 10)))
    lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Path:", w) + RESET + fg(15) + pathText + RESET)
    if let bid = app.bundleIdentifier {
        lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Bundle:", w) + RESET + "   \(bid)")
    }
    if let sv = app.shortVersion {
        var verStr = sv
        if let bv = app.bundleVersion { verStr += " (\(bv))" }
        lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Version:", w) + RESET + "  \(verStr)")
    }
    lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Size:", w) + RESET + "     \(app.formattedSize)")
    lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Arch:", w) + RESET + "     \(app.architecture.label)")

    var originParts: [String] = [app.originLabel]
    if app.isAppleSigned { originParts.append("Verified") }
    if app.isQuarantined { originParts.append("⚠ Unverified") }
    if app.architecture == .i386 { originParts.append("⚠ 32-bit (dead)") }
    if app.architecture == .x86_64 { originParts.append("Rosetta") }
    lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Origin:", w) + RESET + "   " + originParts.joined(separator: " · "))

    if let cd = app.creationDate {
        lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Installed:", w) + RESET + " \(relativeLabel(cd))")
    }
    if let lud = app.lastUsedDate {
        lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Last Used:", w) + RESET + " \(relativeLabel(lud))")
    }
    if app.agentCount > 0 {
        lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Agents:", w) + RESET + "    \(app.agentCount) background process(es)")
    }
    if let minOS = app.minOSVersion {
        lines.append(fg(COLOR_DETAIL_FG) + dimPrefix("  Min macOS:", w) + RESET + " \(minOS)")
    }
    if let purpose = app.purpose {
        lines.append("")
        let purposeText = String("  \(purpose)".prefix(max(0, w - 2)))
        lines.append(fg(COLOR_DETAIL_FG) + purposeText + RESET)
    }

    return lines.joined(separator: "\r\n")
}

private func dimPrefix(_ text: String, _ width: Int) -> String {
    return DIM + text
}

private func statusBar(_ state: TUIState) -> String {
    var parts: [String] = []

    let sortKeys = SortKey.allCases.map { sk -> String in
        if sk == state.sortKey {
            return "[\(sk.sortKeyChar)] \(sk.label)"
        } else {
            return "\(DIM)\(sk.sortKeyChar) \(sk.label)\(RESET)"
        }
    }

    parts.append(sortKeys.joined(separator: " "))

    if state.markedIndices.count > 0 {
        parts.insert("\(state.markedIndices.count) marked [D]elete all", at: 0)
    }

    let joined = parts.joined(separator: "  ")
    return "  " + joined
}

private func padLine(_ text: String, _ width: Int) -> String {
    let cleaned = text.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
    let len = cleaned.count
    if len >= width { return text }
    return text + String(repeating: " ", count: width - len)
}

private func relativeLabel(_ date: Date) -> String {
    let interval = -date.timeIntervalSinceNow
    if interval < 60 { return "just now" }
    if interval < 3600 { return "\(Int(interval / 60))m ago" }
    if interval < 86400 { return "\(Int(interval / 3600))h ago" }
    if interval < 2592000 { return "\(Int(interval / 86400))d ago" }
    if interval < 31536000 { return "\(Int(interval / 2592000))m ago" }
    return "\(Int(interval / 31536000))y ago"
}

// MARK: - Input

private struct Key {
    let char: Character?
    let isUp: Bool
    let isDown: Bool
    let isLeft: Bool
    let isRight: Bool
    let isEnter: Bool
    let isEscape: Bool
    let isTab: Bool
    let isBackspace: Bool

    static let none = Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
}

private func readKey(_ term: TermState) -> Key? {
    var byte: UInt8 = 0
    let n = read(STDIN_FILENO, &byte, 1)
    if n <= 0 { return nil }

    if byte == 27 {
        var next: UInt8 = 0
        let bytesAvailable = readWithTimeout()
        guard bytesAvailable > 0 else {
            return Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: true, isTab: false, isBackspace: false)
        }
        let n2 = read(STDIN_FILENO, &next, 1)
        if n2 <= 0 {
            return Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: true, isTab: false, isBackspace: false)
        }

        if next == 91 {
            var third: UInt8 = 0
            let n3 = read(STDIN_FILENO, &third, 1)
            if n3 <= 0 { return Key.none }
            switch third {
            case 65: return Key(char: nil, isUp: true, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
            case 66: return Key(char: nil, isUp: false, isDown: true, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
            case 67: return Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: true, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
            case 68: return Key(char: nil, isUp: false, isDown: false, isLeft: true, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
            case 72: return Key(char: nil, isUp: true, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
            case 70: return Key(char: nil, isUp: false, isDown: true, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
            case 51:
                var fourth: UInt8 = 0
                _ = read(STDIN_FILENO, &fourth, 1)
                return Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: true)
            default: return Key.none
            }
        }

        if next == 79 {
            var third: UInt8 = 0
            _ = read(STDIN_FILENO, &third, 1)
            return Key.none
        }

        return Key.none
    }

    if byte == 127 || byte == 8 {
        return Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: true)
    }

    if byte == 10 || byte == 13 {
        return Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: true, isEscape: false, isTab: false, isBackspace: false)
    }

    if byte == 9 {
        return Key(char: nil, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: true, isBackspace: false)
    }

    if byte == 3 {
        return Key(char: "\u{3}", isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
    }

    let char = Character(UnicodeScalar(byte))
    return Key(char: char, isUp: false, isDown: false, isLeft: false, isRight: false, isEnter: false, isEscape: false, isTab: false, isBackspace: false)
}

private func readWithTimeout() -> Int {
    var tv = timeval(tv_sec: 0, tv_usec: 10000)
    var fds = fd_set(fds_bits: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    fds.fds_bits.0 = 1 << STDIN_FILENO
    return Int(select(STDIN_FILENO + 1, &fds, nil, nil, &tv))
}

// MARK: - Key Handling

private func handleKey(_ key: Key, state: inout TUIState, term: TermState) -> Bool {
    switch state.mode {
    case .browse:
        return handleBrowseKey(key, state: &state, term: term)

    case .filter(let text):
        return handleFilterKey(key, text: text, state: &state)

    case .confirmDelete(let idx):
        return handleConfirmKey(key, state: &state, idx: idx)
    }
}

private func handleBrowseKey(_ key: Key, state: inout TUIState, term: TermState) -> Bool {
    if let c = key.char {
        switch c {
        case "q", "Q", "\u{3}":
            return false

        case "j":
            moveSelection(by: 1, state: &state)
        case "k":
            moveSelection(by: -1, state: &state)

        case "g":
            if state.filteredApps.isEmpty { return true }
            state.selectedIndex = 0
            state.scrollOffset = 0
        case "G":
            if !state.filteredApps.isEmpty {
                state.selectedIndex = state.filteredApps.count - 1
            }

        case " ":
            toggleMark(state: &state)

        case "d":
            guard let idx = state.selectedOriginalIndex else { return true }
            state.mode = .confirmDelete(idx)
        case "D":
            if state.markedIndices.count > 0 {
                state.mode = .confirmDelete(-1)
            }

        case "o", "\r":
            openInFinder(state: state)

        case "e":
            exportCSV(state: state)

        case "r":
            state.needsRescan = true

        case "/":
            state.mode = .filter("")

        case "t":
            state.showDetailPane.toggle()

        case "?", "h":
            showHelp()

        default:
            if let sk = SortKey(char: c) {
                if state.sortKey == sk {
                    state.ascending.toggle()
                } else {
                    state.sortKey = sk
                    state.ascending = (sk == .size || sk == .agents)
                }
                applySortAndFilter(&state)
            }
        }
    }

    if key.isUp { moveSelection(by: -1, state: &state) }
    if key.isDown { moveSelection(by: 1, state: &state) }
    if key.isLeft { state.showDetailPane = false }
    if key.isRight { state.showDetailPane = true }
    if key.isEscape { state.markedIndices.removeAll(); state.mode = .browse }
    if key.isEnter { openInFinder(state: state) }

    return true
}

private func handleFilterKey(_ key: Key, text: String, state: inout TUIState) -> Bool {
    if key.isEscape {
        state.mode = .browse
        applySortAndFilter(&state)
        return true
    }

    if key.isEnter {
        state.mode = .browse
        applySortAndFilter(&state)
        return true
    }

    if key.isBackspace {
        let newText = String(text.dropLast())
        state.mode = .filter(newText)
        applySortAndFilter(&state)
        return true
    }

    if let c = key.char, c.isLetter || c.isNumber || c == " " || c == "." || c == "-" || c == "_" {
        let newText = text + String(c)
        state.mode = .filter(newText)
        applySortAndFilter(&state)
        return true
    }

    return true
}

private func handleConfirmKey(_ key: Key, state: inout TUIState, idx: Int) -> Bool {
    if let c = key.char {
        switch c {
        case "y", "Y":
            if idx >= 0 {
                performDelete(at: idx, state: &state)
            } else {
                performDeleteMarked(state: &state)
            }
            state.mode = .browse
            applySortAndFilter(&state)
        case "n", "N", "q":
            state.mode = .browse
        default:
            break
        }
    }
    if key.isEscape {
        state.mode = .browse
    }
    return true
}

private func moveSelection(by delta: Int, state: inout TUIState) {
    let new = state.selectedIndex + delta
    if new >= 0 && new < state.filteredApps.count {
        state.selectedIndex = new
    }
}

private func toggleMark(state: inout TUIState) {
    guard let idx = state.selectedOriginalIndex else { return }
    if state.markedIndices.contains(idx) {
        state.markedIndices.remove(idx)
    } else {
        state.markedIndices.insert(idx)
    }
    moveSelection(by: 1, state: &state)
}

private func openInFinder(state: TUIState) {
    guard let app = state.selectedApp else { return }
    NSWorkspace.shared.activateFileViewerSelecting([app.path])
}

private func exportCSV(state: TUIState) {
    let desktop = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop/piggy-export.csv")
    var lines = ["Name,Size,Bundle ID,Arch,Source,Origin,Version,Agents,Quarantined,Purpose,Path"]
    for idx in state.filteredApps where idx < state.apps.count {
        let app = state.apps[idx]
        let fields = [
            csvEscape(app.displayName),
            app.formattedSize,
            csvEscape(app.bundleIdentifier ?? ""),
            app.architecture.shortLabel,
            app.sourceLabel,
            app.originLabel,
            csvEscape(app.shortVersion ?? ""),
            "\(app.agentCount)",
            app.isQuarantined ? "yes" : "no",
            csvEscape(app.purpose ?? ""),
            csvEscape(app.path.path),
        ]
        lines.append(fields.joined(separator: ","))
    }
    try? lines.joined(separator: "\n").write(to: desktop, atomically: true, encoding: .utf8)

    let buf = cursorTo(1, 1) + fg(15) + bg(COLOR_HEADER_BG) + "  Exported to ~/Desktop/piggy-export.csv" + RESET
    write(buf)
    fflush(stdout)
    usleep(1_500_000)
}

private func csvEscape(_ s: String) -> String {
    if s.contains(",") || s.contains("\"") || s.contains("\n") {
        return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return s
}

private func showHelp() {
    let help = """
    \r\n\u{1B}[2J\u{1B}[H
    \(BOLD)piggy — Help\(RESET)

    Navigation
      j / ↓              Move down
      k / ↑              Move up
      g                  Go to top
      G                  Go to bottom
      Enter / o          Reveal in Finder
      t                  Toggle detail pane

    Actions
      Space              Mark/unmark for deletion
      d                  Delete selected app
      D                  Delete all marked apps
      /                  Filter by name (type to search)
      Esc                Clear filter / clear marks

    Sort (press letter, again to toggle asc/desc)
      s  Size     n  Name    c  Created    m  Modified
      u  Used     a  Arch    v  Version    o  Origin
      b  Agents

    Other
      e                  Export to ~/Desktop/piggy-export.csv
      r                  Rescan apps
      q / Ctrl-C         Quit

    Press any key to return to piggy...
    """
    write(help)
    fflush(stdout)
    _ = readWithTimeout()
    usleep(500_000)

    while true {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        if n > 0 { break }
        usleep(50_000)
    }
}

private func performDelete(at idx: Int, state: inout TUIState) {
    guard idx < state.apps.count else { return }
    let app = state.apps[idx]
    let _ = AppRemover.delete(app: app, includeRelated: true)
    state.apps.remove(at: idx)
    state.markedIndices.remove(idx)
    state.markedIndices = Set(state.markedIndices.map { $0 >= idx ? $0 - 1 : $0 })
    if state.selectedIndex >= state.filteredApps.count, !state.filteredApps.isEmpty {
        state.selectedIndex = state.filteredApps.count - 1
    }
}

private func performDeleteMarked(state: inout TUIState) {
    let sorted = state.markedIndices.sorted(by: >)
    for idx in sorted {
        guard idx < state.apps.count else { continue }
        let app = state.apps[idx]
        let _ = AppRemover.delete(app: app, includeRelated: true)
        state.apps.remove(at: idx)
    }
    state.markedIndices.removeAll()
}

private func applySortAndFilter(_ state: inout TUIState) {
    let filterText: String
    if case .filter(let txt) = state.mode {
        filterText = txt
    } else {
        filterText = ""
    }

    let sortedIndices = state.apps.indices.sorted {
        SortKey.comparator(state.sortKey, ascending: state.ascending)(state.apps[$0], state.apps[$1])
    }

    if filterText.isEmpty {
        state.filteredApps = Array(sortedIndices)
    } else {
        let lower = filterText.lowercased()
        state.filteredApps = sortedIndices.filter { idx in
            let app = state.apps[idx]
            return app.displayName.lowercased().contains(lower) ||
                   (app.bundleIdentifier?.lowercased().contains(lower) ?? false) ||
                   (app.purpose?.lowercased().contains(lower) ?? false)
        }
    }

    if state.selectedIndex >= state.filteredApps.count {
        state.selectedIndex = max(0, state.filteredApps.count - 1)
    }
    state.scrollOffset = 0
}

// MARK: - Signal handling

private func write(_ s: String) {
    guard let data = s.data(using: .utf8) else { return }
    _ = data.withUnsafeBytes { ptr in
        Darwin.write(STDOUT_FILENO, ptr.baseAddress!, data.count)
    }
}

nonisolated(unsafe) private var _cookedTermios: termios?

private func setupSignalHandlers() {
    var tmp = termios()
    tcgetattr(STDIN_FILENO, &tmp)
    _cookedTermios = tmp
    signal(SIGWINCH) { _ in }
    signal(SIGINT) { _ in
        if var cooked = _cookedTermios {
            cooked.c_lflag |= tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &cooked)
        }
        write(MAIN_SCREEN + CURSOR_SHOW + RESET + "\r\n")
        fflush(stdout)
        exit(0)
    }
}
