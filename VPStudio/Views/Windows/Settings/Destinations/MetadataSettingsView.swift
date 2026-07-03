import SwiftUI
import UniformTypeIdentifiers

// MARK: - Metadata Settings Policy

enum MetadataSettingsPolicy {
    static let savedMessage = "Metadata provider keys saved."
    static let removedMessage = "Metadata provider keys removed."
    static let missingKeyMessage = "Enter an OMDb key or legacy TMDb key before testing."
    static let legacyFallbackSavedMessage = "Legacy TMDb fallback saved. Add OMDb to enable the primary metadata path."
    static let legacyFallbackValidationMessage = "Legacy TMDb fallback is valid. Add OMDb to enable ratings, search, and sync identity."
    static let validationFailureFallbackMessage = "Metadata validation failed."
    static let validationProbeIMDbID = "tt0111161"
    static let omdbAPIKeyURL = URL(string: "https://www.omdbapi.com/apikey.aspx")!
    static let tmdbAPIKeyURL = URL(string: "https://www.themoviedb.org/settings/api")!
    static let formRowBackground = Color.black.opacity(0.72)
    static let supportingTextColor = Color.white.opacity(0.96)
    static let formSurfaceCornerRadius: CGFloat = 28
    static let formFooterCornerRadius: CGFloat = 22
    static let formSurfaceHorizontalPadding: CGFloat = 20
    static let formSurfaceVerticalPadding: CGFloat = 8
    static let formSectionSpacing: CGFloat = 16
    static let formSurfaceStroke = Color.white.opacity(0.08)
    static let formDividerFill = Color.white.opacity(0.12)
    static let providerCardSpacing: CGFloat = 10
    static let providerCardContentSpacing: CGFloat = 14
    static let providerCardVerticalPadding: CGFloat = 14
    static let providerCardHorizontalPadding: CGFloat = 14
    static let formBottomContentPadding: CGFloat = 12
    static let apiKeyFieldMinHeight: CGFloat = 46
    static let apiKeyFieldCornerRadius: CGFloat = 10
    static let planOptionMinHeight: CGFloat = 36
    static let footerActionMinWidth: CGFloat = 142
    static let footerActionMinHeight: CGFloat = 40
    static let footerActionCornerRadius: CGFloat = 10
    static let apiKeyFieldFill = Color.white.opacity(0.08)
    static let apiKeyFieldStroke = Color.white.opacity(0.16)
    static let selectedPlanFill = VPColor.info.opacity(0.24)
    static let selectedPlanStroke = VPColor.info.opacity(0.88)
    static let selectedPlanShadow = VPColor.info.opacity(0.18)
    static let unselectedPlanFill = Color.white.opacity(0.08)
    static let unselectedPlanStroke = Color.white.opacity(0.14)

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

    static func hasUnsavedAPIKeyChange(
        currentOMDb: String,
        baselineOMDb: String,
        currentTMDb: String,
        baselineTMDb: String
    ) -> Bool {
        hasUnsavedAPIKeyChange(current: currentOMDb, baseline: baselineOMDb)
            || hasUnsavedAPIKeyChange(current: currentTMDb, baseline: baselineTMDb)
    }

    static func hasUnsavedPlanChange(current: MetadataProviderPlan, baseline: MetadataProviderPlan) -> Bool {
        current != baseline
    }

    static func hasUnsavedConfigurationChange(
        currentOMDb: String,
        baselineOMDb: String,
        currentOMDbPlan: MetadataProviderPlan,
        baselineOMDbPlan: MetadataProviderPlan,
        currentTMDb: String,
        baselineTMDb: String,
        currentTMDbPlan: MetadataProviderPlan,
        baselineTMDbPlan: MetadataProviderPlan
    ) -> Bool {
        hasUnsavedAPIKeyChange(
            currentOMDb: currentOMDb,
            baselineOMDb: baselineOMDb,
            currentTMDb: currentTMDb,
            baselineTMDb: baselineTMDb
        )
        || hasUnsavedPlanChange(current: currentOMDbPlan, baseline: baselineOMDbPlan)
        || hasUnsavedPlanChange(current: currentTMDbPlan, baseline: baselineTMDbPlan)
    }

