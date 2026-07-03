import Testing
@testable import VPStudio

@Suite("Library Layout Policy")
struct LibraryLayoutPolicyTests {
    @Test
    func emptyLibraryShowsEmptyStateForWatchlist() {
        #expect(LibraryLayoutPolicy.showsEmptyState(for: .watchlist, entryCount: 0, historyCount: 0) == true)
    }

    @Test(arguments: [1, 3, 10])
    func populatedLibraryShowsGridForWatchlist(entryCount: Int) {
        #expect(LibraryLayoutPolicy.showsEmptyState(for: .watchlist, entryCount: entryCount, historyCount: 0) == false)
    }

    @Test
    func emptyHistoryShowsEmptyState() {
        #expect(LibraryLayoutPolicy.showsEmptyState(for: .history, entryCount: 99, historyCount: 0) == true)
    }

    @Test
    func populatedHistoryShowsGrid() {
        #expect(LibraryLayoutPolicy.showsEmptyState(for: .history, entryCount: 0, historyCount: 2) == false)
    }

    @Test
    func libraryHeaderAndEmptyStateRemainTopPinned() {
        #expect(LibraryLayoutPolicy.rootPinsContentToTop == true)
        #expect(LibraryLayoutPolicy.emptyStatePinsContentToTop == true)
    }

    @Test
    func emptyStateTopPaddingIsStable() {
        #expect(Double(LibraryLayoutPolicy.emptyStateTopPadding) == 20)
    }

    @Test
    func folderCreationPolicyTrimsValidInput() {
        #expect(LibraryFolderCreationPolicy.normalizedName("  Sci-Fi  ") == "Sci-Fi")
    }

    @Test
    func folderCreationPolicyRejectsBlankInput() {
        #expect(LibraryFolderCreationPolicy.normalizedName("   \n\t  ") == nil)
    }

    @Test
    func folderCreationKeyboardDismissDelayIsStable() {
        #expect(LibraryFolderCreationPolicy.keyboardDismissDelayMilliseconds == 80)
    }

    @Test
    func selectedManualFolderPolicyFindsManualFolder() {
        let root = LibraryFolder(
            id: "system-watchlist",
            name: "Watchlist",
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )
        let manual = LibraryFolder(
            id: "folder-manual",
            name: "Sci-Fi",
            parentId: root.id,
            listType: .watchlist
        )

        let selected = LibraryFolderSelectionPolicy.selectedManualFolder(
            from: [root, manual],
            selectedFolderID: manual.id
        )
        #expect(selected?.id == manual.id)
    }

    @Test
    func selectedManualFolderPolicyIgnoresSystemFolderSelection() {
        let root = LibraryFolder(
            id: "system-watchlist",
            name: "Watchlist",
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )

        let selected = LibraryFolderSelectionPolicy.selectedManualFolder(
            from: [root],
            selectedFolderID: root.id
        )
        #expect(selected == nil)
    }

    @Test
    func selectedManualFolderPolicyReturnsNilWhenMissing() {
        let manual = LibraryFolder(
            id: "folder-manual",
            name: "Drama",
            listType: .favorites
        )
        let selected = LibraryFolderSelectionPolicy.selectedManualFolder(
            from: [manual],
            selectedFolderID: "unknown"
        )
        #expect(selected == nil)
    }

    @Test
    func orderedUserFoldersUsesManualOrderAndAppendsMissingFoldersInOriginalOrder() {
        let alpha = manualFolder(id: "alpha", name: "Alpha")
        let beta = manualFolder(id: "beta", name: "Beta")
        let gamma = manualFolder(id: "gamma", name: "Gamma")
        let delta = manualFolder(id: "delta", name: "Delta")

        let ordered = LibraryFolderSelectionPolicy.orderedUserFolders(
            [alpha, beta, gamma, delta],
            manualFolderOrderIDs: ["gamma", "alpha"]
        )

        #expect(ordered.map(\.id) == ["gamma", "alpha", "beta", "delta"])
    }

    @Test
    func orderedUserFoldersIgnoresUnknownManualOrderIDsDeterministically() {
        let alpha = manualFolder(id: "alpha", name: "Alpha")
        let beta = manualFolder(id: "beta", name: "Beta")
        let gamma = manualFolder(id: "gamma", name: "Gamma")

        let ordered = LibraryFolderSelectionPolicy.orderedUserFolders(
            [alpha, beta, gamma],
            manualFolderOrderIDs: ["missing", "gamma", "also-missing"]
        )

        #expect(ordered.map(\.id) == ["gamma", "alpha", "beta"])
    }

    @Test
    func orderedUserFoldersKeepsSourceOrderWhenManualOrderIsEmpty() {
        let alpha = manualFolder(id: "alpha", name: "Alpha")
        let beta = manualFolder(id: "beta", name: "Beta")

        let ordered = LibraryFolderSelectionPolicy.orderedUserFolders(
            [alpha, beta],
            manualFolderOrderIDs: []
        )

        #expect(ordered.map(\.id) == ["alpha", "beta"])
    }

    private func manualFolder(id: String, name: String) -> LibraryFolder {
        LibraryFolder(
            id: id,
            name: name,
            parentId: "system-watchlist",
            listType: .watchlist,
            folderKind: .manual,
            isSystem: false
        )
    }
}
