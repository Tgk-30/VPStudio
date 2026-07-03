#if os(visionOS)
import AVFoundation
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("PlayerView Immersive Control Handler Runtime", .serialized)
struct PlayerImmersiveControlHandlerRuntimeTests {
    @Test func playerViewReceivesEveryImmersiveControlNotificationOnVisionOS() throws {
        let stream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/vision-player-controls.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Vision.Player.Controls.1080p.mp4",
            sizeBytes: 1_024,
            debridService: "fixture"
        )
        let appState = AppState(testHooks: .init())
        let engine = VPPlayerEngine()
        engine.currentTime = 55
        engine.duration = 200
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Opening", startTime: 0, endTime: 100),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Middle", startTime: 100, endTime: 200),
        ]
        let probe = ImmersiveControlEventProbe()

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: stream,
                mediaTitle: "Vision Player Controls",
                mediaId: "vision-player-controls",
                sessionID: UUID(),
                initialPlaybackState: .playing,
                initialActiveEngine: nil,
                disablesAutomaticTasks: true,
                onImmersiveControlEvent: { probe.record($0) }
            )
            .environment(appState)
            .environment(engine)
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        let notifications: [(Notification.Name, Any?)] = [
            (.immersiveTapCatcherDidFire, nil),
            (.immersiveControlTogglePlayPause, nil),
            (.immersiveControlSeekBack, nil),
            (.immersiveControlSeekForward, nil),
            (.immersiveControlSeekToPercent, NSNumber(value: 0.42)),
            (.immersiveControlPreviousChapter, nil),
            (.immersiveControlNextChapter, nil),
            (.immersiveControlCycleRate, nil),
            (.immersiveControlToggleSubtitles, nil),
            (.immersiveControlToggleAudio, nil),
            (.immersiveControlRequestEnvironmentSwitch, nil),
            (.immersiveControlDismiss, nil),
        ]

        for (name, object) in notifications {
            NotificationCenter.default.post(name: name, object: object)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        #expect(probe.events == [
            .toggleControls,
            .togglePlayPause,
            .seekBack,
            .seekForward,
            .seekToPercent(0.42),
            .previousChapter,
            .nextChapter,
            .cycleRate,
            .toggleSubtitles,
            .toggleAudio,
            .requestEnvironmentSwitch,
            .dismiss,
        ])
        #expect(engine.currentTime >= 0)
        #expect(hosted.host.view.bounds.width > 0)
    }
}

@MainActor
@Suite("PlayerView Autoplay Control Handler Runtime", .serialized)
struct PlayerAutoplayControlHandlerRuntimeTests {
    @Test func playerViewAutoplayNotificationsDrivePlayNowAndCancelBranches() async throws {
        let appState = AppState(testHooks: .init())
        try await appState.settingsManager.setBool(key: SettingsKeys.autoPlayNext, value: true)
        let probe = AutoplayRuntimeProbe()

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Autoplay Runtime",
                mediaId: "autoplay-runtime",
                episodeId: "s1e1",
                nextEpisode: makeNextEpisode(),
                sessionID: UUID(),
                initialPlaybackState: .playing,
                initialIsShowingAutoPlayNextPrompt: true,
                initialAutoPlayNextCountdownRemaining: 4,
                disablesAutomaticTasks: true,
                onAutoplayRuntimeEvent: { probe.record($0) }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerAutoplayControlPlayNow, object: nil)
        runPlayerRuntimeLoop(until: {
            probe.snapshots.contains { $0.isResolvingAutoPlayNextEpisode }
        })
        runPlayerRuntimeLoop(until: {
            probe.snapshots.contains {
                $0.didRequestAutoplayNext &&
                !$0.isShowingAutoPlayNextPrompt &&
                !$0.isResolvingAutoPlayNextEpisode
            }
        })

        NotificationCenter.default.post(name: .playerAutoplayControlCancel, object: nil)
        runPlayerRuntimeLoop(until: {
            probe.snapshots.contains {
                $0.didCancelAutoPlayNextPrompt &&
                !$0.isShowingAutoPlayNextPrompt
            }
        })