    static func shouldInvalidateSavedState(newValue: String, baseline: String) -> Bool {
        hasUnsavedAPIKeyChange(current: newValue, baseline: baseline)
    }

    static func shouldInvalidateSavedState(newPlan: MetadataProviderPlan, baseline: MetadataProviderPlan) -> Bool {
        hasUnsavedPlanChange(current: newPlan, baseline: baseline)
    }

    static func omdbPlanDescription(for plan: MetadataProviderPlan) -> String {
        switch plan {
        case .free:
            return "Uses OMDb's normal data responses and poster URLs. The separate OMDb Poster API is patron-only."
        case .paid:
            return "Enables patron-only OMDb image resources, including backdrop or banner-style fields, only when OMDb returns usable URLs that do not embed API keys."
        }
    }

    static func tmdbPlanDescription(for plan: MetadataProviderPlan) -> String {
        switch plan {
        case .free:
            return "Keeps legacy TMDb fields available only as a fallback for older saved items, artwork gaps, and migration."
        case .paid:
            return "Allows expanded TMDb image payloads only when OMDb cannot provide usable artwork for a legacy item."
        }
    }

    static func providerPrecedenceMessage(for configuration: MetadataProviderConfiguration) -> String {
        switch MetadataProviderFactory.mode(for: configuration) {
        case .unconfigured:
            return "Add an OMDb key to enable metadata, ratings, search, and sync identity. TMDb is only a legacy fallback."
        case .omdbOnly:
            return "OMDb powers IMDb lookup, ratings, and poster data. Paid OMDb images are used only when your plan returns usable, keyless artwork URLs."
        case .tmdbOnly:
            return "Only a legacy TMDb key is configured. Add OMDb so ratings, search, sync, and imported IMDb IDs use the current metadata path."
        case .dualProviderOMDbPaidArtwork:
            return "OMDb leads metadata, ratings, and artwork. TMDb is kept only for legacy ID fallback and artwork enrichment when OMDb has gaps."
        case .dualProviderOMDbArtwork:
            return "OMDb leads metadata, ratings, and sync identity. TMDb is kept only as a compatibility fallback for older library entries."
        }
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

    static func saveNotice(for configuration: MetadataProviderConfiguration) -> SettingsInlineNotice {
        if configuration.isConfigured {
            return .success(savedMessage)
        }
        if configuration.hasAnyProvider {
            return .warning(legacyFallbackSavedMessage)
        }
        return .success(removedMessage)
    }

    static var missingAPIKeyNotice: SettingsInlineNotice {
        .warning(missingKeyMessage)
    }

    static func validationSuccessMessage(providerNames: [String]) -> String {
        "\(providerList(providerNames)) metadata is valid."
    }

    static func partialValidationWarningMessage(
        validProviderNames: [String],
        failedProviderNames: [String],
        failureDescription: String? = nil
    ) -> String {
        let baseMessage = "\(providerList(validProviderNames)) valid. \(providerList(failedProviderNames)) failed validation."
        let normalizedFailure = normalizedFailureDescription(failureDescription)

        if let normalizedFailure {
            return "\(baseMessage) \(normalizedFailure). The valid provider will still be used."
        }
        return "\(baseMessage) The valid provider will still be used."
    }

    static func validationFailureDescription(for error: Error) -> String {
        IndexerLogSanitizer.redactedErrorMessage(error)
    }

    static func shouldSurfaceBlockingValidationError(validProviderCount: Int, failedProviderCount: Int) -> Bool {
        validProviderCount == 0 && failedProviderCount > 0
    }

    private static func normalizedFailureDescription(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "N/A" else { return nil }
        return trimmed
    }

    private static func providerList(_ names: [String]) -> String {
        names.joined(separator: " + ")
    }
}

// MARK: - Metadata Settings

struct MetadataSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var omdbApiKey = ""
    @State private var tmdbApiKey = ""
    @State private var omdbPlan: MetadataProviderPlan = .free
    @State private var tmdbPlan: MetadataProviderPlan = .free
    @State private var initialOMDbApiKey = ""
    @State private var initialTMDbApiKey = ""
    @State private var initialOMDbPlan: MetadataProviderPlan = .free
    @State private var initialTMDbPlan: MetadataProviderPlan = .free
    @State private var isSaved = false
    @State private var isTestingApiKey = false
    @State private var surfaceError: AppError?
    @State private var notice: SettingsInlineNotice?
    private let disablesAutomaticTasks: Bool

