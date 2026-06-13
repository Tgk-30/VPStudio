import Foundation
import Testing
@testable import VPStudio

@Suite("Player View Runtime Policy Contracts - Autoplay")
struct PlayerViewRuntimeAutoplayPolicyContractTests {
    @Test
    func autoplayResolutionUsesStatePolicyForPreflightMessagesAndFinishOutcome() throws {
        let body = try functionBody(named: "autoPlayNextEpisodeIfPossible", in: playerViewSource())

        #expect(body.contains("switch PlayerViewStatePolicy.autoplayNextPreflight("))
        #expect(body.contains("isCancelled: Task.isCancelled"))
        #expect(body.contains("nextEpisode: queuedNextEpisode"))
        #expect(containsIgnoringWhitespace(
            body,
            """
            case .finishUnavailable:
                applyAutoPlayNextPromptState(
                    PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
                        from: autoPlayNextPromptState,
                        outcome: .unavailable
                    )
                )
                autoPlayNextResolveTask = nil
                return
            case .proceed(let queuedEpisode):
                nextEpisode = queuedEpisode
                isShowingAutoPlayNextPrompt = true
                playbackMessage = PlayerViewStatePolicy.autoplayNextLoadingMessage(for: nextEpisode)
            """
        ))
        #expect(body.contains("outcome: PlayerViewStatePolicy.autoplayResolutionFinishOutcome("))
        #expect(body.contains("hasQueuedNextEpisode: queuedNextEpisode != nil"))
        #expect(body.contains("playbackMessage = PlayerViewStatePolicy.autoplayNextFailureMessage("))
        #expect(!body.contains("guard let nextEpisode = queuedNextEpisode else { return }"))

        let preflightRange = try requiredRange(
            of: "switch PlayerViewStatePolicy.autoplayNextPreflight(",
            in: body
        )
        let loadingMessageRange = try requiredRange(
            of: "playbackMessage = PlayerViewStatePolicy.autoplayNextLoadingMessage(for: nextEpisode)",
            in: body
        )
        let deferRange = try requiredRange(of: "defer {", in: body)
        let finishOutcomeRange = try requiredRange(
            of: "outcome: PlayerViewStatePolicy.autoplayResolutionFinishOutcome(",
            in: body
        )
        let failureMessageRange = try requiredRange(
            of: "playbackMessage = PlayerViewStatePolicy.autoplayNextFailureMessage(",
            in: body
        )

        #expect(preflightRange.lowerBound < loadingMessageRange.lowerBound)
        #expect(loadingMessageRange.lowerBound < deferRange.lowerBound)
        #expect(deferRange.lowerBound < finishOutcomeRange.lowerBound)
        #expect(finishOutcomeRange.lowerBound < failureMessageRange.lowerBound)
    }
}

@Suite("Player View Runtime Policy Contracts - Audio")
struct PlayerViewRuntimeAudioPolicyContractTests {
    @Test
    func avPlayerPreparationGuardsDelayedTrackRefreshWithTheSharedAudioPolicy() throws {
        let source = try playerViewSource()
        let body = try section(
            from: "// Torrent/direct streams may not expose audio tracks immediately.",
            to: "await loadChapters(from: player)",
            in: source
        )

        #expect(body.contains("audioTrackRefreshTask?.cancel()"))
        #expect(body.contains("audioTrackRefreshTask = Task { @MainActor in"))
        #expect(body.contains("try? await Task.sleep(for: .milliseconds(2000))"))
        #expect(body.contains("Self.audioTrackRefreshShouldRun("))
        #expect(body.contains("requestedStreamID: streamID"))
        #expect(body.contains("currentStreamID: currentStream.id"))
        #expect(body.contains("await refreshAVMediaOptions(for: player)"))

        let sleepRange = try requiredRange(
            of: "try? await Task.sleep(for: .milliseconds(2000))",
            in: body
        )
        let guardRange = try requiredRange(of: "Self.audioTrackRefreshShouldRun(", in: body)
        let refreshRange = try requiredRange(of: "await refreshAVMediaOptions(for: player)", in: body)

        #expect(sleepRange.lowerBound < guardRange.lowerBound)
        #expect(guardRange.lowerBound < refreshRange.lowerBound)
    }

