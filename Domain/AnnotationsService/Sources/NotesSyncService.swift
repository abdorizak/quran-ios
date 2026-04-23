//
//  NotesSyncService.swift
//
//
//  Created by Ahmed Nabil on 2026-04-22.
//

import Combine
import Foundation
import MobileSync
import QuranAnnotations
import QuranKit

#if QURAN_SYNC

    public struct NotesSyncService {
        // MARK: Lifecycle

        public init(syncService: SyncService) {
            self.syncService = syncService
        }

        // MARK: Public

        public func setNote(_ note: String, verses: Set<AyahNumber>) async throws {
            guard let range = Self.ayahIdRange(for: verses) else {
                return
            }

            let existingNotes = try await snapshot().filter { $0.startAyahId == range.start && $0.endAyahId == range.end }

            if let existing = existingNotes.first {
                try await syncService.updateNote(
                    localId: existing.localId,
                    body: note,
                    startAyahId: range.start,
                    endAyahId: range.end
                )

                // Cleanup duplicates if any
                for duplicate in existingNotes.dropFirst() {
                    try await syncService.removeNote(localId: duplicate.localId)
                }
            } else {
                try await syncService.createNote(body: note, startAyahId: range.start, endAyahId: range.end)
            }
        }

        public func removeNotes(for verses: Set<AyahNumber>) async throws {
            let ayahIds = Set(verses.map(Self.ayahId(for:)))
            guard !ayahIds.isEmpty else {
                return
            }

            let notesToDelete = try await snapshot().filter { Self.intersects(note: $0, ayahIds: ayahIds) }
            for note in notesToDelete {
                try await syncService.removeNote(localId: note.localId)
            }
        }

        // MARK: Internal

        func notesSequence() -> AsyncStream<[Note_]> {
            AsyncStream { continuation in
                let task = Task {
                    do {
                        for try await notes in syncService.notesSequence() {
                            continuation.yield(notes)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }

        func snapshot() async throws -> [Note_] {
            for try await notes in syncService.notesSequence() {
                return notes
            }
            return []
        }

        // MARK: Private

        private let syncService: SyncService

        private static func ayahIdRange(for verses: Set<AyahNumber>) -> (start: Int64, end: Int64)? {
            guard let startVerse = verses.min(), let endVerse = verses.max() else {
                return nil
            }
            return (start: ayahId(for: startVerse), end: ayahId(for: endVerse))
        }

        private static func ayahId(for verse: AyahNumber) -> Int64 {
            Int64(QuranData.shared.getAyahId(sura: Int32(verse.sura.suraNumber), ayah: Int32(verse.ayah)))
        }

        private static func intersects(note: Note_, ayahIds: Set<Int64>) -> Bool {
            guard note.startAyahId <= note.endAyahId else {
                return false
            }
            let noteRange = note.startAyahId ... note.endAyahId
            return ayahIds.contains { noteRange.contains($0) }
        }
    }

#endif
