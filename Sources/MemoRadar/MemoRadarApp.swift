import SwiftUI

@main
struct MemoRadarApp: App {
    var body: some Scene {
        MenuBarExtra("MemoRadar", systemImage: "memorychip") {
            Text("MemoRadar")
        }
        .menuBarExtraStyle(.window)
    }
}
