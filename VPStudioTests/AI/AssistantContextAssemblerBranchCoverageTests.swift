import Foundation
import Testing
@testable import VPStudio

@Suite("AssistantContextAssembler Branch Coverage", .serialized)
struct AssistantContextAssemblerBranchCoverageTests {
    private func makeTemporaryDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test
    func assemblyResolvesRatedTitleFromMediaItemWhenMetadataTitleIsBlank() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-rating-title-fallback.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(
            id: "tt0062622",
            type: .movie,
            title: "2001: A Space Odyssey",
            year: 1968,
            lastFetched: Date()
        )
        try await database.saveMediaItem(item)

        try await database.saveTasteEvent(TasteEvent(
            id: "te-title-fallback",
            mediaId: item.id,
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: 10,
            metadata: ["title": "   "],
            createdAt: Date().addingTimeInterval(-3 * 86400)
        ))

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)

        #expect(snapshot.contextNotes.contains { note in
            note.contains("Liked titles") && note.contains(item.title)
        })
        #expect(snapshot.candidateTitles.contains(item.title))
    }

    @Test
    func assemblySkipsNeutralUntitledAndValuelessRatings() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-rating-skip.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.saveTasteEvent(TasteEvent(
            id: "te-neutral",
            mediaId: "tt-neutral",
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: 5,
            metadata: ["title": "Middle Rating"],
            createdAt: Date()
        ))
        try await database.saveTasteEvent(TasteEvent(
            id: "te-missing-value",
            mediaId: "tt-missing-value",
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: nil,
            metadata: ["title": "Missing Value"],
            createdAt: Date()
        ))
        try await database.saveTasteEvent(TasteEvent(
            id: "te-missing-title",
            mediaId: nil,
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: 9,
            metadata: [:],
            createdAt: Date()
        ))

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)

        #expect(!snapshot.contextNotes.contains { $0.contains("Liked titles") })
        #expect(!snapshot.contextNotes.contains { $0.contains("Disliked titles") })
        #expect(snapshot.candidateTitles.contains("Middle Rating"))
        #expect(snapshot.candidateTitles.contains("Missing Value"))
        #expect(!snapshot.candidateTitles.contains("te-missing-title"))
    }

    @Test
    func assemblyDefaultsNilFeedbackScaleAndSortsLikedRatingsByRecency() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-rating-default-scale.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.saveTasteEvent(TasteEvent(
            id: "te-older-default-scale",
            mediaId: "tt-old",
            eventType: .rated,
            feedbackScale: nil,
            feedbackValue: 8,
            metadata: ["title": "Older Default Scale"],
            createdAt: Date().addingTimeInterval(-30 * 86400)
        ))
        try await database.saveTasteEvent(TasteEvent(
            id: "te-newer-default-scale",
            mediaId: "tt-new",
            eventType: .rated,
            feedbackScale: nil,
            feedbackValue: 9,
            metadata: ["title": "Newer Default Scale"],
            createdAt: Date().addingTimeInterval(-1 * 86400)
        ))

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)
        let likedNote = try #require(snapshot.contextNotes.first { $0.contains("Liked titles") })

        #expect(likedNote.contains("Newer Default Scale (9/10"))
        #expect(likedNote.contains("Older Default Scale (8/10"))
        let newerRange = try #require(likedNote.range(of: "Newer Default Scale"))
        let olderRange = try #require(likedNote.range(of: "Older Default Scale"))
        #expect(newerRange.lowerBound < olderRange.lowerBound)
    }

    @Test
    func assemblyIncludesFavoriteTitles() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-favorites.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(
            id: "tt0083658",
            type: .movie,
            title: "Blade Runner",
            year: 1982,
            lastFetched: Date()
        )
        try await database.saveMediaItem(item)

        let favoritesFolderID = try await database.fetchSystemLibraryFolderID(listType: .favorites)
        try await database.addToLibrary(UserLibraryEntry(
            id: "tt0083658-favorite",
            mediaId: item.id,
            folderId: favoritesFolderID,
            listType: .favorites,
            addedAt: Date()
        ))

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)

        #expect(snapshot.contextNotes.contains { note in
            note.contains("Favorites") && note.contains(item.title)
        })
        #expect(snapshot.candidateTitles.contains(item.title))
    }

    @Test
    func assemblySkipsWatchlistEntriesWithEmptyResolvedTitles() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-empty-watchlist-title.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(
            id: "tt-empty-title",
            type: .movie,
            title: "",
            year: 2024,
            lastFetched: Date()
        )
        try await database.saveMediaItem(item)

        let watchlistFolderID = try await database.fetchSystemLibraryFolderID(listType: .watchlist)
        try await database.addToLibrary(UserLibraryEntry(
            id: "tt-empty-title-watchlist",
            mediaId: item.id,
            folderId: watchlistFolderID,
            listType: .watchlist,
            addedAt: Date()
        ))

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)

        #expect(!snapshot.contextNotes.contains { $0.contains("Watchlist") })
        #expect(snapshot.candidateTitles.isEmpty)
    }

    @Test
    func assemblyIgnoresMalformedRecentSearchesSetting() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-malformed-searches.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.setSetting(key: SettingsKeys.recentSearches, value: #"{"not":"an array"}"#)

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)

        #expect(!snapshot.contextNotes.contains { $0.contains("Recent searches") })
        #expect(snapshot.candidateTitles.isEmpty)
    }

    @Test
    func assemblyLimitsRecentSearchesToMaximum() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-search-limit.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let searches = (0..<25).map { "query-\($0)" }
        let data = try JSONEncoder().encode(searches)
        let json = try #require(String(data: data, encoding: .utf8))
        try await database.setSetting(key: SettingsKeys.recentSearches, value: json)

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)
        let note = try #require(snapshot.contextNotes.first { $0.contains("Recent searches") })

        #expect(note.contains("query-0"))
        #expect(note.contains("query-\(AssistantContextAssembler.maxSearchQueries - 1)"))
        #expect(!note.contains("query-\(AssistantContextAssembler.maxSearchQueries)"))
    }

    @Test
    func assemblySeparatesOlderWatchHistoryAndDeduplicatesCandidateTitles() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-older-history.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.saveWatchHistory(WatchHistory(
            id: "older-h1",
            mediaId: "tt001",
            title: "Arrival",
            progress: 50,
            duration: 100,
            watchedAt: Date().addingTimeInterval(-20 * 86400),
            isCompleted: false
        ))
        try await database.saveWatchHistory(WatchHistory(
            id: "older-h2",
            mediaId: "tt002",
            title: " arrival ",
            progress: 75,
            duration: 100,
            watchedAt: Date().addingTimeInterval(-30 * 86400),
            isCompleted: false
        ))

        let snapshot = try await AssistantContextAssembler().assembleContext(from: database)
        let normalizedTitles = snapshot.candidateTitles.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        #expect(snapshot.contextNotes.contains { note in
            note.contains("Watch history") && note.contains("Arrival")
        })
        #expect(normalizedTitles.filter { $0 == "arrival" }.count == 1)
    }

    @Test
    func cachedOrAssembleUsesFreshPersistedSnapshotBeforeRebuilding() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-persisted-cache.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persisted = AssistantContextAssembler.ContextSnapshot(
            contextNotes: ["Persisted context"],
            candidateTitles: ["Persisted Title"],
            assembledAt: Date()
        )
        try await database.saveContextSnapshot(try AIContextSnapshot.from(persisted))

        let snapshot = try await AssistantContextAssembler().cachedOrAssemble(from: database)

        #expect(snapshot.contextNotes == persisted.contextNotes)
        #expect(snapshot.candidateTitles == persisted.candidateTitles)
    }

    @Test
    func cachedOrAssembleIgnoresStalePersistedSnapshot() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "assembler-stale-persisted-cache.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stale = AssistantContextAssembler.ContextSnapshot(
            contextNotes: ["Stale context"],
            candidateTitles: ["Stale Title"],
            assembledAt: Date().addingTimeInterval(-AIContextSnapshot.staleness - 1)
        )
        try await database.saveContextSnapshot(try AIContextSnapshot.from(stale))
        try await database.saveUserTasteProfile(UserTasteProfile(likedGenres: ["Mystery"]))

        let snapshot = try await AssistantContextAssembler().cachedOrAssemble(from: database)

        #expect(snapshot.contextNotes.contains { $0.contains("Mystery") })
        #expect(snapshot.contextNotes != stale.contextNotes)
        #expect(!snapshot.isStale)
    }
}
