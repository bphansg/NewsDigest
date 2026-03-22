import SwiftUI

/// Menu bar dropdown for quick access and background control.
struct MenuBarView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @EnvironmentObject var scheduler: SchedulerService

    var body: some View {
        // Status header
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isFetching ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(viewModel.isFetching ? "Updating..." : "NewsDigest Running")
                    .font(.caption)
            }
            if let lastFetch = viewModel.lastFetchDate {
                Text("Updated \(lastFetch.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        Divider()

        // Top articles
        let topArticles = Array(viewModel.rankedArticles.prefix(7))

        if topArticles.isEmpty {
            Text("No articles yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Top Stories")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(topArticles, id: \.id) { article in
                Button {
                    showMainWindow()
                    viewModel.selectedArticle = article
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: article.source.iconName)
                            .font(.caption2)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(article.title)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(article.sourceName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if article.hnPoints > 0 {
                                    Text("\(article.hnPoints) pts")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                if let topic = article.topicName {
                                    Text(topic)
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }

        Divider()

        // Quick actions
        Button {
            Task { await viewModel.fetchAllNews() }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 16)
                Text("Refresh Now")
                if viewModel.isFetching {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .disabled(viewModel.isFetching)
        .keyboardShortcut("r")

        Divider()

        // Window controls
        Button {
            showMainWindow()
        } label: {
            HStack {
                Image(systemName: "macwindow")
                    .frame(width: 16)
                Text("Open Window")
            }
        }
        .keyboardShortcut("o")

        Button {
            showMainWindow()
            viewModel.selectedTab = .feed
        } label: {
            HStack {
                Image(systemName: "newspaper")
                    .frame(width: 16)
                Text("Feed")
            }
        }

        Button {
            showMainWindow()
            viewModel.selectedTab = .digests
        } label: {
            HStack {
                Image(systemName: "waveform.and.doc")
                    .frame(width: 16)
                Text("Digests")
            }
        }

        Button {
            showMainWindow()
            viewModel.selectedTab = .topics
        } label: {
            HStack {
                Image(systemName: "tag")
                    .frame(width: 16)
                Text("Topics")
            }
        }

        Divider()

        // Settings & system
        Button {
            showMainWindow()
            viewModel.selectedTab = .settings
        } label: {
            HStack {
                Image(systemName: "gearshape")
                    .frame(width: 16)
                Text("Settings")
            }
        }
        .keyboardShortcut(",")

        Button {
            restartApp()
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .frame(width: 16)
                Text("Restart")
            }
        }

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            HStack {
                Image(systemName: "power")
                    .frame(width: 16)
                Text("Quit NewsDigest")
            }
        }
        .keyboardShortcut("q")
    }

    // MARK: - Helpers

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        // Use NSWorkspace for safe relaunch — no Process() needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSWorkspace.shared.open(bundleURL)
        }
        NSApp.terminate(nil)
    }
}
