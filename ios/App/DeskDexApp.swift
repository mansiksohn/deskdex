import SwiftUI
import SwiftData
import DeskDexKit

@main
struct DeskDexApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PersistentNode.self, PersistentScene.self])
    }
}
