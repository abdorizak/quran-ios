//
//  NotesBuilder.swift
//  Quran
//
//  Created by Afifi, Mohamed on 11/14/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import AnnotationsService
import AppDependencies
import FeaturesSupport
import QuranKit
import QuranTextKit
import UIKit

@MainActor
public struct NotesBuilder {
    // MARK: Lifecycle

    public init(container: AppDependencies) {
        self.container = container
    }

    // MARK: Public

    public func build(withListener listener: QuranNavigator) -> UIViewController {
        let textRetriever = ShareableVerseTextRetriever(
            databasesURL: container.databasesURL,
            quranFileURL: container.quranUthmaniV2Database
        )

        #if QURAN_SYNC
            let viewModel = NotesViewModel(
                analytics: container.analytics,
                noteService: container.noteService(),
                textRetriever: textRetriever,
                navigateTo: { [weak listener] verse in
                    listener?.navigateTo(page: verse.page, lastPage: nil, highlightingSearchAyah: nil)
                },
                notesSyncService: container.notesSyncService,
                highlightsSyncService: container.highlightsSyncService
            )
        #else
            let viewModel = NotesViewModel(
                analytics: container.analytics,
                noteService: container.noteService(),
                textRetriever: textRetriever,
                navigateTo: { [weak listener] verse in
                    listener?.navigateTo(page: verse.page, lastPage: nil, highlightingSearchAyah: nil)
                }
            )
        #endif
        let viewController = NotesViewController(viewModel: viewModel)
        return viewController
    }

    // MARK: Internal

    let container: AppDependencies
}
