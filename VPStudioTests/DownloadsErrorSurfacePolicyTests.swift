import Testing
@testable import VPStudio

@Suite("Downloads Error Surface Policy")
struct DownloadsErrorSurfacePolicyTests {
    @Test
    func noRootErrorUsesNormalPresentation() {
        #expect(
            DownloadsErrorSurfacePolicy.presentationMode(
                groupCount: 0,
                hasRootError: false
            ) == .none
        )

        #expect(
            DownloadsErrorSurfacePolicy.presentationMode(
                groupCount: 3,
                hasRootError: false
            ) == .none
        )
    }

    @Test
    func emptyDownloadsWithRootErrorShowsRootErrorSurface() {
        #expect(
            DownloadsErrorSurfacePolicy.presentationMode(
                groupCount: 0,
                hasRootError: true
            ) == .rootError
        )
    }

    @Test
    func populatedDownloadsWithRootErrorShowsInlineError() {
        #expect(
            DownloadsErrorSurfacePolicy.presentationMode(
                groupCount: 2,
                hasRootError: true
            ) == .inlineError
        )
    }

    @Test
    func layoutPolicyReservesBottomViewportScrimClearance() {
        #expect(DownloadsLayoutPolicy.bottomContentPadding == 200)
        #expect(DownloadsLayoutPolicy.bottomViewportInset == 168)
        #expect(DownloadsLayoutPolicy.verticalSectionSpacing == VPSpace.normal)
        #expect(DownloadsLayoutPolicy.groupSpacing == VPSpace.normal)
        #expect(DownloadsLayoutPolicy.topContentPadding == VPSpace.roomy)
        #expect(DownloadsLayoutPolicy.summaryCardPadding == VPSpace.normal)
        #expect(DownloadsLayoutPolicy.summaryIconHaloSize == 64)
        #expect(DownloadsLayoutPolicy.summaryIconSize == 50)
        #expect(DownloadsLayoutPolicy.groupPosterWidth == 84)
        #expect(DownloadsLayoutPolicy.groupPosterHeight == 126)
        #expect(DownloadsLayoutPolicy.groupHeaderPadding == VPSpace.tight)
        #expect(DownloadsLayoutPolicy.taskRowVerticalPadding == VPSpace.micro)
        #expect(DownloadsLayoutPolicy.completedSectionTopPadding == VPSpace.roomy)
        #expect(DownloadsLayoutPolicy.bottomContentPadding > DownloadsLayoutPolicy.bottomViewportInset)
    }
}