    @Test
    func ksTrackRefreshLoopUsesSharedDelaysAndCoordinatorGuardsBeforeRefreshingAudioAndSubtitles() throws {
        let body = try functionBody(named: "scheduleKSTrackRefresh", in: playerViewSource())

        #expect(body.contains("for delay in PlayerViewStatePolicy.scheduledKSTrackRefreshDelaysMilliseconds()"))
        #expect(body.contains("PlayerViewStatePolicy.shouldRunScheduledKSTrackRefresh("))
        #expect(body.contains("requestedStreamID: stream.id"))
        #expect(body.contains("currentStreamID: currentStream.id"))
        #expect(body.contains("hasCurrentCoordinator: ksPlayerCoordinator.map(isCurrentKSPlayerCoordinator) ?? false"))
        #expect(body.contains("refreshKSAudioTracks(from: coordinator)"))
        #expect(body.contains("refreshKSSubtitleTracks(from: coordinator)"))
        #expect(body.contains("subtitleTrackRefreshTask = nil"))

        let delayRange = try requiredRange(
            of: "PlayerViewStatePolicy.scheduledKSTrackRefreshDelaysMilliseconds()",
            in: body
        )
        let guardRange = try requiredRange(
            of: "PlayerViewStatePolicy.shouldRunScheduledKSTrackRefresh(",
            in: body
        )
        let audioRange = try requiredRange(of: "refreshKSAudioTracks(from: coordinator)", in: body)
        let subtitleRange = try requiredRange(of: "refreshKSSubtitleTracks(from: coordinator)", in: body)

        #expect(delayRange.lowerBound < guardRange.lowerBound)
        #expect(guardRange.lowerBound < audioRange.lowerBound)
        #expect(audioRange.lowerBound < subtitleRange.lowerBound)
    }
}

@Suite("Player View Runtime Policy Contracts - Subtitles")
struct PlayerViewRuntimeSubtitlePolicyContractTests {
    @Test
    func automaticSubtitleLoaderRoutesThroughPreflightAndStaleMutationGuards() throws {
        let body = try functionBody(named: "autoLoadSubtitlesIfEnabled", in: playerViewSource())

        #expect(body.contains("let preflight = PlayerViewStatePolicy.autoSubtitlePreflight("))
        #expect(body.contains("guard case .download(let request) = preflight else { return }"))
        #expect(body.contains("let service = resolvedSubtitleService(apiKey: request.apiKey)"))
        #expect(body.contains("query: request.query"))
        #expect(body.contains("languages: request.languages"))
        #expect(body.contains("Self.subtitleMutationShouldRun("))
        #expect(body.contains("requestedStreamID: stream.id"))
        #expect(body.contains("currentStreamID: currentStream.id"))
        #expect(body.contains("PlayerSubtitleServicePolicy.automaticDownloadFailureMessage("))

        let preflightRange = try requiredRange(
            of: "let preflight = PlayerViewStatePolicy.autoSubtitlePreflight(",
            in: body
        )
        let serviceRange = try requiredRange(
            of: "let service = resolvedSubtitleService(apiKey: request.apiKey)",
            in: body
        )
        let mutationGuardRange = try requiredRange(of: "Self.subtitleMutationShouldRun(", in: body)
        let failureMessageRange = try requiredRange(
            of: "PlayerSubtitleServicePolicy.automaticDownloadFailureMessage(",
            in: body
        )

        #expect(preflightRange.lowerBound < serviceRange.lowerBound)
        #expect(serviceRange.lowerBound < mutationGuardRange.lowerBound)
        #expect(mutationGuardRange.lowerBound < failureMessageRange.lowerBound)
    }

