import Foundation
import SwiftData

@Model
final class Topic {
    var id: UUID
    var name: String
    var keywords: [String]
    var enabled: Bool
    var createdAt: Date

    init(name: String, keywords: [String], enabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.keywords = keywords
        self.enabled = enabled
        self.createdAt = Date()
    }
}
