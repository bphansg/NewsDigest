import Foundation

/// Generates NotebookLM-style conversational podcast scripts from curated articles.
struct DigestGenerator {

    // MARK: - Podcast-Style Audio Script

    static func generateScript(articles: [Article]) -> String {
        var script: [String] = []
        let dateStr = Date().formatted(date: .complete, time: .omitted)
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"

        // Cold open — hook the listener
        let topStory = articles.first
        script.append(coldOpen(greeting: greeting, dateStr: dateStr, topStory: topStory))

        // Group by topic for thematic segments
        let segments = buildSegments(articles)

        for (segIndex, segment) in segments.enumerated() {
            // Segment transition
            script.append(segmentTransition(segment.theme, index: segIndex, total: segments.count))

            // Narrate each article with commentary
            for (i, article) in segment.articles.enumerated() {
                let commentary = narrateWithCommentary(article, position: i, groupSize: segment.articles.count)
                script.append(commentary)

                // Connector between articles in the same segment
                if i < segment.articles.count - 1 {
                    script.append(pick(intraConnectors))
                }
            }

            // Segment wrap with insight
            if segment.articles.count > 1 {
                script.append(segmentInsight((theme: segment.theme, articles: segment.articles)))
            }

            script.append("")
        }

        // Sign-off
        script.append(podcastSignOff(articleCount: articles.count))

        return script.joined(separator: "\n")
    }

    // MARK: - Cold Open

    private static func coldOpen(greeting: String, dateStr: String, topStory: Article?) -> String {
        var open = "\(greeting), and welcome to your NewsDigest audio overview for \(dateStr). "

        if let top = topStory {
            let hook = titleToHook(top.title)
            open += "Today we've got some fascinating stuff to get into. \(hook) "
        }

        open += "Let's dive right in.\n"
        return open
    }

    // MARK: - Narrate with Color Commentary

    private static func narrateWithCommentary(_ article: Article, position: Int, groupSize: Int) -> String {
        var parts: [String] = []

        // Conversational lead — never cite points or stats
        parts.append(conversationalLead(article, isFirst: position == 0))

        // Work in the summary naturally, not as a quote
        if let summary = article.summary, !summary.isEmpty {
            let reframed = reframeSummary(summary, title: article.title)
            parts.append(reframed)
        }

        // Add color commentary — the "so what" factor
        let color = colorCommentary(article)
        if !color.isEmpty {
            parts.append(color)
        }

        // Conversational reaction
        parts.append(reaction(article))

        return parts.joined(separator: " ")
    }

    private static func conversationalLead(_ article: Article, isFirst: Bool) -> String {
        let title = article.title

        // Pattern: frame the story like you're telling a friend
        let leads: [(Article) -> String?] = [
            // Surprise/intrigue
            { a in
                let words = a.title.lowercased()
                if words.contains("launch") || words.contains("release") || words.contains("announce") {
                    return "Okay, so this one is pretty exciting. \(a.title)."
                }
                return nil
            },
            // Controversy/debate
            { a in
                let words = a.title.lowercased()
                if words.contains("against") || words.contains("ban") || words.contains("lawsuit") || words.contains("controversy") {
                    return "Now this is spicy. \(a.title)."
                }
                return nil
            },
            // Big company news
            { a in
                let bigCos = ["google", "apple", "microsoft", "amazon", "meta", "openai", "nvidia"]
                if bigCos.contains(where: { a.title.lowercased().contains($0) }) {
                    return "Here's a big one. \(a.title)."
                }
                return nil
            },
            // Technical deep-dive
            { a in
                let words = a.title.lowercased()
                if words.contains("how") || words.contains("why") || words.contains("deep dive") || words.contains("explained") {
                    return "This next one is really interesting if you want to understand the details. \(a.title)."
                }
                return nil
            },
        ]

        // Try contextual leads first
        for leadFn in leads {
            if let result = leadFn(article) {
                return result
            }
        }

        // Fallback conversational leads
        let fallbacks = [
            "So here's something worth paying attention to. \(title).",
            "Alright, this next one caught my eye. \(title).",
            "Now I found this really fascinating. \(title).",
            "This is one you'll want to know about. \(title).",
            "Let's talk about this. \(title).",
            "Here's an interesting one. \(title).",
            "You might have seen this already, but it's worth digging into. \(title).",
        ]

        return pick(fallbacks, seed: title)
    }

