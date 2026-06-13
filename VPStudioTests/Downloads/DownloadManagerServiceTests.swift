import Testing
import Foundation
@testable import VPStudio

private final class LockedState<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

@Suite("DownloadCancellationController")
struct DownloadCancellationControllerTests {

    @Test func isCancelledIsFalseInitially() {
        let controller = DownloadCancellationController()
        #expect(controller.isCancelled == false)
    }

    @Test func registerCallbackNotInvokedImmediatelyWhenNotCancelled() {
        let controller = DownloadCancellationController()
        let invoked = LockedState(false)
        controller.register { invoked.withValue { $0 = true } }
        #expect(invoked.get() == false)
        #expect(controller.isCancelled == false)
    }

    @Test func registerCallbackInvokedImmediatelyWhenAlreadyCancelled() {
        let controller = DownloadCancellationController()
        controller.cancel()
        let invoked = LockedState(false)
        controller.register { invoked.withValue { $0 = true } }
        #expect(invoked.get() == true)
        #expect(controller.isCancelled == true)
    }

    @Test func cancelSetsIsCancelledToTrue() {
        let controller = DownloadCancellationController()
        #expect(controller.isCancelled == false)
        controller.cancel()
        #expect(controller.isCancelled == true)
    }

    @Test func cancelMultipleTimesIsIdempotent() {
        let controller = DownloadCancellationController()
        controller.cancel()
        controller.cancel()
        controller.cancel()
        #expect(controller.isCancelled == true)
    }

    @Test func multipleCallbacksInvokedOnCancel() {
        let controller = DownloadCancellationController()
        let count = LockedState(0)
        controller.register { count.withValue { $0 += 1 } }
        controller.register { count.withValue { $0 += 1 } }
        controller.register { count.withValue { $0 += 1 } }
        #expect(count.get() == 0)
        controller.cancel()
        #expect(count.get() == 3)
    }

    @Test func callbacksNotInvokedAgainOnSecondCancel() {
        let controller = DownloadCancellationController()
        let count = LockedState(0)
        controller.register { count.withValue { $0 += 1 } }
        controller.cancel()
        #expect(count.get() == 1)
        controller.cancel()
        #expect(count.get() == 1)
    }

    @Test func registerAfterCancelInvokedImmediately() {
        let controller = DownloadCancellationController()
        controller.cancel()
        let count = LockedState(0)
        controller.register { count.withValue { $0 += 1 } }
        controller.register { count.withValue { $0 += 1 } }
        #expect(count.get() == 2)
    }

    @Test func cancelClearsCallbacks() {
        let controller = DownloadCancellationController()
        let count = LockedState(0)
        controller.register { count.withValue { $0 += 1 } }
        controller.register { count.withValue { $0 += 1 } }
        controller.cancel()
        #expect(count.get() == 2)
        controller.register { count.withValue { $0 += 1 } }
        #expect(count.get() == 3)
    }
}

@Suite("DownloadTransferError")
struct DownloadTransferErrorTests {

    @Test func badHTTPStatusErrorDescription() {
        let error = DownloadTransferError.badHTTPStatus(404)
        #expect(error.errorDescription == "Download failed with HTTP 404.")
    }

    @Test func badHTTPStatusErrorDescription500() {
        let error = DownloadTransferError.badHTTPStatus(500)
        #expect(error.errorDescription == "Download failed with HTTP 500.")
    }

    @Test func insufficientDiskSpaceErrorDescription() {
        let error = DownloadTransferError.insufficientDiskSpace(required: 1_073_741_824, available: 100_000_000)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("1.0 GB") || error.errorDescription!.contains("GB"))
    }

    @Test func insufficientDiskSpaceZeroAvailable() {
        let error = DownloadTransferError.insufficientDiskSpace(required: 1_000_000_000, available: 0)
        #expect(error.errorDescription != nil)
        // Description spells out "Zero KB" instead of "0"
        #expect(error.errorDescription!.contains("Zero KB"))
    }

    @Test func resumeDataProducedErrorDescription() {
        let error = DownloadTransferError.resumeDataProduced(Data([1, 2, 3]))
        #expect(error.errorDescription == "Download paused.")
    }
}

@Suite("DownloadStatus")
struct DownloadStatusTests {

    @Test func completedIsTerminal() {
        #expect(DownloadStatus.completed.isTerminal == true)
    }

    @Test func failedIsTerminal() {
        #expect(DownloadStatus.failed.isTerminal == true)
    }

    @Test func cancelledIsTerminal() {
        #expect(DownloadStatus.cancelled.isTerminal == true)
    }

    @Test func queuedIsNotTerminal() {
        #expect(DownloadStatus.queued.isTerminal == false)
    }

    @Test func resolvingIsNotTerminal() {
        #expect(DownloadStatus.resolving.isTerminal == false)
    }

    @Test func downloadingIsNotTerminal() {
        #expect(DownloadStatus.downloading.isTerminal == false)
    }
}

