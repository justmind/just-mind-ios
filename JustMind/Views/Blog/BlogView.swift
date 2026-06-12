import SwiftUI
import SwiftData

@Observable
final class BlogStore {
    var allTags: [BlogTag] = []
    var posts: [BlogPost] = []
    var visibleChips: [(label: String, ids: [Int])] = [(label: "All", ids: [])]
    var selected: String = "All"
    var page: Int = 1
    var hasMore: Bool = true
    var isLoading: Bool = false
    var lastError: String? = nil

    func chipIDs(for label: String) -> [Int] {
        visibleChips.first { $0.label == label }?.ids ?? []
    }
}

struct BlogView: View {
    @Environment(\.modelContext) private var context
    @State private var store = BlogStore()
    @State private var safariItem: SafariSheetItem?

    @Query(sort: \CachedPost.publishedAt, order: .reverse) private var cached: [CachedPost]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                contentScroll
                NewsletterCard()
            }
            .background(JMColor.background.ignoresSafeArea())
            .navigationTitle("Blog")
            .navigationBarTitleDisplayMode(.inline)
            .task { await initialLoad() }
            .refreshable { await refresh() }
            .sheet(item: $safariItem) { SafariView(url: $0.url) }
        }
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(spacing: JMSpacing.l) {
                chipsRow

                if store.posts.isEmpty {
                    if store.isLoading {
                        ProgressView().padding(.top, 60)
                    } else if store.lastError != nil && cached.isEmpty {
                        EmptyStateCard(
                            icon: "wifi.slash",
                            text: "Couldn't load articles right now. Check your connection and pull to refresh."
                        )
                        .padding(.horizontal, JMSpacing.l)
                    } else {
                        EmptyStateCard(
                            icon: "magnifyingglass",
                            text: "No articles found for this topic. Try a different category."
                        )
                        .padding(.horizontal, JMSpacing.l)
                    }
                } else {
                    LazyVStack(spacing: JMSpacing.m) {
                        ForEach(store.posts) { post in
                            BlogCard(post: post) {
                                if let url = URL(string: post.url) {
                                    safariItem = SafariSheetItem(url: url)
                                }
                            }
                            .onAppear {
                                if post.id == store.posts.last?.id, store.hasMore, !store.isLoading {
                                    Task { await loadMore() }
                                }
                            }
                        }
                        if store.isLoading && !store.posts.isEmpty {
                            ProgressView().padding()
                        }
                    }
                    .padding(.horizontal, JMSpacing.l)
                }
            }
            .padding(.bottom, 140) // breathing room above sticky newsletter card
            .padding(.top, JMSpacing.s)
        }
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.visibleChips, id: \.label) { chip in
                    let isSelected = store.selected == chip.label
                    Button {
                        store.selected = chip.label
                        Task { await applyFilter() }
                    } label: {
                        Text(chip.label)
                            .font(JMFont.callout)
                            .foregroundStyle(isSelected ? .white : JMColor.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? JMColor.primary : JMColor.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(JMColor.divider, lineWidth: isSelected ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, JMSpacing.l)
        }
    }

    // MARK: Loading

    private func initialLoad() async {
        // Hydrate from cache immediately if posts list is empty
        if store.posts.isEmpty, !cached.isEmpty {
            store.posts = cached.map {
                BlogPost(
                    id: $0.id,
                    title: $0.title,
                    excerpt: $0.excerpt,
                    url: $0.url,
                    imageURL: $0.imageURL,
                    author: $0.author,
                    publishedAt: $0.publishedAt,
                    tagIDs: $0.tagIDs
                )
            }
        }
        await loadTagsAndChips()
        await refresh()
    }

    private func loadTagsAndChips() async {
        do {
            let tags = try await BlogService.shared.fetchTags()
            store.allTags = tags
            var chips: [(String, [Int])] = [("All", [])]
            for entry in BlogService.curatedTagSlugs {
                let ids = entry.slugs.compactMap { slug in
                    tags.first(where: { $0.slug == slug })?.id
                }
                let totalCount = entry.slugs.reduce(0) { acc, slug in
                    acc + (tags.first(where: { $0.slug == slug })?.count ?? 0)
                }
                if !ids.isEmpty, totalCount > 0 {
                    chips.append((entry.label, ids))
                }
            }
            store.visibleChips = chips
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    private func refresh() async {
        store.page = 1
        store.hasMore = true
        store.isLoading = true
        defer { store.isLoading = false }
        let ids = store.chipIDs(for: store.selected)
        do {
            let posts = try await BlogService.shared.fetchPosts(tagIDs: ids, page: 1)
            store.posts = posts
            store.hasMore = posts.count >= 20
            store.lastError = nil
            persist(posts)
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    private func applyFilter() async {
        await refresh()
    }

    private func loadMore() async {
        guard !store.isLoading, store.hasMore else { return }
        store.isLoading = true
        defer { store.isLoading = false }
        let nextPage = store.page + 1
        let ids = store.chipIDs(for: store.selected)
        do {
            let more = try await BlogService.shared.fetchPosts(tagIDs: ids, page: nextPage)
            if more.isEmpty {
                store.hasMore = false
            } else {
                let existing = Set(store.posts.map(\.id))
                let deduped = more.filter { !existing.contains($0.id) }
                store.posts.append(contentsOf: deduped)
                store.page = nextPage
                store.hasMore = more.count >= 20
            }
        } catch {
            store.hasMore = false
        }
    }

    /// Cache only public, non-sensitive fields. No user data is involved here.
    private func persist(_ posts: [BlogPost]) {
        // Replace cache with the latest "All" page (only when filter is All).
        guard store.selected == "All" else { return }
        do {
            try context.delete(model: CachedPost.self)
            for p in posts {
                let row = CachedPost(
                    id: p.id, title: p.title, excerpt: p.excerpt, url: p.url,
                    imageURL: p.imageURL, author: p.author, publishedAt: p.publishedAt,
                    tagIDs: p.tagIDs
                )
                context.insert(row)
            }
            try context.save()
        } catch {
            // Cache failures are non-fatal.
        }
    }
}

private struct BlogCard: View {
    let post: BlogPost
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if let urlStr = post.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .empty:
                            Rectangle().fill(JMColor.divider)
                                .overlay(ProgressView())
                        case .failure:
                            Rectangle().fill(JMColor.divider)
                        @unknown default:
                            Rectangle().fill(JMColor.divider)
                        }
                    }
                    .frame(height: 180)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: JMSpacing.s) {
                    Text(post.title)
                        .font(JMFont.blogTitle) // 20/700, clear step above byline
                        .foregroundStyle(JMColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    HStack(spacing: 6) {
                        Text(post.author)
                        Text("·")
                        Text(formatted(post.publishedAt))
                    }
                    .font(JMFont.footnote) // 13pt
                    .foregroundStyle(JMColor.textSecondary)

                    if !post.excerpt.isEmpty {
                        Text(post.excerpt)
                            .font(JMFont.body)
                            .foregroundStyle(JMColor.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, JMSpacing.l)
                .padding(.vertical, JMSpacing.cardV) // 20pt min
            }
            .background(JMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                    .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: d)
    }
}
