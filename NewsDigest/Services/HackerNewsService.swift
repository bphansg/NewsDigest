import Foundation

/// Fetches top stories from the Hacker News Firebase API.
actor HackerNewsService {
    private let topStoriesURL = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
    private let itemBaseURL = "https://hacker-news.firebaseio.com/v0/item"
    private let requestTimeout: TimeInterval = 15

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
        var request = URLRequest(url: topStoriesURL)
        request.timeoutInterval = requestTimeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        let allIDs = try JSONDecoder().decode([Int].self, from: data)
        let topIDs = Array(allIDs.prefix(count))

        return await withTaskGroup(of: HNItem?.self, returning: [HNItem].self) { group in
            var items: [HNItem] = []
            var index = 0
            let maxConcurrent = 10

            for _ in 0..<min(maxConcurrent, topIDs.count) {
                let id = topIDs[index]
                index += 1
                group.addTask { await self.fetchItem(id: id) }
            }

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
            var request = URLRequest(url: url)
            request.timeoutInterval = requestTimeout
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(HNItem.self, from: data)
        } catch {
            return nil
        }
    }
}
