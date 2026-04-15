//
//  AppDependencies.swift
//
//
//  Created by Mohamed Afifi on 2023-06-18.
//

import Analytics
import AnnotationsService
import AuthenticationClient
import BatchDownloader
import Foundation
import LastPagePersistence
import MobileSync
import NotePersistence
import PageBookmarkPersistence
import QuranAnnotations
import QuranKit
import QuranResources
import QuranTextKit
import ReadingService

public protocol AppDependencies {
    var databasesURL: URL { get }
    var quranUthmaniV2Database: URL { get }
    var wordsDatabase: URL { get }
    var appHost: URL { get }
    var filesAppHost: URL { get }
    var quranProfileURL: URL { get }
    var logsDirectory: URL { get }
    var databasesDirectory: URL { get }

    var supportsCloudKit: Bool { get }

    var downloadManager: DownloadManager { get }
    var analytics: AnalyticsLibrary { get }
    var readingResources: ReadingResourcesService { get }
    var remoteResources: ReadingRemoteResources? { get }

    var lastPagePersistence: LastPagePersistence { get }
    var notePersistence: NotePersistence { get }
    var pageBookmarkPersistence: PageBookmarkPersistence { get }
    var syncService: SyncService? { get }

    var authenticationClient: (any AuthenticationClient)? { get }
}

extension AppDependencies {
    public var quranUthmaniV2Database: URL { QuranResources.quranUthmaniV2Database }

    public func textDataService() -> QuranTextDataService {
        QuranTextDataService(
            databasesURL: databasesURL,
            quranFileURL: quranUthmaniV2Database
        )
    }

    public func noteService() -> NoteService {
        let syncHighlights: NoteService.SyncHighlights? = syncService.map { syncService in
            let closure: NoteService.SyncHighlights = { verses, color in
                try await syncService.setHighlights(verses: verses, color: color)
            }
            return closure
        }
        let removeSyncedHighlights: NoteService.RemoveSyncedHighlights? = syncService.map { syncService in
            let closure: NoteService.RemoveSyncedHighlights = { verses in
                try await syncService.removeHighlights(verses: verses)
            }
            return closure
        }
        return NoteService(
            persistence: notePersistence,
            textService: textDataService(),
            analytics: analytics,
            syncHighlights: syncHighlights,
            removeSyncedHighlights: removeSyncedHighlights
        )
    }
}

private extension SyncService {
    func setHighlights(verses: [AyahNumber], color: QuranAnnotations.Note.Color) async throws {
        guard !verses.isEmpty else {
            return
        }

        let targetCollection = try await ensureHighlightCollection(for: color)
        let collections = try await collectionsSnapshot()
        let otherHighlightCollections = collections
            .filter { QuranAnnotations.Note.Color.highlightColor(forCollectionName: $0.collection.name) != nil }
            .filter { $0.collection.localId != targetCollection.collection.localId }

        try await removeBookmarks(for: verses, from: otherHighlightCollections)

        let existingBookmarks = Set(
            targetCollection.bookmarks
                .compactMap { $0 as? CollectionBookmark.AyahBookmark }
                .map(VerseIdentity.init)
        )

        for verse in verses where !existingBookmarks.contains(VerseIdentity(verse)) {
            let bookmark = try await addAyahBookmark(
                sura: Int32(verse.sura.suraNumber),
                ayah: Int32(verse.ayah)
            )
            try await addBookmarkToCollection(
                collectionLocalId: targetCollection.collection.localId,
                bookmark: bookmark
            )
        }
    }

    func removeHighlights(verses: [AyahNumber]) async throws {
        guard !verses.isEmpty else {
            return
        }

        let collections = try await collectionsSnapshot()
            .filter { QuranAnnotations.Note.Color.highlightColor(forCollectionName: $0.collection.name) != nil }
        try await removeBookmarks(for: verses, from: collections)
    }

    private func ensureHighlightCollection(for color: QuranAnnotations.Note.Color) async throws -> CollectionWithBookmarks {
        if let existing = try await findHighlightCollection(for: color) {
            return existing
        }

        try await createCollection(named: color.highlightCollectionName)

        for _ in 0 ..< 5 {
            if let created = try await findHighlightCollection(for: color) {
                return created
            }
            await Task.yield()
        }

        throw SyncHighlightsError.collectionUnavailable(color)
    }

    private func findHighlightCollection(for color: QuranAnnotations.Note.Color) async throws -> CollectionWithBookmarks? {
        try await collectionsSnapshot().first { color.matches(collectionName: $0.collection.name) }
    }

    private func collectionsSnapshot() async throws -> [CollectionWithBookmarks] {
        for try await collections in collectionsWithBookmarksSequence() {
            return collections
        }
        throw SyncHighlightsError.collectionsUnavailable
    }

    private func removeBookmarks(
        for verses: [AyahNumber],
        from collections: [CollectionWithBookmarks]
    ) async throws {
        let targetVerses = Set(verses.map(VerseIdentity.init))
        for collection in collections {
            for case let bookmark as CollectionBookmark.AyahBookmark in collection.bookmarks
                where targetVerses.contains(VerseIdentity(bookmark))
            {
                try await removeBookmarkFromCollection(
                    collectionLocalId: collection.collection.localId,
                    bookmark: bookmark.bookmark
                )
            }
        }
    }
}

private struct VerseIdentity: Hashable {
    init(_ verse: AyahNumber) {
        sura = verse.sura.suraNumber
        ayah = verse.ayah
    }

    init(_ bookmark: CollectionBookmark.AyahBookmark) {
        sura = Int(bookmark.sura)
        ayah = Int(bookmark.ayah)
    }

    let sura: Int
    let ayah: Int
}

private enum SyncHighlightsError: Error {
    case collectionsUnavailable
    case collectionUnavailable(QuranAnnotations.Note.Color)
}

private extension CollectionBookmark.AyahBookmark {
    var bookmark: Bookmark.AyahBookmark {
        Bookmark.AyahBookmark(
            sura: sura,
            ayah: ayah,
            lastUpdated: lastUpdated,
            localId: bookmarkLocalId
        )
    }
}

private extension QuranAnnotations.Note.Color {
    static var highlightColors: [Self] {
        [.red, .green, .blue, .yellow, .purple]
    }

    static func highlightColor(forCollectionName name: String) -> Self? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return highlightColors.first { $0.collectionNames.contains(normalizedName) }
    }

    var highlightCollectionName: String {
        switch self {
        case .red: "red"
        case .green: "green"
        case .blue: "blue"
        case .yellow: "yellow"
        case .purple: "purple"
        }
    }

    func matches(collectionName name: String) -> Bool {
        collectionNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private var collectionNames: Set<String> {
        let baseName = highlightCollectionName
        return [baseName, "ios-\(baseName)", "ios_\(baseName)"]
    }
}