@Suite("StreamRecoveryContext")
struct StreamRecoveryContextTestsDownloadsDownloadmanagerservicetests {

    @Test func initWithValidHash() {
        let context = StreamRecoveryContext(infoHash: "abc123")
        #expect(context != nil)
        #expect(context?.infoHash == "abc123")
    }

    @Test func initWithWhitespaceHashNormalized() {
        let context = StreamRecoveryContext(infoHash: "  ABC123  ")
        #expect(context != nil)
        #expect(context?.infoHash == "abc123")
    }

    @Test func initWithEmptyHashReturnsNil() {
        let context = StreamRecoveryContext(infoHash: "")
        #expect(context == nil)
    }

    @Test func initWithWhitespaceOnlyHashReturnsNil() {
        let context = StreamRecoveryContext(infoHash: "   ")
        #expect(context == nil)
    }

    @Test func initWithOptionalFields() {
        let context = StreamRecoveryContext(
            infoHash: "abc123",
            preferredService: .realDebrid,
            seasonNumber: 1,
            episodeNumber: 5,
            torrentId: "torrent-123",
            resolvedDebridService: "RealDebrid",
            resolvedFileName: "video.mp4",
            resolvedFileSizeBytes: 1_000_000
        )
        #expect(context != nil)
        #expect(context?.preferredService == .realDebrid)
        #expect(context?.seasonNumber == 1)
        #expect(context?.episodeNumber == 5)
        #expect(context?.torrentId == "torrent-123")
        #expect(context?.resolvedDebridService == "RealDebrid")
        #expect(context?.resolvedFileName == "video.mp4")
        #expect(context?.resolvedFileSizeBytes == 1_000_000)
    }

    @Test func initWithInvalidSizeBytesReturnsNilSize() {
        let context = StreamRecoveryContext(infoHash: "abc123", resolvedFileSizeBytes: 0)
        #expect(context != nil)
        #expect(context?.resolvedFileSizeBytes == nil)
    }

    @Test func initWithNegativeSizeBytesReturnsNilSize() {
        let context = StreamRecoveryContext(infoHash: "abc123", resolvedFileSizeBytes: -100)
        #expect(context != nil)
        #expect(context?.resolvedFileSizeBytes == nil)
    }

    @Test func initWithWhitespaceOptionalStringsReturnsNil() {
        let context = StreamRecoveryContext(
            infoHash: "abc123",
            torrentId: "  ",
            resolvedDebridService: "   ",
            resolvedFileName: ""
        )
        #expect(context != nil)
        #expect(context?.torrentId == nil)
        #expect(context?.resolvedDebridService == nil)
        #expect(context?.resolvedFileName == nil)
    }
}

@Suite("DownloadTask")
struct DownloadTaskTests {

