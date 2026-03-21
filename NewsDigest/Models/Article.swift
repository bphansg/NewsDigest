import Foundation
import SwiftData

enum ArticleSource: String, Codable, CaseIterable {
    case hackerNews = "hackernews"
    case rss = "rss"
    case substack = "substack"

    var displayName: String {
        switch self {
        case .hackerNews: return "Hacker News"
        case .rss: return "RSS"
        case .substack: return "Substack"
        }
    }

    var iconName: String {
        switch self {
        case .hackerNews: return "flame.fill"
        case .rss: return "dot.radiowaves.left.and.right"
        case .substack: return "envelope.open.fill"
        }
    }
}

@Model
final class Article {
    var id: UUID
    var title: String
    var url: String
    var source: ArticleSource
    var sourceName: String
    var summary: String?
    var score: Int
    var publishedAt: Date?
    var fetchedAt: Date
    var topicName: String?
    var hnPoints: Int
    var hnComments: Int
    var isRead: Bool
    var isBookmarked: Bool

    init(
        title: String,
        url: String,
        source: ArticleSource,
        sourceName: String,
        summary: String? = nil,
        score: Int = 0,
        publishedAt: Date? = nil,
        topicName: String? = nil,
        hnPoints: Int = 0,
        hnComments: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.source = source
        self.sourceName = sourceName
        self.summary = summary
        self.score = score
        self.publishedAt = publishedAt
        self.fetchedAt = Date()
        self.topicName = topicName
        self.hnPoints = hnPoints
        self.hnComments = hnComments
        self.isRead = false
        self.isBookmarked = false
    }

    /// Composite ranking score for curation
    var rankScore: Double {
        var total: Double = 0

        // HN engagement (points + 2x comments)
        total += Double(hnPoints) + Double(hnComments) * 2.0

        // Topic match boost
        if topicName != nil {
            total += 50.0
        }

        // Newsletter/Substack boost
        if source == .substack {
            total += 30.0
        }

        // Recency boost: articles from last 6 hours get extra points
        if let pub = publishedAt {
            let hoursAgo = Date().timeIntervalSince(pub) / 3600
            if hoursAgo < 6 {
                total += 20.0
            } else if hoursAgo < 24 {
                total += 10.0
            }
        }

        return total
    }
}
