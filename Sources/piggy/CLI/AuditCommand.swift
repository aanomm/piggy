import Foundation
import ArgumentParser
import PiggyKit

struct Audit: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Let Piggy look over your apps and explain the biggest space gobblers.",
        shouldDisplay: false
    )

    @Option(name: .shortAndLong, help: "Number of largest apps to show")
    var limit: Int = 8

    @Flag(name: .long, help: "Force a fresh app scan and update the cache")
    var fresh: Bool = false

    func run() throws {
        let apps = scannedApps(useDiskCache: !fresh)
        let summary = MacAudit.summarize(apps, topLimit: limit)
        printSummary(summary)
    }

    private func printSummary(_ summary: MacAuditSummary) {
        print("")
        print(CLITheme.title("🐽 Oink! Piggy is checking your apps"))
        print(CLITheme.separator("──────────────────"))
        print("\(CLITheme.purple("•")) Looking at your installed Mac apps.")
        print("\(CLITheme.purple("•")) Just looking: Piggy will not move, edit, or trash anything.")
        print("\(CLITheme.purple("•")) Weighing app size, age clues, download trust flags, and background helpers.")
        print("\(CLITheme.purple("•")) App space means the app files Piggy can see, not your whole Mac.")
        print("")
        for row in summary.metricRows {
            let label = friendlyMetricLabel(row.label).padding(toLength: 32, withPad: " ", startingAt: 0)
            print("\(CLITheme.label(label)) \(CLITheme.gold(row.value))")
        }

        if !summary.largestApps.isEmpty {
            print("")
            print(CLITheme.section("Biggest app snacks"))
            let maxBytes = summary.largestApps.map(\.size).max() ?? 0
            let barWidth = max(10, min(24, Banner.currentTerminalWidth() / 5))
            for (index, app) in summary.largestApps.enumerated() {
                let marker = app.architecture == .x86_64 ? "R" : (app.isQuarantined ? "~" : " ")
                let rank = CLITheme.rank(String(format: "%2d.", index + 1), index: index)
                let flag = CLITheme.flag(marker)
                let bar = CLITheme.bar(value: app.size, max: maxBytes, width: barWidth, index: index)
                let name = CLITheme.path(String(app.displayName.prefix(34)).padding(toLength: 34, withPad: " ", startingAt: 0))
                let size = CLITheme.size(app.formattedSize.padding(toLength: 10, withPad: " ", startingAt: 0), bytes: app.size)
                print("\(rank) \(flag) \(bar)  \(name) \(size)")
            }
        }

        if !summary.insights.isEmpty {
            print("")
            print(CLITheme.section("Piggy noticed"))
            for insight in summary.insights {
                print("\(CLITheme.warning("•")) \(CLITheme.warning(friendlyInsightTitle(insight.title))): \(CLITheme.gold("\(insight.count)")) — \(friendlyInsightMessage(insight))")
                if let command = insight.suggestedCommand {
                    print("  \(CLITheme.label("try next:")) \(CLITheme.command(command))")
                }
            }
        }

        print("")
        print(CLITheme.section("Try another gentle sniff:"))
        print("  \(CLITheme.command("piggy mac list --sort size"))")
        print("  \(CLITheme.command("piggy folders ~/Downloads --limit 25"))")
        print("  \(CLITheme.command("piggy mac list --rosetta"))")
        print("  \(CLITheme.command("piggy list --json"))")
        print("")
    }

    private func friendlyMetricLabel(_ label: String) -> String {
        switch label {
        case "Total apps": return "Apps Piggy found"
        case "Total app disk": return "Space used by apps"
        case "Apple apps": return "Apple-made apps"
        case "3rd Party apps": return "Other apps"
        case "App Store apps": return "From the App Store"
        case "Rosetta apps": return "Older Intel-style apps"
        case "32-bit apps": return "Very old apps"
        case "Unknown architecture": return "Apps Piggy could not read"
        case "Quarantined apps": return "Downloaded apps to check"
        case "Apps with background agents": return "Apps with background helpers"
        default: return label
        }
    }

    private func friendlyInsightTitle(_ title: String) -> String {
        switch title {
        case "Rosetta apps": return "Older Intel-style apps"
        case "32-bit apps": return "Very old apps"
        case "Unknown architecture": return "Apps Piggy could not read"
        case "Quarantined apps": return "Downloaded apps to check"
        case "Background agents": return "Apps with background helpers"
        default: return title
        }
    }

    private func friendlyInsightMessage(_ insight: MacAuditInsight) -> String {
        switch insight.title {
        case "Rosetta apps":
            return "These can be slower on newer Macs, so they are worth a quick look."
        case "32-bit apps":
            return "These usually do not run on modern macOS."
        case "Unknown architecture":
            return "Piggy could not read their chip type, so look before tidying."
        case "Quarantined apps":
            return "These came from downloads and may deserve a trust check."
        case "Background agents":
            return "These apps also leave little background helpers behind."
        default:
            return insight.message
        }
    }
}
