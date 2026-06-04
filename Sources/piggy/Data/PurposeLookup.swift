import Foundation

enum PurposeLookup {
    nonisolated(unsafe) private static var purposes: [String: String] = [:]

    static func load() {
        guard let url = Bundle.module.url(forResource: "purpose", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return }
        purposes = json
    }

    static func purpose(for bundleID: String?) -> String? {
        guard let bid = bundleID else { return nil }
        return purposes[bid]
    }
}
