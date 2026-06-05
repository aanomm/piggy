import Foundation

public enum AppSearch {
    public struct Results {
        public let apps: [AppInfo]
        public let usedTechnicalFallback: Bool
    }

    public static func search(_ apps: [AppInfo], query rawQuery: String) -> Results {
        let query = normalized(rawQuery)
        guard !query.isEmpty else {
            return Results(apps: [], usedTechnicalFallback: false)
        }

        let visibleMatches = rankedVisibleMatches(apps, query: query)
        if !visibleMatches.isEmpty {
            return Results(apps: visibleMatches.map(\.app), usedTechnicalFallback: false)
        }

        let technicalMatches = rankedTechnicalMatches(apps, query: query)
        return Results(apps: technicalMatches.map(\.app), usedTechnicalFallback: true)
    }

    public static func visibleNameMatchedAppIDs(_ apps: [AppInfo], query rawQuery: String) -> Set<AppInfo.ID> {
        let query = normalized(rawQuery)
        guard !query.isEmpty else { return [] }
        return Set(rankedVisibleMatches(apps, query: query).map(\.app.id))
    }

    private static func rankedVisibleMatches(_ apps: [AppInfo], query: String) -> [(app: AppInfo, rank: Int)] {
        apps.compactMap { app in
            let name = normalized(app.displayName)
            guard let rank = visibleRank(name: name, query: query) else { return nil }
            return (app, rank)
        }
        .sorted(by: compareRankedApps)
    }

    private static func rankedTechnicalMatches(_ apps: [AppInfo], query: String) -> [(app: AppInfo, rank: Int)] {
        apps.compactMap { app in
            var bestRank: Int?
            if let bundleIdentifier = app.bundleIdentifier {
                let bundleID = normalized(bundleIdentifier)
                bestRank = minRank(bestRank, technicalRank(value: bundleID, query: query))
            }
            if let purpose = app.purpose {
                bestRank = minRank(bestRank, technicalRank(value: normalized(purpose), query: query))
            }
            guard let rank = bestRank else { return nil }
            return (app, rank)
        }
        .sorted(by: compareRankedApps)
    }

    private static func visibleRank(name: String, query: String) -> Int? {
        if name == query { return 0 }
        if name.hasPrefix(query) { return 1 }
        if name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(query) }) {
            return 2
        }
        if name.contains(query) { return 3 }
        return nil
    }

    private static func technicalRank(value: String, query: String) -> Int? {
        if value == query { return 10 }
        if value.hasPrefix(query) { return 11 }
        if value.contains(query) { return 12 }
        return nil
    }

    private static func minRank(_ lhs: Int?, _ rhs: Int?) -> Int? {
        switch (lhs, rhs) {
        case let (.some(l), .some(r)): return min(l, r)
        case let (.some(l), .none): return l
        case let (.none, .some(r)): return r
        case (.none, .none): return nil
        }
    }

    private static func compareRankedApps(
        _ lhs: (app: AppInfo, rank: Int),
        _ rhs: (app: AppInfo, rank: Int)
    ) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        let nameOrder = lhs.app.displayName.localizedStandardCompare(rhs.app.displayName)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.app.size > rhs.app.size
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
