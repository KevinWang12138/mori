import SwiftUI

@main
@MainActor
struct MoriApp: App {
    @NSApplicationDelegateAdaptor(MoriAppDelegate.self) private var appDelegate
    @StateObject private var preferences: PreferencesStore
    @StateObject private var documents: DocumentStore

    init() {
        let preferences = PreferencesStore()
        _preferences = StateObject(wrappedValue: preferences)
        _documents = StateObject(wrappedValue: DocumentStore(preferences: preferences))
    }

    var body: some Scene {
        Window("Mori", id: "workspace") {
            WorkspaceView()
                .environmentObject(documents).environmentObject(preferences)
                .onAppear { appDelegate.connect(documents) }
                .onDisappear { documents.flushRecovery() }
                .onOpenURL { documents.open($0) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1360, height: 870)
        .commands { MoriCommands(store: documents) }
    }
}
