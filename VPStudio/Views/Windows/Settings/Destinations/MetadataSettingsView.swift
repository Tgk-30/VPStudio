import SwiftUI
import UniformTypeIdentifiers

// MARK: - Metadata Settings Policy

enum MetadataSettingsPolicy {
    static let savedMessage = "TMDB API key saved."
    static let removedMessage = "TMDB API key removed."
    static let missingKeyMessage = "Enter an API key before testing."
    static let validationFailureFallbackMessage = "TMDB validation failed."

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
    @State private var tmdbApiKey = ""
    @State private var initialTMDBApiKey = ""
    @State private var isSaved = false
    @State private var isTestingApiKey = false
    @State private var surfaceError: AppError?
    @State private var notice: SettingsInlineNotice?
    private let disablesAutomaticTasks: Bool

    init(
        initialTMDBApiKey: String = "",
        initialBaselineTMDBApiKey: String? = nil,
        initialIsSaved: Bool = false,
        initialIsTestingApiKey: Bool = false,
        initialSurfaceError: AppError? = nil,
        initialNotice: SettingsInlineNotice? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        _tmdbApiKey = State(initialValue: initialTMDBApiKey)
        _initialTMDBApiKey = State(initialValue: initialBaselineTMDBApiKey ?? initialTMDBApiKey)
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
                    SecureField("TMDB API Key", text: $tmdbApiKey)
                    PasteFieldButton { tmdbApiKey = $0 }
                }
                Text("Get a free key at themoviedb.org")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Save") {
                    Task { await saveTMDBAPIKey() }
                }
                .disabled(!hasUnsavedChanges)

                Button(isTestingApiKey ? "Testing..." : "Test API Key") {
                    Task { await testTMDBAPIKey() }
                }
                .disabled(isTestingApiKey || normalizedTMDBApiKey == nil)

                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let notice {
                    SettingsNoticeBanner(notice: notice)
                }

                if let surfaceError {
                    SettingsErrorBanner(error: surfaceError)
                }
            }
        }
        .navigationTitle("Movie & TV Metadata (TMDB)")
        .task {
            guard !disablesAutomaticTasks else { return }
            await loadTMDBAPIKey()
        }
        .onChange(of: tmdbApiKey) { _, _ in
            isSaved = false
            notice = nil
            surfaceError = nil
        }
    }

    private var normalizedTMDBApiKey: String? {
        MetadataSettingsPolicy.normalizedAPIKey(tmdbApiKey)
    }

    private var hasUnsavedChanges: Bool {
        MetadataSettingsPolicy.hasUnsavedAPIKeyChange(current: tmdbApiKey, baseline: initialTMDBApiKey)
    }

    private func saveTMDBAPIKey() async {
        do {
            let normalized = normalizedTMDBApiKey
            try await appState.settingsManager.setString(key: SettingsKeys.tmdbApiKey, value: normalized)
            let presentation = MetadataSettingsPolicy.savePresentation(for: normalized)
            tmdbApiKey = presentation.visibleValue
            initialTMDBApiKey = presentation.baselineValue
            isSaved = presentation.isSaved
            surfaceError = nil
            notice = presentation.notice
            NotificationCenter.default.post(name: .tmdbApiKeyDidChange, object: nil)
        } catch {
            isSaved = false
            notice = nil
            surfaceError = AppError(error)
        }
    }

    private func testTMDBAPIKey() async {
        guard let apiKey = normalizedTMDBApiKey else {
            notice = MetadataSettingsPolicy.missingAPIKeyNotice
            surfaceError = nil
            return
        }

        isTestingApiKey = true
        defer { isTestingApiKey = false }

        do {
            let service = appState.createMetadataService(apiKey: apiKey)
            _ = try await service.getTrending(type: .movie, timeWindow: .week, page: 1)
            notice = .success("TMDB API key is valid.")
            surfaceError = nil
        } catch {
            notice = nil
            surfaceError = AppError(error, fallback: .unknown(MetadataSettingsPolicy.validationFailureFallbackMessage))
        }
    }

    private func loadTMDBAPIKey() async {
        do {
            let state = MetadataSettingsPolicy.loadedState(
                for: try await appState.settingsManager.getString(key: SettingsKeys.tmdbApiKey)
            )
            tmdbApiKey = state.visibleValue
            initialTMDBApiKey = state.baselineValue
            isSaved = state.isSaved
            surfaceError = nil
        } catch {
            tmdbApiKey = ""
            initialTMDBApiKey = ""
            isSaved = false
            surfaceError = AppError(error)
        }
    }
}