    @Test func defaultInitWithRequiredFields() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4"
        )
        #expect(task.mediaId == "tt123")
        #expect(task.fileName == "movie.mp4")
        #expect(task.status == .queued)
        #expect(task.progress == 0)
        #expect(task.bytesWritten == 0)
    }

    @Test func progressNormalizedBetweenZeroAndOne() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            progress: 0.5
        )
        #expect(task.progress == 0.5)
    }

    @Test func progressNegativeNormalizedToZero() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            progress: -0.5
        )
        #expect(task.progress == 0)
    }

    @Test func progressOverOneNormalizedToOne() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            progress: 1.5
        )
        #expect(task.progress == 1)
    }

    @Test func completedStatusForcesProgressToOne() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            status: .completed,
            progress: 0.5
        )
        #expect(task.progress == 1)
    }

    @Test func bytesWrittenNegativeNormalizedToZero() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            bytesWritten: -100
        )
        #expect(task.bytesWritten == 0)
    }

    @Test func totalBytesZeroBecomesNil() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            totalBytes: 0
        )
        #expect(task.totalBytes == nil)
    }

    @Test func expectedBytesZeroBecomesNil() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            expectedBytes: 0
        )
        #expect(task.expectedBytes == nil)
    }

    @Test func emptyMediaTitleBecomesEmptyString() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4"
        )
        #expect(task.mediaTitle == "")
    }

    @Test func displayTitleForMovie() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            mediaTitle: "My Movie"
        )
        #expect(task.displayTitle == "My Movie")
    }

    @Test func displayTitleForEpisode() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "S01E05.mp4",
            mediaTitle: "My Show",
            seasonNumber: 1,
            episodeNumber: 5
        )
        #expect(task.displayTitle == "S01E05")
    }

    @Test func displayTitleForEpisodeWithTitle() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "S01E05.mp4",
            mediaTitle: "My Show",
            seasonNumber: 1,
            episodeNumber: 5,
            episodeTitle: "The Episode"
        )
        #expect(task.displayTitle == "S01E05 - The Episode")
    }

    @Test func episodeSortKeyCalculation() {
        let task1 = DownloadTask(mediaId: "tt123", fileName: "f.mp4", seasonNumber: 1, episodeNumber: 1)
        let task2 = DownloadTask(mediaId: "tt123", fileName: "f.mp4", seasonNumber: 1, episodeNumber: 10)
        let task3 = DownloadTask(mediaId: "tt123", fileName: "f.mp4", seasonNumber: 2, episodeNumber: 1)

        #expect(task1.episodeSortKey == 10001)
        #expect(task2.episodeSortKey == 10010)
        #expect(task3.episodeSortKey == 20001)
    }

    @Test func resumeDataRoundTrip() {
        var task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            status: .downloading
        )
        let originalData = Data([1, 2, 3, 4, 5])
        task.resumeData = originalData

        #expect(task.resumeData == originalData)
    }

    @Test func resumeDataClearedOnCompleted() {
        var task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            status: .downloading
        )
        task.resumeData = Data([1, 2, 3])
        #expect(task.resumeData != nil)

        task.status = .completed
        task.resumeData = task.resumeData // Re-normalize with new status
        #expect(task.resumeData == nil)
    }

    @Test func streamURLNormalized() {
        let task = DownloadTask(
            mediaId: "tt123",
            streamURL: "  https://example.com/video.mp4  ",
            fileName: "movie.mp4",
            status: .downloading
        )
        #expect(task.persistedStreamURL == "https://example.com/video.mp4")
    }

    @Test func streamURLClearedOnCompleted() {
        let task = DownloadTask(
            mediaId: "tt123",
            streamURL: "https://example.com/video.mp4",
            fileName: "movie.mp4",
            status: .completed
        )
        #expect(task.persistedStreamURL == nil)
    }

    @Test func recoveryContextRoundTrip() {
        var task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4"
        )
        let context = StreamRecoveryContext(
            infoHash: "abc123",
            preferredService: .realDebrid,
            torrentId: "t123"
        )
        task.recoveryContext = context

        #expect(task.recoveryContext == context)
    }

    @Test func redactedForRecoveryBackedPersistenceClearsSensitiveFields() {
        var task = DownloadTask(
            mediaId: "tt123",
            streamURL: "https://example.com/video.mp4",
            fileName: "movie.mp4"
        )
        task.resumeData = Data([1, 2, 3])

        let redacted = task.redactedForRecoveryBackedPersistence
        #expect(redacted.persistedStreamURL == nil)
        #expect(redacted.resumeData == nil)
    }

    @Test func sanitizedForPersistencePreservesFields() {
        let task = DownloadTask(
            mediaId: "tt123",
            fileName: "movie.mp4",
            status: .downloading
        )
        let sanitized = task.sanitizedForPersistence
        #expect(sanitized.mediaId == task.mediaId)
        #expect(sanitized.fileName == task.fileName)
        #expect(sanitized.status == task.status)
    }
}

@Suite("StreamInfo")
struct StreamInfoTests {

    private func makeStreamInfo(
        fileName: String = "video.mp4",
        sizeBytes: Int64? = 1_000_000
    ) -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com/video.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: fileName,
            sizeBytes: sizeBytes,
            debridService: "RealDebrid"
        )
    }

    @Test func idIsUnique() {
        let info1 = makeStreamInfo(fileName: "video1.mp4")
        let info2 = makeStreamInfo(fileName: "video2.mp4")
        #expect(info1.id != info2.id)
    }

    @Test func sizeStringGB() {
        let info = makeStreamInfo(sizeBytes: 2_147_483_648)
        #expect(info.sizeString.contains("GB"))
    }

    @Test func sizeStringMB() {
        let info = makeStreamInfo(sizeBytes: 50_000_000)
        #expect(info.sizeString.contains("MB"))
    }

    @Test func sizeStringEmptyWhenNil() {
        let info = makeStreamInfo(sizeBytes: nil)
        #expect(info.sizeString == "")
    }

    @Test func qualityBadgeContainsQuality() {
        let info = makeStreamInfo()
        #expect(info.qualityBadge.contains("1080p"))
    }

    @Test func qualityBadgeContainsHDR() {
        var info = makeStreamInfo()
        info.hdr = .hdr10
        #expect(info.qualityBadge.contains("HDR10"))
    }

    @Test func qualityBadgeContainsCodec() {
        let info = makeStreamInfo()
        #expect(info.qualityBadge.contains("H.264"))
    }

    @Test func withRecoveryContext() {
        let info = makeStreamInfo()
        let context = StreamRecoveryContext(infoHash: "abc123")!
        let newInfo = info.withRecoveryContext(context)
        #expect(newInfo.recoveryContext == context)
    }

    @Test func withStreamURL() {
        let info = makeStreamInfo()
        let newURL = URL(string: "https://example.com/newvideo.mp4")!
        let newInfo = info.withStreamURL(newURL)
        #expect(newInfo.streamURL == newURL)
    }
}
