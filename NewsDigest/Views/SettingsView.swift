import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @EnvironmentObject var scheduler: SchedulerService
    @State private var fetchInterval = 60
    @State private var cleanupDays = 7

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 20)

                VStack(spacing: 20) {
                    scheduleSection
                    storageSection
                    sourcesSection
                    aboutSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            fetchInterval = scheduler.fetchIntervalMinutes
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        SettingsCard(title: "SCHEDULE", icon: "clock", color: .blue) {
            VStack(spacing: 0) {
                SettingsRow(label: "Auto-fetch interval") {
                    Picker("", selection: $fetchInterval) {
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("4 hours").tag(240)
                        Text("6 hours").tag(360)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .onChange(of: fetchInterval) { _, newValue in
                        scheduler.fetchIntervalMinutes = newValue
                        scheduler.start()
                    }
                }

                SettingsRow(label: "Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isFetching ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        Text(viewModel.isFetching ? "Fetching..." : "Active")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsRow(label: "Last fetch") {
                    Text(lastFetchText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.fetchAllNews() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                            Text("Fetch Now")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isFetching)
                }
                .padding(.top, 4)
            }
        }
    }

    private var lastFetchText: String {
        if let date = viewModel.lastFetchDate {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return "Never"
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        SettingsCard(title: "STORAGE", icon: "internaldrive", color: .purple) {
            VStack(spacing: 0) {
                SettingsRow(label: "Auto-cleanup") {
                    Picker("", selection: $cleanupDays) {
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("Never").tag(999)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                SettingsRow(label: "Articles") {
                    statText("\(viewModel.articles.count)")
                }

                SettingsRow(label: "Topics") {
                    statText("\(viewModel.topics.count)")
                }

                SettingsRow(label: "Digests") {
                    statText("\(viewModel.digests.count)")
                }

                HStack {
                    Spacer()
                    Button {
                        viewModel.cleanupOldArticles(olderThan: cleanupDays)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Cleanup Now")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.08), in: Capsule())
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
    }

    private func statText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }

    // MARK: - Sources Section

    private var sourcesSection: some View {
        SettingsCard(title: "SOURCES", icon: "antenna.radiowaves.left.and.right", color: .orange) {
            VStack(spacing: 8) {
                SourceRow(icon: "flame.fill", color: .orange, name: "Hacker News", detail: "Top 60 stories")
                SourceRow(icon: "dot.radiowaves.left.and.right", color: .blue, name: "RSS Feeds", detail: "TechCrunch, Ars Technica, The Verge, MIT Tech Review, Wired")
                SourceRow(icon: "envelope.open.fill", color: .purple, name: "Newsletters", detail: "Stratechery, Simon Willison, Astral Codex Ten, Lenny's, Pragmatic Engineer")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsCard(title: "ABOUT", icon: "info.circle", color: .gray) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NewsDigest")
                            .font(.system(size: 14, weight: .semibold))
                        Text("AI-powered news curation for your Mac")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("v1.0")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.tertiary)
                }

                HStack {
                    Text("Author")
                        .font(.system(size: 13))
                    Spacer()
                    Text("Binh Phan")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            VStack(spacing: 0) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            content
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Source Row

struct SourceRow: View {
    let icon: String
    let color: Color
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
