//
//  NoteEditorBuilder.swift
//  Quran
//
//  Created by Afifi, Mohamed on 12/20/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import AnnotationsService
import AppDependencies
import QuranAnnotations
import UIKit

@MainActor
public struct NoteEditorBuilder {
    // MARK: Lifecycle

    public init(container: AppDependencies) {
        self.container = container
    }

    // MARK: Public

    public func build(withListener listener: NoteEditorListener, note: Note) -> UIViewController {
        #if QURAN_SYNC
            let viewModel = NoteEditorInteractor(
                noteService: container.noteService(),
                note: note,
                notesSyncService: container.notesSyncService,
                highlightsSyncService: container.highlightsSyncService
            )
        #else
            let viewModel = NoteEditorInteractor(
                noteService: container.noteService(),
                note: note
            )
        #endif
        let viewController = NoteEditorViewController(viewModel: viewModel)
        viewModel.listener = listener
        return viewController
    }

    // MARK: Internal

    let container: AppDependencies
}
