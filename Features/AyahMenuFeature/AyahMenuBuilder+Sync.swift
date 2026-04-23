//
//  AyahMenuBuilder+Sync.swift
//  Quran
//

import AnnotationsService
import QuranTextKit

extension AyahMenuBuilder {
    #if QURAN_SYNC
        func makeSyncViewModel(
            input: AyahMenuInput,
            noteService: NoteService,
            textRetriever: ShareableVerseTextRetriever
        ) -> AyahMenuViewModel {
            AyahMenuViewModel(deps: AyahMenuViewModel.Deps(
                sourceView: input.sourceView,
                pointInView: input.pointInView,
                verses: input.verses,
                notes: input.notes,
                noteService: noteService,
                highlightsSyncService: container.highlightsSyncService,
                textRetriever: textRetriever
            ))
        }
    #endif
}
