//
//  QuranBuilder+Sync.swift
//  Quran
//

import AnnotationsService
import AudioBannerFeature
import AyahMenuFeature
import MoreMenuFeature
import NoteEditorFeature
import QuranContentFeature
import QuranKit
import ReadingService
import TranslationsFeature
import TranslationVerseFeature
import WordPointerFeature

extension QuranBuilder {
    #if QURAN_SYNC
        func makeSyncInteractorDeps(
            quran: Quran,
            pageBookmarkService: PageBookmarkService,
            highlightsService: QuranHighlightsService
        ) -> QuranInteractor.Deps {
            QuranInteractor.Deps(
                quran: quran,
                analytics: container.analytics,
                pageBookmarkService: pageBookmarkService,
                noteService: container.noteService(),
                ayahMenuBuilder: AyahMenuBuilder(container: container),
                moreMenuBuilder: MoreMenuBuilder(),
                audioBannerBuilder: AudioBannerBuilder(container: container),
                wordPointerBuilder: WordPointerBuilder(container: container),
                noteEditorBuilder: NoteEditorBuilder(container: container),
                contentBuilder: ContentBuilder(container: container, highlightsService: highlightsService),
                translationsSelectionBuilder: TranslationsListBuilder(container: container),
                translationVerseBuilder: TranslationVerseBuilder(container: container),
                resources: container.readingResources,
                notesSyncService: container.notesSyncService,
                highlightsSyncService: container.highlightsSyncService
            )
        }
    #endif
}