        #expect(probe.events.contains(.playNowRequested))
        #expect(probe.events.contains(.cancelRequested))
        #expect(probe.snapshots.contains { $0.countdownRemaining == 0 && $0.didRequestAutoplayNext })
        #expect(probe.snapshots.contains { $0.isResolvingAutoPlayNextEpisode })
        #expect(probe.snapshots.contains { $0.didCancelAutoPlayNextPrompt && !$0.isShowingAutoPlayNextPrompt })
    }

    @Test func playerViewAutoplayProgressNotificationRespectsDisabledSetting() async throws {
        let appState = AppState(testHooks: .init())
        try await appState.settingsManager.setBool(key: SettingsKeys.autoPlayNext, value: false)
        let probe = AutoplayRuntimeProbe()

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Autoplay Progress",
                mediaId: "autoplay-progress",
                episodeId: "s1e1",
                nextEpisode: makeNextEpisode(),
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onAutoplayRuntimeEvent: { probe.record($0) }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(
            name: .playerAutoplayControlProgress,
            object: nil,
            userInfo: [
                PlayerAutoplayControlNotificationKey.currentTime: TimeInterval(95),
                PlayerAutoplayControlNotificationKey.duration: TimeInterval(100),
            ]
        )
        runPlayerRuntimeLoop(until: {
            probe.snapshots.contains {
                $0.didRequestAutoplayNext &&
                !$0.isShowingAutoPlayNextPrompt &&
                !$0.isResolvingAutoPlayNextEpisode
            }
        })

        #expect(probe.events.contains(.progressObserved(currentTime: 95, duration: 100)))
        #expect(probe.snapshots.contains { $0.didRequestAutoplayNext })
        #expect(!probe.snapshots.contains { $0.isShowingAutoPlayNextPrompt })
        #expect(!probe.snapshots.contains { $0.isResolvingAutoPlayNextEpisode })
    }
}

