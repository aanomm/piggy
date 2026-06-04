import Foundation

public struct RemovalCandidate: Equatable {
    public let path: URL
    public let size: Int64
    public let category: String
    public let assessment: SafetyAssessment

    public init(
        path: URL,
        size: Int64,
        category: String,
        homeDirectory: String = NSHomeDirectory()
    ) {
        self.path = path
        self.size = size
        self.category = category
        self.assessment = SafetyClassifier.assess(path: path.path, homeDirectory: homeDirectory)
    }

    private init(path: URL, size: Int64, category: String, assessment: SafetyAssessment) {
        self.path = path
        self.size = size
        self.category = category
        self.assessment = assessment
    }

    public func reassessed(homeDirectory: String) -> RemovalCandidate {
        RemovalCandidate(
            path: path,
            size: size,
            category: category,
            assessment: SafetyClassifier.assess(path: path.path, homeDirectory: homeDirectory)
        )
    }
}

public struct RemovalPlan {
    public let app: AppInfo
    public let appAssessment: SafetyAssessment
    public let canTrashApp: Bool
    public let relatedFilesToTrash: [RemovalCandidate]
    public let skippedRelatedFiles: [RemovalCandidate]

    public var plannedFreedBytes: Int64 {
        guard canTrashApp else { return 0 }
        return app.size + relatedFilesToTrash.reduce(0) { $0 + $1.size }
    }
}

public enum RemovalPlanner {
    public static func plan(
        app: AppInfo,
        relatedFiles: [RemovalCandidate],
        includeRelated: Bool,
        homeDirectory: String = NSHomeDirectory()
    ) -> RemovalPlan {
        let appAssessment = SafetyClassifier.assess(path: app.path.path, homeDirectory: homeDirectory)
        let canTrashApp = appAssessment.level < .sensitive
        let reassessed = relatedFiles.map { $0.reassessed(homeDirectory: homeDirectory) }

        let relatedToTrash: [RemovalCandidate]
        let skipped: [RemovalCandidate]
        if includeRelated {
            relatedToTrash = reassessed.filter { $0.assessment.level < .sensitive }
            skipped = reassessed.filter { $0.assessment.level >= .sensitive }
        } else {
            relatedToTrash = []
            skipped = reassessed
        }

        return RemovalPlan(
            app: app,
            appAssessment: appAssessment,
            canTrashApp: canTrashApp,
            relatedFilesToTrash: relatedToTrash,
            skippedRelatedFiles: skipped
        )
    }
}
