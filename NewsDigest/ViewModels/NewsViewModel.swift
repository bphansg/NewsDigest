import Foundation
import SwiftData
import Combine

/// Main view model for the News Digest app. Coordinates fetching, storage, and digest generation.
@MainActor
class NewsViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var topics: [Topic] = []
    @Published var digests: [Digest] = []
    @Published var isFetching = false
    @Published var lastFetchDate: Date?
    @Published var statusMessage = "Ready"
    @Published var selectedTab: AppTab = .feed
    @Published var selectedArticle: Article?

    // Cached sorted articles — invalidated only when articles change
    private var _rankedArticles: [Article]?

    enum AppTab: String, CaseIterable {
        case feed = "Feed"
        case topics = "Topics"
        case digests = "Digests"
        case settings = "Settings"
    }

    private let hnService = HackerNewsService()
    private let rssService = RSSService()
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private var knownURLs = Set<String>()

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
        seedDefaultTopics()

        // Listen for scheduler-triggered fetches
        NotificationCenter.default.publisher(for: .newsFetchRequested)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.fetchAllNews()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() {
        guard let ctx = modelContext else { return }
        do {
            let topicDescriptor = FetchDescriptor<Topic>(sortBy: [SortDescriptor(\.name)])
            topics = try ctx.fetch(topicDescriptor)

            let articleDescriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)])
            articles = try ctx.fetch(articleDescriptor)
            knownURLs = Set(articles.map(\.url))
            _rankedArticles = nil

            let digestDescriptor = FetchDescriptor<Digest>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            digests = try ctx.fetch(digestDescriptor)
        } catch {
            print("⚠️ Error loading data: \(error)")
        }
    }

    // MARK: - Topic Management

    func addTopic(name: String, keywords: [String]) {
        guard let ctx = modelContext else { return }
        let topic = Topic(name: name, keywords: keywords)
        ctx.insert(topic)
        try? ctx.save()
        loadData()
    }

    func deleteTopic(_ topic: Topic) {
        guard let ctx = modelContext else { return }
        ctx.delete(topic)
        try? ctx.save()
        loadData()
    }

    func toggleTopic(_ topic: Topic) {
        topic.enabled.toggle()
        try? modelContext?.save()
        loadData()
    }

    private func seedDefaultTopics() {
        guard let ctx = modelContext else { return }
        guard topics.isEmpty else { return }

        let defaults: [(String, [String])] = [
            ("AI & Machine Learning", ["artificial intelligence", "machine learning", "llm", "gpt", "openai", "claude", "transformer", "neural network", "deep learning", "generative ai"]),
            ("Cloud Security", ["cloud security", "cnapp", "crowdstrike", "zero trust", "siem", "vulnerability", "ransomware", "cybersecurity", "infosec"]),
            ("Apple & macOS", ["apple", "macos", "swift", "swiftui", "xcode", "iphone", "wwdc", "ios"]),
            ("Startups & VC", ["startup", "venture capital", "series a", "funding round", "ycombinator", "y combinator", "seed round", "valuation"]),
            ("Developer Tools", ["developer tools", "devtools", "vscode", "github", "copilot", "terraform", "docker", "kubernetes", "rust", "golang"]),
        ]

        for (name, keywords) in defaults {
            let topic = Topic(name: name, keywords: keywords)
            ctx.insert(topic)
        }
        try? ctx.save()
        loadData()
    }

    // MARK: - News Fetching

    func fetchAllNews() async {
        guard !isFetching else { return }
        isFetching = true
        statusMessage = "Fetching news..."

        var newCount = 0

        // Fetch HN
        statusMessage = "Fetching Hacker News..."
        do {
            let hnItems = try await hnService.fetchTopStories(count: 60)
            for item in hnItems {
                guard let title = item.title, let urlStr = item.url, !urlStr.isEmpty else { continue }
                guard !articleExists(url: urlStr) else { continue }

                let matchedTopic = TopicMatcher.match(text: title, topics: topics)
                let article = Article(
                    title: title,
                    url: urlStr,
                    source: .hackerNews,
                    sourceName: "Hacker News",
                    publishedAt: item.time.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    topicName: matchedTopic,
                    hnPoints: item.score ?? 0,
                    hnComments: item.descendants ?? 0
                )
                modelContext?.insert(article)
                knownURLs.insert(urlStr)
                newCount += 1
            }
        } catch {
            print("⚠️ HN fetch error: \(error)")
        }

        // Fetch RSS + Substack
        statusMessage = "Fetching RSS & newsletters..."
        let feedItems = await rssService.fetchAllFeeds()
        for item in feedItems {
            guard !articleExists(url: item.link) else { continue }
            let matchedTopic = TopicMatcher.match(
                text: item.title + " " + (item.description ?? ""),
                topics: topics
            )
            let article = Article(
                title: item.title,
                url: item.link,
                source: item.sourceType,
                sourceName: item.sourceName,
                summary: item.description,
                publishedAt: item.pubDate,
                topicName: matchedTopic,
                hnPoints: 0,
                hnComments: 0
            )
            modelContext?.insert(article)
            knownURLs.insert(item.link)
            newCount += 1
        }

        try? modelContext?.save()
        loadData()

        isFetching = false
        lastFetchDate = Date()
        statusMessage = newCount > 0 ? "Found \(newCount) new articles" : "No new articles"

        if newCount > 0 {
            SchedulerService.shared.sendNotification(articleCount: newCount)
        }
    }

    private func articleExists(url: String) -> Bool {
        return knownURLs.contains(url)
    }

    // MARK: - Digest Generation

    var rankedArticles: [Article] {
        if let cached = _rankedArticles { return cached }
        let sorted = TopicMatcher.rankArticles(articles)
        _rankedArticles = sorted
        return sorted
    }

    var topicMatchedArticles: [Article] {
        articles.filter { $0.topicName != nil }
    }

    func generateDigest(count: Int = 15) -> Digest? {
        guard let ctx = modelContext else { return nil }

        let top = Array(rankedArticles.prefix(count))
        guard !top.isEmpty else { return nil }

        let script = DigestGenerator.generateScript(articles: top)
        let dateStr = Date().formatted(date: .abbreviated, time: .omitted)
        let digest = Digest(
            title: "Daily Digest — \(dateStr)",
            articleIDs: top.map { $0.id },
            audioScript: script
        )
        digest.status = .ready

        ctx.insert(digest)
        try? ctx.save()
        loadData()
        return digest
    }

    func generateReport(count: Int = 15) -> String {
        let top = Array(rankedArticles.prefix(count))
        return DigestGenerator.generateReport(articles: top)
    }

    func articlesForDigest(_ digest: Digest) -> [Article] {
        let idSet = Set(digest.articleIDs)
        let articleMap = Dictionary(uniqueKeysWithValues: articles.lazy.map { ($0.id, $0) })
        return digest.articleIDs.compactMap { articleMap[$0] }
    }

    // MARK: - Cleanup

    /// Remove articles older than `days` days.
    func cleanupOldArticles(olderThan days: Int = 7) {
        guard let ctx = modelContext else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let old = articles.filter { $0.fetchedAt < cutoff && !$0.isBookmarked }
        for article in old {
            ctx.delete(article)
        }
        try? ctx.save()
        loadData()
    }
}