@MainActor
@Suite("PlayerView Subtitle Control Handler Runtime", .serialized)
struct PlayerSubtitleControlHandlerRuntimeTests {
    @Test func playerViewHookedAVPreparationDrivesObserverAndCleanup() async throws {
        let stream = makeAutoplayStream()
        let sessionID = UUID()
        let appState = AppState(testHooks: .init())
        appState.activePlayerSession = PlayerSessionRequest(
            id: sessionID,
            stream: stream,
            mediaTitle: "Hooked AV Preparation",
            mediaId: "hooked-av-preparation"
        )
        let engine = VPPlayerEngine()
        let observerProbe = AVTimeObserverRuntimeProbe()
        let player = AVPlayer()

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: stream,
                mediaTitle: "Hooked AV Preparation",
                mediaId: "hooked-av-preparation",
                sessionID: sessionID,
                disablesAutomaticTasks: false,
                prepareAVPlayerSessionOverride: { stream in
                    PreparedPlaybackSession(
                        engineKind: .avPlayer,
                        streamURL: stream.streamURL,
                        avPlayer: player,
                        ksPlayerCoordinator: nil,
                        ksOptions: nil
                    )
                },
                waitUntilAVPlayerReadyOverride: { _, onState in
                    onState(.playing, "AVPlayer test hook is ready.")
                },
                avTimeObserverHooks: PlayerViewAVTimeObserverHooks(
                    addPeriodicTimeObserver: { _, _, callback in
                        observerProbe.capture(callback)
                        return observerProbe.token
                    },
                    removeTimeObserver: { _, token in
                        observerProbe.remove(token)
                    }
                )
            )
            .environment(appState)
            .environment(engine)
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )

        await waitForPlayerRuntimeAsync(timeout: 2) {
            observerProbe.hasCallback()
        }
        observerProbe.fire(CMTime(seconds: 2.5, preferredTimescale: 600))
        await waitForPlayerRuntimeMainActor(timeout: 2) {
            engine.currentTime == 2.5
        }
        #expect(engine.currentTime == 2.5)

        tearDownPlayerImmersiveControlWindow(hosted.window)
        runPlayerRuntimeLoop(until: { appState.activePlayerSession == nil })
        runPlayerRuntimeLoop(until: { observerProbe.didRemoveToken() }, timeout: 2)

        #expect(observerProbe.didRemoveToken())
        #expect(appState.activePlayerSession == nil)
    }

    @Test func playerViewHookedAVPreparationAutoLoadsSubtitlesWithInjectedService() async throws {
        let appState = AppState(testHooks: .init())

        let engine = VPPlayerEngine()
        var stream = makeAutoplayStream()
        stream.recoveryContext = StreamRecoveryContext(
            infoHash: "0123456789abcdef0123456789abcdef01234567",
            seasonNumber: 1,
            episodeNumber: 2
        )
        let service = PlayerSubtitleRuntimeService(
            searchResult: .success([
                makeSubtitle(id: "auto", fileName: "Autoload.Runtime.en.srt", fileId: 88, format: .srt),
            ]),
            downloadResult: .success(Self.fixtureSubtitleContent)
        )
        let probe = SubtitleRuntimeProbe()
        let player = AVPlayer()

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: stream,
                mediaTitle: "Subtitle Autoload Runtime",
                mediaId: "tt7654321",
                sessionID: UUID(),
                disablesAutomaticTasks: false,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(
                    openSubtitlesAPIKey: "subtitle-key",
                    subtitleLanguage: "en",
                    subtitleAutoSearch: true
                ),
                prepareAVPlayerSessionOverride: { stream in
                    PreparedPlaybackSession(
                        engineKind: .avPlayer,
                        streamURL: stream.streamURL,
                        avPlayer: player,
                        ksPlayerCoordinator: nil,
                        ksOptions: nil
                    )
                },
                waitUntilAVPlayerReadyOverride: { _, onState in
                    onState(.playing, "AVPlayer test hook is ready.")
                },
                avTimeObserverHooks: PlayerViewAVTimeObserverHooks(
                    addPeriodicTimeObserver: { _, _, _ in NSObject() },
                    removeTimeObserver: { _, _ in }
                ),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(engine)
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        await waitForPlayerRuntimeAsync(timeout: 2) {
            await service.firstMatchRequests().count >= 1
        }
        await waitForPlayerRuntimeMainActor(timeout: 2) {
            engine.selectedSubtitleTrack == 0 && engine.subtitlesEnabled
        }

        let requests = await service.firstMatchRequests()
        #expect(!requests.isEmpty)
        #expect(requests.allSatisfy { $0.imdbId == "tt7654321" })
        #expect(requests.allSatisfy { $0.tmdbId == nil })
        #expect(requests.allSatisfy { $0.query == "Autoplay Runtime 1080p" })
        #expect(requests.allSatisfy { $0.languages == ["en"] })
        #expect(requests.allSatisfy { $0.season == 1 && $0.episode == 2 })
        #expect(engine.selectedSubtitleTrack == 0)
        #expect(engine.subtitlesEnabled)
        #expect(probe.snapshots.contains { $0.selectedSubtitleTrack == 0 && $0.subtitlesEnabled })
    }

    @Test func playerViewSubtitleRefreshNotificationSearchesCatalogWithInjectedService() async throws {
        let appState = AppState(testHooks: .init())

        let service = PlayerSubtitleRuntimeService(
            searchResult: .success([
                makeSubtitle(id: "supported", fileName: "Autoplay.Runtime.en.srt", fileId: 42, format: .srt),
                makeSubtitle(id: "unsupported", fileName: "Autoplay.Runtime.txt", fileId: 43, format: .unknown),
            ]),
            downloadResult: .success(Self.fixtureSubtitleContent)
        )
        let probe = SubtitleRuntimeProbe()
        var stream = makeAutoplayStream()
        stream.recoveryContext = StreamRecoveryContext(
            infoHash: "0123456789abcdef0123456789abcdef01234567",
            seasonNumber: 1,
            episodeNumber: 2
        )

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: stream,
                mediaTitle: "Subtitle Catalog",
                mediaId: "tt1234567",
                tmdbId: 55_555,
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(
                    openSubtitlesAPIKey: "subtitle-key",
                    subtitleLanguage: "en"
                ),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerSubtitleControlRefreshCatalog, object: nil)
        await waitForPlayerRuntimeAsync {
            await service.searchRequests().count == 1
        }

        let requests = await service.searchRequests()
        #expect(probe.events.contains(.refreshRequested))
        #expect(probe.snapshots.contains { $0.isRefreshingSubtitleCatalog })
        #expect(requests.count == 1)
        #expect(requests.first?.imdbId == "tt1234567")
        // IMDb-first policy (see lookupIDsPreferIMDbAndUseTMDBOnlyAsLegacyFallback):
        // when an IMDb id is present, the TMDb id is dropped from subtitle lookup.
        #expect(requests.first?.tmdbId == nil)
        #expect(requests.first?.languages == ["en"])
        #expect(requests.first?.season == 1)
        #expect(requests.first?.episode == 2)
    }

    @Test func playerViewSubtitleRefreshNotificationReportsMissingAPIKeyWithoutSearching() async throws {
        let appState = AppState(testHooks: .init())
        let service = PlayerSubtitleRuntimeService(
            searchResult: .success([
                makeSubtitle(id: "unused", fileName: "Unused.en.srt", fileId: 42, format: .srt),
            ]),
            downloadResult: .success(Self.fixtureSubtitleContent)
        )
        let probe = SubtitleRuntimeProbe()

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Subtitle Missing Key",
                mediaId: "tt1234567",
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(openSubtitlesAPIKey: nil),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerSubtitleControlRefreshCatalog, object: nil)
        await waitForPlayerRuntimeMainActor {
            probe.snapshots.contains {
                $0.catalogMessage == PlayerSubtitleServicePolicy.missingCatalogAPIKeyMessage &&
                !$0.isRefreshingSubtitleCatalog
            }
        }

        let requests = await service.searchRequests()
        #expect(probe.events.contains(.refreshRequested))
        #expect(requests.isEmpty)
        #expect(probe.snapshots.contains {
            $0.catalogMessage == PlayerSubtitleServicePolicy.missingCatalogAPIKeyMessage &&
            !$0.isRefreshingSubtitleCatalog
        })
    }

    @Test func playerViewSubtitleRefreshNotificationSurfacesSearchFailure() async throws {
        let appState = AppState(testHooks: .init())

        let service = PlayerSubtitleRuntimeService(
            searchResult: .failure(PlayerRuntimeTestError.searchFailed),
            downloadResult: .success(Self.fixtureSubtitleContent)
        )
        let probe = SubtitleRuntimeProbe()

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Subtitle Search Failure",
                mediaId: "tt1234567",
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(
                    openSubtitlesAPIKey: "subtitle-key",
                    subtitleLanguage: "en"
                ),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerSubtitleControlRefreshCatalog, object: nil)
        await waitForPlayerRuntimeAsync {
            await service.searchRequests().count == 1
        }
        await waitForPlayerRuntimeMainActor {
            probe.snapshots.contains {
                $0.catalogMessage == PlayerRuntimeTestError.searchFailed.localizedDescription &&
                !$0.isRefreshingSubtitleCatalog
            }
        }

        let requests = await service.searchRequests()
        #expect(requests.count == 1)
        #expect(probe.snapshots.contains {
            $0.candidateCount == 0 &&
            $0.catalogMessage == PlayerRuntimeTestError.searchFailed.localizedDescription &&
            !$0.isRefreshingSubtitleCatalog
        })
    }

    @Test func playerViewSubtitleDownloadNotificationDownloadsAndSelectsSubtitle() async throws {
        let appState = AppState(testHooks: .init())
        let engine = VPPlayerEngine()
        let service = PlayerSubtitleRuntimeService(
            searchResult: .success([]),
            downloadResult: .success(Self.fixtureSubtitleContent)
        )
        let probe = SubtitleRuntimeProbe()
        let subtitle = makeSubtitle(id: "downloadable", fileName: "Runtime.Download.en.srt", fileId: 77, format: .srt)

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Subtitle Download",
                mediaId: "tt1234567",
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(openSubtitlesAPIKey: "subtitle-key"),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(engine)
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerSubtitleControlDownload, object: subtitle)
        await waitForPlayerRuntimeAsync {
            await service.downloadFileIDs().contains(77)
        }
        runPlayerRuntimeLoop(until: {
            engine.selectedSubtitleTrack == 0 && engine.subtitlesEnabled
        })
        let downloadedIDs = await service.downloadFileIDs()

        #expect(probe.events.contains(.downloadRequested(fileID: 77)))
        #expect(downloadedIDs.contains(77), "download IDs: \(downloadedIDs), snapshots: \(probe.snapshots)")
        #expect(engine.selectedSubtitleTrack == 0)
        #expect(engine.subtitlesEnabled)
    }

    @Test func playerViewSubtitleDownloadNotificationRejectsUnsupportedSubtitle() async throws {
        let appState = AppState(testHooks: .init())
        let service = PlayerSubtitleRuntimeService(
            searchResult: .success([]),
            downloadResult: .success(Self.fixtureSubtitleContent)
        )
        let probe = SubtitleRuntimeProbe()
        let subtitle = makeSubtitle(id: "unsupported", fileName: "Runtime.Download.txt", fileId: 78, format: .unknown)

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Subtitle Unsupported",
                mediaId: "tt1234567",
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(openSubtitlesAPIKey: "subtitle-key"),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerSubtitleControlDownload, object: subtitle)
        await waitForPlayerRuntimeMainActor {
            probe.snapshots.contains {
                $0.catalogMessage == PlayerSubtitleServicePolicy.unsupportedSubtitleMessage
            }
        }

        let downloadedIDs = await service.downloadFileIDs()
        #expect(probe.events.contains(.downloadRequested(fileID: 78)))
        #expect(downloadedIDs.isEmpty)
        #expect(probe.snapshots.contains {
            $0.catalogMessage == PlayerSubtitleServicePolicy.unsupportedSubtitleMessage &&
            !$0.isDownloadingSubtitle
        })
    }

    @Test func playerViewSubtitleDownloadNotificationReportsMissingAPIKey() async throws {
        let appState = AppState(testHooks: .init())
        let service = PlayerSubtitleRuntimeService(
            searchResult: .success([]),
            downloadResult: .success(Self.fixtureSubtitleContent)
        )
        let probe = SubtitleRuntimeProbe()
        let subtitle = makeSubtitle(id: "missing-key", fileName: "Runtime.Download.en.srt", fileId: 79, format: .srt)

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Subtitle Missing Download Key",
                mediaId: "tt1234567",
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(openSubtitlesAPIKey: nil),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerSubtitleControlDownload, object: subtitle)
        await waitForPlayerRuntimeMainActor {
            probe.snapshots.contains {
                $0.catalogMessage == PlayerSubtitleServicePolicy.missingDownloadAPIKeyMessage
            }
        }

        let downloadedIDs = await service.downloadFileIDs()
        #expect(probe.events.contains(.downloadRequested(fileID: 79)))
        #expect(downloadedIDs.isEmpty)
        #expect(probe.snapshots.contains {
            $0.catalogMessage == PlayerSubtitleServicePolicy.missingDownloadAPIKeyMessage &&
            !$0.isDownloadingSubtitle
        })
    }

    @Test func playerViewSubtitleDownloadNotificationSurfacesDownloadFailure() async throws {
        let appState = AppState(testHooks: .init())
        let service = PlayerSubtitleRuntimeService(
            searchResult: .success([]),
            downloadResult: .failure(PlayerRuntimeTestError.downloadFailed)
        )
        let probe = SubtitleRuntimeProbe()
        let subtitle = makeSubtitle(id: "download-failure", fileName: "Runtime.Download.en.srt", fileId: 80, format: .srt)

        let hosted = try hostPlayerImmersiveControlWindow(
            PlayerView(
                stream: makeAutoplayStream(),
                mediaTitle: "Subtitle Download Failure",
                mediaId: "tt1234567",
                sessionID: UUID(),
                initialPlaybackState: .playing,
                disablesAutomaticTasks: true,
                onSubtitleRuntimeEvent: { probe.record($0) },
                subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings(openSubtitlesAPIKey: "subtitle-key"),
                subtitleServiceFactory: { _ in service }
            )
            .environment(appState)
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        )
        defer { tearDownPlayerImmersiveControlWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        spinPlayerRuntimeLoop(for: 0.12)

        NotificationCenter.default.post(name: .playerSubtitleControlDownload, object: subtitle)
        await waitForPlayerRuntimeAsync {
            await service.downloadFileIDs().contains(80)
        }
        await waitForPlayerRuntimeMainActor {
            probe.snapshots.contains {
                $0.catalogMessage == PlayerRuntimeTestError.downloadFailed.localizedDescription &&
                !$0.isDownloadingSubtitle
            }
        }

        let downloadedIDs = await service.downloadFileIDs()
        #expect(probe.events.contains(.downloadRequested(fileID: 80)))
        #expect(downloadedIDs.contains(80))
        #expect(probe.snapshots.contains { $0.isDownloadingSubtitle })
        #expect(probe.snapshots.contains {
            $0.catalogMessage == PlayerRuntimeTestError.downloadFailed.localizedDescription &&
            !$0.isDownloadingSubtitle
        })
    }

    private static let fixtureSubtitleContent = """
    1
    00:00:00,000 --> 00:00:01,000
    Runtime subtitle
    """
}