    init(
        initialOMDbApiKey: String = "",
        initialTMDbApiKey: String = "",
        initialOMDbPlan: MetadataProviderPlan = .free,
        initialTMDbPlan: MetadataProviderPlan = .free,
        initialBaselineOMDbApiKey: String? = nil,
        initialBaselineTMDbApiKey: String? = nil,
        initialBaselineOMDbPlan: MetadataProviderPlan? = nil,
        initialBaselineTMDbPlan: MetadataProviderPlan? = nil,
        initialIsSaved: Bool = false,
        initialIsTestingApiKey: Bool = false,
        initialSurfaceError: AppError? = nil,
        initialNotice: SettingsInlineNotice? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        _omdbApiKey = State(initialValue: initialOMDbApiKey)
        _tmdbApiKey = State(initialValue: initialTMDbApiKey)
        _omdbPlan = State(initialValue: initialOMDbPlan)
        _tmdbPlan = State(initialValue: initialTMDbPlan)
        _initialOMDbApiKey = State(initialValue: initialBaselineOMDbApiKey ?? initialOMDbApiKey)
        _initialTMDbApiKey = State(initialValue: initialBaselineTMDbApiKey ?? initialTMDbApiKey)
        _initialOMDbPlan = State(initialValue: initialBaselineOMDbPlan ?? initialOMDbPlan)
        _initialTMDbPlan = State(initialValue: initialBaselineTMDbPlan ?? initialTMDbPlan)
        _isSaved = State(initialValue: initialIsSaved)
        _isTestingApiKey = State(initialValue: initialIsTestingApiKey)
        _surfaceError = State(initialValue: initialSurfaceError)
        _notice = State(initialValue: initialNotice)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    metadataProviderPanel

                    Spacer(minLength: MetadataSettingsPolicy.formSectionSpacing)

                    metadataFooterPanel
                }
                .frame(
                    minHeight: max(
                        0,
                        geometry.size.height
                            - MetadataSettingsPolicy.formBottomContentPadding
                            - (MetadataSettingsPolicy.formSurfaceVerticalPadding * 2)
                    ),
                    alignment: .top
                )
                .padding(.horizontal, MetadataSettingsPolicy.formSurfaceHorizontalPadding)
                .padding(.vertical, MetadataSettingsPolicy.formSurfaceVerticalPadding)
            }
            .scrollContentBackground(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: MetadataSettingsPolicy.formBottomContentPadding)
        }
        .background {
            VPBackground()
        }
        .navigationTitle("Movie & TV Metadata")
        .task {
            guard !disablesAutomaticTasks else { return }
            await loadMetadataConfiguration()
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
        .onChange(of: omdbPlan) { _, newValue in
            guard MetadataSettingsPolicy.shouldInvalidateSavedState(
                newPlan: newValue,
                baseline: initialOMDbPlan
            ) else { return }
            isSaved = false
            notice = nil
            surfaceError = nil
        }
        .onChange(of: tmdbApiKey) { _, newValue in
            guard MetadataSettingsPolicy.shouldInvalidateSavedState(
                newValue: newValue,
                baseline: initialTMDbApiKey
            ) else { return }
            isSaved = false
            notice = nil
            surfaceError = nil
        }
        .onChange(of: tmdbPlan) { _, newValue in
            guard MetadataSettingsPolicy.shouldInvalidateSavedState(
                newPlan: newValue,
                baseline: initialTMDbPlan
            ) else { return }
            isSaved = false
            notice = nil
            surfaceError = nil
        }
    }

    private var metadataProviderPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            metadataProviderCard(
                title: "OMDb",
                description: "Works by IMDb ID and adds IMDb ratings, posters, and paid image resources when OMDb returns usable URLs.",
                linkTitle: "Get OMDb API Key",
                linkDestination: MetadataSettingsPolicy.omdbAPIKeyURL,
                planTitle: "OMDb Plan",
                standardTitle: "Free",
                paidTitle: "Paid",
                selection: $omdbPlan,
                selectedPlanTitle: omdbPlan == .paid ? "Paid" : "Free",
                hasUnsavedPlanChange: MetadataSettingsPolicy.hasUnsavedPlanChange(
                    current: omdbPlan,
                    baseline: initialOMDbPlan
                ),
                planDescription: MetadataSettingsPolicy.omdbPlanDescription(for: omdbPlan)
            ) {
                SecureField("OMDb API Key", text: $omdbApiKey)
                PasteFieldButton { omdbApiKey = $0 }
            }

            metadataPanelDivider

            metadataProviderCard(
                title: "TMDb",
                description: "Adds richer artwork, backdrops, banners, languages, people, and discovery filters.",
                linkTitle: "Open TMDb API Settings",
                linkDestination: MetadataSettingsPolicy.tmdbAPIKeyURL,
                planTitle: "TMDb Plan",
                standardTitle: "Standard",
                paidTitle: "Expanded",
                selection: $tmdbPlan,
                selectedPlanTitle: tmdbPlan == .paid ? "Expanded" : "Standard",
                hasUnsavedPlanChange: MetadataSettingsPolicy.hasUnsavedPlanChange(
                    current: tmdbPlan,
                    baseline: initialTMDbPlan
                ),
                planDescription: MetadataSettingsPolicy.tmdbPlanDescription(for: tmdbPlan)
            ) {
                SecureField("TMDb API Key or Read Token", text: $tmdbApiKey)
                PasteFieldButton { tmdbApiKey = $0 }
            }

            metadataPanelDivider

            Text(MetadataSettingsPolicy.providerPrecedenceMessage(for: metadataConfiguration))
                .font(.caption)
                .foregroundStyle(MetadataSettingsPolicy.supportingTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MetadataSettingsPolicy.providerCardHorizontalPadding)
                .padding(.vertical, 14)
        }
        .background {
            RoundedRectangle(cornerRadius: MetadataSettingsPolicy.formSurfaceCornerRadius, style: .continuous)
                .fill(MetadataSettingsPolicy.formRowBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MetadataSettingsPolicy.formSurfaceCornerRadius, style: .continuous)
                .strokeBorder(MetadataSettingsPolicy.formSurfaceStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: MetadataSettingsPolicy.formSurfaceCornerRadius, style: .continuous))
    }

    private var metadataFooterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                metadataFooterActionButton(
                    title: "Save changes",
                    systemImage: "tray.and.arrow.down",
                    isEnabled: hasUnsavedChanges,
                    tint: VPColor.info
                ) {
                    Task { await saveMetadataConfiguration() }
                }

                metadataFooterActionButton(
                    title: isTestingApiKey ? "Testing" : "Test API Key",
                    systemImage: isTestingApiKey ? "hourglass" : "checkmark.shield",
                    isEnabled: isTestingApiKey == false && metadataConfiguration.hasAnyProvider,
                    tint: VPColor.success
                ) {
                    Task { await testMetadataAPIKeys() }
                }

                Spacer(minLength: 12)

                metadataFooterStatus
            }

            if let notice {
                SettingsNoticeBanner(notice: notice)
            }

            if let surfaceError {
                SettingsErrorBanner(error: surfaceError)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: MetadataSettingsPolicy.formFooterCornerRadius, style: .continuous)
                .fill(MetadataSettingsPolicy.formRowBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MetadataSettingsPolicy.formFooterCornerRadius, style: .continuous)
                .strokeBorder(MetadataSettingsPolicy.formSurfaceStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: MetadataSettingsPolicy.formFooterCornerRadius, style: .continuous))
    }

    private var metadataPanelDivider: some View {
        Rectangle()
            .fill(MetadataSettingsPolicy.formDividerFill)
            .frame(height: 0.8)
    }

    private var normalizedOMDbApiKey: String? {
        MetadataSettingsPolicy.normalizedAPIKey(omdbApiKey)
    }

    private var normalizedTMDbApiKey: String? {
        MetadataSettingsPolicy.normalizedAPIKey(tmdbApiKey)
    }

    private var metadataConfiguration: MetadataProviderConfiguration {
        MetadataProviderConfiguration(
            omdbApiKey: normalizedOMDbApiKey,
            tmdbApiKey: normalizedTMDbApiKey,
            omdbPlan: omdbPlan,
            tmdbPlan: tmdbPlan
        )
    }

    private func metadataProviderCard<Field: View>(
        title: String,
        description: String,
        linkTitle: String,
        linkDestination: URL,
        planTitle: String,
        standardTitle: String,
        paidTitle: String,
        selection: Binding<MetadataProviderPlan>,
        selectedPlanTitle: String,
        hasUnsavedPlanChange: Bool,
        planDescription: String,
        @ViewBuilder field: () -> Field
    ) -> some View {
        VStack(alignment: .leading, spacing: MetadataSettingsPolicy.providerCardContentSpacing) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, alignment: .leading)

                HStack(spacing: 8) {
                    field()
                }
                .padding(.leading, 12)
                .frame(minHeight: MetadataSettingsPolicy.apiKeyFieldMinHeight)
                .background {
                    RoundedRectangle(
                        cornerRadius: MetadataSettingsPolicy.apiKeyFieldCornerRadius,
                        style: .continuous
                    )
                    .fill(MetadataSettingsPolicy.apiKeyFieldFill)
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: MetadataSettingsPolicy.apiKeyFieldCornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(MetadataSettingsPolicy.apiKeyFieldStroke, lineWidth: 0.8)
                }
            }

            Text(description)
                .font(.footnote)
                .foregroundStyle(MetadataSettingsPolicy.supportingTextColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 16) {
                metadataProviderLink(title: linkTitle, destination: linkDestination)
                    .frame(maxWidth: .infinity, alignment: .leading)

                metadataPlanSelector(
                    title: planTitle,
                    standardTitle: standardTitle,
                    paidTitle: paidTitle,
                    selection: selection
                )
                .frame(maxWidth: 520)
            }

            metadataPlanStateRow(
                title: planTitle,
                selectedTitle: selectedPlanTitle,
                isUnsaved: hasUnsavedPlanChange
            )

            Text(planDescription)
                .font(.footnote)
                .foregroundStyle(MetadataSettingsPolicy.supportingTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, MetadataSettingsPolicy.providerCardVerticalPadding)
        .padding(.horizontal, MetadataSettingsPolicy.providerCardHorizontalPadding)
        .accessibilityElement(children: .contain)
    }

    private func metadataPlanStateRow(
        title: String,
        selectedTitle: String,
        isUnsaved: Bool
    ) -> some View {
        Label(
            "\(title): \(selectedTitle) \(isUnsaved ? "unsaved" : "saved")",
            systemImage: isUnsaved ? "circle.dashed" : "checkmark.circle"
        )
        .font(.footnote.weight(.semibold))
        .foregroundStyle(isUnsaved ? VPColor.warning : VPColor.success)
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("\(title) is \(selectedTitle), \(isUnsaved ? "unsaved" : "saved")")
    }

    private func metadataPlanSelector(
        title: String,
        standardTitle: String,
        paidTitle: String,
        selection: Binding<MetadataProviderPlan>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 8) {
                metadataPlanOption(title: standardTitle, plan: .free, selection: selection)
                metadataPlanOption(title: paidTitle, plan: .paid, selection: selection)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func metadataProviderLink(title: String, destination: URL) -> some View {
        Link(destination: destination) {
            Label(title, systemImage: "arrow.up.right.square")
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(VPColor.info)
    }

    private func metadataPlanOption(
        title: String,
        plan: MetadataProviderPlan,
        selection: Binding<MetadataProviderPlan>
    ) -> some View {
        let isSelected = selection.wrappedValue == plan
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection.wrappedValue = plan
            }
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .frame(minHeight: MetadataSettingsPolicy.planOptionMinHeight)
                .background {
                    Capsule()
                        .fill(isSelected ? MetadataSettingsPolicy.selectedPlanFill : MetadataSettingsPolicy.unselectedPlanFill)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected ? MetadataSettingsPolicy.selectedPlanStroke : MetadataSettingsPolicy.unselectedPlanStroke,
                            lineWidth: isSelected ? 1.2 : 0.8
                        )
                }
                .shadow(color: isSelected ? MetadataSettingsPolicy.selectedPlanShadow : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) plan")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        #if os(visionOS)
        .hoverEffect(.highlight)
        #endif
    }

    private func metadataFooterActionButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.62))
                .frame(minWidth: MetadataSettingsPolicy.footerActionMinWidth)
                .frame(minHeight: MetadataSettingsPolicy.footerActionMinHeight)
                .background {
                    RoundedRectangle(cornerRadius: MetadataSettingsPolicy.footerActionCornerRadius, style: .continuous)
                        .fill(isEnabled ? tint.opacity(0.24) : Color.white.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MetadataSettingsPolicy.footerActionCornerRadius, style: .continuous)
                        .strokeBorder(isEnabled ? tint.opacity(0.82) : Color.white.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isEnabled ? "Available" : "Unavailable")
        #if os(visionOS)
        .hoverEffect(.highlight)
        #endif
    }

    @ViewBuilder
    private var metadataFooterStatus: some View {
        if isSaved {
            metadataStatusChip(title: "Saved", systemImage: "checkmark.circle.fill", tint: VPColor.success)
        } else if hasUnsavedChanges {
            metadataStatusChip(title: "Unsaved", systemImage: "circle.dashed", tint: VPColor.warning)
        } else {
            metadataStatusChip(title: metadataConfiguration.isConfigured ? "Ready" : "Not configured", systemImage: "info.circle.fill", tint: VPColor.info)
        }
    }

    private func metadataStatusChip(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(tint.opacity(0.14))
            }
            .overlay {
                Capsule()
                    .strokeBorder(tint.opacity(0.42), lineWidth: 0.8)
            }
            .frame(minWidth: 112, alignment: .trailing)
    }

    private var hasUnsavedChanges: Bool {
        MetadataSettingsPolicy.hasUnsavedConfigurationChange(
            currentOMDb: omdbApiKey,
            baselineOMDb: initialOMDbApiKey,
            currentOMDbPlan: omdbPlan,
            baselineOMDbPlan: initialOMDbPlan,
            currentTMDb: tmdbApiKey,
            baselineTMDb: initialTMDbApiKey,
            currentTMDbPlan: tmdbPlan,
            baselineTMDbPlan: initialTMDbPlan
        )
    }

    private func saveMetadataConfiguration() async {
        do {
            let configuration = metadataConfiguration
            try await appState.settingsManager.setString(key: SettingsKeys.omdbApiKey, value: configuration.omdbApiKey)
            try await appState.settingsManager.setString(key: SettingsKeys.tmdbApiKey, value: configuration.tmdbApiKey)
            try await appState.settingsManager.setString(key: SettingsKeys.omdbProviderPlan, value: configuration.omdbPlan.rawValue)
            try await appState.settingsManager.setString(key: SettingsKeys.tmdbProviderPlan, value: configuration.tmdbPlan.rawValue)
            initialOMDbApiKey = configuration.omdbApiKey ?? ""
            initialTMDbApiKey = configuration.tmdbApiKey ?? ""
            initialOMDbPlan = configuration.omdbPlan
            initialTMDbPlan = configuration.tmdbPlan
            omdbApiKey = configuration.omdbApiKey ?? ""
            tmdbApiKey = configuration.tmdbApiKey ?? ""
            omdbPlan = configuration.omdbPlan
            tmdbPlan = configuration.tmdbPlan
            isSaved = configuration.isConfigured
            surfaceError = nil
            notice = MetadataSettingsPolicy.saveNotice(for: configuration)
            NotificationCenter.default.post(name: .metadataApiKeyDidChange, object: nil)
        } catch {
            isSaved = false
            notice = nil
            surfaceError = AppError(error)
        }
    }

    private func testMetadataAPIKeys() async {
        let configuration = metadataConfiguration
        guard configuration.hasAnyProvider else {
            notice = MetadataSettingsPolicy.missingAPIKeyNotice
            surfaceError = nil
            return
        }

        isTestingApiKey = true
        defer { isTestingApiKey = false }

        var validProviders: [String] = []
        var failedProviders: [(name: String, error: Error)] = []

        if let omdbApiKey = configuration.omdbApiKey {
            do {
                _ = try await OMDbService(apiKey: omdbApiKey, includesPaidArtwork: configuration.omdbPlan.usesPaidResources)
                    .getDetail(id: MetadataSettingsPolicy.validationProbeIMDbID, type: .movie)
                validProviders.append("OMDb")
            } catch {
                failedProviders.append(("OMDb", error))
            }
        }

        if let tmdbApiKey = configuration.tmdbApiKey {
            do {
                _ = try await TMDBService(apiKey: tmdbApiKey, plan: configuration.tmdbPlan)
                    .getDetail(id: MetadataSettingsPolicy.validationProbeIMDbID, type: .movie)
                validProviders.append("TMDb")
            } catch {
                failedProviders.append(("TMDb", error))
            }
        }

        if failedProviders.isEmpty {
            notice = configuration.isConfigured
                ? .success(MetadataSettingsPolicy.validationSuccessMessage(providerNames: validProviders))
                : .warning(MetadataSettingsPolicy.legacyFallbackValidationMessage)
            surfaceError = nil
        } else if !MetadataSettingsPolicy.shouldSurfaceBlockingValidationError(
            validProviderCount: validProviders.count,
            failedProviderCount: failedProviders.count
        ),
            let firstFailure = failedProviders.first {
            notice = .warning(
                MetadataSettingsPolicy.partialValidationWarningMessage(
                    validProviderNames: validProviders,
                    failedProviderNames: failedProviders.map(\.name),
                    failureDescription: MetadataSettingsPolicy.validationFailureDescription(for: firstFailure.error)
                )
            )
            surfaceError = nil
        } else if let firstFailure = failedProviders.first {
            notice = nil
            surfaceError = AppError(firstFailure.error, fallback: .unknown(MetadataSettingsPolicy.validationFailureFallbackMessage))
        }
    }

    private func loadMetadataConfiguration() async {
        do {
            let configuration = try await appState.settingsManager.getMetadataProviderConfiguration()
            initialOMDbApiKey = configuration.omdbApiKey ?? ""
            initialTMDbApiKey = configuration.tmdbApiKey ?? ""
            initialOMDbPlan = configuration.omdbPlan
            initialTMDbPlan = configuration.tmdbPlan
            omdbApiKey = configuration.omdbApiKey ?? ""
            tmdbApiKey = configuration.tmdbApiKey ?? ""
            omdbPlan = configuration.omdbPlan
            tmdbPlan = configuration.tmdbPlan
            isSaved = configuration.isConfigured
            surfaceError = nil
        } catch {
            omdbApiKey = ""
            tmdbApiKey = ""
            omdbPlan = .free
            tmdbPlan = .free
            initialOMDbApiKey = ""
            initialTMDbApiKey = ""
            initialOMDbPlan = .free
            initialTMDbPlan = .free
            isSaved = false
            surfaceError = AppError(error)
        }
    }
}
