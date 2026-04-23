//
//  ContentBuilder+Sync.swift
//  Quran
//

import AnnotationsService
import QuranImageFeature
import QuranKit
import QuranTranslationFeature
import ReadingService

extension ContentBuilder {
    #if QURAN_SYNC
        func makeSyncInteractorDeps(
            quran: Quran,
            noteService: NoteService,
            lastPageUpdater: LastPageUpdater
        ) -> ContentViewModel.Deps {
            ContentViewModel.Deps(
                analytics: container.analytics,
                noteService: noteService,
                lastPageUpdater: lastPageUpdater,
                quran: quran,
                highlightsService: highlightsService,
                highlightsSyncService: container.highlightsSyncService,
                imageDataSourceBuilder: ContentImageBuilder(container: container, highlightsService: highlightsService),
                translationDataSourceBuilder: ContentTranslationBuilder(container: container, highlightsService: highlightsService)
            )
        }
    #endif
}
