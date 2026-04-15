//
//  NoteService.swift
//  Quran
//
//  Created by Afifi, Mohamed on 12/21/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import Analytics
import Combine
import Foundation
import Localization
import NotePersistence
import Preferences
import QuranAnnotations
import QuranKit
import QuranText
import QuranTextKit

public struct NoteService {
    public typealias SyncHighlights = @Sendable (_ verses: [AyahNumber], _ color: Note.Color) async throws -> Void
    public typealias RemoveSyncedHighlights = @Sendable (_ verses: [AyahNumber]) async throws -> Void

    // MARK: Lifecycle

    public init(
        persistence: NotePersistence,
        textService: QuranTextDataService,
        analytics: AnalyticsLibrary,
        syncHighlights: SyncHighlights? = nil,
        removeSyncedHighlights: RemoveSyncedHighlights? = nil
    ) {
        self.persistence = persistence
        self.textService = textService
        self.analytics = analytics
        self.syncHighlights = syncHighlights
        self.removeSyncedHighlights = removeSyncedHighlights
    }

    // MARK: Public

    public func color(from notes: [Note]) -> Note.Color {
        notes.max { $0.modifiedDate < $1.modifiedDate }?.color ?? lastUsedHighlightColor
    }

    public func updateHighlight(verses: [AyahNumber], color: Note.Color, quran: Quran) async throws -> Note {
        // update last used highlight color
        lastUsedHighlightColor = color

        analytics.highlight(verses: verses)
        let persistenceVerses = verses.map(VersePersistenceModel.init)
        let persistenceModel = try await persistence.setNote(nil, verses: persistenceVerses, color: color.rawValue)
        try await syncHighlights?(persistenceModel.verses.map { AyahNumber(quran: quran, $0) }, color)
        return Note(quran: quran, persistenceModel)
    }

    public func setNote(_ note: String, verses: Set<AyahNumber>, color: Note.Color) async throws {
        // update last used highlight color
        lastUsedHighlightColor = color

        analytics.updateNote(verses: verses)
        let verses = Array(verses)
        let persistenceVerses = verses.map(VersePersistenceModel.init)
        _ = try await persistence.setNote(note, verses: persistenceVerses, color: color.rawValue)
        #if !QURAN_SYNC
            try await syncHighlights?(verses, color)
        #endif
    }

    public func removeNotes(with verses: [AyahNumber]) async throws {
        analytics.unhighlight(verses: verses)
        let persistenceVerses = verses.map(VersePersistenceModel.init)
        _ = try await persistence.removeNotes(with: persistenceVerses)
    }

    public func removeHighlights(with verses: [AyahNumber]) async throws {
        analytics.unhighlight(verses: verses)
        let persistenceVerses = verses.map(VersePersistenceModel.init)
        _ = try await persistence.removeNotes(with: persistenceVerses)
        try await removeSyncedHighlights?(verses)
    }

    public func notes(quran: Quran) -> AnyPublisher<[Note], Never> {
        persistence.notes()
            .map { notes in notes.map { Note(quran: quran, $0) } }
            .eraseToAnyPublisher()
    }

    public func textForVerses(_ verses: [AyahNumber]) async throws -> String {
        let versesWithText = try await textDictionaryForVerses(verses)
        let sortedVerses = verses.sorted()
        let versesText = sortedVerses.compactMap { verse in versesWithText[verse].map { (verse, $0) } }
        let combinedVersesText = versesText.map { $0.1 + " \(NumberFormatter.arabicNumberFormatter.format($0.0.ayah))" }
            .joined(separator: " ")
        return combinedVersesText
    }

    // MARK: Internal

    let persistence: NotePersistence
    let textService: QuranTextDataService
    let analytics: AnalyticsLibrary
    let syncHighlights: SyncHighlights?
    let removeSyncedHighlights: RemoveSyncedHighlights?

    // MARK: Private

    private static let defaultLastUsedNoteHighlightColor = Note.Color.red
    private static let lastUsedNoteHighlightColorKey = PreferenceKey<Int>(
        key: "lastUsedNoteHighlightColor",
        defaultValue: defaultLastUsedNoteHighlightColor.rawValue
    )

    @TransformedPreference(lastUsedNoteHighlightColorKey, transformer: .rawRepresentable(defaultValue: defaultLastUsedNoteHighlightColor))
    private var lastUsedHighlightColor: Note.Color

    private func textDictionaryForVerses(_ verses: [AyahNumber]) async throws -> [AyahNumber: String] {
        let verseTexts = try await textService.textForVerses(verses, translations: [])
        return verseTexts.mapValues(\.arabicText)
    }
}

private extension Note {
    init(quran: Quran, _ note: NotePersistenceModel) {
        self.init(
            verses: Set(note.verses.map { AyahNumber(quran: quran, $0) }),
            modifiedDate: note.modifiedDate,
            note: note.note,
            color: Note.Color(rawValue: note.color) ?? .red
        )
    }
}

private extension AyahNumber {
    init(quran: Quran, _ other: VersePersistenceModel) {
        self.init(quran: quran, sura: other.sura, ayah: other.ayah)!
    }
}

private extension VersePersistenceModel {
    init(_ verse: AyahNumber) {
        self.init(ayah: verse.ayah, sura: verse.sura.suraNumber)
    }
}