@MainActor
private final class ImmersiveControlEventProbe {
    private(set) var events: [PlayerImmersiveControlEvent] = []

    func record(_ event: PlayerImmersiveControlEvent) {
        events.append(event)
    }
}

@MainActor
private final class AutoplayRuntimeProbe {
    private(set) var events: [PlayerAutoplayRuntimeEvent] = []

    var snapshots: [PlayerAutoplayRuntimeSnapshot] {
        events.compactMap { event in
            if case .stateChanged(let snapshot) = event { return snapshot }
            return nil
        }
    }

    func record(_ event: PlayerAutoplayRuntimeEvent) {
        events.append(event)
    }
}

@MainActor
private final class SubtitleRuntimeProbe {
    private(set) var events: [PlayerSubtitleRuntimeEvent] = []

    var snapshots: [PlayerSubtitleRuntimeSnapshot] {
        events.compactMap { event in
            if case .stateChanged(let snapshot) = event { return snapshot }
            return nil
        }
    }

    func record(_ event: PlayerSubtitleRuntimeEvent) {
        events.append(event)
    }
}

private enum PlayerRuntimeTestError: LocalizedError {
    case searchFailed
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .searchFailed:
            return "Subtitle search failed"
        case .downloadFailed:
            return "Subtitle download failed"
        }
    }
}

