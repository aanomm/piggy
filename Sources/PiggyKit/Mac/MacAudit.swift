import Foundation

public struct MacAuditSummary {
    public let totalApps: Int
    public let totalBytes: Int64
    public let appleSignedApps: Int
    public let thirdPartyApps: Int
    public let appStoreApps: Int
    public let rosettaApps: Int
    public let dead32BitApps: Int
    public let unknownArchitectureApps: Int
    public let quarantinedApps: Int
    public let appsWithAgents: Int
    public let largestApps: [AppInfo]
    public let insights: [MacAuditInsight]

    public var diskUsageContext: String {
        "Combined on-disk size of the scanned .app bundles."
    }

    public var metricRows: [MacAuditMetricRow] {
        [
            MacAuditMetricRow(label: "Total apps", value: "\(totalApps)"),
            MacAuditMetricRow(label: "Total app disk", value: ByteFormat.string(totalBytes)),
            MacAuditMetricRow(label: "Apple apps", value: "\(appleSignedApps)"),
            MacAuditMetricRow(label: "3rd Party apps", value: "\(thirdPartyApps)"),
            MacAuditMetricRow(label: "App Store apps", value: "\(appStoreApps)"),
            MacAuditMetricRow(label: "Rosetta apps", value: "\(rosettaApps)"),
            MacAuditMetricRow(label: "32-bit apps", value: "\(dead32BitApps)"),
            MacAuditMetricRow(label: "Unknown architecture", value: "\(unknownArchitectureApps)"),
            MacAuditMetricRow(label: "Quarantined apps", value: "\(quarantinedApps)"),
            MacAuditMetricRow(label: "Apps with background agents", value: "\(appsWithAgents)")
        ]
    }
}

public struct MacAuditMetricRow: Equatable {
    public let label: String
    public let value: String
}

public struct MacAuditInsight: Equatable {
    public let title: String
    public let count: Int
    public let message: String
    public let suggestedCommand: String?
}

public enum MacAudit {
    public static func summarize(_ apps: [AppInfo], topLimit: Int = 8) -> MacAuditSummary {
        let appleSigned = apps.filter(\.isAppleSigned).count
        let thirdParty = apps.count - appleSigned
        let appStore = apps.filter(\.isFromAppStore).count
        let rosetta = apps.filter { $0.architecture == .x86_64 }.count
        let dead32 = apps.filter { $0.architecture == .i386 }.count
        let unknownArch = apps.filter { $0.architecture == .unknown }.count
        let quarantined = apps.filter(\.isQuarantined).count
        let withAgents = apps.filter { $0.agentCount > 0 }.count
        let largest = apps.sorted { $0.size > $1.size }.prefix(max(0, topLimit))

        var insights: [MacAuditInsight] = []
        if rosetta > 0 {
            insights.append(MacAuditInsight(
                title: "Rosetta apps",
                count: rosetta,
                message: "Intel-only apps may be slower or stale on Apple Silicon.",
                suggestedCommand: "piggy mac list --rosetta"
            ))
        }
        if dead32 > 0 {
            insights.append(MacAuditInsight(
                title: "32-bit apps",
                count: dead32,
                message: "32-bit apps cannot run on modern macOS and are usually safe review candidates.",
                suggestedCommand: "piggy mac list --flag32bit"
            ))
        }
        if unknownArch > 0 {
            insights.append(MacAuditInsight(
                title: "Unknown architecture",
                count: unknownArch,
                message: "Piggy could not identify these app binaries; inspect before deleting.",
                suggestedCommand: "piggy mac list --sort arch"
            ))
        }
        if quarantined > 0 {
            insights.append(MacAuditInsight(
                title: "Quarantined apps",
                count: quarantined,
                message: "Downloaded apps still carrying quarantine deserve a trust check.",
                suggestedCommand: "piggy mac list --quarantined"
            ))
        }
        if withAgents > 0 {
            insights.append(MacAuditInsight(
                title: "Background agents",
                count: withAgents,
                message: "These apps have launch agents/daemons; removal should include a related-file review.",
                suggestedCommand: "piggy mac list --sort agents"
            ))
        }

        return MacAuditSummary(
            totalApps: apps.count,
            totalBytes: apps.reduce(0) { $0 + $1.size },
            appleSignedApps: appleSigned,
            thirdPartyApps: thirdParty,
            appStoreApps: appStore,
            rosettaApps: rosetta,
            dead32BitApps: dead32,
            unknownArchitectureApps: unknownArch,
            quarantinedApps: quarantined,
            appsWithAgents: withAgents,
            largestApps: Array(largest),
            insights: insights
        )
    }
}
