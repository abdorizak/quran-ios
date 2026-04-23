//
//  QuranHighlightsSyncService.swift
//
//
//  Created by Ahmed Nabil on 2026-04-22.
//

import Foundation
import MobileSync
import QuranAnnotations
import QuranKit
import ReadingService

#if QURAN_SYNC

    public struct QuranHighlightsSyncService {
        // MARK: Lifecycle

        public init(collectionService: BookmarkCollectionService) {
            self.collectionService = collectionService
        }

        // MARK: Public

        public func setHighlight(verses: [AyahNumber], color: QuranAnnotations.Note.Color) async throws {
            guard !verses.isEmpty else {
                return
            }

            let targetCollection = try await ensureHighlightCollection(for: color)
            let collections = try await collectionService.snapshot()
            let otherHighlightCollections = collections
                .filter { QuranAnnotations.Note.Color.highlightColor(forCollectionName: $0.collection.name) != nil }
                .filter { $0.collection.localId != targetCollection.collection.localId }

            for verse in verses {
                for collection in otherHighlightCollections {
                    try await collectionService.removeBookmark(
                        sura: verse.sura.suraNumber,
                        ayah: verse.ayah,
                        fromCollectionLocalId: collection.collection.localId
                    )
                }
                try await collectionService.addBookmark(
                    sura: verse.sura.suraNumber,
                    ayah: verse.ayah,
                    toCollectionLocalId: targetCollection.collection.localId
                )
            }
        }

        public func removeHighlights(verses: [AyahNumber]) async throws {
            guard !verses.isEmpty else {
                return
            }

            let collections = try await collectionService.snapshot()
                .filter { QuranAnnotations.Note.Color.highlightColor(forCollectionName: $0.collection.name) != nil }

            for verse in verses {
                for collection in collections {
                    try await collectionService.removeBookmark(
                        sura: verse.sura.suraNumber,
                        ayah: verse.ayah,
                        fromCollectionLocalId: collection.collection.localId
                    )
                }
            }
        }

        public func highlightColorsSequence() -> AsyncStream<[AyahNumber: QuranAnnotations.Note.Color]> {
            let quran = ReadingPreferences.shared.reading.quran
            let stream = collectionService.collectionsSequence()

            return AsyncStream { continuation in
                let task = Task {
                    for await collections in stream {
                        var colorByVerse: [AyahNumber: QuranAnnotations.Note.Color] = [:]
                        for collection in collections {
                            guard let color = QuranAnnotations.Note.Color.highlightColor(forCollectionName: collection.collection.name) else {
                                continue
                            }
                            for case let bookmark as CollectionBookmark.AyahBookmark in collection.bookmarks {
                                if let ayah = AyahNumber(quran: quran, sura: Int(bookmark.sura), ayah: Int(bookmark.ayah)) {
                                    colorByVerse[ayah] = color
                                }
                            }
                        }
                        continuation.yield(colorByVerse)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        // MARK: Private

        private enum QuranHighlightsSyncError: Error {
            case collectionUnavailable(QuranAnnotations.Note.Color)
        }

        private let collectionService: BookmarkCollectionService

        private func ensureHighlightCollection(for color: QuranAnnotations.Note.Color) async throws -> CollectionWithBookmarks {
            if let existing = try await findHighlightCollection(for: color) {
                return existing
            }

            try await collectionService.createCollection(named: color.highlightCollectionName)

            for _ in 0 ..< 5 {
                if let created = try await findHighlightCollection(for: color) {
                    return created
                }
                await Task.yield()
            }

            throw QuranHighlightsSyncError.collectionUnavailable(color)
        }

        private func findHighlightCollection(for color: QuranAnnotations.Note.Color) async throws -> CollectionWithBookmarks? {
            try await collectionService.snapshot().first { color.matches(collectionName: $0.collection.name) }
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

#endif
