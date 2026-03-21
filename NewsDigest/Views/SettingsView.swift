import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @EnvironmentObject var scheduler: SchedulerService
    @State private var fetchInterval = 60
    @State private var cleanupDays = 7

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 20)

                VStack(spacing: 18) {
                    scheduleCard
                    storageCard
                    sourcesCard
                    aboutCard
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .onAppear { fetchInterval = scheduler.fetchIntervalMinutes }
    }

    // MARK: - Schedule

    private var scheduleCard: some View {
        FlipSettingsCard(title: "SCHEDULE", icon: "clock") {
            VStack(spacing: 0) {
                FlipRow(label: "Auto-fetch") {
                    Picker("", selection: $fetchInterval) {
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("4 hours").tag(240)
                        Text("6 hours").tag(360)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .onChange(of: fetchInterval) { _, v in
                        scheduler.fetchIntervalMinutes = v
                        scheduler.start()
                    }
                }
                FlipRow(label: "Status") {
                    HStack(spacing: 6) {
                        Circle().fill(viewModel.isFetching ? Color.orange : Color.green).frame(width: 6, height: 6)
                        Text(viewModel.isFetching ? "Fetching..." : "Active")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                FlipRow(label: "Last fetch") {
                    Text(lastFetchStr)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.fetchAllNews() }
                    } label: {
                        Text("Fetch Now")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color.flipRed.opacity(0.1), in: Capsule())
                            .foregroundStyle(Color.flipRed)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isFetching)
                }
                .padding(.top, 6)
            }
        }
    }

    private var lastFetchStr: String {
        viewModel.lastFetchDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
    }

    // MARK: - Storage

    private var storageCard: some View {
        FlipSettingsCard(title: "STORAGE", icon: "internaldrive") {
            VStack(spacing: 0) {
                FlipRow(label: "Auto-cleanup") {
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
                FlipRow(label: "Articles") { statLabel("\(viewModel.articles.count)") }
                FlipRow(label: "Topics") { statLabel("\(viewModel.topics.count)") }
                FlipRow(label: "Digests") { statLabel("\(viewModel.digests.count)") }
                HStack {
                    Spacer()
                    Button {
                        viewModel.cleanupOldArticles(olderThan: cleanupDays)
                    } label: {
                        Text("Cleanup")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color.red.opacity(0.08), in: Capsule())
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
        }
    }

    private func statLabel(_ val: String) -> some View {
        Text(val)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }

    // MARK: - Sources

    private var sourcesCard: some View {
        FlipSettingsCard(title: "SOURCES", icon: "antenna.radiowaves.left.and.right") {
            VStack(spacing: 8) {
                FlipSourceRow(icon: "flame.fill", color: .orange, name: "Hacker News", detail: "Top 60 stories")
                FlipSourceRow(icon: "dot.radiowaves.left.and.right", color: Color.flipRed, name: "RSS Feeds", detail: "TechCrunch, Ars Technica, The Verge, MIT Tech Review, Wired")
                FlipSourceRow(icon: "envelope.open.fill", color: .purple, name: "Newsletters", detail: "Stratechery, Simon Willison, Astral Codex Ten, Lenny's, Pragmatic Engineer")
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        FlipSettingsCard(title: "ABOUT", icon: "info.circle") {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NewsDigest")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                        Text("AI-powered news curation for your Mac")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("v1.0")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Author").font(.system(size: 13))
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

struct FlipSettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.flipRed)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            VStack(spacing: 0) { content }
                .padding(14)
                .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.08), lineWidth: 1))
        }
    }
}

// MARK: - Settings Row

struct FlipRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            content
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Source Row

struct FlipSourceRow: View {
    let icon: String
    let color: Color
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color.opacity(0.1))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
