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
        if showTopicMatchesOnly { result = result.filter { $0.topicName != nil } }
        if let source = selectedSource { result = result.filter { $0.source == source } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                ($0.summary?.lowercased().contains(q) ?? false) ||
                $0.sourceName.lowercased().contains(q) ||
                ($0.topicName?.lowercased().contains(q) ?? false)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            feedFilters

            if filteredArticles.isEmpty {
                emptyState
            } else {
                magazineLayout
            }
        }
        .sheet(item: $readerArticle) { article in
            ArticleReaderView(article: article)
                .frame(width: 900, height: 650)
        }
    }

    // MARK: - Filters

    private var feedFilters: some View {
        HStack(spacing: 0) {
            // Search
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.tertiary)
                TextField("Search stories...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .light, design: .serif))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 200)
            .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()

            // Source pills
            HStack(spacing: 3) {
                SourcePill(label: "All", isSelected: selectedSource == nil) { selectedSource = nil }
                ForEach(ArticleSource.allCases, id: \.self) { src in
                    SourcePill(label: src.displayName, isSelected: selectedSource == src) {
                        selectedSource = selectedSource == src ? nil : src
                    }
                }

                Rectangle().fill(Color.secondary.opacity(0.12)).frame(width: 1, height: 16).padding(.horizontal, 4)

                SourcePill(label: "Topics", isSelected: showTopicMatchesOnly) { showTopicMatchesOnly.toggle() }
                SourcePill(label: "Ranked", isSelected: sortByRank) { sortByRank.toggle() }
            }

            Spacer()

            Text("\(filteredArticles.count) stories")
                .font(.system(size: 11, weight: .light, design: .serif))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 10)
        .background(Color.flipBg)
    }

    // MARK: - Magazine Layout

    private var magazineLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Section header
                HStack(alignment: .firstTextBaseline) {
                    Text("Your Daily Brief")
                        .font(.system(size: 34, weight: .heavy, design: .serif))
                    Spacer()
                    if let d = viewModel.lastFetchDate {
                        Text(d.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .light, design: .serif))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 6)

                // Thin red accent line
                HStack(spacing: 0) {
                    Rectangle().fill(Color.flipRed).frame(width: 40, height: 3)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

                // Magazine grid: alternating patterns
                let articles = filteredArticles
                MagazineGrid(articles: articles) { article in
                    readerArticle = article
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No stories")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(.secondary)
            Text("Your feed is empty. Fetch the latest from your sources.")
                .font(.system(size: 14, weight: .light, design: .serif))
                .foregroundStyle(.tertiary)
            if !viewModel.isFetching {
                Button {
                    Task { await viewModel.fetchAllNews() }
                } label: {
                    Text("Fetch News")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 28).padding(.vertical, 10)
                        .background(Color.flipRed, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Magazine Grid (alternating layouts)

struct MagazineGrid: View {
    let articles: [Article]
    let onTap: (Article) -> Void

    var body: some View {
        LazyVStack(spacing: 20) {
            let chunks = makeChunks(articles)
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                switch chunk {
                case .hero(let a):
                    CoverCard(article: a) { onTap(a) }
                case .pair(let a, let b):
                    HStack(spacing: 16) {
                        EditorialCard(article: a) { onTap(a) }
                        EditorialCard(article: b) { onTap(b) }
                    }
                case .single(let a):
                    WideCard(article: a) { onTap(a) }
                }
            }
        }
    }

    enum Chunk {
        case hero(Article)
        case pair(Article, Article)
        case single(Article)
    }

    // Pattern: hero, pair, pair, wide, pair, pair, wide...
    private func makeChunks(_ articles: [Article]) -> [Chunk] {
        var result: [Chunk] = []
        var i = 0
        guard !articles.isEmpty else { return result }

        // First article = hero
        result.append(.hero(articles[i])); i += 1

        while i < articles.count {
            let remaining = articles.count - i
            let patternPos = result.count % 5 // cycle: pair, pair, wide, pair, pair

            if patternPos == 3 || remaining == 1 {
                // Wide card
                result.append(.single(articles[i])); i += 1
            } else if remaining >= 2 {
                // Pair
                result.append(.pair(articles[i], articles[i + 1])); i += 2
            } else {
                result.append(.single(articles[i])); i += 1
            }
        }
        return result
    }
}

// MARK: - Cover Card (hero / featured)

struct CoverCard: View {
    let article: Article
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width gradient banner
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(bannerGradient)
                    .frame(height: 160)

                // Large decorative letter
                Text(String(article.sourceName.prefix(1)).uppercased())
                    .font(.system(size: 120, weight: .black, design: .serif))
                    .foregroundStyle(.white.opacity(0.06))
                    .offset(x: -10, y: 20)

                // Source label
                VStack(alignment: .leading, spacing: 3) {
                    if let topic = article.topicName {
                        Text(topic.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Text(article.sourceName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(22)
            }
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text(article.title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let summary = article.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 14, weight: .light, design: .serif))
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                coverFooter
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 16 : 6, y: isHovered ? 8 : 3)
        .scaleEffect(isHovered ? 1.004 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { h in withAnimation(.easeOut(duration: 0.2)) { isHovered = h } }
    }

    private var coverFooter: some View {
        HStack(spacing: 10) {
            // Source icon
            Image(systemName: article.source.iconName)
                .font(.system(size: 10))
                .foregroundStyle(sourceColor)

            Text(article.sourceName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if article.hnPoints > 0 {
                Text("\(article.hnPoints) points")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            if article.hnComments > 0 {
                Text("\(article.hnComments) comments")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let pub = article.publishedAt {
                Text(pub.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.tertiary)
            }

            // Actions on hover
            HStack(spacing: 2) {
                CardAction(icon: "safari", help: "Browser") {
                    if let url = URL(string: article.url), url.scheme == "https" || url.scheme == "http" { NSWorkspace.shared.open(url) }
                }
                CardAction(icon: article.isBookmarked ? "bookmark.fill" : "bookmark",
                           help: "Bookmark", tint: article.isBookmarked ? .yellow : nil) {
                    article.isBookmarked.toggle()
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
    }

    private var bannerGradient: LinearGradient {
        switch article.source {
        case .hackerNews:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.42, blue: 0.08), Color(red: 0.82, green: 0.22, blue: 0.02)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case .substack:
            return LinearGradient(colors: [Color(red: 0.56, green: 0.27, blue: 0.72), Color(red: 0.38, green: 0.12, blue: 0.52)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rss:
            return LinearGradient(colors: [Color.flipRed, Color(red: 0.72, green: 0.08, blue: 0.10)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange; case .substack: return .purple; case .rss: return Color.flipRed
        }
    }
}

// MARK: - Editorial Card (half-width, in pairs)

struct EditorialCard: View {
    let article: Article
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colored top stripe
            Rectangle()
                .fill(sourceColor)
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 10) {
                // Source + topic
                HStack(spacing: 0) {
                    Text(article.sourceName.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(sourceColor)
                    Spacer()
                    if let topic = article.topicName {
                        Text(topic)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.flipRed)
                    }
                }

                // Headline
                Text(article.title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .lineSpacing(1)
                    .foregroundStyle(article.isRead ? .secondary : .primary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Summary
                if let summary = article.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12, weight: .light, design: .serif))
                        .lineSpacing(2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                // Footer
                HStack(spacing: 6) {
                    if article.hnPoints > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up").font(.system(size: 7, weight: .heavy))
                            Text("\(article.hnPoints)").font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.orange)
                    }
                    if article.hnComments > 0 {
                        Text("\(article.hnComments)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if let pub = article.publishedAt {
                        Text(pub.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .padding(16)
        }
        .frame(minHeight: 180)
        .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(isHovered ? 0.12 : 0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 10 : 3, y: isHovered ? 5 : 1)
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovered = h } }
    }

    private var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange; case .substack: return .purple; case .rss: return Color.flipRed
        }
    }
}

// MARK: - Wide Card (full-width, horizontal)

struct WideCard: View {
    let article: Article
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(sourceColor)
                .frame(width: 5)

            HStack(alignment: .top, spacing: 18) {
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.sourceName.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(sourceColor)

                    Text(article.title)
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .lineSpacing(1)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(2)

                    if let summary = article.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 13, weight: .light, design: .serif))
                            .lineSpacing(2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        if article.hnPoints > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up").font(.system(size: 7, weight: .heavy))
                                Text("\(article.hnPoints)").font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.orange)
                        }

                        if let topic = article.topicName {
                            Text(topic)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.flipRed.opacity(0.08), in: Capsule())
                                .foregroundStyle(Color.flipRed)
                        }

                        Spacer()

                        if let pub = article.publishedAt {
                            Text(pub.formatted(.relative(presentation: .named)))
                                .font(.system(size: 10, weight: .light))
                                .foregroundStyle(.quaternary)
                        }
                    }
                }

                // Reading indicator
                VStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .opacity(isHovered ? 1 : 0.3)
            }
            .padding(18)
        }
        .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(isHovered ? 0.12 : 0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 10 : 3, y: isHovered ? 5 : 1)
        .scaleEffect(isHovered ? 1.004 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovered = h } }
    }

    private var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange; case .substack: return .purple; case .rss: return Color.flipRed
        }
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
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(isSelected ? Color.flipRed : Color.clear, in: Capsule())
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
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
                .background(isHovered ? Color.primary.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }
}
