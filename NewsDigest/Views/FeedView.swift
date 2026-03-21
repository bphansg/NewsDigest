import SwiftUI

struct FeedView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var searchText = ""
    @State private var selectedSource: ArticleSource?
    @State private var showTopicMatchesOnly = false
    @State private var sortByRank = true
    @State private var readerArticle: Article?

    var filteredArticles: [Article] {
        var result = sortByRank ? viewModel.rankedArticles : viewModel.articles

        if showTopicMatchesOnly {
            result = result.filter { $0.topicName != nil }
        }

        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                ($0.summary?.lowercased().contains(query) ?? false) ||
                $0.sourceName.lowercased().contains(query) ||
                ($0.topicName?.lowercased().contains(query) ?? false)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Feed")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("\(filteredArticles.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.5), in: Capsule())

                    Spacer()

                    Button {
                        Task { await viewModel.fetchAllNews() }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isFetching {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(viewModel.isFetching ? "Updating..." : "Refresh")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isFetching)
                }

                // Filter bar
                HStack(spacing: 10) {
                    // Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: 220)

                    // Source pills
                    HStack(spacing: 4) {
                        FilterPill(label: "All", isSelected: selectedSource == nil) {
                            selectedSource = nil
                        }
                        ForEach(ArticleSource.allCases, id: \.self) { source in
                            FilterPill(
                                label: source.displayName,
                                icon: source.iconName,
                                isSelected: selectedSource == source
                            ) {
                                selectedSource = selectedSource == source ? nil : source
                            }
                        }
                    }

                    Spacer()

                    // Toggle pills
                    HStack(spacing: 4) {
                        TogglePill(icon: "tag", label: "Topics", isOn: $showTopicMatchesOnly)
                        TogglePill(icon: "arrow.up.arrow.down", label: "Ranked", isOn: $sortByRank)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle()
                .fill(.quaternary.opacity(0.4))
                .frame(height: 1)

            // Article list
            if filteredArticles.isEmpty {
                EmptyStateView(
                    icon: "newspaper",
                    title: "No articles yet",
                    subtitle: "Pull the latest stories from your configured sources.",
                    actionLabel: "Fetch News",
                    onAction: viewModel.isFetching ? nil : {
                        Task { await viewModel.fetchAllNews() }
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredArticles.enumerated()), id: \.element.id) { index, article in
                            ArticleRow(article: article, onRead: { readerArticle = article })

                            if index < filteredArticles.count - 1 {
                                Rectangle()
                                    .fill(.quaternary.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(item: $readerArticle) { article in
            ArticleReaderView(article: article)
                .frame(width: 900, height: 650)
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected ? Color.blue.opacity(0.12) : Color.clear,
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toggle Pill

struct TogglePill: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 11, weight: isOn ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isOn ? Color.purple.opacity(0.12) : Color.secondary.opacity(0.08),
                in: Capsule()
            )
            .foregroundStyle(isOn ? .purple : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionLabel: String = ""
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.06))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let handler = onAction {
                Button(action: handler) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Article Row

struct ArticleRow: View {
    let article: Article
    let onRead: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Source indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(sourceColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: article.source.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(sourceColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.system(size: 13, weight: article.isRead ? .regular : .semibold))
                    .foregroundStyle(article.isRead ? .secondary : .primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(article.sourceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)

                    if article.hnPoints > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                            Text("\(article.hnPoints)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.orange)
                    }

                    if article.hnComments > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 8))
                            Text("\(article.hnComments)")
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundStyle(.tertiary)
                    }

                    if let topic = article.topicName {
                        Text(topic)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    if let pub = article.publishedAt {
                        Text(pub.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                }

                if let summary = article.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }

            // Actions — only visible on hover
            HStack(spacing: 2) {
                IconAction(icon: "doc.text", help: "Read in app") { onRead() }
                IconAction(icon: "safari", help: "Open in browser") {
                    if let url = URL(string: article.url) {
                        NSWorkspace.shared.open(url)
                        article.isRead = true
                    }
                }
                IconAction(
                    icon: article.isBookmarked ? "bookmark.fill" : "bookmark",
                    help: "Bookmark",
                    tint: article.isBookmarked ? .yellow : nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        article.isBookmarked.toggle()
                    }
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onRead() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange
        case .substack: return .purple
        case .rss: return .blue
        }
    }
}

// MARK: - Icon Action Button

struct IconAction: View {
    let icon: String
    let help: String
    var tint: Color? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint ?? (isHovered ? .primary : .secondary))
                .frame(width: 28, height: 28)
                .background(
                    isHovered ? Color.primary.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }
}
