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
            feedHeader
            feedFilters

            Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)

            if filteredArticles.isEmpty {
                emptyState
            } else {
                feedContent
            }
        }
        .sheet(item: $readerArticle) { article in
            ArticleReaderView(article: article)
                .frame(width: 900, height: 650)
        }
    }

    // MARK: - Header

    private var feedHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text("Your Daily Brief")
                .font(.system(size: 28, weight: .bold, design: .serif))

            Spacer()

            Text("\(filteredArticles.count) stories")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }

    // MARK: - Filters

    private var feedFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 160)
                .background(Color.secondary.opacity(0.06), in: Capsule())

                Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1, height: 20)

                // Source pills
                SourcePill(label: "All", isSelected: selectedSource == nil) {
                    selectedSource = nil
                }
                ForEach(ArticleSource.allCases, id: \.self) { source in
                    SourcePill(label: source.displayName, isSelected: selectedSource == source) {
                        selectedSource = selectedSource == source ? nil : source
                    }
                }

                Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1, height: 20)

                SourcePill(label: "Topics Only", isSelected: showTopicMatchesOnly) {
                    showTopicMatchesOnly.toggle()
                }
                SourcePill(label: "Ranked", isSelected: sortByRank) {
                    sortByRank.toggle()
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Content Grid

    private var feedContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero card — first article
                if let hero = filteredArticles.first {
                    HeroCard(article: hero) { readerArticle = hero }
                }

                // Two-column grid for remaining articles
                let remaining = Array(filteredArticles.dropFirst())
                if !remaining.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(remaining, id: \.id) { article in
                            StoryCard(article: article) { readerArticle = article }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "newspaper")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.secondary)
            Text("No stories yet")
                .font(.system(size: 18, weight: .semibold, design: .serif))
            Text("Pull the latest from your sources.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if !viewModel.isFetching {
                Button {
                    Task { await viewModel.fetchAllNews() }
                } label: {
                    Text("Fetch News")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background(Color.flipRed, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Source Pill

struct SourcePill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.flipRed : Color.secondary.opacity(0.06),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero Card (first/featured article)

struct HeroCard: View {
    let article: Article
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color banner
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(bannerGradient)
                    .frame(height: 140)

                VStack(alignment: .leading, spacing: 4) {
                    if let topic = article.topicName {
                        Text(topic.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(article.sourceName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(18)
            }

            // Content
            VStack(alignment: .leading, spacing: 10) {
                Text(article.title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let summary = article.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 12) {
                    heroMeta
                    Spacer()
                    heroActions
                }
            }
            .padding(18)
        }
        .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.04), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovered = h } }
    }

    private var heroMeta: some View {
        HStack(spacing: 8) {
            Image(systemName: article.source.iconName)
                .font(.system(size: 10))
                .foregroundStyle(sourceColor)
            Text(article.sourceName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            if article.hnPoints > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up").font(.system(size: 8, weight: .bold))
                    Text("\(article.hnPoints)").font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.orange)
            }
            if let pub = article.publishedAt {
                Text(pub.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
    }

    private var heroActions: some View {
        HStack(spacing: 4) {
            CardAction(icon: "safari", help: "Open in browser") {
                if let url = URL(string: article.url) { NSWorkspace.shared.open(url) }
            }
            CardAction(icon: article.isBookmarked ? "bookmark.fill" : "bookmark",
                       help: "Bookmark", tint: article.isBookmarked ? .yellow : nil) {
                article.isBookmarked.toggle()
            }
        }
        .opacity(isHovered ? 1 : 0)
    }

    private var bannerGradient: LinearGradient {
        switch article.source {
        case .hackerNews:
            return LinearGradient(colors: [Color(red: 0.95, green: 0.4, blue: 0.1), Color(red: 0.85, green: 0.25, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .substack:
            return LinearGradient(colors: [Color(red: 0.55, green: 0.25, blue: 0.7), Color(red: 0.4, green: 0.15, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rss:
            return LinearGradient(colors: [Color.flipRed, Color(red: 0.75, green: 0.1, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange
        case .substack: return .purple
        case .rss: return Color.flipRed
        }
    }
}

// MARK: - Story Card (grid item)

struct StoryCard: View {
    let article: Article
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source stripe
            HStack(spacing: 6) {
                Circle()
                    .fill(sourceColor)
                    .frame(width: 6, height: 6)
                Text(article.sourceName.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                if let topic = article.topicName {
                    Text(topic)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.flipRed.opacity(0.1), in: Capsule())
                        .foregroundStyle(Color.flipRed)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Title
            Text(article.title)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)

            // Summary
            if let summary = article.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            // Footer
            HStack(spacing: 6) {
                if article.hnPoints > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up").font(.system(size: 8, weight: .bold))
                        Text("\(article.hnPoints)").font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.orange)
                }
                if article.hnComments > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left").font(.system(size: 8))
                        Text("\(article.hnComments)").font(.system(size: 10, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let pub = article.publishedAt {
                    Text(pub.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(minHeight: 160)
        .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(isHovered ? 0.15 : 0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 10 : 3, y: isHovered ? 4 : 1)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovered = h } }
    }

    private var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange
        case .substack: return .purple
        case .rss: return Color.flipRed
        }
    }
}

// MARK: - Card Action

struct CardAction: View {
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
                .frame(width: 26, height: 26)
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
