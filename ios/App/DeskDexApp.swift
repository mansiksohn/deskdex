import SwiftUI
import SwiftData
import DeskDexKit

@main
struct DeskDexApp: App {
    // DeskDexKit에도 `Scene`(촬영 장면)이 있어서 SwiftUI 쪽을 명시한다.
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PersistentNode.self, PersistentScene.self])
    }
}
