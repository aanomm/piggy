import Foundation
import ArgumentParser

@main
struct Piggy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "piggy",
        abstract: "A friendly Mac tidy helper that looks, weighs, and explains before anything moves.",
        discussion: "Piggy helps you see which apps and folders take up space. Most commands only look. Trash commands ask first.",
        subcommands: [Mac.self, Folders.self, Folder.self, Audit.self, Snort.self, List.self, Info.self, Delete.self, Search.self, Export.self],
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
        subcommands: [Audit.self, Snort.self, List.self, Info.self, Delete.self, Search.self, Export.self],
        defaultSubcommand: List.self
    )
}
