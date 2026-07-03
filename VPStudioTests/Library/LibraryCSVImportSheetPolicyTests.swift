import Testing
import UniformTypeIdentifiers
@testable import VPStudio

@Suite("Library CSV Import Sheet Policy")
struct LibraryCSVImportSheetPolicyTests {
    @Test
    func pickerPresentationFollowsSelectedMode() {
        #expect(LibraryCSVImportSheetPolicy.isPickerPresented(mode: nil) == false)
        #expect(LibraryCSVImportSheetPolicy.isPickerPresented(mode: .csvFiles))
        #expect(LibraryCSVImportSheetPolicy.isPickerPresented(mode: .folder))
        #expect(LibraryCSVImportPickerMode.csvFiles.id == .csvFiles)
    }

    @Test
    func activeContentTypesUseFolderOnlyForFolderMode() {
        let csvTypes = [UTType.plainText, .text]

        #expect(LibraryCSVImportSheetPolicy.activeContentTypes(mode: .folder, supportedCSVTypes: csvTypes) == [.folder])
        #expect(LibraryCSVImportSheetPolicy.activeContentTypes(mode: .csvFiles, supportedCSVTypes: csvTypes) == csvTypes)
        #expect(LibraryCSVImportSheetPolicy.activeContentTypes(mode: nil, supportedCSVTypes: csvTypes) == csvTypes)
    }

    @Test
    func destinationFolderListTypesMapToSupportedLists() {
        #expect(LibraryCSVImportSheetPolicy.destinationFolderListTypes(for: .watchlist) == [.watchlist])
        #expect(LibraryCSVImportSheetPolicy.destinationFolderListTypes(for: .favorites) == [.favorites])
        #expect(LibraryCSVImportSheetPolicy.destinationFolderListTypes(for: .auto) == [.watchlist, .favorites])
        #expect(LibraryCSVImportSheetPolicy.destinationFolderListTypes(for: .history) == [])
    }

    @Test
    func destinationSupportsFoldersOnlyForListBackedDestinations() {
        #expect(LibraryCSVImportSheetPolicy.destinationSupportsFolders(.watchlist))
        #expect(LibraryCSVImportSheetPolicy.destinationSupportsFolders(.favorites))
        #expect(LibraryCSVImportSheetPolicy.destinationSupportsFolders(.auto))
        #expect(LibraryCSVImportSheetPolicy.destinationSupportsFolders(.history) == false)
    }

    @Test
    func customFolderFieldShowsWhenNoOptionsOrCreateNewIsSelected() {
        let createNew = LibraryCSVImportSheetPolicy.createNewFolderOption

        #expect(LibraryCSVImportSheetPolicy.shouldShowCustomFolderField(existingFolderOptions: [], selectedExistingFolderName: "Anything"))
        #expect(LibraryCSVImportSheetPolicy.shouldShowCustomFolderField(existingFolderOptions: ["Queued"], selectedExistingFolderName: createNew))
        #expect(LibraryCSVImportSheetPolicy.shouldShowCustomFolderField(existingFolderOptions: ["Queued"], selectedExistingFolderName: "Queued") == false)
    }

    @Test
    func selectedManualFolderNameTrimsTypedOrExistingFolderName() {
        let createNew = LibraryCSVImportSheetPolicy.createNewFolderOption

        let typed = LibraryCSVImportSheetPolicy.selectedManualFolderName(
            existingFolderOptions: ["Queued"],
            selectedExistingFolderName: createNew,
            typedFolderName: "  New Queue \n"
        )
        #expect(typed == "New Queue")

        let existing = LibraryCSVImportSheetPolicy.selectedManualFolderName(
            existingFolderOptions: ["Queued"],
            selectedExistingFolderName: "  Queued \t",
            typedFolderName: "Ignored"
        )
        #expect(existing == "Queued")
    }

    @Test
    func selectedManualFolderNameUsesTypedValueWhenNoExistingFoldersAreAvailable() {
        let selected = LibraryCSVImportSheetPolicy.selectedManualFolderName(
            existingFolderOptions: [],
            selectedExistingFolderName: "Any Existing Name",
            typedFolderName: "  Fresh Imports  "
        )

        #expect(selected == "Fresh Imports")
    }

