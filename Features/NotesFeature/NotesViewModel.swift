//
//  NotesViewModel.swift
//
//
//  Created by Mohamed Afifi on 2023-07-16.
//

import Analytics
import AnnotationsService
import AsyncAlgorithms
import Combine
import Crashing
import Foundation
import Localization
import QuranAnnotations
import QuranKit
import QuranTextKit
import ReadingService
import SwiftUI
import Utilities
import VLogging

@MainActor
final class NotesViewModel: ObservableObject {
    // MARK: Lifecycle

    #if QURAN_SYNC
        init(
            analytics: AnalyticsLibrary,
            noteService: NoteService,
            textRetriever: ShareableVerseTextRetriever,
            navigateTo: @escaping (AyahNumber) -> Void,
            notesSyncService: NotesSyncService?,
            highlightsSyncService: QuranHighlightsSyncService?
        ) {
            self.analytics = analytics
            self.noteService = noteService
            self.textRetriever = textRetriever
            self.navigateTo = navigateTo
            self.notesSyncService = notesSyncService
            self.highlightsSyncService = highlightsSyncService
        }
    #else
        init(
            analytics: AnalyticsLibrary,
            noteService: NoteService,
            textRetriever: ShareableVerseTextRetriever,
            navigateTo: @escaping (AyahNumber) -> Void
        ) {
            self.analytics = analytics
            self.noteService = noteService
            self.textRetriever = textRetriever
            self.navigateTo = navigateTo
        }
    #endif

    // MARK: Internal

    @Published var editMode: EditMode = .inactive
    @Published var error: Error? = nil
    @Published var notes: [NoteItem] = []

    func start() async {
        let readingSequence = readingPreferences.$reading
            .prepend(readingPreferences.reading)
            .values()

        for await reading in readingSequence {
            let notesSequence = noteService.notes(quran: reading.quran).values()
            #if QURAN_SYNC
                let highlightColorsSequence = highlightsSyncService?.highlightColorsSequence() ?? AsyncStream { $0.yield([:]); $0.finish() }
                let combined = combineLatest(notesSequence, highlightColorsSequence)
                for await (notes, highlightColors) in combined {
                    let noteItems_ = notes.filter {
                        !($0.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                    self.notes = await noteItems(with: noteItems_, highlightColorsByVerse: highlightColors)
                        .sorted { $0.note.modifiedDate > $1.note.modifiedDate }
                }
            #else
                for await notes in notesSequence {
                    self.notes = await noteItems(with: notes, highlightColorsByVerse: [:])
                        .sorted { $0.note.modifiedDate > $1.note.modifiedDate }
                }
            #endif
        }
    }

    func navigateTo(_ item: NoteItem) {
        logger.info("Notes: select note at \(item.note.firstVerse)")
        navigateTo(item.note.firstVerse)
    }

    func deleteItem(_ item: NoteItem) async {
        logger.info("Notes: delete note at \(item.note.firstVerse)")
        do {
            try await noteService.removeNotes(with: Array(item.note.verses))
        } catch {
            self.error = error
        }
    }

    func prepareNotesForSharing() async throws -> String {
        try await crasher.recordError("Failed to share notes") {
            var notesText = [String]()
            let notes: [NoteItem] = await self.notes
            for (index, note) in notes.enumerated() {
                let title: [String] = if let noteContent = note.note.note, noteContent != "" {
                    [
                        "\(noteContent.trimmingCharacters(in: .newlines))", "",
                    ]
                } else {
                    []
                }
                let verses = try await textRetriever.textForVerses(Array(note.note.verses))

                notesText.append(contentsOf: title + verses)
                if index != notes.count - 1 {
                    notesText.append(contentsOf: ["", "", ""])
                }
            }
            return notesText.joined(separator: "\n")
        }
    }

    // MARK: Private

    private let analytics: AnalyticsLibrary
    private let noteService: NoteService
    private let textRetriever: ShareableVerseTextRetriever
    private let navigateTo: (AyahNumber) -> Void
    #if QURAN_SYNC
        private let notesSyncService: NotesSyncService?
        private let highlightsSyncService: QuranHighlightsSyncService?
    #endif
    private let readingPreferences = ReadingPreferences.shared

    private nonisolated func noteItems(with notes: [Note], highlightColorsByVerse: [AyahNumber: Note.Color]) async -> [NoteItem] {
        await withTaskGroup(of: NoteItem.self) { group in
            for note in notes {
                group.addTask {
                    do {
                        let verseText = try await self.noteService.textForVerses(Array(note.verses))
                        return NoteItem(
                            note: note,
                            verseText: verseText,
                            highlightColor: self.highlightColor(for: note, highlights: highlightColorsByVerse)
                        )
                    } catch {
                        crasher.recordError(error, reason: "NoteService.textForVerses")
                        return NoteItem(
                            note: note,
                            verseText: note.firstVerse.localizedName,
                            highlightColor: self.highlightColor(for: note, highlights: highlightColorsByVerse)
                        )
                    }
                }
            }

            let result = await group.collect()
            return result
        }
    }

    private nonisolated func highlightColor(for note: Note, highlights: [AyahNumber: Note.Color]) -> Note.Color? {
        #if QURAN_SYNC
            let colors = Set(note.verses.compactMap { highlights[$0] })
            guard colors.count == 1 else {
                return nil
            }
            return colors.first
        #else
            return note.color
        #endif
    }
}
