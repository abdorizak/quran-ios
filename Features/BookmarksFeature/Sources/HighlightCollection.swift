import Foundation
import MobileSync
import QuranAnnotations

struct HighlightBookmarkSnapshot: Equatable, Hashable, Sendable {
    let sura: Int
    let ayah: Int
    let modifiedDate: Date
}

struct HighlightCollectionSnapshot: Equatable, Sendable {
    let name: String
    let bookmarks: [HighlightBookmarkSnapshot]
}

enum HighlightCollection: Int, CaseIterable, Identifiable, Sendable {
    case red
    case green
    case blue
    case yellow
    case purple

    // MARK: Internal

    var id: Int { rawValue }

    var color: QuranAnnotations.Note.Color {
        switch self {
        case .red: .red
        case .green: .green
        case .blue: .blue
        case .yellow: .yellow
        case .purple: .purple
        }
    }

    var localizationKey: String {
        switch self {
        case .red: "highlights.color.red"
        case .green: "highlights.color.green"
        case .blue: "highlights.color.blue"
        case .yellow: "highlights.color.yellow"
        case .purple: "highlights.color.purple"
        }
    }

    static func count(in collections: [HighlightCollectionSnapshot]) -> Int {
        allCases.reduce(0) { $0 + $1.count(in: collections) }
    }

    static func updates(from syncService: SyncService) -> AsyncThrowingStream<[HighlightCollectionSnapshot], Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    for try await collections in syncService.collectionsWithBookmarksSequence() {
                        continuation.yield(collections.map(snapshot(from:)))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func collection(for name: String) -> HighlightCollection? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first { $0.collectionNames.contains(normalizedName) }
    }

    func count(in collections: [HighlightCollectionSnapshot]) -> Int {
        bookmarks(in: collections).count
    }

    func bookmarks(in collections: [HighlightCollectionSnapshot]) -> [HighlightBookmarkSnapshot] {
        collections
            .filter { Self.collection(for: $0.name) == self }
            .flatMap(\.bookmarks)
            .sorted { $0.modifiedDate > $1.modifiedDate }
    }

    // MARK: Private

    private var collectionNames: Set<String> {
        let baseName = rawName
        return [baseName, "ios-\(baseName)", "ios_\(baseName)"]
    }

    private var rawName: String {
        switch self {
        case .red: "red"
        case .green: "green"
        case .blue: "blue"
        case .yellow: "yellow"
        case .purple: "purple"
        }
    }

    private static func snapshot(from collection: CollectionWithBookmarks) -> HighlightCollectionSnapshot {
        HighlightCollectionSnapshot(
            name: collection.collection.name,
            bookmarks: collection.bookmarks.compactMap(snapshot(from:))
        )
    }

    private static func snapshot(from bookmark: CollectionBookmark) -> HighlightBookmarkSnapshot? {
        guard let bookmark = bookmark as? CollectionBookmark.AyahBookmark else {
            return nil
        }

        return HighlightBookmarkSnapshot(
            sura: Int(bookmark.sura),
            ayah: Int(bookmark.ayah),
            modifiedDate: bookmark.lastUpdated
        )
    }
}
