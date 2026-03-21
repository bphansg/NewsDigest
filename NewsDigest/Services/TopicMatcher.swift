import Foundation

/// Matches articles against user-defined topics by keyword matching.
struct TopicMatcher {

    /// Returns the name of the first matching topic, or nil.
    static func match(text: String, topics: [Topic]) -> String? {
        let lower = text.lowercased()
        for topic in topics where topic.enabled {
            for keyword in topic.keywords {
                if lower.contains(keyword.lowercased()) {
                    return topic.name
                }
            }
        }
        return nil
    }

    /// Rank articles by composite score (HN engagement + topic match + source quality + recency).
    static func rankArticles(_ articles: [Article]) -> [Article] {
        return articles.sorted { $0.rankScore > $1.rankScore }
    }
}
