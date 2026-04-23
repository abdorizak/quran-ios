//
//  BookmarkCollectionService.swift
//
//
//  Created by Ahmed Nabil on 2026-04-22.
//

import Foundation
import MobileSync

#if QURAN_SYNC

    public struct BookmarkCollectionService {
        // MARK: Lifecycle

        public init(syncService: SyncService) {
            self.syncService = syncService
        }

        // MARK: Public

        public func collectionsSequence() -> AsyncStream<[CollectionWithBookmarks]> {
            AsyncStream { continuation in
                let task = Task {
                    do {
                        for try await collections in syncService.collectionsWithBookmarksSequence() {
                            continuation.yield(collections)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        public func createCollection(named name: String) async throws {
            try await syncService.createCollection(named: name)
        }

        public func addBookmark(sura: Int, ayah: Int, toCollectionLocalId localId: String) async throws {
            let bookmark = try await syncService.addAyahBookmark(sura: Int32(sura), ayah: Int32(ayah))
            try await syncService.addBookmarkToCollection(collectionLocalId: localId, bookmark: bookmark)
        }

        public func removeBookmark(sura: Int, ayah: Int, fromCollectionLocalId localId: String) async throws {
            let collections = try await snapshot()
            guard let collection = collections.first(where: { $0.collection.localId == localId }) else {
                return
            }

            for case let bookmark as CollectionBookmark.AyahBookmark in collection.bookmarks
                where Int(bookmark.sura) == sura && Int(bookmark.ayah) == ayah
            {
                try await syncService.removeBookmarkFromCollection(
                    collectionLocalId: localId,
                    bookmark: bookmark.bookmark
                )
            }
        }

        public func snapshot() async throws -> [CollectionWithBookmarks] {
            for try await collections in syncService.collectionsWithBookmarksSequence() {
                return collections
            }
            throw BookmarkCollectionError.collectionsUnavailable
        }

        // MARK: Private

        private let syncService: SyncService

        private enum BookmarkCollectionError: Error {
            case collectionsUnavailable
        }
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

#endif
