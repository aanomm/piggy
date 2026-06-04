import Foundation

enum AgentScanner {
    struct AgentInfo {
        let path: URL
        let plist: [String: Any]?
    }

    static func scanAllAgents() -> [String: [AgentInfo]] {
        let home = NSHomeDirectory()
        let searchPaths = [
            "\(home)/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ]

        var allAgents: [AgentInfo] = []
        for searchPath in searchPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else { continue }

            for url in contents where url.pathExtension == "plist" {
                let plist = NSDictionary(contentsOf: url) as? [String: Any]
                allAgents.append(AgentInfo(path: url, plist: plist))
            }
        }

        var byBundleID: [String: [AgentInfo]] = [:]

        for agent in allAgents {
            guard let plist = agent.plist else { continue }
            let label = plist["Label"] as? String ?? ""
            let programArgs = plist["ProgramArguments"] as? [String] ?? []
            let programs = plist["Program"] as? String ?? ""

            let bundleIDs = extractBundleIDs(label: label, args: programArgs, program: programs)
            for bid in bundleIDs {
                byBundleID[bid, default: []].append(agent)
            }
        }

        return byBundleID
    }

    private static func extractBundleIDs(label: String, args: [String], program: String) -> Set<String> {
        var ids = Set<String>()

        if label.contains("."), label.count > 4 {
            ids.insert(label)
        }

        for arg in args {
            if arg.hasSuffix(".app") {
                continue
            }
            let components = arg.split(separator: ".")
            if components.count >= 3, !arg.hasPrefix("-"), !arg.hasPrefix("/") {
                ids.insert(arg)
            }
        }

        if !program.isEmpty {
            let components = program.split(separator: "/")
            if let last = components.last {
                let sub = String(last).split(separator: ".")
                if sub.count >= 3 {
                    ids.insert(String(last))
                }
            }
        }

        return ids
    }

    static func countForBundleID(_ bundleID: String, in agents: [String: [AgentInfo]]) -> Int {
        var count = 0

        for (key, agentList) in agents {
            if key == bundleID || bundleID.hasPrefix(key) || key.hasPrefix(bundleID) {
                count += agentList.count
            }
        }

        return count
    }
}
