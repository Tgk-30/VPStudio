import SwiftUI
import UniformTypeIdentifiers

// MARK: - Metadata Settings Policy

enum MetadataSettingsPolicy {
    static let savedMessage = "OMDb API key saved."
    static let removedMessage = "OMDb API key removed."
    static let missingKeyMessage = "Enter an API key before testing."
    static let validationFailureFallbackMessage = "OMDb validation failed."
    static let validationProbeIMDbID = "tt0111161"

    struct APIKeyState: Equatable {
        let visibleValue: String
        let baselineValue: String
        let isSaved: Bool
    }

    struct SavePresentation: Equatable {
        let visibleValue: String
        let baselineValue: String
        let isSaved: Bool
        let noticeMessage: String
        let noticeTone: SettingsInlineNotice.Tone

        var notice: SettingsInlineNotice {
            switch noticeTone {
            case .success:
                return .success(noticeMessage)
            case .info:
                return .info(noticeMessage)
            case .warning:
                return .warning(noticeMessage)
            }
        }
    }

    static func normalizedAPIKey(_ value: String) -> String? {
        SettingsInputValidation.normalizedSecret(value)
    }

    static func hasUnsavedAPIKeyChange(current: String, baseline: String) -> Bool {
        SettingsInputValidation.hasUnsavedSecretChange(current: current, initial: baseline)
    }

    static func shouldInvalidateSavedState(newValue: String, baseline: String) -> Bool {
        hasUnsavedAPIKeyChange(current: newValue, baseline: baseline)
    }

    static func loadedState(for persistedValue: String?) -> APIKeyState {
        let value = normalizedAPIKey(persistedValue ?? "") ?? ""
        return APIKeyState(
            visibleValue: value,
            baselineValue: value,
            isSaved: !value.isEmpty
        )
    }

    static func savePresentation(for normalizedAPIKey: String?) -> SavePresentation {
        let value = normalizedAPIKey ?? ""
        return SavePresentation(
            visibleValue: value,
            baselineValue: value,
            isSaved: !value.isEmpty,
            noticeMessage: value.isEmpty ? removedMessage : savedMessage,
            noticeTone: .success
        )
    }

    static var missingAPIKeyNotice: SettingsInlineNotice {
        .warning(missingKeyMessage)
    }
}

// MARK: - Metadata Settings

struct MetadataSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var omdbApiKey = ""
    @State private var initialOMDbApiKey = ""
    @State private var isSaved = false
    @State private var isTestingApiKey = false
    @State private var surfaceError: AppError?
    @State private var notice: SettingsInlineNotice?
    private let disablesAutomaticTasks: Bool

    init(
        initialOMDbApiKey: String = "",
        initialBaselineOMDbApiKey: String? = nil,
        initialIsSaved: Bool = false,
        initialIsTestingApiKey: Bool = false,
        initialSurfaceError: AppError? = nil,
        initialNotice: SettingsInlineNotice? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        _omdbApiKey = State(initialValue: initialOMDbApiKey)
        _initialOMDbApiKey = State(initialValue: initialBaselineOMDbApiKey ?? initialOMDbApiKey)
        _isSaved = State(initialValue: initialIsSaved)
        _isTestingApiKey = State(initialValue: initialIsTestingApiKey)
        _surfaceError = State(initialValue: initialSurfaceError)
        _notice = State(initialValue: initialNotice)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    SecureField("OMDb API Key", text: $omdbApiKey)
                    PasteFieldButton { omdbApiKey = $0 }
                }
                Text("Get a free key at omdbapi.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Save") {
                    Task { await saveOMDbAPIKey() }
                }
                .disabled(!hasUnsavedChanges)

                Button(isTestingApiKey ? "Testing..." : "Test API Key") {
                    Task { await testOMDbAPIKey() }
                }
                .disabled(isTestingApiKey || normalizedOMDbApiKey == nil)

                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(VPColor.success)
                }

                if let notice {
                    SettingsNoticeBanner(notice: notice)
                }

                if let surfaceError {
                    SettingsErrorBanner(error: surfaceError)
                }
            }
        }
        .navigationTitle("Movie & TV Metadata (OMDb)")
        .task {
            guard !disablesAutomaticTasks else { return }
            await loadOMDbAPIKey()
        }
        .onChange(of: omdbApiKey) { _, newValue in
            guard MetadataSettingsPolicy.shouldInvalidateSavedState(
                newValue: newValue,
                baseline: initialOMDbApiKey
            ) else { return }
            isSaved = false
            notice = nil
            surfaceError = nil
        }
    }

    private var normalizedOMDbApiKey: String? {
        MetadataSettingsPolicy.normalizedAPIKey(omdbApiKey)
    }

    private var hasUnsavedChanges: Bool {
        MetadataSettingsPolicy.hasUnsavedAPIKeyChange(current: omdbApiKey, baseline: initialOMDbApiKey)
    }

    private func saveOMDbAPIKey() async {
        do {
            let normalized = normalizedOMDbApiKey
            try await appState.settingsManager.setString(key: SettingsKeys.omdbApiKey, value: normalized)
            let presentation = MetadataSettingsPolicy.savePresentation(for: normalized)
            initialOMDbApiKey = presentation.baselineValue
            omdbApiKey = presentation.visibleValue
            isSaved = presentation.isSaved
            surfaceError = nil
            notice = presentation.notice
            NotificationCenter.default.post(name: .metadataApiKeyDidChange, object: nil)
        } catch {
            isSaved = false
            notice = nil
            surfaceError = AppError(error)
        }
    }

    private func testOMDbAPIKey() async {
        guard let apiKey = normalizedOMDbApiKey else {
            notice = MetadataSettingsPolicy.missingAPIKeyNotice
            surfaceError = nil
            return
        }

        isTestingApiKey = true
        defer { isTestingApiKey = false }

        do {
            let service = appState.createMetadataService(apiKey: apiKey)
            _ = try await service.getDetail(id: MetadataSettingsPolicy.validationProbeIMDbID, type: .movie)
            notice = .success("OMDb API key is valid.")
            surfaceError = nil
        } catch {
            notice = nil
            surfaceError = AppError(error, fallback: .unknown(MetadataSettingsPolicy.validationFailureFallbackMessage))
        }
    }

    private func loadOMDbAPIKey() async {
        do {
            let state = MetadataSettingsPolicy.loadedState(
                for: try await appState.settingsManager.getMetadataApiKey()
            )
            initialOMDbApiKey = state.baselineValue
            omdbApiKey = state.visibleValue
            isSaved = state.isSaved
            surfaceError = nil
        } catch {
            omdbApiKey = ""
            initialOMDbApiKey = ""
            isSaved = false
            surfaceError = AppError(error)
        }
    }
}
