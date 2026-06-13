import Foundation
import Testing
@testable import VPStudio

@Suite("NetworkError Cases and Descriptions")
struct NetworkErrorTests {

    @Test("NetworkError all cases exist")
    func allCasesExist() {
        #expect(NetworkError.invalidURL("test").errorDescription != nil)
        #expect(NetworkError.unauthorized.errorDescription != nil)
        #expect(NetworkError.notFound("test").errorDescription != nil)
        #expect(NetworkError.rateLimited.errorDescription != nil)
        #expect(NetworkError.timeout.errorDescription != nil)
        #expect(NetworkError.offline.errorDescription != nil)
        #expect(NetworkError.invalidResponse.errorDescription != nil)
        #expect(NetworkError.server(statusCode: 500, message: "error").errorDescription != nil)
        #expect(NetworkError.transport("error").errorDescription != nil)
    }

    @Test("NetworkError errorDescription for invalidURL")
    func errorDescriptionInvalidURL() {
        let error = NetworkError.invalidURL("https://bad.com")
        #expect(error.errorDescription == "Invalid URL: https://bad.com")
    }

    @Test("NetworkError errorDescription for unauthorized")
    func errorDescriptionUnauthorized() {
        let error = NetworkError.unauthorized
        #expect(error.errorDescription == "Unauthorized request.")
    }

    @Test("NetworkError errorDescription for notFound")
    func errorDescriptionNotFound() {
        let error = NetworkError.notFound("movie/123")
        #expect(error.errorDescription == "Not found: movie/123")
    }

    @Test("NetworkError errorDescription for rateLimited")
    func errorDescriptionRateLimited() {
        #expect(NetworkError.rateLimited.errorDescription == "Request was rate limited.")
    }

    @Test("NetworkError errorDescription for timeout")
    func errorDescriptionTimeout() {
        #expect(NetworkError.timeout.errorDescription == "Request timed out.")
    }

    @Test("NetworkError errorDescription for offline")
    func errorDescriptionOffline() {
        #expect(NetworkError.offline.errorDescription == "No internet connection.")
    }

    @Test("NetworkError errorDescription for invalidResponse")
    func errorDescriptionInvalidResponse() {
        #expect(NetworkError.invalidResponse.errorDescription == "Received an invalid response.")
    }

    @Test("NetworkError errorDescription for server")
    func errorDescriptionServer() {
        let error = NetworkError.server(statusCode: 500, message: "Internal Error")
        #expect(error.errorDescription == "Server error (500): Internal Error")
    }

    @Test("NetworkError errorDescription for transport")
    func errorDescriptionTransport() {
        let error = NetworkError.transport("Connection reset")
        #expect(error.errorDescription == "Network error: Connection reset")
    }

    @Test("NetworkError recoverySuggestion for invalidURL")
    func recoveryInvalidURL() {
        let error = NetworkError.invalidURL("test")
        #expect(error.recoverySuggestion == "Review service endpoints and API configuration in Settings.")
    }

    @Test("NetworkError recoverySuggestion for unauthorized")
    func recoveryUnauthorized() {
        let error = NetworkError.unauthorized
        #expect(error.recoverySuggestion == "Verify your API key or token in Settings and try again.")
    }

    @Test("NetworkError recoverySuggestion for notFound")
    func recoveryNotFound() {
        let error = NetworkError.notFound("test")
        #expect(error.recoverySuggestion == "Refresh metadata or try a different title.")
    }

    @Test("NetworkError recoverySuggestion for rateLimited")
    func recoveryRateLimited() {
        #expect(NetworkError.rateLimited.recoverySuggestion == "Wait briefly, then retry.")
    }

    @Test("NetworkError recoverySuggestion for timeout/offline/transport")
    func recoveryTimeoutOfflineTransport() {
        #expect(NetworkError.timeout.recoverySuggestion == "Check your connection and retry.")
        #expect(NetworkError.offline.recoverySuggestion == "Check your connection and retry.")
        #expect(NetworkError.transport("test").recoverySuggestion == "Check your connection and retry.")
    }

    @Test("NetworkError recoverySuggestion for invalidResponse/server")
    func recoveryInvalidResponseServer() {
        #expect(NetworkError.invalidResponse.recoverySuggestion == "Retry in a moment. If this persists, verify provider settings.")
        #expect(NetworkError.server(statusCode: 500, message: "error").recoverySuggestion == "Retry in a moment. If this persists, verify provider settings.")
    }

    @Test("NetworkError Equatable conformance")
    func networkErrorEquatable() {
        #expect(NetworkError.unauthorized == NetworkError.unauthorized)
        #expect(NetworkError.notFound("test") == NetworkError.notFound("test"))
        #expect(NetworkError.notFound("test") != NetworkError.notFound("other"))
        #expect(NetworkError.server(statusCode: 500, message: "a") == NetworkError.server(statusCode: 500, message: "a"))
        #expect(NetworkError.server(statusCode: 500, message: "a") != NetworkError.server(statusCode: 501, message: "a"))
    }

    @Test("NetworkError Sendable conformance")
    func networkErrorSendable() async {
        let error: NetworkError = .unauthorized
        let task = Task { @Sendable in
            #expect(error == NetworkError.unauthorized)
        }
        await task.value
    }
}

