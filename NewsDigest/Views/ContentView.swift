import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var scheduler: SchedulerService

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView()
                .frame(width: 240)

            // Subtle separator
            Rectangle()
                .fill(.quaternary.opacity(0.5))
                .frame(width: 1)

            // Main content
            VStack(spacing: 0) {
                switch viewModel.selectedTab {
                case .feed:
                    FeedView()
                case .topics:
                    TopicsView()
                case .digests:
                    DigestsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $viewModel.selectedArticle) { article in
            ArticleReaderView(article: article)
                .frame(width: 900, height: 650)
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var hoveredTab: NewsViewModel.AppTab?

    var body: some View {
        VStack(spacing: 0) {
            // App title
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("NewsDigest")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(viewModel.isFetching ? "Updating..." : statusText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Refresh button
                Button {
                    Task { await viewModel.fetchAllNews() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.quaternary.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isFetching)
                .opacity(viewModel.isFetching ? 0.4 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Navigation items
            VStack(spacing: 2) {
                SidebarNavItem(
                    icon: "newspaper",
                    label: "Feed",
                    count: viewModel.articles.count,
                    accentColor: .blue,
                    isSelected: viewModel.selectedTab == .feed,
                    isHovered: hoveredTab == .feed
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedTab = .feed
                    }
                }
                .onHover { h in hoveredTab = h ? .feed : nil }

                SidebarNavItem(
                    icon: "tag",
                    label: "Topics",
                    count: viewModel.topics.filter(\.enabled).count,
                    accentColor: .purple,
                    isSelected: viewModel.selectedTab == .topics,
                    isHovered: hoveredTab == .topics
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedTab = .topics
                    }
                }
                .onHover { h in hoveredTab = h ? .topics : nil }

                SidebarNavItem(
                    icon: "waveform.and.doc",
                    label: "Digests",
                    count: viewModel.digests.count,
                    accentColor: .orange,
                    isSelected: viewModel.selectedTab == .digests,
                    isHovered: hoveredTab == .digests
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedTab = .digests
                    }
                }
                .onHover { h in hoveredTab = h ? .digests : nil }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Bottom status + settings
            VStack(spacing: 8) {
                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isFetching ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)

                    if let lastFetch = viewModel.lastFetchDate {
                        Text(lastFetch.formatted(.relative(presentation: .named)))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)

                // Settings button
                SidebarNavItem(
                    icon: "gearshape",
                    label: "Settings",
                    count: 0,
                    accentColor: .gray,
                    isSelected: viewModel.selectedTab == .settings,
                    isHovered: hoveredTab == .settings
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedTab = .settings
                    }
                }
                .onHover { h in hoveredTab = h ? .settings : nil }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
        }
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
    }

    private var statusText: String {
        if let lastFetch = viewModel.lastFetchDate {
            return "Updated \(lastFetch.formatted(.relative(presentation: .named)))"
        }
        return "Ready"
    }
}

// MARK: - Sidebar Nav Item

struct SidebarNavItem: View {
    let icon: String
    let label: String
    let count: Int
    let accentColor: Color
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? accentColor : Color.gray)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            (isSelected ? accentColor.opacity(0.12) : Color.secondary.opacity(0.08)),
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.1) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
