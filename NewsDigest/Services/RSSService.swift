import Foundation

/// A lightweight RSS/Atom feed parser that works without external dependencies.
actor RSSService {

    struct FeedSource {
        let name: String
        let url: String
        let type: ArticleSource
    }

    /// Curated list of high-quality tech news feeds.
    static let defaultFeeds: [FeedSource] = [
        // Major tech publications
        FeedSource(name: "TechCrunch", url: "https://techcrunch.com/feed/", type: .rss),
        FeedSource(name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index", type: .rss),
        FeedSource(name: "The Verge", url: "https://www.theverge.com/rss/index.xml", type: .rss),
        FeedSource(name: "MIT Tech Review", url: "https://www.technologyreview.com/feed/", type: .rss),
        FeedSource(name: "Wired", url: "https://www.wired.com/feed/rss", type: .rss),

        // Newsletters / Substack
        FeedSource(name: "Stratechery", url: "https://stratechery.com/feed/", type: .substack),
        FeedSource(name: "Simon Willison", url: "https://simonwillison.net/atom/everything/", type: .substack),
        FeedSource(name: "Astral Codex Ten", url: "https://www.astralcodexten.com/feed", type: .substack),
        FeedSource(name: "Lenny's Newsletter", url: "https://www.lennysnewsletter.com/feed", type: .substack),
        FeedSource(name: "The Pragmatic Engineer", url: "https://newsletter.pragmaticengineer.com/feed", type: .substack),
    ]

    struct FeedItem {
        let title: String
        let link: String
        let description: String?
        let pubDate: Date?
        let sourceName: String
        let sourceType: ArticleSource
    }

    /// Parse all configured feeds and return items.
    func fetchAllFeeds(feeds: [FeedSource]? = nil) async -> [FeedItem] {
        let sources = feeds ?? Self.defaultFeeds
        return await withTaskGroup(of: [FeedItem].self, returning: [FeedItem].self) { group in
            for source in sources {
                group.addTask {
                    await self.parseFeed(source: source)
                }
            }
            var allItems: [FeedItem] = []
            for await items in group {
                allItems.append(contentsOf: items)
            }
            return allItems
        }
    }

    /// Maximum feed response size: 5 MB
    private static let maxResponseSize = 5 * 1024 * 1024

    private func parseFeed(source: FeedSource) async -> [FeedItem] {
        guard let url = URL(string: source.url) else { return [] }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            // Validate response
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return []
            }
            guard data.count <= Self.maxResponseSize else { return [] }
            guard let xmlString = String(data: data, encoding: .utf8) else { return [] }
            return parseXML(xmlString, source: source)
        } catch {
            return []
        }
    }

    /// Minimal XML parser for RSS <item> and Atom <entry> elements.
    private func parseXML(_ xml: String, source: FeedSource) -> [FeedItem] {
        var items: [FeedItem] = []

        // Determine if Atom or RSS
        let isAtom = xml.contains("<feed") && xml.contains("xmlns=\"http://www.w3.org/2005/Atom\"")

        if isAtom {
            items = parseAtomEntries(xml, source: source)
        } else {
            items = parseRSSItems(xml, source: source)
        }

        return Array(items.prefix(15))
    }

    private func parseRSSItems(_ xml: String, source: FeedSource) -> [FeedItem] {
        var items: [FeedItem] = []
        let itemBlocks = xml.components(separatedBy: "<item")
        for (index, block) in itemBlocks.enumerated() {
            if index == 0 { continue } // Skip preamble
            let title = extractTag("title", from: block)
            let link = extractTag("link", from: block)
            let description = extractTag("description", from: block)
            let pubDateStr = extractTag("pubDate", from: block)
            let pubDate = parseDate(pubDateStr)

            if let title = title, let link = link, !title.isEmpty, !link.isEmpty {
                items.append(FeedItem(
                    title: cleanHTML(title),
                    link: link.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.map { cleanHTML($0) },
                    pubDate: pubDate,
                    sourceName: source.name,
                    sourceType: source.type
                ))
            }
        }
        return items
    }

    private func parseAtomEntries(_ xml: String, source: FeedSource) -> [FeedItem] {
        var items: [FeedItem] = []
        let entryBlocks = xml.components(separatedBy: "<entry")
        for (index, block) in entryBlocks.enumerated() {
            if index == 0 { continue }
            let title = extractTag("title", from: block)

            // Atom links are in <link href="..." /> format
            var link: String? = nil
            if let range = block.range(of: #"<link[^>]*href="([^"]+)"#, options: .regularExpression) {
                let match = String(block[range])
                if let hrefRange = match.range(of: #"href="([^"]+)"#, options: .regularExpression) {
                    let hrefStr = String(match[hrefRange])
                    link = String(hrefStr.dropFirst(6).dropLast(1))
                }
            }

            let summary = extractTag("summary", from: block) ?? extractTag("content", from: block)
            let updatedStr = extractTag("updated", from: block) ?? extractTag("published", from: block)
            let pubDate = parseDate(updatedStr)

            if let title = title, let link = link, !title.isEmpty, !link.isEmpty {
                items.append(FeedItem(
                    title: cleanHTML(title),
                    link: link.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: summary.map { cleanHTML(String($0.prefix(300))) },
                    pubDate: pubDate,
                    sourceName: source.name,
                    sourceType: source.type
                ))
            }
        }
        return items
    }

    // Cache compiled regexes per tag name (instance-level, actor-isolated)
    private var cdataRegexCache = [String: NSRegularExpression]()
    private var tagRegexCache = [String: NSRegularExpression]()

    private func extractTag(_ tag: String, from block: String) -> String? {
        let nsRange = NSRange(block.startIndex..., in: block)

        // Handle CDATA: <tag><![CDATA[content]]></tag>
        let cdataRegex: NSRegularExpression
        if let cached = cdataRegexCache[tag] {
            cdataRegex = cached
        } else if let compiled = try? NSRegularExpression(
            pattern: "<\(tag)[^>]*>\\s*<!\\[CDATA\\[(.+?)\\]\\]>\\s*</\(tag)>",
            options: .dotMatchesLineSeparators
        ) {
            cdataRegexCache[tag] = compiled
            cdataRegex = compiled
        } else {
            cdataRegex = NSRegularExpression()
        }

        if let result = cdataRegex.firstMatch(in: block, range: nsRange),
           result.numberOfRanges > 1,
           let captureRange = Range(result.range(at: 1), in: block) {
            return String(block[captureRange])
        }

        // Standard tag
        let tagRegex: NSRegularExpression
        if let cached = tagRegexCache[tag] {
            tagRegex = cached
        } else if let compiled = try? NSRegularExpression(
            pattern: "<\(tag)[^>]*>(.+?)</\(tag)>",
            options: .dotMatchesLineSeparators
        ) {
            tagRegexCache[tag] = compiled
            tagRegex = compiled
        } else {
            tagRegex = NSRegularExpression()
        }

        if let result = tagRegex.firstMatch(in: block, range: nsRange),
           result.numberOfRanges > 1,
           let captureRange = Range(result.range(at: 1), in: block) {
            return String(block[captureRange])
        }
        return nil
    }

    private static let htmlTagRegex = try! NSRegularExpression(pattern: "<[^>]+>")

    private static let entityReplacements: [(String, String)] = [
        ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
        ("&#39;", "'"), ("&apos;", "'"), ("&#8217;", "'"),
        ("&#8220;", "\""), ("&#8221;", "\""),
    ]

    private func cleanHTML(_ str: String) -> String {
        let nsRange = NSRange(str.startIndex..., in: str)
        var result = Self.htmlTagRegex.stringByReplacingMatches(in: str, range: nsRange, withTemplate: "")
        for (entity, replacement) in Self.entityReplacements {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Static cached formatters — created once, reused across all parses
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func parseDate(_ str: String?) -> Date? {
        guard let str = str?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return nil }
        for formatter in Self.dateFormatters {
            if let date = formatter.date(from: str) {
                return date
            }
        }
        return Self.isoFormatter.date(from: str)
    }
}