@Suite("IndexerError Tests")
struct IndexerErrorTests {

    @Test("IndexerError cases")
    func indexerErrorCases() {
        #expect(IndexerError.allIndexersFailed("details").errorDescription != nil)
        #expect(IndexerError.queryFailed("details").errorDescription != nil)
        #expect(IndexerError.notConfigured.errorDescription != nil)
    }

    @Test("IndexerError errorDescription")
    func indexerErrorDescriptions() {
        #expect(IndexerError.allIndexersFailed("timeout").errorDescription == "All indexers failed: timeout")
        #expect(IndexerError.queryFailed("no results").errorDescription == "Torrent search failed: no results")
        #expect(IndexerError.notConfigured.errorDescription == "No active indexers are configured.")
    }

    @Test("IndexerError recoverySuggestion")
    func indexerErrorRecovery() {
        #expect(IndexerError.allIndexersFailed("test").recoverySuggestion == "Check indexer URLs, API keys, and activation status in Settings > Indexers.")
        #expect(IndexerError.queryFailed("test").recoverySuggestion == "Try a broader query or run the search again.")
        #expect(IndexerError.notConfigured.recoverySuggestion == "Check indexer URLs, API keys, and activation status in Settings > Indexers.")
    }

    @Test("IndexerError Equatable")
    func indexerErrorEquatable() {
        #expect(IndexerError.notConfigured == IndexerError.notConfigured)
        #expect(IndexerError.allIndexersFailed("x") == IndexerError.allIndexersFailed("x"))
        #expect(IndexerError.allIndexersFailed("x") != IndexerError.allIndexersFailed("y"))
    }
}

@Suite("PlayerError Tests")
struct PlayerErrorTests {

    @Test("PlayerError cases")
    func playerErrorCases() {
        #expect(PlayerError.invalidStreamURL("url").errorDescription != nil)
        #expect(PlayerError.startupTimeout(.avPlayer).errorDescription != nil)
        #expect(PlayerError.initializationFailed(.ksPlayer, "crash").errorDescription != nil)
        #expect(PlayerError.unsupportedFormat("codec").errorDescription != nil)
        #expect(PlayerError.playbackFailed("error").errorDescription != nil)
    }

    @Test("PlayerError errorDescription")
    func playerErrorDescriptions() {
        #expect(PlayerError.invalidStreamURL("bad://url").errorDescription == "Invalid stream URL: bad://url")
        #expect(PlayerError.unsupportedFormat("XviD").errorDescription == "Unsupported media format: XviD")
        #expect(PlayerError.playbackFailed("buffer underrun").errorDescription == "Playback failed: buffer underrun")
    }

    @Test("PlayerError recoverySuggestion")
    func playerErrorRecovery() {
        #expect(PlayerError.invalidStreamURL("test").recoverySuggestion == "Choose a different stream and retry playback.")
        #expect(PlayerError.startupTimeout(.avPlayer).recoverySuggestion == "Try a different player engine in Settings > Playback.")
        #expect(PlayerError.initializationFailed(.ksPlayer, "test").recoverySuggestion == "Try a different player engine in Settings > Playback.")
        #expect(PlayerError.unsupportedFormat("test").recoverySuggestion == "Try another release or a different quality/HDR format.")
        #expect(PlayerError.playbackFailed("test").recoverySuggestion == "Retry playback, or switch to another stream.")
    }
}

@Suite("AppError Cases Tests")
struct AppErrorCasesTests {

    @Test("AppError cases")
    func appErrorCases() {
        #expect(AppError.network(.unauthorized).errorDescription != nil)
        #expect(AppError.debrid(.unauthorized).errorDescription != nil)
        #expect(AppError.indexer(.notConfigured).errorDescription != nil)
        #expect(AppError.player(.startupTimeout(.avPlayer)).errorDescription != nil)
        #expect(AppError.unknown("test error").errorDescription != nil)
    }

    @Test("AppError errorDescription delegates to underlying error")
    func appErrorErrorDescription() {
        #expect(AppError.network(.unauthorized).errorDescription == "Unauthorized request.")
        #expect(AppError.indexer(.notConfigured).errorDescription == "No active indexers are configured.")
    }

    @Test("AppError unknown case")
    func appErrorUnknown() {
        let error = AppError.unknown("Something went wrong")
        #expect(error.errorDescription == "Something went wrong")
    }

    @Test("AppError tmdbSetupRequired")
    func appErrorTmdbSetupRequired() {
        let error = AppError.tmdbSetupRequired(feature: "Search")
        #expect(error.requiresTMDBSetupAction == true)
    }

    @Test("AppError requiresTMDBSetupAction false for other errors")
    func appErrorRequiresTMDBFalse() {
        #expect(AppError.unknown("generic error").requiresTMDBSetupAction == false)
        #expect(AppError.network(.unauthorized).requiresTMDBSetupAction == false)
    }

    @Test("AppError recoverySuggestion for unknown")
    func appErrorRecoveryUnknown() {
        #expect(AppError.unknown("test").recoverySuggestion == "Try again. If the issue continues, review app configuration.")
    }
}
