import Foundation
import SwiftData

enum DigestStatus: String, Codable {
    case draft
    case ready
    case narrating
    case narrated
}

@Model
final class Digest {
    var id: UUID
    var title: String
    var createdAt: Date
    var articleIDs: [UUID]
    var audioScript: String?
    var audioFilePath: String?
    var status: DigestStatus

    init(title: String, articleIDs: [UUID], audioScript: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.articleIDs = articleIDs
        self.audioScript = audioScript
        self.audioFilePath = nil
        self.status = .draft
    }
}
