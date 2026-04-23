//
//  NoteItem.swift
//  Quran
//
//  Created by Afifi, Mohamed on 11/22/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import QuranAnnotations
import QuranKit

struct NoteItem: Equatable, Identifiable {
    let note: Note
    let verseText: String
    let highlightColor: Note.Color?

    var id: Set<AyahNumber> { note.verses }
}
