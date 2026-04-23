//
//  NoteEditorInteractor.swift
//  Quran
//
//  Created by Afifi, Mohamed on 12/20/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import AnnotationsService
import Crashing
import Foundation
import NoorUI
import QuranAnnotations
import VLogging

@MainActor
public protocol NoteEditorListener: AnyObject {
    func dismissNoteEditor()
}

@MainActor
final class NoteEditorInteractor {
    // MARK: Lifecycle

    #if QURAN_SYNC
        init(
            noteService: NoteService,
            note: Note,
            notesSyncService: NotesSyncService?,
            highlightsSyncService: QuranHighlightsSyncService?
        ) {
            self.note = note
            self.noteService = noteService
            self.notesSyncService = notesSyncService
            self.highlightsSyncService = highlightsSyncService
        }
    #else
        init(
            noteService: NoteService,
            note: Note
        ) {
            self.note = note
            self.noteService = noteService
        }
    #endif

    // MARK: Internal

    weak var listener: NoteEditorListener?

    var isEditedNote: Bool {
        !(editbleNote?.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func fetchNote() async throws -> EditableNote {
        do {
            let versesText = try await getNoteText()

            logger.info("NoteEditor: note loaded")
            let editbleNote = EditableNote(
                ayahText: versesText,
                modifiedSince: note.modifiedDate.timeAgo(),
                selectedColor: note.color,
                note: note.note ?? ""
            )
            self.editbleNote = editbleNote
            return editbleNote
        } catch {
            crasher.recordError(error, reason: "Failed to retrieve note text")
            throw error
        }
    }

    func commitEditsAndExist() async {
        logger.info("NoteEditor: done tapped")
        let editorColor = editbleNote?.selectedColor
        do {
            try await noteService.setNote(
                editbleNote?.note ?? note.note ?? "",
                verses: note.verses,
                color: editorColor ?? note.color
            )
            #if QURAN_SYNC
                if let body = editbleNote?.note {
                    do {
                        try await notesSyncService?.setNote(body, verses: note.verses)
                    } catch {
                        crasher.recordError(error, reason: "Failed to sync note")
                    }
                }
            #endif
            logger.info("NoteEditor: note saved")
            listener?.dismissNoteEditor()
        } catch {
            // TODO: should show error to the user
            crasher.recordError(error, reason: "Failed to set note")
        }
    }

    func forceDelete() async {
        logger.info("NoteEditor: force delete note")
        do {
            try await noteService.removeNotes(with: Array(note.verses))
            #if QURAN_SYNC
                try await notesSyncService?.removeNotes(for: note.verses)
                try await highlightsSyncService?.removeHighlights(verses: Array(note.verses))
            #endif
            logger.info("NoteEditor: notes removed")
            listener?.dismissNoteEditor()
        } catch {
            // TODO: should show error to the user
            crasher.recordError(error, reason: "Failed to delete note")
        }
    }

    // MARK: Private

    private let noteService: NoteService
    private let note: Note
    #if QURAN_SYNC
        private let notesSyncService: NotesSyncService?
        private let highlightsSyncService: QuranHighlightsSyncService?
    #endif

    private var editbleNote: EditableNote?

    // MAKR: - Helpers

    private func getNoteText() async throws -> String {
        try await noteService.textForVerses(Array(note.verses))
    }
}