    private static func reframeSummary(_ summary: String, title: String) -> String {
        let clean = String(summary.prefix(280)).trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "" }

        let framings = [
            "Basically, \(clean)",
            "The gist of it is, \(clean)",
            "What's happening here is, \(clean)",
            "So the story is, \(clean)",
        ]

        return pick(framings, seed: title)
    }

    private static func colorCommentary(_ article: Article) -> String {
        let lower = article.title.lowercased()

        // AI stories
        if lower.contains("ai") || lower.contains("llm") || lower.contains("gpt") || lower.contains("model") {
            return pick([
                "And this really speaks to how fast the AI landscape is moving right now.",
                "It feels like every week there's a new development that shifts the whole conversation.",
                "This is the kind of thing that would have been science fiction five years ago.",
                "The pace of change here is honestly hard to keep up with.",
            ], seed: article.title)
        }

        // Security stories
        if lower.contains("security") || lower.contains("breach") || lower.contains("hack") || lower.contains("vulnerability") {
            return pick([
                "And this is a good reminder that security is everyone's problem, not just the security team's.",
                "The implications here go way beyond just the technical details.",
                "It's one of those stories that makes you want to go check your own systems.",
            ], seed: article.title)
        }

        // Startup/funding stories
        if lower.contains("funding") || lower.contains("raise") || lower.contains("startup") || lower.contains("valuation") {
            return pick([
                "The funding environment right now is really telling about where investors think the future is heading.",
                "It says a lot about market confidence in this space.",
                "Interesting to see where the smart money is flowing.",
            ], seed: article.title)
        }

        // Open source
        if lower.contains("open source") || lower.contains("github") || lower.contains("open-source") {
            return pick([
                "And this is why the open source community continues to be such a powerful force in tech.",
                "It's a great example of what happens when you build in the open.",
            ], seed: article.title)
        }

        // Apple
        if lower.contains("apple") || lower.contains("iphone") || lower.contains("mac") || lower.contains("swift") {
            return pick([
                "Apple always manages to make these things feel like a big deal, and honestly, this kind of is.",
                "It'll be interesting to see how the developer community responds to this one.",
            ], seed: article.title)
        }

        // Generic but still insightful
        return pick([
            "There's a bigger trend here that's worth watching.",
            "I think the implications of this go further than people realize.",
            "This is one of those stories where the details really matter.",
            "It's the kind of development that could quietly reshape how we think about this space.",
            "",  // Sometimes no commentary is fine
            "",
        ], seed: article.title)
    }

    private static func reaction(_ article: Article) -> String {
        let reactions = [
            "Definitely one to keep an eye on.",
            "Really curious to see where this goes.",
            "That's going to be worth following.",
            "I'll be watching this closely.",
            "Fascinating stuff.",
            "Pretty compelling when you think about it.",
        ]
        return pick(reactions, seed: article.url)
    }

    // MARK: - Segment Transitions

    private static func segmentTransition(_ theme: String?, index: Int, total: Int) -> String {
        if index == 0 && theme == nil { return "" }

        guard let theme = theme else {
            if index > 0 {
                return pick([
                    "Alright, switching gears a bit.",
                    "Now, a few other stories that caught our attention.",
                    "Before we wrap up, a few more worth mentioning.",
                ])
            }
            return ""
        }

        let lower = theme.lowercased()

        if lower.contains("ai") || lower.contains("machine learning") {
            return pick([
                "Okay, let's talk AI. And honestly, there is a lot happening here.",
                "Now, turning to artificial intelligence, which continues to just dominate the conversation.",
                "Let's get into the AI news, because there's some really interesting stuff.",
            ])
        }
        if lower.contains("security") || lower.contains("cyber") {
            return pick([
                "Alright, let's shift to security, because there are some things you need to know about.",
                "On the cybersecurity front, and this is important.",
            ])
        }
        if lower.contains("apple") || lower.contains("mac") {
            return pick([
                "Now, for the Apple fans out there, and I know there are a lot of you.",
                "Let's talk about what's happening in the Apple world.",
            ])
        }
        if lower.contains("startup") || lower.contains("vc") {
            return pick([
                "Okay, let's look at what's happening in the startup world.",
                "Turning to startups and venture capital, where it's been an interesting week.",
            ])
        }
        if lower.contains("developer") || lower.contains("tool") {
            return pick([
                "For the developers listening, this section is for you.",
                "Let's get into some developer news.",
            ])
        }

        return "Now, moving to \(theme)."
    }

    private static func segmentInsight(_ segment: (theme: String?, articles: [Article])) -> String {
        guard let theme = segment.theme else { return "" }
        let count = segment.articles.count
        let lower = theme.lowercased()

        if lower.contains("ai") {
            return "So yeah, \(count) stories just on AI alone. That tells you something about where things are heading."
        }
        if lower.contains("security") {
            return "The security space just never slows down. Always something to stay on top of."
        }

        return "That's \(count) stories in \(theme), and honestly, each one deserves a deeper look."
    }

    // MARK: - Sign-off

    private static func podcastSignOff(articleCount: Int) -> String {
        let signoffs = [
            "And that's your overview for today. \(articleCount) stories, and honestly, any one of them could be its own deep dive. If something caught your ear, tap in and read the full piece. Thanks for listening, and we'll catch you next time.",
            "Alright, that is a wrap on today's briefing. We covered a lot of ground, \(articleCount) stories across the tech landscape. If you found this useful, come back tomorrow. We'll have more. Take care.",
            "And that does it for today. \(articleCount) stories, all curated just for you. Remember, the best way to stay ahead is to stay curious. Until next time.",
        ]
        return pick(signoffs)
    }

    // MARK: - Connectors

    private static let intraConnectors = [
        "And speaking of which.",
        "Related to that.",
        "On a similar note.",
        "Now, staying in this space.",
        "And there's more.",
    ]

    // MARK: - Helpers

    private static func titleToHook(_ title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("ai") || lower.contains("gpt") || lower.contains("llm") {
            return "There's some major AI news you need to hear about."
        }
        if lower.contains("apple") || lower.contains("google") || lower.contains("microsoft") {
            return "Some big moves from the major players."
        }
        if lower.contains("security") || lower.contains("breach") || lower.contains("hack") {
            return "There's a security story you'll want to pay attention to."
        }
        return "There's a lot to unpack."
    }

    /// Deterministic pick using a seed string for variety without randomness
    private static func pick(_ options: [String], seed: String = "") -> String {
        guard !options.isEmpty else { return "" }
        let hash = seed.isEmpty ? Int.random(in: 0..<options.count) : abs(seed.hashValue) % options.count
        return options[hash]
    }

    // MARK: - Segment Model

    struct Segment {
        let theme: String?
        let articles: [Article]
    }

    private static func buildSegments(_ articles: [Article]) -> [Segment] {
        var themed: [String: [Article]] = [:]
        var unthemed: [Article] = []

        for article in articles {
            if let topic = article.topicName {
                themed[topic, default: []].append(article)
            } else {
                unthemed.append(article)
            }
        }

        var result: [Segment] = []
        for (topic, group) in themed.sorted(by: { $0.value.count > $1.value.count }) {
            result.append(Segment(theme: topic, articles: group))
        }
        if !unthemed.isEmpty {
            result.append(Segment(theme: nil, articles: unthemed))
        }
        return result
    }

    // MARK: - Markdown Report

    static func generateReport(articles: [Article]) -> String {
        var lines: [String] = []
        let dateStr = Date().formatted(date: .complete, time: .omitted)

        lines.append("# NewsDigest Briefing")
        lines.append("### \(dateStr)")
        lines.append("")
        lines.append("*\(articles.count) curated stories from across the tech landscape*")
        lines.append("")
        lines.append("---")
        lines.append("")

        let segments = buildSegments(articles)

        for segment in segments {
            if let theme = segment.theme {
                lines.append("## \(theme)")
            } else if segments.count > 1 {
                lines.append("## Also Noteworthy")
            }
            lines.append("")

            for article in segment.articles {
                lines.append("### \(article.title)")
                lines.append("")
                lines.append("**\(article.sourceName)**")

                var meta: [String] = []
                if let pub = article.publishedAt {
                    meta.append(pub.formatted(.relative(presentation: .named)))
                }
                if !meta.isEmpty { lines.append(meta.joined(separator: " · ")) }

                if let summary = article.summary, !summary.isEmpty {
                    lines.append("")
                    lines.append("> \(String(summary.prefix(400)))")
                }

                lines.append("")
                lines.append("[\(article.url)](\(article.url))")
                lines.append("")
            }

            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
