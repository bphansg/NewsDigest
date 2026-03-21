import SwiftUI
import SwiftData

@main
struct NewsDigestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = NewsViewModel()
    @StateObject private var speechService = SpeechService.shared
    @StateObject private var scheduler = SchedulerService.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Topic.self,
            Article.self,
            Digest.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(speechService)
                .environmentObject(scheduler)
                .modelContainer(sharedModelContainer)
                .onAppear {
                    let ctx = sharedModelContainer.mainContext
                    viewModel.configure(modelContext: ctx)
                    scheduler.requestNotificationPermission()
                    scheduler.start()

                    // Initial fetch on launch
                    Task {
                        await viewModel.fetchAllNews()
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)

        // Menu bar extra
        MenuBarExtra("News Digest", systemImage: "newspaper.fill") {
            MenuBarView()
                .environmentObject(viewModel)
                .environmentObject(scheduler)
        }
        .menuBarExtraStyle(.menu)

        // Settings scene
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(scheduler)
                .modelContainer(sharedModelContainer)
        }
    }
}

// MARK: - App Delegate (background running + dock behavior)

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep running when all windows are closed
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        // Don't quit when window closes — keep running in background
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Re-open main window when dock icon is clicked
        if !flag {
            for window in sender.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(self)
                    break
                }
            }
        }
        return true
    }
}
