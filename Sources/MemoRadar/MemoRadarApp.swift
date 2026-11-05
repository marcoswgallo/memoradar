import SwiftUI

@main
struct MemoRadarApp: App {
    private let model: AppModel

    init() {
        model = AppModel(settings: AppSettings())
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            MenuBarIcon(state: model.iconState)
        }
        .menuBarExtraStyle(.window)
    }
}
