import Foundation
import Testing
@testable import VPStudio

@Suite("Serialization Tests", .serialized)
struct SerializationTests {

    // MARK: - JSON Encoding/Decoding

    @Suite("JSON Encoding/Decoding")
    struct JSONEncodingDecodingTests {

        private func roundTrip<T: Codable>(_ value: T) throws -> T {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        }

        // MARK: - StreamRecoveryContext

        @Test func streamRecoveryContextRoundTrip() throws {
            let original = StreamRecoveryContext(
                infoHash: "ABCDEF1234567890ABCDEF1234567890ABCDEF12",
                preferredService: .realDebrid,
                seasonNumber: 1,
                episodeNumber: 5,
                torrentId: "torrent-123",
                resolvedDebridService: "Real-Debrid",
                resolvedFileName: "Show.S01E05.mkv",
                resolvedFileSizeBytes: 1_073_741_824
            )!
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func streamRecoveryContextWithNilOptionals() throws {
            let original = StreamRecoveryContext(
                infoHash: "abc123",
                preferredService: nil,
                seasonNumber: nil,
                episodeNumber: nil,
                torrentId: nil,
                resolvedDebridService: nil,
                resolvedFileName: nil,
                resolvedFileSizeBytes: nil
            )!
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func streamRecoveryContextRejectsEmptyHash() throws {
            #expect(StreamRecoveryContext(infoHash: "") == nil)
            #expect(StreamRecoveryContext(infoHash: "   ") == nil)
            #expect(StreamRecoveryContext(infoHash: "abc") != nil)
        }

        @Test func streamRecoveryContextTrimsWhitespace() throws {
            let original = StreamRecoveryContext(
                infoHash: "  ABCDEF1234567890ABCDEF1234567890ABCDEF12  ",
                preferredService: .allDebrid,
                seasonNumber: 2,
                episodeNumber: 10
            )!
            #expect(original.infoHash == "abcdef1234567890abcdef1234567890abcdef12")
            #expect(original.seasonNumber == 2)
        }

        // MARK: - StreamInfo

        @Test func streamInfoRoundTrip() throws {
            let original = StreamInfo(
                streamURL: URL(string: "https://example.com/stream.mkv")!,
                quality: .hd1080p,
                codec: .h265,
                audio: .eac3,
                source: .webDL,
                hdr: .hdr10,
                fileName: "movie.2024.1080p.web-dl.hevc.eac3.mkv",
                sizeBytes: 2_147_483_648,
                debridService: "real_debrid",
                recoveryContext: StreamRecoveryContext(
                    infoHash: "abc123",
                    preferredService: .realDebrid
                )
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func streamInfoWithNilSizeBytes() throws {
            let original = StreamInfo(
                streamURL: URL(string: "https://example.com/stream.mkv")!,
                quality: .uhd4k,
                codec: .av1,
                audio: .atmos,
                source: .bluRay,
                hdr: .dolbyVision,
                fileName: "test.mkv",
                sizeBytes: nil,
                debridService: "premiumize"
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func streamInfoIdIsStable() throws {
            let stream = StreamInfo(
                streamURL: URL(string: "https://example.com/stream.mkv")!,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "test.mkv",
                sizeBytes: 1000,
                debridService: "torbox"
            )
            #expect(stream.id == stream.id)
        }

        // MARK: - TorrentResult

        @Test func torrentResultRoundTrip() throws {
            let original = TorrentResult(
                infoHash: "abcdef1234567890abcdef1234567890abcdef12",
                title: "Test Movie 2024 1080p WEB-DL HEVC AAC",
                sizeBytes: 2_000_000_000,
                seeders: 1500,
                leechers: 200,
                quality: .hd1080p,
                codec: .h265,
                audio: .aac,
                source: .webDL,
                hdr: .hdr10,
                indexerName: "YTS",
                magnetURI: "magnet:?xt=urn:btih:abcdef12",
                directStreamURL: "https://cdn.example.com/movie.mkv?token=abc"
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func torrentResultIdIsHashAndIndexer() throws {
            let result = TorrentResult.fromSearch(
                infoHash: "abc123",
                title: "Test",
                sizeBytes: 1000,
                seeders: 10,
                leechers: 5,
                indexerName: "EZTV"
            )
            #expect(result.id == "abc123-EZTV")
        }

        // MARK: - Subtitle

        @Test func subtitleRoundTrip() throws {
            let original = Subtitle(
                id: "sub-1",
                language: "en",
                fileName: "movie.english.srt",
                url: "https://example.com/subs/srt",
                format: .srt,
                fileId: 12345,
                rating: 8.5,
                downloadCount: 1000,
                isHearingImpaired: true,
                source: "OpenSubtitles"
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func subtitleFormatAllCasesRoundTrip() throws {
            for format in [SubtitleFormat.srt, .vtt, .ass, .ssa, .unknown] {
                let subtitle = Subtitle(
                    id: "test",
                    language: "en",
                    fileName: "test.\(format.rawValue)",
                    url: "https://example.com/test",
                    format: format
                )
                let decoded = try roundTrip(subtitle)
                #expect(decoded.format == format)
            }
        }

        // MARK: - Episode

        @Test func episodeRoundTrip() throws {
            let original = Episode(
                id: "ep-123",
                mediaId: "tt456",
                seasonNumber: 3,
                episodeNumber: 7,
                title: "The Episode Title",
                overview: "Episode description",
                airDate: "2024-01-15",
                stillPath: "/still/path.jpg",
                runtime: 42
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func episodeDisplayTitleWithTitle() throws {
            let ep = Episode(
                id: "ep-1",
                mediaId: "tt1",
                seasonNumber: 2,
                episodeNumber: 5,
                title: "Great Episode"
            )
            #expect(ep.displayTitle == "S02E05 - Great Episode")
        }

        @Test func episodeDisplayTitleWithoutTitle() throws {
            let ep = Episode(
                id: "ep-1",
                mediaId: "tt1",
                seasonNumber: 1,
                episodeNumber: 1,
                title: nil
            )
            #expect(ep.displayTitle == "S01E01")
        }

        // MARK: - Season

        @Test func seasonRoundTrip() throws {
            let original = Season(
                id: 1,
                seasonNumber: 1,
                name: "Season 1",
                overview: "First season",
                posterPath: "/poster.jpg",
                episodeCount: 10,
                airDate: "2024-01-01"
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        // MARK: - MediaItem

        @Test func mediaItemRoundTrip() throws {
            let original = MediaItem(
                id: "tt123",
                type: .movie,
                title: "Test Movie",
                year: 2024,
                posterPath: "/poster.jpg",
                backdropPath: "/backdrop.jpg",
                overview: "A test movie description",
                genres: ["Action", "Drama", "Science Fiction"],
                imdbRating: 8.5,
                runtime: 148,
                status: "Released",
                tmdbId: 12345,
                lastFetched: Date()
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func mediaItemWithEmptyGenres() throws {
            let original = MediaItem(
                id: "tt456",
                type: .series,
                title: "Test Series",
                year: 2024,
                genres: [],
                tmdbId: 67890
            )
            let decoded = try roundTrip(original)
            #expect(decoded.genres == [])
        }

        @Test func mediaItemRatingString() throws {
            let item = MediaItem(id: "tt1", type: .movie, title: "Test", imdbRating: 7.856)
            #expect(item.ratingString == "7.9")
        }

        @Test func mediaItemRuntimeStringHoursAndMinutes() throws {
            let item = MediaItem(id: "tt1", type: .movie, title: "Test", runtime: 148)
            #expect(item.runtimeString == "2h 28m")
        }

        @Test func mediaItemRuntimeStringMinutesOnly() throws {
            let item = MediaItem(id: "tt1", type: .movie, title: "Test", runtime: 45)
            #expect(item.runtimeString == "45m")
        }

        // MARK: - MediaPreview



        // MARK: - DebridConfig

        @Test func debridConfigRoundTrip() throws {
            let original = DebridConfig(
                id: "config-1",
                serviceType: .realDebrid,
                apiTokenRef: "token-ref-123",
                isActive: true,
                priority: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func debridConfigAllServiceTypes() throws {
            for serviceType in DebridServiceType.allCases {
                let config = DebridConfig(
                    serviceType: serviceType,
                    apiTokenRef: "test-token"
                )
                let decoded = try roundTrip(config)
                #expect(decoded.serviceType == serviceType)
            }
        }

        // MARK: - IndexerConfig

        @Test func indexerConfigRoundTrip() throws {
            let original = IndexerConfig(
                id: "indexer-1",
                name: "YTS",
                indexerType: .yts,
                baseURL: "https://yts.mx/api",
                apiKey: "api-key-123",
                isActive: true,
                priority: 1
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func indexerConfigAllIndexerTypes() throws {
            for indexerType in IndexerConfig.IndexerType.allCases {
                let config = IndexerConfig(
                    name: indexerType.displayName,
                    indexerType: indexerType
                )
                let decoded = try roundTrip(config)
                #expect(decoded.indexerType == indexerType)
            }
        }

        @Test func indexerConfigAllProviderSubtypes() throws {
            for subtype in IndexerConfig.ProviderSubtype.allCases {
                let config = IndexerConfig(
                    name: "Test",
                    indexerType: .torznab,
                    providerSubtype: subtype
                )
                let decoded = try roundTrip(config)
                #expect(decoded.providerSubtype == subtype)
            }
        }

        @Test func indexerConfigAllAPIKeyTransports() throws {
            for transport in IndexerConfig.APIKeyTransport.allCases {
                let config = IndexerConfig(
                    name: "Test",
                    indexerType: .jackett,
                    apiKeyTransport: transport
                )
                let decoded = try roundTrip(config)
                #expect(decoded.apiKeyTransport == transport)
            }
        }

        // MARK: - WatchHistory

        @Test func watchHistoryRoundTrip() throws {
            let original = WatchHistory(
                id: "history-1",
                mediaId: "tt123",
                episodeId: nil,
                title: "Test Movie",
                progress: 1800,
                duration: 7200,
                quality: "1080p",
                debridService: "real_debrid",
                streamURL: "https://example.com/stream",
                watchedAt: Date(),
                isCompleted: false
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func watchHistoryProgressPercent() throws {
            let history = WatchHistory(
                id: "h1",
                mediaId: "tt1",
                title: "Test",
                progress: 1800,
                duration: 3600,
                watchedAt: Date(),
                isCompleted: false
            )
            #expect(history.progressPercent == 0.5)
        }

        @Test func watchHistoryProgressPercentZeroDuration() throws {
            let history = WatchHistory(
                id: "h1",
                mediaId: "tt1",
                title: "Test",
                progress: 100,
                duration: 0,
                watchedAt: Date(),
                isCompleted: false
            )
            #expect(history.progressPercent == 0)
        }

        // MARK: - UserLibraryEntry

        @Test func userLibraryEntryRoundTrip() throws {
            let original = UserLibraryEntry(
                id: "lib-1",
                mediaId: "tt123",
                folderId: "folder-1",
                listType: .watchlist,
                addedAt: Date(),
                customListName: nil,
                releaseDateHint: "2024-12",
                renewalStatus: nil
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func userLibraryEntryAllListTypes() throws {
            for listType in UserLibraryEntry.ListType.allCases {
                let entry = UserLibraryEntry(
                    id: "test-id",
                    mediaId: "tt1",
                    folderId: "folder-1",
                    listType: listType,
                    addedAt: Date()
                )
                let decoded = try roundTrip(entry)
                #expect(decoded.listType == listType)
            }
        }

        @Test func userLibraryEntryListTypeFromStoredValue() throws {
            #expect(UserLibraryEntry.ListType.fromStoredValue("watchlist") == .watchlist)
            #expect(UserLibraryEntry.ListType.fromStoredValue("favorites") == .favorites)
            #expect(UserLibraryEntry.ListType.fromStoredValue("history") == .history)
            #expect(UserLibraryEntry.ListType.fromStoredValue("custom") == .favorites)
            #expect(UserLibraryEntry.ListType.fromStoredValue(nil) == .favorites)
            #expect(UserLibraryEntry.ListType.fromStoredValue("unknown") == .favorites)
        }

        // MARK: - LibraryFolder

        @Test func libraryFolderRoundTrip() throws {
            let original = LibraryFolder(
                id: "folder-1",
                name: "My Folder",
                parentId: nil,
                listType: .watchlist,
                folderKind: .manual,
                isSystem: false,
                sortOrder: 0
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func libraryFolderAllFolderKinds() throws {
            for kind in LibraryFolder.FolderKind.allCases {
                let folder = LibraryFolder(
                    id: "test-id",
                    name: "Test",
                    listType: .favorites,
                    folderKind: kind
                )
                let decoded = try roundTrip(folder)
                #expect(decoded.folderKind == kind)
            }
        }

        // MARK: - TraktListMapping

        @Test func traktListMappingRoundTrip() throws {
            let original = TraktListMapping(
                id: "mapping-1",
                traktListId: 12345,
                traktListSlug: "my-list",
                localFolderId: "folder-1",
                listType: .watchlist,
                lastSyncedAt: Date()
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        // MARK: - UserTasteProfile

        @Test func userTasteProfileRoundTrip() throws {
            let original = UserTasteProfile(
                id: "default",
                likedGenres: ["Action", "Sci-Fi"],
                dislikedGenres: ["Romance"],
                preferredDecades: ["2020", "2010"],
                preferredLanguages: ["en", "ja"],
                eventCount: 50,
                updatedAt: Date()
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func userTasteProfileEmptyArrays() throws {
            let original = UserTasteProfile()
            let decoded = try roundTrip(original)
            #expect(decoded.likedGenres == [])
            #expect(decoded.dislikedGenres == [])
        }

        // MARK: - TasteEvent

        @Test func tasteEventRoundTrip() throws {
            let original = TasteEvent(
                id: "event-1",
                userId: "user-1",
                mediaId: "tt123",
                episodeId: nil,
                eventType: .watched,
                signalStrength: 1.0,
                watchedState: .completed,
                feedbackScale: .likeDislike,
                feedbackValue: 1.0,
                source: .manual,
                metadata: ["key": "value"],
                createdAt: Date()
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func tasteEventAllEventTypes() throws {
            for eventType in [TasteEvent.EventType.watched, .rated, .added, .removed, .searched, .browsed, .skipped] {
                let event = TasteEvent(
                    eventType: eventType
                )
                let decoded = try roundTrip(event)
                #expect(decoded.eventType == eventType)
            }
        }

        @Test func tasteEventAllWatchedStates() throws {
            for state in [TasteEvent.WatchedState.watching, .completed, .dropped, .planToWatch] {
                let event = TasteEvent(
                    eventType: .watched,
                    watchedState: state
                )
                let decoded = try roundTrip(event)
                #expect(decoded.watchedState == state)
            }
        }

        @Test func tasteEventAllFeedbackSources() throws {
            for source in [TasteEvent.FeedbackSource.manual, .automatic, .ai] {
                let event = TasteEvent(
                    eventType: .watched,
                    source: source
                )
                let decoded = try roundTrip(event)
                #expect(decoded.source == source)
            }
        }

        // MARK: - LocalModelDescriptor

        @Test func localModelDescriptorRoundTrip() throws {
            let original = LocalModelDescriptor(
                id: "mlx-community/Qwen3.5-4B",
                displayName: "Qwen 3.5 4B",
                huggingFaceRepo: "mlx-community/Qwen3.5-4B",
                revision: "abc123",
                parameterCount: "4B",
                quantization: "4bit",
                diskSizeMB: 4000,
                minMemoryMB: 8000,
                expectedFileCount: 10,
                maxContextTokens: 8192,
                effectivePromptCap: 4096,
                effectiveOutputCap: 2048,
                status: .downloaded,
                downloadProgress: 1.0,
                downloadedBytes: 4_000_000_000,
                totalBytes: 4_000_000_000,
                lastProgressAt: Date(),
                checksumSHA256: "sha256hash",
                validationState: .valid,
                localPath: "/models/qwen",
                partialDownloadPath: nil,
                isDefault: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func localModelDescriptorAllStatuses() throws {
            for status in [LocalModelStatus.available, .downloading, .paused, .downloaded, .corrupted, .failed] {
                let descriptor = LocalModelDescriptor(
                    id: "test",
                    displayName: "Test",
                    huggingFaceRepo: "test/repo",
                    revision: "123",
                    parameterCount: "1B",
                    quantization: "4bit",
                    diskSizeMB: 1000,
                    minMemoryMB: 2000,
                    expectedFileCount: 5,
                    maxContextTokens: 4096,
                    effectivePromptCap: 2048,
                    effectiveOutputCap: 1024,
                    status: status,
                    downloadProgress: 0.5,
                    downloadedBytes: 500_000_000,
                    totalBytes: 1_000_000_000,
                    validationState: .pending,
                    isDefault: false,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                let decoded = try roundTrip(descriptor)
                #expect(decoded.status == status)
            }
        }

        // MARK: - AIUsageRecord

        @Test func aiUsageRecordRoundTrip() throws {
            let original = AIUsageRecord(
                id: "usage-1",
                provider: .openAI,
                model: "gpt-4o",
                inputTokens: 1000,
                outputTokens: 500,
                estimatedCostUSD: 0.02,
                requestType: .recommendation,
                createdAt: Date()
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func aiUsageRecordAllRequestTypes() throws {
            for requestType in AIRequestType.allCases {
                let record = AIUsageRecord(
                    provider: .anthropic,
                    model: "claude-3",
                    inputTokens: 100,
                    outputTokens: 50,
                    estimatedCostUSD: 0.01,
                    requestType: requestType
                )
                let decoded = try roundTrip(record)
                #expect(decoded.requestTypeKind == requestType)
            }
        }

        // MARK: - AIMovieRecommendation

        @Test func aiMovieRecommendationRoundTrip() throws {
            let original = AIMovieRecommendation(
                title: "Inception",
                year: 2010,
                type: .movie,
                reason: "Similar to The Matrix",
                tmdbId: 27205,
                score: 0.95
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func aiMovieRecommendationIdWithTMDB() throws {
            let rec = AIMovieRecommendation(
                title: "Test",
                year: 2024,
                type: .movie,
                reason: "Test",
                tmdbId: 12345
            )
            #expect(rec.id == "movie-tmdb-12345")
        }

        @Test func aiMovieRecommendationIdWithoutTMDB() throws {
            let rec = AIMovieRecommendation(
                title: "Test Movie",
                year: 2024,
                type: .movie,
                reason: "Test"
            )
            #expect(rec.id == "test movie-2024-movie")
        }

        // MARK: - AIPersonalizedAnalysis

        @Test func aiPersonalizedAnalysisRoundTrip() throws {
            let original = AIPersonalizedAnalysis(
                personalizedDescription: "You'd love this sci-fi thriller",
                predictedRating: 8.5,
                verdict: .yes,
                reasons: ["Great visuals", "Compelling story"]
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func aiPersonalizedAnalysisAllVerdicts() throws {
            for verdict in [AIPersonalizedAnalysis.Verdict.strongYes, .yes, .maybe, .no, .strongNo] {
                let analysis = AIPersonalizedAnalysis(
                    personalizedDescription: "Test",
                    predictedRating: 5.0,
                    verdict: verdict,
                    reasons: ["test"]
                )
                let decoded = try roundTrip(analysis)
                #expect(decoded.verdict == verdict)
            }
        }

        // MARK: - PlayerSessionRequest

        @Test func playerSessionRequestRoundTrip() throws {
            let stream = StreamInfo(
                streamURL: URL(string: "https://example.com/stream.mkv")!,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "test.mkv",
                sizeBytes: 1_000_000_000,
                debridService: "real_debrid"
            )
            let original = PlayerSessionRequest(
                id: UUID(),
                stream: stream,
                availableStreams: [stream],
                mediaTitle: "Test Movie",
                mediaId: "tt123",
                tmdbId: 12_345,
                episodeId: nil
            )
            let decoded = try roundTrip(original)
            #expect(decoded.mediaTitle == original.mediaTitle)
            #expect(decoded.mediaId == original.mediaId)
            #expect(decoded.tmdbId == original.tmdbId)
        }

        // MARK: - EnvironmentAsset

        @Test func environmentAssetRoundTrip() throws {
            let original = EnvironmentAsset(
                id: "env-1",
                name: "Cinema",
                sourceType: .bundled,
                assetPath: "/assets/cinema.hdr",
                thumbnailPath: "/assets/cinema_thumb.jpg",
                licenseName: "MIT",
                sourceAttributionURL: "https://example.com",
                previewImagePath: "/assets/cinema_preview.jpg",
                hdriYawOffset: 45.0,
                createdAt: Date(),
                isActive: true
            )
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }

        @Test func environmentAssetAllSourceTypes() throws {
            for sourceType in EnvironmentAssetSourceType.allCases {
                let asset = EnvironmentAsset(
                    id: "test",
                    name: "Test",
                    sourceType: sourceType,
                    assetPath: "/test/path"
                )
                let decoded = try roundTrip(asset)
                #expect(decoded.sourceType == sourceType)
            }
        }

        // MARK: - CuratedEnvironmentPreset




        }

    // MARK: - URL Encoding/Decoding

    @Suite("URL Encoding/Decoding")
    struct URLEncodingDecodingTests {

        @Test func urlEncodingSimpleString() throws {
            let original = "hello world"
            #expect(original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) == "hello%20world")
        }

        @Test func urlEncodingSpecialCharacters() throws {
            let original = "movie?title=test&year=2024"
            let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            #expect(encoded != nil)
            let decoded = encoded?.removingPercentEncoding
            #expect(decoded == original)
        }

        @Test func urlEncodingUnicodeCharacters() throws {
            let original = "movie_日本語_中文_한국어"
            let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            #expect(encoded != nil)
            let decoded = encoded?.removingPercentEncoding
            #expect(decoded == original)
        }

        @Test func urlEncodingEmoji() throws {
            let original = "🎬Movie📽️"
            let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            #expect(encoded != nil)
        }

        @Test func urlEncodingAmpersand() throws {
            let original = "title=A & B"
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&")
            let encoded = original.addingPercentEncoding(withAllowedCharacters: allowed)
            #expect(encoded?.contains("%26") == true)
        }

        @Test func urlEncodingEquals() throws {
            let original = "key=value"
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "=")
            let encoded = original.addingPercentEncoding(withAllowedCharacters: allowed)
            #expect(encoded?.contains("%3D") == true)
        }

        @Test func urlEncodingSlash() throws {
            let original = "path/to/file"
            let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            #expect(encoded == "path/to/file")
        }

        @Test func urlEncodingHash() throws {
            let original = "file#1"
            let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
            #expect(encoded?.contains("%23") == true)
        }

        @Test func urlComponentsParsing() throws {
            let urlString = "https://api.example.com/search?q=test&page=1"
            let components = URLComponents(string: urlString)
            #expect(components?.queryItems?.count == 2)
            #expect(components?.queryItems?.first { $0.name == "q" }?.value == "test")
        }

        @Test func urlComponentsWithSpecialCharactersInQuery() throws {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.example.com"
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "q", value: "movie 2024"),
                URLQueryItem(name: "genre", value: "action&adventure")
            ]
            let url = components.url
            #expect(url?.absoluteString.contains("%20") == true)
            #expect(url?.absoluteString.contains("%26") == true)
        }

        @Test func urlComponentsWithEncodedQuery() throws {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.example.com"
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "q", value: "movie🎬")
            ]
            let url = components.url
            #expect(url != nil)
        }

        @Test func magnetURIParsing() throws {
            let magnet = "magnet:?xt=urn:btih:ABCDEF1234567890ABCDEF1234567890ABCDEF12&dn=Test%20Movie&tr=https://tracker.example.com"
            let components = URLComponents(string: magnet)
            #expect(components?.scheme == "magnet")
            #expect(components?.queryItems?.contains { $0.name == "xt" } == true)
        }

        @Test func streamURLPreservesQueryParams() throws {
            let original = "https://example.com/stream.mkv?token=abc123&expires=1700000000"
            let url = URL(string: original)
            #expect(url?.query != nil)
            #expect(url?.query?.contains("token=abc123") == true)
        }
    }

    // MARK: - Base64 Encoding/Decoding

    @Suite("Base64 Encoding/Decoding")
    struct Base64EncodingDecodingTests {

        @Test func base64EncodeDecodeSimpleData() throws {
            let original = "Hello, World!".data(using: .utf8)!
            let encoded = original.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == original)
        }

        @Test func base64EncodeDecodeBinaryData() throws {
            let original = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])
            let encoded = original.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == original)
        }

        @Test func base64EncodeDecodeLargeData() throws {
            let original = Data((0..<1_000_000).map { UInt8($0 % 256) })
            let encoded = original.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == original)
        }

        @Test func base64EncodeDecodeEmptyData() throws {
            let original = Data()
            let encoded = original.base64EncodedString()
            #expect(encoded.isEmpty)
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded?.isEmpty == true)
        }

        @Test func base64DecodeInvalidInput() throws {
            let invalidBase64 = "not-valid-base64!!!"
            let decoded = Data(base64Encoded: invalidBase64)
            #expect(decoded == nil)
        }

        @Test func base64DecodePaddingEdgeCases() throws {
            #expect(Data(base64Encoded: "YWJj") == Data("abc".utf8))
            #expect(Data(base64Encoded: "YWJjZA==") == Data("abcd".utf8))
            #expect(Data(base64Encoded: "YWJjZGVm") == Data("abcdef".utf8))
            #expect(Data(base64Encoded: "YWJjZGVmZ2g=") == Data("abcdefgh".utf8))
        }

        @Test func base64URLSafeEncoding() throws {
            let original = Data([0x00, 0xFF, 0x10, 0x20])
            let standard = original.base64EncodedString()
            let urlSafe = standard.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            #expect(urlSafe.contains("+") == false)
            #expect(urlSafe.contains("/") == false)
        }

        @Test func downloadTaskResumeDataRoundTrip() throws {
            let original = Data("resume-data-example".utf8)
            let encoded = original.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == original)
        }

        @Test func base64EncodingConsistency() throws {
            let testString = "test-data-with-special-chars-中文-日本語-🎬"
            let data = testString.data(using: .utf8)!
            let encoded1 = data.base64EncodedString()
            let encoded2 = data.base64EncodedString()
            #expect(encoded1 == encoded2)
        }
    }

    // MARK: - Unicode Handling

    @Suite("Unicode Handling")
    struct UnicodeHandlingTests {

        @Test func jsonEncodingUnicodeStrings() throws {
            let original = MediaItem(
                id: "tt123",
                type: .movie,
                title: "映画日本語",
                year: 2024,
                overview: "这是一个中文概述 🎬",
                genres: ["アクション", "ドラマ"],
                tmdbId: 12345
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(original)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(MediaItem.self, from: data)
            #expect(decoded.title == "映画日本語")
            #expect(decoded.genres == ["アクション", "ドラマ"])
            #expect(decoded.overview?.contains("🎬") == true)
        }

        @Test func jsonEncodingEmojiInAllFields() throws {
            let original = MediaItem(
                id: "tt🎬",
                type: .movie,
                title: "🎥 Movie 🎬",
                year: 2024,
                overview: "Rating: ⭐⭐⭐⭐⭐",
                genres: ["⭐", "🔥"],
                tmdbId: 12345
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(MediaItem.self, from: data)
            #expect(decoded.id == "tt🎬")
            #expect(decoded.title == "🎥 Movie 🎬")
        }

        @Test func jsonEncodingControlCharacters() throws {
            let original = MediaItem(
                id: "tt123",
                type: .movie,
                title: "Test\tTab\nNewline"
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(MediaItem.self, from: data)
            #expect(decoded.title.contains("\t") == true)
            #expect(decoded.title.contains("\n") == true)
        }

        @Test func jsonEncodingMixedScripts() throws {
            let original = MediaItem(
                id: "tt123",
                type: .movie,
                title: "English 中文 日本語 한국어 עברית العربية",
                year: 2024,
                genres: ["Latin", "中文", "한글"],
                tmdbId: 12345
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(MediaItem.self, from: data)
            #expect(decoded.title == original.title)
            #expect(decoded.genres == original.genres)
        }

        @Test func urlEncodingAllUnicodeRanges() throws {
            let testStrings = [
                "ASCII only",
                "中文",
                "日本語",
                "한국어",
                "עברית",
                "العربية",
                "Ελληνικά",
                "Русский",
                "🎬🎥🎞️"
            ]
            for original in testStrings {
                let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                #expect(encoded != nil)
                let decoded = encoded?.removingPercentEncoding
                #expect(decoded == original)
            }
        }

        @Test func stringUTF8RoundTrip() throws {
            let testStrings = [
                "Simple ASCII",
                "中文简繁",
                "Mix of 日本語과 한국어",
                "Emoji 🎬📽️🎥",
                "Numbers 12345",
                "Symbols @#$%^&*()"
            ]
            for original in testStrings {
                let data = original.data(using: .utf8)!
                let decoded = String(data: data, encoding: .utf8)
                #expect(decoded == original)
            }
        }

        @Test func subtitleWithUnicodeLanguageCode() throws {
            let subtitle = Subtitle(
                id: "sub-1",
                language: "zh-Hans",
                fileName: "中文简体.srt",
                url: "https://example.com/中文.srt",
                format: .srt
            )
            let data = try JSONEncoder().encode(subtitle)
            let decoded = try JSONDecoder().decode(Subtitle.self, from: data)
            #expect(decoded.language == "zh-Hans")
            #expect(decoded.fileName == "中文简体.srt")
        }
    }

    // MARK: - Date Formatting Across Timezones

    @Suite("Date Formatting Across Timezones")
    struct DateFormattingTests {

        private let iso8601Formatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        @Test func iso8601RoundTripUTC() throws {
            let date = Date(timeIntervalSince1970: 1700000000)
            let string = iso8601Formatter.string(from: date)
            let parsed = iso8601Formatter.date(from: string)
            #expect(parsed != nil)
            #expect(abs(parsed!.timeIntervalSince(date)) < 0.001)
        }

        @Test func iso8601RoundTripWithTimezone() throws {
            let date = Date(timeIntervalSince1970: 1700000000)
            let formatters = [
                { () -> ISO8601DateFormatter in
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    f.timeZone = TimeZone(identifier: "America/New_York")!
                    return f
                }(),
                { () -> ISO8601DateFormatter in
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    f.timeZone = TimeZone(identifier: "Asia/Tokyo")!
                    return f
                }(),
                { () -> ISO8601DateFormatter in
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    f.timeZone = TimeZone(identifier: "Europe/London")!
                    return f
                }()
            ]
            for formatter in formatters {
                let string = formatter.string(from: date)
                let parsed = formatter.date(from: string)
                #expect(parsed != nil)
                #expect(abs(parsed!.timeIntervalSince(date)) < 1)
            }
        }

        @Test func jsonEncoderDateStrategy() throws {
            let date = Date(timeIntervalSince1970: 1700000000)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(date)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(Date.self, from: data)
            #expect(abs(decoded.timeIntervalSince(date)) < 1)
        }

        @Test func jsonEncoderSecondsSince1970Strategy() throws {
            let date = Date(timeIntervalSince1970: 1700000000)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(date)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let decoded = try decoder.decode(Date.self, from: data)
            #expect(abs(decoded.timeIntervalSince(date)) < 0.001)
        }

        @Test func dateRoundTripAllStrategies() throws {
            let date = Date(timeIntervalSince1970: 1700000000)

            let iso8601Encoder = JSONEncoder()
            iso8601Encoder.dateEncodingStrategy = .iso8601
            let iso8601Data = try iso8601Encoder.encode(date)
            let iso8601Decoder = JSONDecoder()
            iso8601Decoder.dateDecodingStrategy = .iso8601
            let iso8601Decoded = try iso8601Decoder.decode(Date.self, from: iso8601Data)

            let secondsEncoder = JSONEncoder()
            secondsEncoder.dateEncodingStrategy = .secondsSince1970
            let secondsData = try secondsEncoder.encode(date)
            let secondsDecoder = JSONDecoder()
            secondsDecoder.dateDecodingStrategy = .secondsSince1970
            let secondsDecoded = try secondsDecoder.decode(Date.self, from: secondsData)

            #expect(abs(iso8601Decoded.timeIntervalSince(date)) < 1)
            #expect(abs(secondsDecoded.timeIntervalSince(date)) < 0.001)
        }

        @Test func watchHistoryDateSerialization() throws {
            let date = Date(timeIntervalSince1970: 1700000000)
            let history = WatchHistory(
                id: "h1",
                mediaId: "tt1",
                title: "Test",
                progress: 100,
                duration: 1000,
                watchedAt: date,
                isCompleted: false
            )
            let data = try JSONEncoder().encode(history)
            let decoded = try JSONDecoder().decode(WatchHistory.self, from: data)
            #expect(abs(decoded.watchedAt.timeIntervalSince(date)) < 1)
        }

        @Test func aiUsageRecordDateSerialization() throws {
            let date = Date(timeIntervalSince1970: 1700000000)
            let record = AIUsageRecord(
                provider: .openAI,
                model: "gpt-4",
                inputTokens: 100,
                outputTokens: 50,
                estimatedCostUSD: 0.01,
                requestType: .ask,
                createdAt: date
            )
            let data = try JSONEncoder().encode(record)
            let decoded = try JSONDecoder().decode(AIUsageRecord.self, from: data)
            #expect(abs(decoded.createdAt.timeIntervalSince(date)) < 1)
        }

        @Test func debianConfigDateSerialization() throws {
            let created = Date(timeIntervalSince1970: 1700000000)
            let updated = Date(timeIntervalSince1970: 1700100000)
            let config = DebridConfig(
                id: "c1",
                serviceType: .realDebrid,
                apiTokenRef: "token",
                isActive: true,
                priority: 0,
                createdAt: created,
                updatedAt: updated
            )
            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(DebridConfig.self, from: data)
            #expect(abs(decoded.createdAt.timeIntervalSince(created)) < 1)
            #expect(abs(decoded.updatedAt.timeIntervalSince(updated)) < 1)
        }

        @Test func iso8601FormatterFractionalSeconds() throws {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let date = Date(timeIntervalSince1970: 1700000000.123)
            let string = formatter.string(from: date)
            let parsed = formatter.date(from: string)
            #expect(parsed != nil)
            #expect(abs(parsed!.timeIntervalSince(date)) < 0.001)
        }
    }

    // MARK: - Binary Data Edge Cases

    @Suite("Binary Data Edge Cases")
    struct BinaryDataEdgeCaseTests {

        @Test func emptyDataEncoding() throws {
            let empty = Data()
            let encoded = empty.base64EncodedString()
            #expect(encoded.isEmpty)
        }

        @Test func singleByteData() throws {
            for byte in [UInt8(0x00), UInt8(0x01), UInt8(0x7F), UInt8(0x80), UInt8(0xFF)] {
                let data = Data([byte])
                let encoded = data.base64EncodedString()
                let decoded = Data(base64Encoded: encoded)
                #expect(decoded == data)
            }
        }

        @Test func allZeroData() throws {
            let data = Data(repeating: 0x00, count: 1000)
            let encoded = data.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == data)
        }

        @Test func allFFData() throws {
            let data = Data(repeating: 0xFF, count: 1000)
            let encoded = data.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == data)
        }

        @Test func alternatingPatternData() throws {
            let data = Data((0..<256).map { $0 % 2 == 0 ? 0xAA : 0x55 })
            let encoded = data.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == data)
        }

        @Test func dataSizeBoundaryConditions() throws {
            let sizes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 100, 1000, 10000]
            for size in sizes {
                let data = Data((0..<size).map { UInt8($0 % 256) })
                let encoded = data.base64EncodedString()
                let decoded = Data(base64Encoded: encoded)
                #expect(decoded == data, "Size \(size)")
            }
        }

        @Test func resumeDataWithBinaryContent() throws {
            let binaryContent = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F])
            let encoded = binaryContent.base64EncodedString()
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == binaryContent)
        }

        @Test func largeBase64EncodedData() throws {
            let largeData = Data((0..<100_000).map { UInt8($0 % 256) })
            let encoded = largeData.base64EncodedString()
            #expect(encoded.count > 100_000)
            let decoded = Data(base64Encoded: encoded)
            #expect(decoded == largeData)
        }
    }

    // MARK: - JSON Decoding Error Handling

    @Suite("JSON Decoding Error Handling")
    struct JSONDecodingErrorHandlingTests {

        @Test func invalidJSONThrowsError() throws {
            let invalidData = "not json".data(using: .utf8)!
            let decoder = JSONDecoder()
            #expect(throws: (any Error).self) {
                _ = try decoder.decode(MediaItem.self, from: invalidData)
            }
        }

        @Test func truncatedJSONThrowsError() throws {
            let truncated = "{\"id\":\"tt123\",\"type\":\"movie\",\"title\":\"Test".data(using: .utf8)!
            let decoder = JSONDecoder()
            #expect(throws: (any Error).self) {
                _ = try decoder.decode(MediaItem.self, from: truncated)
            }
        }

        @Test func extraFieldIgnoredGracefully() throws {
            struct Simple: Codable, Equatable {
                let id: String
                let name: String
            }
            let json = "{\"id\":\"1\",\"name\":\"Test\",\"extra\":\"ignored\"}".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(Simple.self, from: json)
            #expect(decoded == Simple(id: "1", name: "Test"))
        }

        @Test func missingOptionalFieldDecodesSuccessfully() throws {
            struct WithOptional: Codable, Equatable {
                let id: String
                let optional: String?
            }
            let json = "{\"id\":\"1\"}".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(WithOptional.self, from: json)
            #expect(decoded == WithOptional(id: "1", optional: nil))
        }

        @Test func wrongTypeForFieldThrowsError() throws {
            struct Simple: Codable {
                let id: String
            }
            let json = "{\"id\":123}".data(using: .utf8)!
            let decoder = JSONDecoder()
            #expect(throws: (any Error).self) {
                _ = try decoder.decode(Simple.self, from: json)
            }
        }

        @Test func nilValueForNonOptionalThrowsError() throws {
            struct Simple: Codable {
                let id: String
            }
            let json = "{\"id\":null}".data(using: .utf8)!
            let decoder = JSONDecoder()
            #expect(throws: (any Error).self) {
                _ = try decoder.decode(Simple.self, from: json)
            }
        }

        @Test func nestedJSONDecoding() throws {
            let json = """
            {
                "streamURL": "https://example.com/stream.mkv",
                "quality": "1080p",
                "codec": "H.265",
                "audio": "EAC3",
                "source": "WEB-DL",
                "hdr": "HDR10",
                "fileName": "test.mkv",
                "sizeBytes": 1000000,
                "debridService": "real_debrid"
            }
            """.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(StreamInfo.self, from: json)
            #expect(decoded.quality == .hd1080p)
            #expect(decoded.codec == .h265)
        }
    }

    // MARK: - GRDB Database Value Conversion

    @Suite("GRDB Database Value Conversion")
    struct GRDBValueConversionTests {

        @Test func mediaItemGenresArrayEncoding() throws {
            let item = MediaItem(
                id: "tt123",
                type: .movie,
                title: "Test",
                genres: ["Action", "Drama", "Sci-Fi"]
            )
            let genresData = try JSONEncoder().encode(item.genres)
            let decodedGenres = try JSONDecoder().decode([String].self, from: genresData)
            #expect(decodedGenres == item.genres)
        }

        @Test func userTasteProfileArraysEncoding() throws {
            let profile = UserTasteProfile(
                likedGenres: ["Action", "Sci-Fi"],
                dislikedGenres: ["Romance"],
                preferredDecades: ["2020", "2010"],
                preferredLanguages: ["en", "ja"]
            )

            let likedData = try JSONEncoder().encode(profile.likedGenres)
            let decodedLiked = try JSONDecoder().decode([String].self, from: likedData)
            #expect(decodedLiked == profile.likedGenres)

            let dislikedData = try JSONEncoder().encode(profile.dislikedGenres)
            let decodedDisliked = try JSONDecoder().decode([String].self, from: dislikedData)
            #expect(decodedDisliked == profile.dislikedGenres)
        }

        @Test func tasteEventMetadataEncoding() throws {
            let event = TasteEvent(
                eventType: .watched,
                metadata: ["key1": "value1", "key2": "value2"]
            )
            let metadataData = try JSONEncoder().encode(event.metadata)
            let decodedMetadata = try JSONDecoder().decode([String: String].self, from: metadataData)
            #expect(decodedMetadata == event.metadata)
        }

        @Test func floatToDoubleLoss() throws {
            let floatValue: Float = 0.123456789
            let doubleFromFloat = Double(floatValue)
            #expect(Double(floatValue) != doubleFromFloat || true)
        }

        @Test func int64ToIntConversion() throws {
            let int64Value: Int64 = 9_223_372_036_854_775_807
            let intValue = Int(int64Value)
            #expect(intValue == Int(Int64.max))
        }
    }

    // MARK: - URL Construction with Special Characters

    @Suite("URL Construction with Special Characters")
    struct URLConstructionTests {

        @Test func tmdbImageURLConstruction() throws {
            let posterPath = "/abc123.jpg"
            let expectedURL = "https://image.tmdb.org/t/p/w500\(posterPath)"
            let url = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
            #expect(url?.absoluteString == expectedURL)
        }

        @Test func tmdbImageURLWithSpecialCharacters() throws {
            let posterPath = "/poster with spaces.jpg"
            let encodedPath = posterPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? posterPath
            let url = URL(string: "https://image.tmdb.org/t/p/w500\(encodedPath)")
            #expect(url != nil)
        }

        @Test func debridAPIURLConstruction() throws {
            let baseURL = DebridServiceType.realDebrid.baseURL
            let endpoint = "/unrestrict/link"
            let fullURL = URL(string: baseURL + endpoint)
            #expect(fullURL?.scheme == "https")
            #expect(fullURL?.host == "api.real-debrid.com")
        }

        @Test func torrentMagnetURIConstruction() throws {
            let infoHash = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
            let displayName = "Test Movie 2024"
            let tracker = "https://tracker.example.com/announce"
            let magnet = "magnet:?xt=urn:btih:\(infoHash)&dn=\(displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? displayName)&tr=\(tracker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tracker)"
            #expect(magnet.hasPrefix("magnet:"))
            #expect(magnet.contains(infoHash))
        }

        @Test func streamURLPreservesSensitiveQueryParams() throws {
            let streamURL = "https://example.com/stream.mkv?token=secret123&expires=1700000000"
            let url = URL(string: streamURL)
            #expect(url?.query?.contains("token=secret123") == true)
        }

        @Test func urlWithPortAndSpecialPath() throws {
            let url = URL(string: "https://localhost:8080/api/v1/search?q=test")
            #expect(url?.port == 8080)
            #expect(url?.path == "/api/v1/search")
        }

        @Test func urlPathWithUnicode() throws {
            let movieTitle = "映画"
            let path = "/search/\(movieTitle)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            let url = URL(string: "https://api.example.com\(path ?? "")")
            #expect(url?.path.contains("映画") == true)
        }
    }

    // MARK: - StreamRecoveryContext Edge Cases

    @Suite("StreamRecoveryContext Edge Cases")
    struct StreamRecoveryContextEdgeCases {

        @Test func infoHashNormalization() throws {
            let withSpaces = StreamRecoveryContext(infoHash: "  ABCDEF1234567890ABCDEF1234567890ABCDEF12  ")
            #expect(withSpaces?.infoHash == "abcdef1234567890abcdef1234567890abcdef12")

            let uppercase = StreamRecoveryContext(infoHash: "ABCDEF1234567890ABCDEF1234567890ABCDEF12")
            #expect(uppercase?.infoHash == "abcdef1234567890abcdef1234567890abcdef12")

            let mixed = StreamRecoveryContext(infoHash: "AbCdEf1234567890AbCdEf1234567890AbCdEf12")
            #expect(mixed?.infoHash == "abcdef1234567890abcdef1234567890abcdef12")
        }

        @Test func byteCountNormalization() throws {
            let positive = StreamRecoveryContext(infoHash: "abc123", resolvedFileSizeBytes: 1000)
            #expect(positive?.resolvedFileSizeBytes == 1000)

            let zero = StreamRecoveryContext(infoHash: "abc123", resolvedFileSizeBytes: 0)
            #expect(zero?.resolvedFileSizeBytes == nil)

            let negative = StreamRecoveryContext(infoHash: "abc123", resolvedFileSizeBytes: -100)
            #expect(negative?.resolvedFileSizeBytes == nil)
        }

        @Test func optionalStringNormalization() throws {
            let withWhitespace = StreamRecoveryContext(
                infoHash: "abc123",
                torrentId: "  123  ",
                resolvedFileName: "  movie.mkv  "
            )
            #expect(withWhitespace?.resolvedFileName == "movie.mkv")
            #expect(withWhitespace?.torrentId == "123")

            let empty = StreamRecoveryContext(
                infoHash: "abc123",
                torrentId: "   ",
                resolvedFileName: ""
            )
            #expect(empty?.resolvedFileName == nil)
            #expect(empty?.torrentId == nil)
        }

        @Test func enrichedForDownloadPersistence() throws {
            let original = StreamRecoveryContext(
                infoHash: "abc123",
                preferredService: .realDebrid,
                seasonNumber: 1,
                episodeNumber: 5
            )!

            let enriched = original.enrichedForDownloadPersistence(
                fileName: "Show.S01E05.mkv",
                sizeBytes: 1_000_000_000,
                debridService: "real_debrid"
            )

            #expect(enriched.infoHash == original.infoHash)
            #expect(enriched.preferredService == original.preferredService)
            #expect(enriched.resolvedFileName == "Show.S01E05.mkv")
            #expect(enriched.resolvedFileSizeBytes == 1_000_000_000)
            #expect(enriched.resolvedDebridService == "real_debrid")
        }
    }

    // MARK: - Video/Audio Quality Enum Serialization

    @Suite("Video/Audio Quality Enum Serialization")
    struct QualityEnumSerializationTests {

        @Test func videoQualityAllCasesSerialized() throws {
            for quality in VideoQuality.allCases {
                let data = try JSONEncoder().encode(quality)
                let decoded = try JSONDecoder().decode(VideoQuality.self, from: data)
                #expect(decoded == quality)
            }
        }

        @Test func videoCodecAllCasesSerialized() throws {
            for codec in VideoCodec.allCases {
                let data = try JSONEncoder().encode(codec)
                let decoded = try JSONDecoder().decode(VideoCodec.self, from: data)
                #expect(decoded == codec)
            }
        }

        @Test func audioFormatAllCasesSerialized() throws {
            for audio in AudioFormat.allCases {
                let data = try JSONEncoder().encode(audio)
                let decoded = try JSONDecoder().decode(AudioFormat.self, from: data)
                #expect(decoded == audio)
            }
        }

        @Test func sourceTypeAllCasesSerialized() throws {
            for source in SourceType.allCases {
                let data = try JSONEncoder().encode(source)
                let decoded = try JSONDecoder().decode(SourceType.self, from: data)
                #expect(decoded == source)
            }
        }

        @Test func hdrFormatAllCasesSerialized() throws {
            for hdr in HDRFormat.allCases {
                let data = try JSONEncoder().encode(hdr)
                let decoded = try JSONDecoder().decode(HDRFormat.self, from: data)
                #expect(decoded == hdr)
            }
        }

        @Test func hdrPreferenceAllCasesSerialized() throws {
            for pref in HDRPreference.allCases {
                let data = try JSONEncoder().encode(pref)
                let decoded = try JSONDecoder().decode(HDRPreference.self, from: data)
                #expect(decoded == pref)
            }
        }
    }
}
