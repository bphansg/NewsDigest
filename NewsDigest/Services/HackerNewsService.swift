import Foundation

/// Fetches top stories from the Hacker News Firebase API.
actor HackerNewsService {
    private let topStoriesURL = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
    private let itemBaseURL = "https://hacker-news.firebaseio.com/v0/item"

    struct HNItem: Decodable {
        let id: Int
        let title: String?
        let url: String?
        let score: Int?
        let descendants: Int?
        let time: Int?
        let type: String?
    }

    /// Fetch up to `count` top stories from HN, with bounded concurrency.
    func fetchTopStories(count: Int = 60) async throws -> [HNItem] {
        let (data, _) = try await URLSession.shared.data(from: topStoriesURL)
        let allIDs = try JSONDecoder().decode([Int].self, from: data)
        let topIDs = Array(allIDs.prefix(count))

        // Limit concurrency to 10 parallel requests to avoid overwhelming the network
        return await withTaskGroup(of: HNItem?.self, returning: [HNItem].self) { group in
            var items: [HNItem] = []
            var index = 0
            let maxConcurrent = 10

            // Seed initial batch
            for _ in 0..<min(maxConcurrent, topIDs.count) {
                let id = topIDs[index]
                index += 1
                group.addTask { await self.fetchItem(id: id) }
            }

            // As each completes, start the next
            for await item in group {
                if let item = item {
                    items.append(item)
                }
                if index < topIDs.count {
                    let id = topIDs[index]
                    index += 1
                    group.addTask { await self.fetchItem(id: id) }
                }
            }
            return items
        }
    }

    private func fetchItem(id: Int) async -> HNItem? {
        guard let url = URL(string: "\(itemBaseURL)/\(id).json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(HNItem.self, from: data)
        } catch {
            return nil
        }
    }
}
