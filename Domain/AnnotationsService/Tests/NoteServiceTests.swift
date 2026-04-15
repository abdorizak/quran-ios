import Analytics
import Combine
import QuranAnnotations
import QuranKit
import QuranTextKit
import XCTest
@testable import AnnotationsService
@testable import NotePersistence

final class NoteServiceTests: XCTestCase {
    // MARK: Internal

    func test_updateHighlight_mirrorsHighlightsToSync_whenSyncClosureProvided() async throws {
        let verse = AyahNumber(quran: quran, sura: 1, ayah: 1)!
        let persistence = NotePersistenceSpy()
        persistence.setNoteResult = NotePersistenceModel(
            nil,
            color: Note.Color.green.rawValue,
            modifiedDate: Date(),
            verses: [VersePersistenceModel(ayah: 1, sura: 1)]
        )
        let syncSpy = SyncSpy()
        let sut = makeSUT(
            persistence: persistence,
            syncHighlights: { verses, color in await syncSpy.recordSync(verses: verses, color: color) }
        )

        _ = try await sut.updateHighlight(verses: [verse], color: .green, quran: quran)

        XCTAssertEqual(persistence.setNoteCalls.count, 1)
        let calls = await syncSpy.syncCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].verses, [verse])
        XCTAssertEqual(calls[0].color, .green)
    }

    #if QURAN_SYNC
        func test_setNote_doesNotMirrorHighlightsToSync_whenSyncClosureProvided() async throws {
            let verses: Set<AyahNumber> = [
                AyahNumber(quran: quran, sura: 1, ayah: 1)!,
                AyahNumber(quran: quran, sura: 1, ayah: 2)!,
            ]
            let persistence = NotePersistenceSpy()
            let syncSpy = SyncSpy()
            let sut = makeSUT(
                persistence: persistence,
                syncHighlights: { verses, color in await syncSpy.recordSync(verses: verses, color: color) }
            )

            try await sut.setNote("Test", verses: verses, color: .purple)

            XCTAssertEqual(persistence.setNoteCalls.count, 1)
            let calls = await syncSpy.syncCalls
            XCTAssertTrue(calls.isEmpty)
        }
    #else
        func test_setNote_mirrorsHighlightsToSync_whenSyncClosureProvided() async throws {
            let verses: Set<AyahNumber> = [
                AyahNumber(quran: quran, sura: 1, ayah: 1)!,
                AyahNumber(quran: quran, sura: 1, ayah: 2)!,
            ]
            let persistence = NotePersistenceSpy()
            let syncSpy = SyncSpy()
            let sut = makeSUT(
                persistence: persistence,
                syncHighlights: { verses, color in await syncSpy.recordSync(verses: verses, color: color) }
            )

            try await sut.setNote("Test", verses: verses, color: .purple)

            XCTAssertEqual(persistence.setNoteCalls.count, 1)
            let calls = await syncSpy.syncCalls
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(Set(calls[0].verses), verses)
            XCTAssertEqual(calls[0].color, .purple)
        }
    #endif

    func test_removeHighlights_mirrorsHighlightRemovalToSync_whenSyncClosureProvided() async throws {
        let verses = [
            AyahNumber(quran: quran, sura: 2, ayah: 1)!,
            AyahNumber(quran: quran, sura: 2, ayah: 2)!,
        ]
        let persistence = NotePersistenceSpy()
        let syncSpy = SyncSpy()
        let sut = makeSUT(
            persistence: persistence,
            removeSyncedHighlights: { verses in await syncSpy.recordRemove(verses: verses) }
        )

        try await sut.removeHighlights(with: verses)

        XCTAssertEqual(persistence.removeNotesCalls.count, 1)
        let calls = await syncSpy.removeCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0], verses)
    }

    func test_removeNotes_doesNotMirrorHighlightRemovalToSync_whenSyncClosureProvided() async throws {
        let verses = [
            AyahNumber(quran: quran, sura: 2, ayah: 1)!,
            AyahNumber(quran: quran, sura: 2, ayah: 2)!,
        ]
        let persistence = NotePersistenceSpy()
        let syncSpy = SyncSpy()
        let sut = makeSUT(
            persistence: persistence,
            removeSyncedHighlights: { verses in await syncSpy.recordRemove(verses: verses) }
        )

        try await sut.removeNotes(with: verses)

        XCTAssertEqual(persistence.removeNotesCalls.count, 1)
        let calls = await syncSpy.removeCalls
        XCTAssertTrue(calls.isEmpty)
    }

    func test_updateHighlight_keepsWorkingWithoutSyncClosures() async throws {
        let verse = AyahNumber(quran: quran, sura: 3, ayah: 1)!
        let persistence = NotePersistenceSpy()
        persistence.setNoteResult = NotePersistenceModel(
            nil,
            color: Note.Color.red.rawValue,
            modifiedDate: Date(),
            verses: [VersePersistenceModel(ayah: 1, sura: 3)]
        )
        let sut = makeSUT(persistence: persistence)

        _ = try await sut.updateHighlight(verses: [verse], color: .red, quran: quran)

        XCTAssertEqual(persistence.setNoteCalls.count, 1)
    }

    // MARK: Private

    private let quran = Quran.hafsMadani1405

    private func makeSUT(
        persistence: NotePersistenceSpy,
        syncHighlights: NoteService.SyncHighlights? = nil,
        removeSyncedHighlights: NoteService.RemoveSyncedHighlights? = nil
    ) -> NoteService {
        NoteService(
            persistence: persistence,
            textService: QuranTextDataService(
                databasesURL: URL(fileURLWithPath: "/tmp"),
                quranFileURL: URL(fileURLWithPath: "/tmp/quran.sqlite")
            ),
            analytics: AnalyticsSpy(),
            syncHighlights: syncHighlights,
            removeSyncedHighlights: removeSyncedHighlights
        )
    }
}

private struct AnalyticsSpy: AnalyticsLibrary {
    func logEvent(_: String, value _: String) {}
}

private final class NotePersistenceSpy: NotePersistence {
    var setNoteCalls: [(note: String?, verses: [VersePersistenceModel], color: Int)] = []
    var removeNotesCalls: [[VersePersistenceModel]] = []
    var setNoteResult = NotePersistenceModel(nil, color: 0, modifiedDate: Date())

    func notes() -> AnyPublisher<[NotePersistenceModel], Never> {
        Just([]).eraseToAnyPublisher()
    }

    func setNote(_ note: String?, verses: [VersePersistenceModel], color: Int) async throws -> NotePersistenceModel {
        setNoteCalls.append((note, verses, color))
        return setNoteResult
    }

    func removeNotes(with verses: [VersePersistenceModel]) async throws -> [NotePersistenceModel] {
        removeNotesCalls.append(verses)
        return []
    }
}

private actor SyncSpy {
    struct SyncCall: Equatable {
        let verses: [AyahNumber]
        let color: Note.Color
    }

    private(set) var syncCalls: [SyncCall] = []
    private(set) var removeCalls: [[AyahNumber]] = []

    func recordSync(verses: [AyahNumber], color: Note.Color) {
        syncCalls.append(SyncCall(verses: verses, color: color))
    }

    func recordRemove(verses: [AyahNumber]) {
        removeCalls.append(verses)
    }
}

private extension NotePersistenceModel {
    init(_ text: String?, color: Int, modifiedDate: Date, verses: Set<VersePersistenceModel> = []) {
        self.init(verses: verses, modifiedDate: modifiedDate, note: text, color: color)
    }
}
