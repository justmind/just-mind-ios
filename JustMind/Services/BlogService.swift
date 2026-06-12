import Foundation
import SwiftData

struct BlogTag: Identifiable, Hashable, Codable {
    let id: Int
    let slug: String
    let name: String
    let count: Int
}

struct BlogPost: Identifiable, Hashable {
    let id: Int
    let title: String
    let excerpt: String
    let url: String
    let imageURL: String?
    let author: String
    let publishedAt: Date
    let tagIDs: [Int]
}

enum BlogServiceError: Error, LocalizedError {
    case network(String)
    case decoding(String)
    var errorDescription: String? {
        switch self {
        case .network(let m): return m
        case .decoding(let m): return m
        }
    }
}

actor BlogService {
    static let shared = BlogService()
    private let baseURL = URL(string: "https://justmind.org/wp-json/wp/v2")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Curated topical tags shown as filter chips (mapped to slugs that exist on the site).
    /// WordPress *categories* on justmind.org are minimal (Blog/Events/Uncategorized),
    /// so the topical filter chips below are wired to *tags* instead.
    static let curatedTagSlugs: [(label: String, slugs: [String])] = [
        ("Anxiety",       ["anxiety", "accepting-anxiety", "panic-attacks"]),
        ("Depression",    ["depression"]),
        ("Relationships", ["couples", "marriage", "marriage-counseling", "boundaries"]),
        ("ADHD",          ["adhd"]),
        ("Trauma",        ["trauma", "emdr", "ifs", "internal-family-systems-model"]),
        ("LGBTQ+",        ["lgbt"]),
        ("Parenting",     ["parenting", "child-therapy", "children", "family"]),
        ("Self-Growth",   ["growth", "mindfulness", "mindset", "compassion", "live-in-the-now", "lifestyle"])
    ]

    func fetchTags() async throws -> [BlogTag] {
        var components = URLComponents(url: baseURL.appendingPathComponent("tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "hide_empty", value: "true")
        ]
        let (data, _) = try await fetch(components.url!)
        struct Raw: Decodable { let id: Int; let slug: String; let name: String; let count: Int }
        do {
            let raw = try JSONDecoder().decode([Raw].self, from: data)
            return raw.map { BlogTag(id: $0.id, slug: $0.slug, name: $0.name, count: $0.count) }
        } catch {
            throw BlogServiceError.decoding(error.localizedDescription)
        }
    }

    func fetchPosts(tagIDs: [Int] = [], page: Int = 1, perPage: Int = 20) async throws -> [BlogPost] {
        var components = URLComponents(url: baseURL.appendingPathComponent("posts"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "_embed", value: "1"),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if !tagIDs.isEmpty {
            items.append(URLQueryItem(name: "tags", value: tagIDs.map(String.init).joined(separator: ",")))
        }
        components.queryItems = items
        let (data, _) = try await fetch(components.url!)
        return try Self.decodePosts(data)
    }

    private func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("JustMindiOS/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw BlogServiceError.network("Server returned \(code)")
            }
            return (data, response)
        } catch let e as BlogServiceError {
            throw e
        } catch {
            throw BlogServiceError.network(error.localizedDescription)
        }
    }

    static func decodePosts(_ data: Data) throws -> [BlogPost] {
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw BlogServiceError.decoding("Unexpected payload")
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoNoTZ = ISO8601DateFormatter()
        isoNoTZ.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return arr.map { dict in
            let id = (dict["id"] as? Int) ?? 0
            let title = ((dict["title"] as? [String: Any])?["rendered"] as? String) ?? ""
            let rawExcerpt = ((dict["excerpt"] as? [String: Any])?["rendered"] as? String) ?? ""
            let url = (dict["link"] as? String) ?? "https://justmind.org"
            let dateStr = (dict["date_gmt"] as? String) ?? ""
            let publishedAt = iso.date(from: dateStr + "Z") ?? iso.date(from: dateStr) ?? Date()
            let tagIDs = (dict["tags"] as? [Int]) ?? []

            // Embedded data
            let embedded = dict["_embedded"] as? [String: Any]
            let media = ((embedded?["wp:featuredmedia"] as? [[String: Any]])?.first)
            var imageURL = (media?["source_url"] as? String)
            if imageURL == nil, let details = media?["media_details"] as? [String: Any],
               let sizes = details["sizes"] as? [String: Any],
               let medium = (sizes["medium_large"] as? [String: Any]) ?? (sizes["large"] as? [String: Any]) ?? (sizes["full"] as? [String: Any]),
               let src = medium["source_url"] as? String {
                imageURL = src
            }
            let author = ((embedded?["author"] as? [[String: Any]])?.first?["name"] as? String) ?? "Just Mind"

            return BlogPost(
                id: id,
                title: stripHTML(title).trimmingCharacters(in: .whitespacesAndNewlines),
                excerpt: truncate(stripHTML(rawExcerpt).trimmingCharacters(in: .whitespacesAndNewlines), to: 120),
                url: url,
                imageURL: imageURL,
                author: author,
                publishedAt: publishedAt,
                tagIDs: tagIDs
            )
        }
    }

    static func stripHTML(_ s: String) -> String {
        var out = s
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            out = regex.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        return out
            .replacingOccurrences(of: "&hellip;", with: "…")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#8217;", with: "’")
            .replacingOccurrences(of: "&#8220;", with: "“")
            .replacingOccurrences(of: "&#8221;", with: "”")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    static func truncate(_ s: String, to limit: Int) -> String {
        guard s.count > limit else { return s }
        let idx = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
