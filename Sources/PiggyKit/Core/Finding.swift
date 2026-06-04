import Foundation

public enum FindingSeverity: String, Codable, CaseIterable, Comparable {
    case info
    case low
    case medium
    case high
    case critical

    public var weight: Double {
        switch self {
        case .info: return 1
        case .low: return 2
        case .medium: return 4
        case .high: return 7
        case .critical: return 10
        }
    }

    public static func < (lhs: FindingSeverity, rhs: FindingSeverity) -> Bool {
        lhs.weight < rhs.weight
    }
}

public enum FindingEffort: String, Codable, CaseIterable {
    case tiny
    case small
    case medium
    case large
    case unknown

    public var weight: Double {
        switch self {
        case .tiny: return 1
        case .small: return 2
        case .medium: return 4
        case .large: return 8
        case .unknown: return 5
        }
    }
}

public struct Finding: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let explanation: String
    public let evidence: [String]
    public let severity: FindingSeverity
    public let effort: FindingEffort
    public let confidence: Double
    public let reclaimableBytes: Int64?

    public init(
        id: String,
        title: String,
        explanation: String,
        evidence: [String] = [],
        severity: FindingSeverity,
        effort: FindingEffort,
        confidence: Double,
        reclaimableBytes: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.evidence = evidence
        self.severity = severity
        self.effort = effort
        self.confidence = min(max(confidence, 0), 1)
        self.reclaimableBytes = reclaimableBytes
    }

    public var priorityScore: Double {
        (severity.weight * confidence) / effort.weight
    }
}

public extension Array where Element == Finding {
    func rankedByPriority() -> [Finding] {
        sorted { lhs, rhs in
            if lhs.priorityScore != rhs.priorityScore {
                return lhs.priorityScore > rhs.priorityScore
            }
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}
