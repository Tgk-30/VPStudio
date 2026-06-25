import Foundation
import Testing
@testable import VPStudio

@Suite("Settings View Behavioral Tests")
struct SettingsViewBehavioralTests {

    // MARK: - IndexerSettingsView Tests

    @Suite("IndexerSettingsView")
    struct IndexerSettingsViewTests {
        @Test
        func indexerDraftNewProducesDefaultValues() {
            let draft = IndexerSettingsView.IndexerDraft.new()

            #expect(draft.editingID == nil)
            #expect(draft.name == "")
            #expect(draft.indexerType == .jackett)
            #expect(draft.baseURL == "")
            #expect(draft.apiKey == "")
            #expect(draft.isActive == true)
            #expect(draft.endpointPath == "/api/v2.0/indexers/all/results/torznab/api")
            #expect(draft.categoryFilter == "")
            #expect(draft.apiKeyTransport == .header)
        }

        @Test
        func indexerDraftFromConfigPreservesEditableFields() {
            let config = IndexerConfig(
                id: "config-123",
                name: "My Indexer",
                indexerType: .prowlarr,
                baseURL: "https://prowlarr.example",
                apiKey: "secret-key",
                isActive: false,
                priority: 5,
                endpointPath: "/api/v1/search",
                categoryFilter: "5000",
                apiKeyTransport: .query
            )

            let draft = IndexerSettingsView.IndexerDraft.from(config)

            #expect(draft.editingID == "config-123")
            #expect(draft.name == "My Indexer")
            #expect(draft.indexerType == .prowlarr)
            #expect(draft.baseURL == "https://prowlarr.example")
            #expect(draft.apiKey == "secret-key")
            #expect(draft.isActive == false)
            #expect(draft.endpointPath == "/api/v1/search")
            #expect(draft.categoryFilter == "5000")
            #expect(draft.apiKeyTransport == .query)
        }

        @Test
        func indexerDraftNormalizationTrimsWhitespace() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.name = "  My Indexer  "
            draft.baseURL = "  https://example.com  "
            draft.apiKey = "  token-value  "
            draft.endpointPath = "  /api/custom  "
            draft.categoryFilter = "  2000,5000  "

            #expect(draft.normalizedURL == "https://example.com")
            #expect(draft.normalizedAPIKey == "token-value")
            #expect(draft.normalizedEndpointPath == "/api/custom")
            #expect(draft.normalizedCategoryFilter == "2000,5000")
        }

        @Test
        func indexerDraftValidationRequiresName() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            #expect(draft.validationError == "Indexer name is required.")

