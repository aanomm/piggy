import Foundation
import ArgumentParser

@main
struct Piggy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "piggy",
        abstract: "Sniff out disk hogs — a lean, fast Mac space scout",
        discussion: "Scan all apps, view details, sort by size/date/arch, delete with leftover cleanup.",
        subcommands: [Snort.self, List.self, Info.self, Delete.self, Search.self, Orphans.self, Export.self],
        defaultSubcommand: nil
    )

    func run() throws {
        SplashMenu.run()
    }
}
