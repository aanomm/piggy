import Foundation
import ArgumentParser
import PiggyKit

struct Audit: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show a read-only Mac app bloat and risk summary"
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
        print("🐷 Piggy Mac Audit")
        print("──────────────────")
        print("Scope: non-destructive scan of macOS .app bundles")
        print("Disk:  \(summary.diskUsageContext)")
        print("")
        for row in summary.metricRows {
            let label = row.label.padding(toLength: 29, withPad: " ", startingAt: 0)
            print("\(label) \(row.value)")
        }

        if !summary.largestApps.isEmpty {
            print("")
            print("Largest apps")
            for (index, app) in summary.largestApps.enumerated() {
                let marker = app.architecture == .x86_64 ? "R" : (app.isQuarantined ? "~" : " ")
                let name = String(app.displayName.prefix(34)).padding(toLength: 34, withPad: " ", startingAt: 0)
                let size = app.formattedSize.padding(toLength: 10, withPad: " ", startingAt: 0)
                print(String(format: "%2d. %@ %@ %@", index + 1, marker, name, size))
            }
        }

        if !summary.insights.isEmpty {
            print("")
            print("Worth reviewing")
            for insight in summary.insights {
                print("• \(insight.title): \(insight.count) — \(insight.message)")
                if let command = insight.suggestedCommand {
                    print("  try: \(command)")
                }
            }
        }

        print("")
        print("Safe next commands:")
        print("  piggy mac list --sort size")
        print("  piggy mac list --rosetta")
        print("  piggy mac orphans")
        print("")
    }
}
