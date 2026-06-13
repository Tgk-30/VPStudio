import SwiftUI

enum ExploreFilterSheetLanguageSelectionPolicy {
    static let defaultLanguageCode = "en-US"

    static func normalizedSelection(from codes: Set<String>) -> Set<String> {
        SearchLanguageOption.normalizeSelection(from: codes)
    }

    static func selection(afterToggling code: String, in currentSelection: Set<String>) -> Set<String> {
        if code == defaultLanguageCode {
            return [defaultLanguageCode]
        }

        if currentSelection.contains(code) {
            var updatedSelection = currentSelection
            updatedSelection.remove(code)
            return updatedSelection.isEmpty ? [defaultLanguageCode] : updatedSelection
        }

        var updatedSelection = currentSelection
        if updatedSelection == [defaultLanguageCode] {
            updatedSelection.remove(defaultLanguageCode)
        }
        updatedSelection.insert(code)
        return updatedSelection
    }
}

struct ExploreFilterSheet: View {
    @Binding var sortOption: DiscoverFilters.SortOption
    @Binding var selectedYear: Int?
    @Binding var selectedLanguages: Set<String>
    let genres: [Genre]
    @Binding var selectedGenre: Genre?
    let displayedSortOptions: [DiscoverFilters.SortOption]
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    private static let yearRange: [Int] = {
        let current = Calendar.current.component(.year, from: Date())
        return Array((1950...current).reversed())
    }()

    var body: some View {
        NavigationStack {
            Form {
                // Genre
                if !genres.isEmpty {
                    Section("Genre") {
                        Picker("Genre", selection: $selectedGenre) {
                            Text("All Genres").tag(nil as Genre?)
                            ForEach(genres) { genre in
                                Text(genre.name).tag(genre as Genre?)
                            }
                        }
                    }
                }

                // Sort
                Section("Sort By") {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(displayedSortOptions, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Year
                Section("Release Year") {
                    Picker("Year", selection: $selectedYear) {
                        Text("Any Year").tag(nil as Int?)
                        ForEach(Self.yearRange, id: \.self) { year in
                            Text(String(year)).tag(year as Int?)
                        }
                    }
                }

                // Language
                Section("Languages") {
                    languageRows
                }
            }
            .navigationTitle("Filters")
            #if os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                selectedLanguages = ExploreFilterSheetLanguageSelectionPolicy.normalizedSelection(from: selectedLanguages)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(visionOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private var languageRows: some View {
        ForEach(SearchLanguageOption.common, id: \.code) { option in
            LanguageToggleRow(
                name: option.name,
                isSelected: selectedLanguages.contains(option.code),
                onTap: {
                    selectedLanguages = ExploreFilterSheetLanguageSelectionPolicy.selection(
                        afterToggling: option.code,
                        in: selectedLanguages
                    )
                }
            )
        }
    }
}

struct LanguageToggleRow: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
