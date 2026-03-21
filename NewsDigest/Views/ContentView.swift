import SwiftUI

// Flipboard-inspired color palette
extension Color {
    static let flipRed = Color(red: 0.88, green: 0.15, blue: 0.16)
    static let flipDark = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let flipCard = Color(nsColor: .controlBackgroundColor)
    static let flipBg = Color(nsColor: .windowBackgroundColor)
}

struct ContentView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var scheduler: SchedulerService

    var body: some View {
        HStack(spacing: 0) {
            FlipSidebar()
                .frame(width: 220)

            Rectangle()
                .fill(Color.black.opacity(0.08))
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
        .frame(minWidth: 1000, minHeight: 660)
        .background(Color.flipBg)
    }
}

// MARK: - Flipboard Sidebar

struct FlipSidebar: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var hoveredTab: NewsViewModel.AppTab?

    var body: some View {
        VStack(spacing: 0) {
            // Logo area
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.flipRed)
                        .frame(width: 34, height: 34)
                    Text("N")
                        .font(.system(size: 20, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("News")
                        .font(.system(size: 16, weight: .heavy, design: .serif))
                    + Text("Digest")
                        .font(.system(size: 16, weight: .light, design: .serif))
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 28)

            // Nav items
            VStack(spacing: 1) {
                FlipNavItem(icon: "newspaper.fill", label: "Home",
                            isSelected: viewModel.selectedTab == .feed,
                            isHovered: hoveredTab == .feed) {
                    viewModel.selectedTab = .feed
                }
                .onHover { hoveredTab = $0 ? .feed : nil }

                FlipNavItem(icon: "number", label: "Topics",
                            isSelected: viewModel.selectedTab == .topics,
                            isHovered: hoveredTab == .topics) {
                    viewModel.selectedTab = .topics
                }
                .onHover { hoveredTab = $0 ? .topics : nil }

                FlipNavItem(icon: "text.document.fill", label: "Digests",
                            isSelected: viewModel.selectedTab == .digests,
                            isHovered: hoveredTab == .digests) {
                    viewModel.selectedTab = .digests
                }
                .onHover { hoveredTab = $0 ? .digests : nil }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Bottom section
            VStack(spacing: 8) {
                // Fetch button
                Button {
                    Task { await viewModel.fetchAllNews() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isFetching {
                            ProgressView()
                                .scaleEffect(0.45)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(viewModel.isFetching ? "Updating..." : "Refresh")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.flipRed.opacity(viewModel.isFetching ? 0.06 : 0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(Color.flipRed)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isFetching)
                .padding(.horizontal, 14)

                // Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isFetching ? Color.orange : Color.green)
                        .frame(width: 5, height: 5)
                    if let lastFetch = viewModel.lastFetchDate {
                        Text(lastFetch.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)

                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                // Settings
                FlipNavItem(icon: "gearshape", label: "Settings",
                            isSelected: viewModel.selectedTab == .settings,
                            isHovered: hoveredTab == .settings) {
                    viewModel.selectedTab = .settings
                }
                .onHover { hoveredTab = $0 ? .settings : nil }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 14)
        }
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
    }
}

// MARK: - Sidebar Nav Item

struct FlipNavItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.flipRed : .secondary)
                    .frame(width: 22)

                Text(label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.flipRed)
                        .frame(width: 3, height: 18)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.flipRed.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Effect

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