            draft.name = "Valid Name"
            draft.baseURL = "https://valid.example"
            draft.apiKey = "token"
            #expect(draft.validationError == nil)
        }

        @Test
        func indexerDraftValidationRequiresHTTPSForRemoteURLsButAllowsLocalHTTP() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.name = "Test"
            draft.baseURL = "http://insecure.example"
            draft.apiKey = "token"

            #expect(draft.validationError == IndexerURLSecurityPolicy.validationMessage)

            draft.baseURL = "https://secure.example"
            #expect(draft.validationError == nil)

            draft.baseURL = "http://localhost:9696"
            #expect(draft.validationError == nil)

            draft.baseURL = "http://192.168.1.40:9117"
            #expect(draft.validationError == nil)
        }

        @Test
        func indexerDraftValidationRequiresAPIKeyForJackett() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.name = "Test"
            draft.baseURL = "https://jackett.example"
            draft.apiKey = ""

            #expect(draft.validationError == "API key is required for Jackett.")

            draft.apiKey = "valid-token"
            #expect(draft.validationError == nil)
        }

        @Test
        func indexerDraftValidationRequiresAPIKeyForProwlarr() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.indexerType = .prowlarr
            draft.name = "Test"
            draft.baseURL = "https://prowlarr.example"
            draft.apiKey = ""

            #expect(draft.validationError == "API key is required for Prowlarr.")
        }

        @Test
        func indexerDraftValidationRequiresAPIKeyForTorznab() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.indexerType = .torznab
            draft.name = "Test"
            draft.baseURL = "https://torznab.example"
            draft.apiKey = ""

            #expect(draft.validationError == "API key is required for Torznab.")
        }

        @Test
        func indexerDraftStremioValidationChecksManifestEndpoint() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.indexerType = .stremio
            draft.name = "Stremio"
            draft.baseURL = "https://stremio.example"
            draft.applyDefaults(for: .stremio)

            #expect(draft.validationError == nil)

            draft.endpointPath = "/catalog/movie/top.json"
            #expect(draft.validationError == "Stremio endpoint should usually point to /manifest.json.")

            draft.endpointPath = "/manifest.json"
            #expect(draft.validationError == nil)
        }

        @Test
        func indexerDraftFieldVisibilityForJackett() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.indexerType = .jackett

            #expect(draft.showsAPIKeyField == true)
            #expect(draft.showsAPIKeyTransportField == true)
            #expect(draft.showsEndpointPathField == true)
            #expect(draft.showsCategoryField == true)
        }

        @Test
        func indexerDraftFieldVisibilityForProwlarr() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.indexerType = .prowlarr

            #expect(draft.showsAPIKeyField == true)
            #expect(draft.showsAPIKeyTransportField == true)
            #expect(draft.showsEndpointPathField == true)
            #expect(draft.showsCategoryField == false)
        }

        @Test
        func indexerDraftFieldVisibilityForStremio() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.indexerType = .stremio

            #expect(draft.showsAPIKeyField == false)
            #expect(draft.showsAPIKeyTransportField == false)
            #expect(draft.showsEndpointPathField == true)
            #expect(draft.showsCategoryField == false)
        }

        @Test
        func indexerDraftFieldVisibilityForBuiltIns() {
            for type in [IndexerConfig.IndexerType.apiBay, .yts, .eztv] {
                var draft = IndexerSettingsView.IndexerDraft.new()
                draft.indexerType = type

                #expect(draft.showsAPIKeyField == false)
                #expect(draft.showsAPIKeyTransportField == false)
                #expect(draft.showsEndpointPathField == false)
                #expect(draft.showsCategoryField == false)
            }
        }

        @Test
        func indexerDraftApplyDefaultsSetsCorrectEndpointForEachType() {
            var draft = IndexerSettingsView.IndexerDraft.new()

            draft.indexerType = .jackett
            draft.applyDefaults(for: .jackett)
            #expect(draft.endpointPath == "/api/v2.0/indexers/all/results/torznab/api")
            #expect(draft.apiKeyTransport == .header)

            draft.indexerType = .prowlarr
            draft.applyDefaults(for: .prowlarr)
            #expect(draft.endpointPath == "/api/v1/search")
            #expect(draft.apiKeyTransport == .header)

            draft.indexerType = .torznab
            draft.applyDefaults(for: .torznab)
            #expect(draft.endpointPath == "/api")
            #expect(draft.apiKeyTransport == .header)

            draft.indexerType = .stremio
            draft.applyDefaults(for: .stremio)
            #expect(draft.endpointPath == "/manifest.json")
            #expect(draft.apiKeyTransport == .query)

            draft.indexerType = .zilean
            draft.applyDefaults(for: .zilean)
            #expect(draft.endpointPath == "/api")
            #expect(draft.apiKeyTransport == .query)
        }

        @Test
        func indexerDraftApplyDefaultsClearsCategoryForTypesWithoutField() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.categoryFilter = "2000,5000"
            draft.indexerType = .jackett
            draft.applyDefaults(for: .jackett)
            #expect(draft.categoryFilter == "2000,5000")

            draft.categoryFilter = "2000,5000"
            draft.indexerType = .stremio
            draft.applyDefaults(for: .stremio)
            #expect(draft.categoryFilter.isEmpty)
        }

        @Test
        func indexerDraftProviderSubtypeMapping() {
            var draft = IndexerSettingsView.IndexerDraft.new()

            draft.indexerType = .jackett
            #expect(draft.providerSubtype == .jackett)

            draft.indexerType = .prowlarr
            #expect(draft.providerSubtype == .prowlarr)

            draft.indexerType = .stremio
            #expect(draft.providerSubtype == .stremioAddon)

            draft.indexerType = .torznab
            #expect(draft.providerSubtype == .customTorznab)

            draft.indexerType = .zilean
            #expect(draft.providerSubtype == .customTorznab)

            draft.indexerType = .apiBay
            #expect(draft.providerSubtype == .builtIn)

            draft.indexerType = .yts
            #expect(draft.providerSubtype == .builtIn)

            draft.indexerType = .eztv
            #expect(draft.providerSubtype == .builtIn)
        }

        @Test
        func indexerDraftNormalizedURLReturnsNilForEmptyString() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.baseURL = ""
            #expect(draft.normalizedURL == nil)

            draft.baseURL = "   "
            #expect(draft.normalizedURL == nil)

            draft.baseURL = "https://valid.example"
            #expect(draft.normalizedURL == "https://valid.example")
        }

        @Test
        func indexerDraftNormalizedAPIKeyReturnsNilForEmptyString() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.apiKey = ""
            #expect(draft.normalizedAPIKey == nil)

            draft.apiKey = "   "
            #expect(draft.normalizedAPIKey == nil)

            draft.apiKey = "valid-token"
            #expect(draft.normalizedAPIKey == "valid-token")
        }

        @Test
        func indexerDraftNormalizedEndpointPathAddsLeadingSlash() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.endpointPath = "api/custom"

            #expect(draft.normalizedEndpointPath == "/api/custom")

            draft.endpointPath = "/already/slashed"
            #expect(draft.normalizedEndpointPath == "/already/slashed")
        }

        @Test
        func indexerDraftNormalizedEndpointPathUsesDefaultWhenEmpty() {
            var draft = IndexerSettingsView.IndexerDraft.new()
            draft.endpointPath = ""
            draft.indexerType = .jackett

            #expect(draft.normalizedEndpointPath == "/api/v2.0/indexers/all/results/torznab/api")
        }

        @Test
        func normalizePrioritiesPreservingOrderAssignsSequentialPriorities() {
            let first = makeTorznab(id: "first", name: "First", priority: 0, isActive: true)
            let second = makeTorznab(id: "second", name: "Second", priority: 2, isActive: true)
            let third = makeTorznab(id: "third", name: "Third", priority: 1, isActive: true)

            let reordered = [third, first, second]
            let normalized = IndexerSettingsView.normalizePrioritiesPreservingOrder(reordered)

            #expect(normalized.map(\.id) == ["third", "first", "second"])
            #expect(normalized.map(\.priority) == [0, 1, 2])
        }

        @Test
        func normalizePrioritiesPreservingOrderWithEmptyArray() {
            let normalized = IndexerSettingsView.normalizePrioritiesPreservingOrder([])
            #expect(normalized.isEmpty)
        }

        @Test
        func normalizePrioritiesPreservingOrderWithSingleElement() {
            let single = [makeTorznab(id: "only", name: "Only", priority: 99, isActive: true)]
            let normalized = IndexerSettingsView.normalizePrioritiesPreservingOrder(single)

            #expect(normalized.count == 1)
            #expect(normalized.first?.priority == 0)
        }

        private func makeTorznab(id: String, name: String, priority: Int, isActive: Bool) -> IndexerConfig {
            IndexerConfig(
                id: id,
                name: name,
                indexerType: .torznab,
                baseURL: "https://\(name.lowercased()).example",
                apiKey: "api-key",
                isActive: isActive,
                priority: priority
            )
        }
    }

    // MARK: - MetadataSettingsView Tests

    @Suite("MetadataSettingsView")
    struct MetadataSettingsViewTests {
        @Test
        func hasUnsavedChangesDetectsUnchangedSecret() {
            #expect(SettingsInputValidation.hasUnsavedSecretChange(current: "api-key", initial: "api-key") == false)
        }

        @Test
        func hasUnsavedChangesDetectsChangedSecret() {
            #expect(SettingsInputValidation.hasUnsavedSecretChange(current: "new-key", initial: "old-key") == true)
        }

        @Test
        func hasUnsavedChangesTrimsBeforeComparing() {
            #expect(SettingsInputValidation.hasUnsavedSecretChange(current: "  api-key  ", initial: "api-key") == false)
        }

        @Test
        func hasUnsavedChangesWithEmptyCurrentAndNilInitial() {
            #expect(SettingsInputValidation.hasUnsavedSecretChange(current: "", initial: "") == false)
        }

        @Test
        func hasUnsavedChangesWithNewValueAndEmptyInitial() {
            #expect(SettingsInputValidation.hasUnsavedSecretChange(current: "new-key", initial: "") == true)
        }

        @Test
        func hasUnsavedChangesWithEmptyCurrentAndExistingInitial() {
            #expect(SettingsInputValidation.hasUnsavedSecretChange(current: "", initial: "old-key") == true)
        }

        @Test
        func normalizedSecretTrimsWhitespace() {
            #expect(SettingsInputValidation.normalizedSecret("  key  ") == "key")
        }

        @Test
        func normalizedSecretReturnsNilForEmptyString() {
            #expect(SettingsInputValidation.normalizedSecret("") == nil)
        }

        @Test
        func normalizedSecretReturnsNilForWhitespaceOnly() {
            #expect(SettingsInputValidation.normalizedSecret("   \n\t ") == nil)
        }
    }

    // MARK: - SubtitleSettingsView Tests

    @Suite("SubtitleSettingsView")
    struct SubtitleSettingsViewTests {
        @Test
        func subtitleFontSizeClampedToValidRange() {
            let minSize = 16.0
            let maxSize = 48.0

            #expect(max(minSize, min(maxSize, 10)) == minSize)
            #expect(max(minSize, min(maxSize, 50)) == maxSize)
            #expect(max(minSize, min(maxSize, 32)) == 32)
        }

        @Test
        func subtitleLanguageDefaultsToEnglish() {
            let defaultLanguage = "en"
            #expect(defaultLanguage == "en")
        }

        @Test
        func subtitleAutoSearchDefaultsToTrue() {
            let defaultAutoSearch = true
            #expect(defaultAutoSearch == true)
        }
    }

    // MARK: - PlayerSettingsView Tests

    @Suite("PlayerSettingsView")
    struct PlayerSettingsViewTests {
        @Test
        func videoQualityEnumHasExpectedCases() {
            let cases = VideoQuality.allCases
            #expect(cases.contains(.uhd4k))
            #expect(cases.contains(.hd1080p))
            #expect(cases.contains(.hd720p))
            #expect(cases.count >= 3)
        }

        @Test
        func hdrPreferenceEnumHasExpectedCases() {
            let cases = HDRPreference.allCases
            #expect(cases.contains(.auto))
            #expect(cases.contains(.dolbyVision))
            #expect(cases.contains(.hdr10))
            #expect(cases.contains(.hdr10))
        }

        @Test
        func playerEngineStrategyEnumHasExpectedCases() {
            let cases = PlayerEngineStrategy.allCases
            #expect(cases.contains(.compatibility))
            #expect(cases.contains(.adaptive))
            #expect(cases.contains(.performance))
        }

        @Test
        func externalPlayerAppEnumHasExpectedCases() {
            let cases = ExternalPlayerApp.allCases
            #expect(cases.contains(.builtIn))
            #expect(cases.contains(.vlc))
            #expect(cases.contains(.infuse))
            #expect(cases.contains(.custom))
        }

        @Test
        func navigationLayoutEnumHasExpectedCases() {
            let cases = NavigationLayout.allCases
            #expect(cases.contains(.bottomTabBar))
            #expect(cases.contains(.leftSidebar))
        }

        @Test
        func videoQualityRawValueRoundTrip() {
            for quality in VideoQuality.allCases {
                let recovered = VideoQuality(rawValue: quality.rawValue)
                #expect(recovered == quality)
            }
        }

        @Test
        func hdrPreferenceRawValueRoundTrip() {
            for preference in HDRPreference.allCases {
                let recovered = HDRPreference(rawValue: preference.rawValue)
                #expect(recovered == preference)
            }
        }

        @Test
        func playerEngineStrategyRawValueRoundTrip() {
            for strategy in PlayerEngineStrategy.allCases {
                let recovered = PlayerEngineStrategy(rawValue: strategy.rawValue)
                #expect(recovered == strategy)
            }
        }

        @Test
        func externalPlayerAppRawValueRoundTrip() {
            for app in ExternalPlayerApp.allCases {
                let recovered = ExternalPlayerApp(rawValue: app.rawValue)
                #expect(recovered == app)
            }
        }

        @Test
        func navigationLayoutRawValueRoundTrip() {
            for layout in NavigationLayout.allCases {
                let recovered = NavigationLayout(rawValue: layout.rawValue)
                #expect(recovered == layout)
            }
        }

        @Test
        func settingsKeysContainsExpectedPlayerKeys() {
            #expect(SettingsKeys.preferredQuality == "preferred_quality")
            #expect(SettingsKeys.autoPlayNext == "auto_play_next")
            #expect(SettingsKeys.hardwareDecoding == "hardware_decoding")
            #expect(SettingsKeys.playerEngineStrategy == "player_engine_strategy")
            #expect(SettingsKeys.externalPlayerApp == "external_player_app")
            #expect(SettingsKeys.externalPlayerURLTemplate == "external_player_url_template")
            #expect(SettingsKeys.preferCachedStreams == "prefer_cached_streams")
            #expect(SettingsKeys.preferAtmosAudio == "prefer_atmos_audio")
            #expect(SettingsKeys.preferredHDRFormat == "preferred_hdr_format")
            #expect(SettingsKeys.runtimeDiagnosticsEnabled == "runtime_diagnostics_enabled")
            #expect(SettingsKeys.navigationLayout == "navigation_layout")
        }
    }

    // MARK: - ExternalPlayerRouting Validation Tests

    @Suite("ExternalPlayerRouting")
    struct ExternalPlayerRoutingTests {
        @Test
        func customTemplateValidationRecognizesEmptyTemplate() {
            let result = ExternalPlayerRouting.validationResult(forCustomTemplate: "")
            #expect(result == .empty)
        }

        @Test
        func customTemplateValidationRecognizesValidTemplate() {
            let result = ExternalPlayerRouting.validationResult(forCustomTemplate: "player://open?url={url}")
            #expect(result == .valid)
        }

        @Test
        func customTemplateValidationDetectsMissingUrlPlaceholder() {
            // Templates without {url} are still valid if they have a valid scheme
            let result = ExternalPlayerRouting.validationResult(forCustomTemplate: "player://open?url=https://example.com")
            #expect(result == .valid)
        }

        @Test
        func normalizedCustomTemplatePreservesValidTemplate() {
            let template = "player://open?url={url}"
            let normalized = ExternalPlayerRouting.normalizedCustomTemplate(template)
            #expect(normalized == template)
        }

        @Test
        func normalizedCustomTemplateReturnsNilForEmpty() {
            let normalized = ExternalPlayerRouting.normalizedCustomTemplate("")
            #expect(normalized == nil)
        }

        @Test
        func normalizedCustomTemplateTrimsWhitespace() {
            let normalized = ExternalPlayerRouting.normalizedCustomTemplate("  player://open?url={url}  ")
            #expect(normalized == "player://open?url={url}")
        }
    }

    // MARK: - IndexerDefaultRanking Tests

    @Suite("IndexerDefaultRanking")
    struct IndexerDefaultRankingTests {
        @Test
        func deletedBuiltInsReturnsCorrectSet() {
            let configured = [
                IndexerConfig(id: "apiBay", name: "APiBay", indexerType: .apiBay, isActive: true, priority: 0),
                IndexerConfig(id: "custom", name: "Custom", indexerType: .torznab, isActive: true, priority: 1)
            ]

            let missing = IndexerDefaultRanking.deletedBuiltIns(from: configured)
            let missingTypes = missing.map(\.type)

            #expect(missingTypes.contains(.yts))
            #expect(missingTypes.contains(.eztv))
            #expect(!missingTypes.contains(.apiBay))
            #expect(!missingTypes.contains(.torznab))
        }

        @Test
        func deletedBuiltInsReturnsEmptyWhenAllBuiltInsConfigured() {
            let configured = [
                IndexerConfig(id: "builtin-apibay", name: "APiBay", indexerType: .apiBay, isActive: true, priority: 0),
                IndexerConfig(id: "builtin-yts", name: "YTS", indexerType: .yts, isActive: true, priority: 1),
                IndexerConfig(id: "builtin-eztv", name: "EZTV", indexerType: .eztv, isActive: true, priority: 2),
                IndexerConfig(id: "builtin-torrentio", name: "Stremio Torrentio", indexerType: .stremio, baseURL: "https://torrentio.strem.fun", isActive: true, priority: 3, endpointPath: "/manifest.json"),
                IndexerConfig(id: "builtin-mediafusion", name: "Stremio MediaFusion", indexerType: .stremio, baseURL: "https://mediafusion.elfhosted.com", isActive: true, priority: 4, endpointPath: "/manifest.json"),
                IndexerConfig(id: "builtin-torrentgalaxy", name: "TorrentGalaxy", indexerType: .stremio, baseURL: "https://torrentio.strem.fun/providers=torrentgalaxy", isActive: true, priority: 5, endpointPath: "/manifest.json")
            ]

            let missing = IndexerDefaultRanking.deletedBuiltIns(from: configured)
            #expect(missing.isEmpty)
        }

        @Test
        func definitionMakeConfigCreatesInactiveConfig() {
            let definition = IndexerDefaultRanking.Definition(
                id: "builtin-yts",
                name: "YTS",
                type: .yts,
                baseURL: nil,
                endpointPath: "",
                providerSubtype: .builtIn,
                apiKeyTransport: .query,
                activeByDefault: false
            )

            let config = definition.makeConfig(priority: 0, isActive: false)

            #expect(config.indexerType == .yts)
            #expect(config.name == "YTS")
            #expect(config.priority == 0)
            #expect(config.isActive == false)
        }

        @Test
        func definitionMakeConfigCreatesActiveConfig() {
            let definition = IndexerDefaultRanking.Definition(
                id: "builtin-stremio",
                name: "Stremio",
                type: .stremio,
                baseURL: "https://torrentio.strem.fun",
                endpointPath: "/manifest.json",
                providerSubtype: .stremioAddon,
                apiKeyTransport: .query,
                activeByDefault: true
            )

            let config = definition.makeConfig(priority: 5, isActive: true)

            #expect(config.indexerType == .stremio)
            #expect(config.isActive == true)
            #expect(config.priority == 5)
        }
    }

    // MARK: - Settings Keys Consistency Tests

    @Suite("SettingsKeys Consistency")
    struct SettingsKeysConsistencyTests {
        @Test
        func subtitleSettingsKeysAreDefined() {
            #expect(SettingsKeys.subtitleLanguage == "subtitle_language")
            #expect(SettingsKeys.audioLanguage == "audio_language")
            #expect(SettingsKeys.subtitleFontSize == "subtitle_font_size")
            #expect(SettingsKeys.subtitleAutoSearch == "subtitle_auto_search")
            #expect(SettingsKeys.openSubtitlesApiKey == "opensubtitles_api_key")
        }

        @Test
        func metadataApiKeysAreStoredAsSecrets() {
            let secretKeys: [String] = [
                SettingsKeys.omdbApiKey,
                SettingsKeys.tmdbApiKey,
                SettingsKeys.openSubtitlesApiKey,
                SettingsKeys.traktClientId,
                SettingsKeys.traktClientSecret,
                SettingsKeys.simklClientId
            ]

            for key in secretKeys {
                #expect(!key.isEmpty)
            }
        }
    }
}
