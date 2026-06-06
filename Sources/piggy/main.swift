import Foundation
import ArgumentParser

@main
struct Piggy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "piggy",
        abstract: "Find fat folders and files on your Mac.",
        discussion: "Architecture: piggy [action] [what] [where]. Actions: sniff, snort, search, mudmap. What: apps, imgs, vids, docs.",
        subcommands: [Sniff.self, Snort.self, Search.self, MudMap.self, Mud.self, Map.self, Stye.self, Mac.self, Folders.self, Folder.self, Audit.self, List.self, Info.self, Delete.self, Export.self],
        defaultSubcommand: nil
    )

    func run() throws {
        SplashMenu.run()
    }
}

struct Mac: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mac",
        abstract: "Sniff around your Mac apps.",
        discussion: "These commands help Piggy list apps, explain space use, and export app data for review.",
        shouldDisplay: false,
        subcommands: [Audit.self, Snort.self, List.self, Info.self, Delete.self, Search.self, Export.self],
        defaultSubcommand: List.self
    )
}