    @Test
    func selectedExistingFolderNamePreservesCanonicalCaseInsensitiveMatch() {
        let selected = LibraryCSVImportSheetPolicy.selectedExistingFolderName(
            afterLoading: ["Favorites", "Watch Later"],
            currentSelection: "watch later"
        )

        #expect(selected == "Watch Later")
    }

    @Test
    func selectedExistingFolderNameFallsBackToFirstOrCreateNew() {
        let createNew = LibraryCSVImportSheetPolicy.createNewFolderOption

        #expect(LibraryCSVImportSheetPolicy.selectedExistingFolderName(afterLoading: [], currentSelection: "Old") == createNew)
        #expect(LibraryCSVImportSheetPolicy.selectedExistingFolderName(afterLoading: ["Alpha", "Beta"], currentSelection: createNew) == "Alpha")
        #expect(LibraryCSVImportSheetPolicy.selectedExistingFolderName(afterLoading: ["Alpha", "Beta"], currentSelection: "Missing") == "Alpha")
    }

    @Test
    func supportedCSVTypesUseAvailableIdentifiersAndFallbackToData() {
        let csvTypes = LibraryCSVImportSheetPolicy.supportedCSVTypes()

        #expect(csvTypes.contains(.commaSeparatedText))
        #expect(csvTypes.contains(.plainText))
        #expect(csvTypes.contains(.text))
        if let extensionType = UTType(filenameExtension: "csv") {
            #expect(csvTypes.contains(extensionType))
        }

        let emptyCandidates: [UTType?] = [nil]
        #expect(LibraryCSVImportSheetPolicy.supportedCSVTypes(from: emptyCandidates) == [.data])
    }

    @Test
    func multiFileImportRequiresManualSubfolderWhenAutoSubfoldersAreOff() {
        #expect(
            LibraryCSVImportSheetPolicy.requiresManualSubfolderName(
                fileCount: 2,
                importToFolder: true,
                destinationSupportsFolders: true,
                autoSubfolderPerFile: false,
                manualFolderName: "  "
            )
        )
        #expect(
            LibraryCSVImportSheetPolicy.requiresManualSubfolderName(
                fileCount: 1,
                importToFolder: true,
                destinationSupportsFolders: true,
                autoSubfolderPerFile: false,
                manualFolderName: ""
            ) == false
        )
        #expect(
            LibraryCSVImportSheetPolicy.requiresManualSubfolderName(
                fileCount: 2,
                importToFolder: true,
                destinationSupportsFolders: true,
                autoSubfolderPerFile: true,
                manualFolderName: ""
            ) == false
        )
        #expect(
            LibraryCSVImportSheetPolicy.requiresManualSubfolderName(
                fileCount: 2,
                importToFolder: true,
                destinationSupportsFolders: true,
                autoSubfolderPerFile: false,
                manualFolderName: "IMDb"
            ) == false
        )
    }

    @Test
    func manualSubfolderValidationSkipsWhenFolderDestinationIsNotApplicable() {
        #expect(
            LibraryCSVImportSheetPolicy.requiresManualSubfolderName(
                fileCount: 4,
                importToFolder: false,
                destinationSupportsFolders: true,
                autoSubfolderPerFile: false,
                manualFolderName: ""
            ) == false
        )
        #expect(
            LibraryCSVImportSheetPolicy.requiresManualSubfolderName(
                fileCount: 4,
                importToFolder: true,
                destinationSupportsFolders: false,
                autoSubfolderPerFile: false,
                manualFolderName: ""
            ) == false
        )
    }

    @Test
    func canonicalFolderNamesSortTrimAndDeduplicateCaseInsensitively() {
        let names = [
            "  Watch Later ",
            "anime",
            "ANIME",
            "",
            "  ",
            "Favorites",
            "watch later",
        ]

        #expect(
            LibraryCSVImportSheetPolicy.canonicalFolderNames(from: names)
                == ["anime", "Favorites", "Watch Later"]
        )
    }
}
