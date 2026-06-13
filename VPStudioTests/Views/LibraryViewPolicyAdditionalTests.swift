import Foundation
import Testing
@testable import VPStudio

@Suite("Library View Additional Policy Coverage")
struct LibraryViewPolicyAdditionalTests {
    @Test
    func selectedManualFolderReturnsNilWhenNoSelectionExists() {
        let folder = makeManualFolder(id: "manual-folder", name: "Manual")

        let selected = LibraryFolderSelectionPolicy.selectedManualFolder(
            from: [folder],
            selectedFolderID: nil
        )

        #expect(selected == nil)
    }

    @Test
    func orderedUserFoldersUsesProvidedManualOrderWithoutAppendingWhenComplete() {
        let first = makeManualFolder(id: "first", name: "First")
        let second = makeManualFolder(id: "second", name: "Second")
        let third = makeManualFolder(id: "third", name: "Third")

        let ordered = LibraryFolderSelectionPolicy.orderedUserFolders(
            [first, second, third],
            manualFolderOrderIDs: ["third", "first", "second"]
        )

        #expect(ordered.map(\.id) == ["third", "first", "second"])
    }

    @Test
    func titleRefreshStartPolicyRequiresSupportedListAndIdleState() {
        #expect(LibraryTitleRefreshPolicy.canStartRefresh(selectedList: .watchlist, isRefreshing: false))
        #expect(LibraryTitleRefreshPolicy.canStartRefresh(selectedList: .watchlist, isRefreshing: true) == false)
        #expect(LibraryTitleRefreshPolicy.canStartRefresh(selectedList: .history, isRefreshing: false) == false)
    }

    @Test
    func feedbackPresentationSuppressesEmptyStatusWithoutError() {
        #expect(
            LibraryFeedbackPresentationPolicy.message(
                statusMessage: "",
                actionError: nil
            ) == nil
        )
    }

    @Test
    func selectionTransitionPolicyOnlyResetsOnActualListChange() {
        #expect(
            LibrarySelectionTransitionPolicy.shouldResetTransientFolderState(
                previous: .watchlist,
                next: .favorites
            )
        )
        #expect(
            LibrarySelectionTransitionPolicy.shouldResetTransientFolderState(
                previous: .history,
                next: .history
            ) == false
        )
    }

    @Test
    func folderReorderPolicyMovesDraggedFolderAfterForwardDestination() {
        let reordered = LibraryFolderReorderPolicy.reorderedIDs(
            orderedFolderIDs: ["alpha", "bravo", "charlie", "delta"],
            draggedFolderID: "alpha",
            destinationFolderID: "charlie"
        )

        #expect(reordered == ["bravo", "charlie", "alpha", "delta"])
    }

    @Test
    func folderReorderPolicyMovesDraggedFolderBeforeBackwardDestination() {
        let reordered = LibraryFolderReorderPolicy.reorderedIDs(
            orderedFolderIDs: ["alpha", "bravo", "charlie", "delta"],
            draggedFolderID: "delta",
            destinationFolderID: "bravo"
        )

        #expect(reordered == ["alpha", "delta", "bravo", "charlie"])
    }

    @Test
    func folderReorderPolicyIgnoresMissingSelfAndNoOpDrags() {
        #expect(LibraryFolderReorderPolicy.reorderedIDs(
            orderedFolderIDs: ["alpha", "bravo"],
            draggedFolderID: nil,
            destinationFolderID: "bravo"
        ) == nil)
        #expect(LibraryFolderReorderPolicy.reorderedIDs(
            orderedFolderIDs: ["alpha", "bravo"],
            draggedFolderID: "alpha",
            destinationFolderID: "alpha"
        ) == nil)
        #expect(LibraryFolderReorderPolicy.reorderedIDs(
            orderedFolderIDs: ["alpha", "bravo"],
            draggedFolderID: "missing",
            destinationFolderID: "bravo"
        ) == nil)
        #expect(LibraryFolderReorderPolicy.reorderedIDs(
            orderedFolderIDs: ["alpha", "bravo"],
            draggedFolderID: "alpha",
            destinationFolderID: "missing"
        ) == nil)
    }

    @Test
    func folderReorderPolicyOnlyPersistsChangedOrders() {
        #expect(LibraryFolderReorderPolicy.shouldPersist(
            reorderedIDs: ["bravo", "alpha"],
            currentIDs: ["alpha", "bravo"]
        ))
        #expect(!LibraryFolderReorderPolicy.shouldPersist(
            reorderedIDs: ["alpha", "bravo"],
            currentIDs: ["alpha", "bravo"]
        ))
    }

    private func makeManualFolder(id: String, name: String) -> LibraryFolder {
        LibraryFolder(
            id: id,
            name: name,
            parentId: LibraryFolder.systemFolderID(for: .watchlist),
            listType: .watchlist,
            folderKind: .manual,
            isSystem: false,
            sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
