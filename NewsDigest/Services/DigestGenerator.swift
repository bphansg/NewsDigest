import Foundation

/// Generates a readable/speakable digest script from a set of articles.
struct DigestGenerator {

    /// Create a text script suitable for text-to-speech narration.
    static func generateScript(articles: [Article]) -> String {
        var lines: [String] = []

        let dateStr = Date().formatted(date: .complete, time: .omitted)
        lines.append("Good morning. Here is your news digest for \(dateStr).")
        lines.append("I've curated the top \(articles.count) stories for you today.\n")

        for (index, article) in articles.enumerated() {
            let num = index + 1
            var line = "Story \(num): \(article.title)."
            line += " From \(article.sourceName)."

            if article.hnPoints > 0 {
                line += " This has \(article.hnPoints) points on Hacker News"
                if article.hnComments > 0 {
                    line += " with \(article.hnComments) comments"
                }
                line += "."
            }

            if let summary = article.summary, !summary.isEmpty {
                let trimmed = String(summary.prefix(250))
                line += " \(trimmed)."
            }

            if let topicName = article.topicName {
                line += " This matches your interest in \(topicName)."
            }

            lines.append(line)
            lines.append("") // blank line between stories
        }

        lines.append("That wraps up today's digest. Stay curious, and have a great day.")
        return lines.joined(separator: "\n")
    }

    /// Create a concise markdown report with links.
    static func generateReport(articles: [Article]) -> String {
        var lines: [String] = []

        let dateStr = Date().formatted(date: .complete, time: .omitted)
        lines.append("# News Digest — \(dateStr)")
        lines.append("")
        lines.append("*Top \(articles.count) curated stories*")
        lines.append("")
        lines.append("---")
        lines.append("")

        for (index, article) in articles.enumerated() {
            let num = index + 1
            let sourceIcon: String
            switch article.source {
            case .hackerNews: sourceIcon = "🔥"
            case .substack: sourceIcon = "📨"
            case .rss: sourceIcon = "📡"
            }

            lines.append("### \(num). \(article.title)")
            lines.append("")
            lines.append("\(sourceIcon) **\(article.sourceName)**")

            var meta: [String] = []
            if article.hnPoints > 0 { meta.append("\(article.hnPoints) pts") }
            if article.hnComments > 0 { meta.append("\(article.hnComments) comments") }
            if let topic = article.topicName { meta.append("📌 \(topic)") }
            if let pub = article.publishedAt {
                meta.append(pub.formatted(.relative(presentation: .named)))
            }
            if !meta.isEmpty {
                lines.append(meta.joined(separator: " · "))
            }

            if let summary = article.summary, !summary.isEmpty {
                lines.append("")
                lines.append("> \(String(summary.prefix(300)))")
            }

            lines.append("")
            lines.append("🔗 [\(article.url)](\(article.url))")
            lines.append("")
            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