private actor PlayerSubtitleRuntimeService: OpenSubtitlesServicing {
    struct SearchRequest: Equatable {
        var imdbId: String?
        var tmdbId: Int?
        var query: String?
        var season: Int?
        var episode: Int?
        var languages: [String]
    }

    private let searchResult: Result<[Subtitle], Error>
    private let downloadResult: Result<String, Error>
    private var recordedSearchRequests: [SearchRequest] = []
    private var recordedDownloadFileIDs: [Int] = []
    private var recordedFirstMatchRequests: [FirstMatchRequest] = []

    struct FirstMatchRequest: Equatable {
        var imdbId: String?
        var tmdbId: Int?
        var query: String
        var languages: [String]
        var season: Int?
        var episode: Int?
    }

    init(searchResult: Result<[Subtitle], Error>, downloadResult: Result<String, Error>) {
        self.searchResult = searchResult
        self.downloadResult = downloadResult
    }

    func search(
        imdbId: String?,
        tmdbId: Int?,
        query: String?,
        season: Int?,
        episode: Int?,
        languages: [String]
    ) async throws -> [Subtitle] {
        recordedSearchRequests.append(SearchRequest(
            imdbId: imdbId,
            tmdbId: tmdbId,
            query: query,
            season: season,
            episode: episode,
            languages: languages
        ))
        return try searchResult.get()
    }

    func downloadSubtitle(fileId: Int) async throws -> String {
        recordedDownloadFileIDs.append(fileId)
        return try downloadResult.get()
    }

    func downloadFirstMatch(
        query: String,
        languages: [String]
    ) async throws -> Subtitle {
        try await downloadFirstMatch(query: query, languages: languages, season: nil, episode: nil)
    }

    func downloadFirstMatch(
        query: String,
        languages: [String],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle {
        try await downloadFirstMatch(
            imdbId: nil,
            tmdbId: nil,
            query: query,
            languages: languages,
            season: season,
            episode: episode
        )
    }

    func downloadFirstMatch(
        imdbId: String?,
        tmdbId: Int?,
        query: String,
        languages: [String],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle {
        recordedFirstMatchRequests.append(FirstMatchRequest(
            imdbId: imdbId,
            tmdbId: tmdbId,
            query: query,
            languages: languages,
            season: season,
            episode: episode
        ))
        guard let subtitle = try searchResult.get().first else {
            throw SubtitleError.noSubtitlesFound
        }
        return subtitle
    }

    func searchRequests() -> [SearchRequest] {
        recordedSearchRequests
    }

    func downloadFileIDs() -> [Int] {
        recordedDownloadFileIDs
    }

    func firstMatchRequests() -> [FirstMatchRequest] {
        recordedFirstMatchRequests
    }
}

@MainActor
private final class AVTimeObserverRuntimeProbe {
    let token = NSObject()
    private var callback: ((CMTime) -> Void)?
    private var removedToken: Any?

    func capture(_ callback: @escaping (CMTime) -> Void) {
        self.callback = callback
    }

    func remove(_ token: Any) {
        removedToken = token
    }

    func fire(_ time: CMTime) {
        callback?(time)
    }

    func hasCallback() -> Bool {
        callback != nil
    }

    func didRemoveToken() -> Bool {
        guard let removedToken else { return false }
        return (removedToken as AnyObject) === token
    }
}

private func makeAutoplayStream() -> StreamInfo {
    StreamInfo(
        streamURL: URL(string: "https://cdn.example.com/autoplay-runtime.mp4")!,
        quality: .hd1080p,
        codec: .h264,
        audio: .aac,
        source: .webDL,
        hdr: .sdr,
        fileName: "Autoplay.Runtime.1080p.mp4",
        sizeBytes: 1_024,
        debridService: "fixture"
    )
}

private func makeSubtitle(
    id: String,
    fileName: String,
    fileId: Int?,
    format: SubtitleFormat
) -> Subtitle {
    Subtitle(
        id: id,
        language: "en",
        fileName: fileName,
        url: "https://subtitles.example.com/\(fileName)",
        format: format,
        fileId: fileId,
        rating: 8.0,
        downloadCount: 12,
        isHearingImpaired: false,
        source: "OpenSubtitles"
    )
}

private func makeNextEpisode() -> PlayerSessionRequest.NextEpisodeCandidate {
    PlayerSessionRequest.NextEpisodeCandidate(
        episodeId: "s1e2",
        seasonNumber: 1,
        episodeNumber: 2,
        title: "Episode 2"
    )
}

@MainActor
private func runPlayerRuntimeLoop(
    until condition: @MainActor () -> Bool,
    timeout: TimeInterval = 1.0
) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
}

@MainActor
private func spinPlayerRuntimeLoop(for interval: TimeInterval) {
    RunLoop.main.run(until: Date().addingTimeInterval(interval))
}

private func waitForPlayerRuntimeAsync(
    timeout: TimeInterval = 1.0,
    condition: () async -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(20))
    }
}

@MainActor
private func waitForPlayerRuntimeMainActor(
    timeout: TimeInterval = 1.0,
    condition: @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(20))
    }
}

@MainActor
private func hostPlayerImmersiveControlWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<AnyView>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let host = UIHostingController(rootView: AnyView(rootView))
    host.view.backgroundColor = .clear
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.frame = CGRect(x: 0, y: 0, width: 980, height: 620)
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownPlayerImmersiveControlWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.isHidden = true
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
}
#endif