    @Test
    func subtitleCatalogRefreshSwitchesOverPreflightBeforeSearchingAndFilteringResults() throws {
        let body = try functionBody(named: "refreshSubtitleCatalog", in: playerViewSource())

        #expect(body.contains("Self.subtitleMutationShouldRun("))
        #expect(body.contains("requestedStreamID: requestedStreamID"))
        #expect(body.contains("currentStreamID: currentStream.id"))
        #expect(body.contains("requestedMutationID: mutationID"))
        #expect(body.contains("activeMutationID: subtitleCatalogMutationID"))
        #expect(body.contains("let preflight = PlayerViewStatePolicy.subtitleCatalogPreflight("))
        #expect(body.contains("case .missingAPIKey(let message):"))
        #expect(body.contains("case .emptyQuery(let message):"))
        #expect(body.contains("case .search(let lookupRequest):"))
        #expect(body.contains("subtitleCandidates = []"))
        #expect(body.contains("subtitleCatalogMessage = message"))
        #expect(body.contains("recordSubtitleRuntimeState()"))
        #expect(body.contains("let service = resolvedSubtitleService(apiKey: request.apiKey)"))
        #expect(body.contains("tmdbId: tmdbId"))
        #expect(body.contains("season: stream.recoveryContext?.seasonNumber"))
        #expect(body.contains("episode: stream.recoveryContext?.episodeNumber"))
        #expect(body.contains("candidates = PlayerSubtitleServicePolicy.supportedCatalogCandidates(candidates)"))
        #expect(body.contains("subtitleCatalogMessage = PlayerSubtitleServicePolicy.catalogResultMessage("))

        let initialGuardRange = try requiredRange(of: "Self.subtitleMutationShouldRun(", in: body)
        let loadingRange = try requiredRange(of: "isRefreshingSubtitleCatalog = true", in: body)
        let preflightRange = try requiredRange(
            of: "let preflight = PlayerViewStatePolicy.subtitleCatalogPreflight(",
            in: body
        )
        let switchRange = try requiredRange(of: "switch preflight {", in: body)
        let preSwitchBody = try section(
            from: "isRefreshingSubtitleCatalog = true",
            to: "switch preflight {",
            in: body
        )
        let serviceRange = try requiredRange(
            of: "let service = resolvedSubtitleService(apiKey: request.apiKey)",
            in: body
        )
        let filterRange = try requiredRange(
            of: "candidates = PlayerSubtitleServicePolicy.supportedCatalogCandidates(candidates)",
            in: body
        )

        #expect(initialGuardRange.lowerBound < loadingRange.lowerBound)
        #expect(preflightRange.lowerBound < switchRange.lowerBound)
        #expect(preSwitchBody.contains("Self.subtitleMutationShouldRun("))
        #expect(switchRange.lowerBound < serviceRange.lowerBound)
        #expect(serviceRange.lowerBound < filterRange.lowerBound)
    }

    @Test
    func subtitleCatalogRefreshDoesNotClearLoadingOrPreflightStateForStaleStreams() throws {
        let body = try functionBody(named: "refreshSubtitleCatalog", in: playerViewSource())
        let deferBody = try section(
            from: "defer {",
            to: "let rawAPIKey",
            in: body
        )
        let preflightMutationBody = try section(
            from: "let request: PlayerViewStatePolicy.SubtitleLookupRequest",
            to: "let service = resolvedSubtitleService(apiKey: request.apiKey)",
            in: body
        )

        #expect(deferBody.contains("Self.subtitleMutationShouldRun("))
        #expect(deferBody.contains("isRefreshingSubtitleCatalog = false"))
        #expect(preflightMutationBody.contains("guard !Task.isCancelled"))
        #expect(preflightMutationBody.contains("Self.subtitleMutationShouldRun("))
        #expect(preflightMutationBody.contains("subtitleCandidates = []"))
        #expect(preflightMutationBody.contains("subtitleCatalogMessage = message"))

        let guardRange = try requiredRange(of: "Self.subtitleMutationShouldRun(", in: preflightMutationBody)
        let messageRange = try requiredRange(of: "subtitleCatalogMessage = message", in: preflightMutationBody)
        #expect(guardRange.lowerBound < messageRange.lowerBound)
    }

