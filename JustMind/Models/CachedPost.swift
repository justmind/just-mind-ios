import Foundation
import SwiftData

@Model
final class CachedPost {
    @Attribute(.unique) var id: Int
    var title: String
    var excerpt: String
    var url: String
    var imageURL: String?
    var author: String
    var publishedAt: Date
    var tagIDsRaw: String
    var cachedAt: Date

    init(
        id: Int,
        title: String,
        excerpt: String,
        url: String,
        imageURL: String?,
        author: String,
        publishedAt: Date,
        tagIDs: [Int]
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.url = url
        self.imageURL = imageURL
        self.author = author
        self.publishedAt = publishedAt
        self.tagIDsRaw = tagIDs.map(String.init).joined(separator: ",")
        self.cachedAt = .now
    }

    var tagIDs: [Int] {
        tagIDsRaw.isEmpty ? [] : tagIDsRaw.split(separator: ",").compactMap { Int($0) }
    }
}