    @Test
    func subtitleDownloadHonorsPreflightCasesAndCleansLocalFilesOnStaleMutations() throws {
        let body = try functionBody(named: "downloadAndSelectSubtitle", in: playerViewSource())

        #expect(body.contains("let preflight = PlayerViewStatePolicy.subtitleDownloadPreflight("))
        #expect(body.contains("case .skip:"))
        #expect(body.contains("case .unsupported(let message):"))
        #expect(body.contains("case .missingAPIKey(let message):"))
        #expect(body.contains("case .download(let resolvedAPIKey, let resolvedFileID):"))
        #expect(body.contains("subtitleCatalogMessage = message"))
        #expect(body.contains("recordSubtitleRuntimeState()"))
        #expect(body.contains("let service = resolvedSubtitleService(apiKey: apiKey)"))
        #expect(body.contains("let content = try await service.downloadSubtitle(fileId: fileID)"))
        #expect(body.contains("let localURL = try writeExternalSubtitle(content: content, source: subtitle)"))
        #expect(body.contains("Self.subtitleMutationShouldRun("))
        #expect(body.contains("try? FileManager.default.removeItem(at: localURL)"))

        let preflightRange = try requiredRange(
            of: "let preflight = PlayerViewStatePolicy.subtitleDownloadPreflight(",
            in: body
        )
        let serviceRange = try requiredRange(
            of: "let service = resolvedSubtitleService(apiKey: apiKey)",
            in: body
        )
        let writeRange = try requiredRange(
            of: "let localURL = try writeExternalSubtitle(content: content, source: subtitle)",
            in: body
        )
        let bodyAfterWrite = String(body[writeRange.upperBound..<body.endIndex])
        let mutationGuardRange = try requiredRange(of: "Self.subtitleMutationShouldRun(", in: bodyAfterWrite)
        let cleanupRange = try requiredRange(
            of: "try? FileManager.default.removeItem(at: localURL)",
            in: bodyAfterWrite
        )

        #expect(preflightRange.lowerBound < serviceRange.lowerBound)
        #expect(serviceRange.lowerBound < writeRange.lowerBound)
        #expect(mutationGuardRange.lowerBound < cleanupRange.lowerBound)
    }
}

private func playerViewSource() throws -> String {
    try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
}

private func contents(of relativePath: String) throws -> String {
    let fileURL = workspaceRoot().appendingPathComponent(relativePath)
    return try String(contentsOf: fileURL, encoding: .utf8)
}

private func workspaceRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func functionBody(named functionName: String, in source: String) throws -> String {
    guard let signatureRange = source.range(of: "func \(functionName)(") else {
        throw NSError(
            domain: "PlayerRuntimePolicyContractTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing function: \(functionName)"]
        )
    }

    guard let openingBrace = source.range(
        of: "{",
        range: signatureRange.upperBound..<source.endIndex
    )?.lowerBound else {
        throw NSError(
            domain: "PlayerRuntimePolicyContractTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Missing opening brace for function: \(functionName)"]
        )
    }

    var depth = 0
    var cursor = openingBrace
    while cursor < source.endIndex {
        let character = source[cursor]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                let bodyStart = source.index(after: openingBrace)
                return String(source[bodyStart..<cursor])
            }
        }
        cursor = source.index(after: cursor)
    }

    throw NSError(
        domain: "PlayerRuntimePolicyContractTests",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Missing closing brace for function: \(functionName)"]
    )
}

private func section(from startToken: String, to endToken: String, in source: String) throws -> String {
    let startRange = try requiredRange(of: startToken, in: source)
    guard let endRange = source.range(
        of: endToken,
        range: startRange.upperBound..<source.endIndex
    ) else {
        throw NSError(
            domain: "PlayerRuntimePolicyContractTests",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Missing section terminator: \(endToken)"]
        )
    }
    return String(source[startRange.upperBound..<endRange.lowerBound])
}

private func requiredRange(of token: String, in source: String) throws -> Range<String.Index> {
    guard let range = source.range(of: token) else {
        throw NSError(
            domain: "PlayerRuntimePolicyContractTests",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Missing token: \(token)"]
        )
    }
    return range
}

private func containsIgnoringWhitespace(_ source: String, _ snippet: String) -> Bool {
    normalizedWhitespace(source).contains(normalizedWhitespace(snippet))
}

private func normalizedWhitespace(_ source: String) -> String {
    source.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
}
