import Testing
@testable import VPStudio

@Suite("AI Settings Runtime Command Policy")
struct AISettingsRuntimeCommandPolicyTests {
    @Test
    func cloudCredentialCommandsResolveSettingsKeysForCloudProvidersOnly() {
        let expectedKeys: [AIProviderKind: String?] = [
            .anthropic: SettingsKeys.anthropicApiKey,
            .openAI: SettingsKeys.openAIApiKey,
            .gemini: SettingsKeys.geminiApiKey,
            .openRouter: SettingsKeys.openRouterApiKey,
            .mistral: SettingsKeys.mistralApiKey,
            .minimax: SettingsKeys.minimaxApiKey,
            .ollama: nil,
            .local: nil,
        ]

        for provider in AIProviderKind.allCases {
            let command = AISettingsCloudCredentialRuntimeCommand(
                provider: provider,
                value: "credential-\(provider.rawValue)"
            )

            #expect(command.settingsKey == expectedKeys[provider]!)
            #expect(command.value == "credential-\(provider.rawValue)")
        }
    }

    @Test
    func stringAndBoolRuntimeCommandsPreservePayloads() {
        let stringCommand = AISettingsStringRuntimeCommand(
            key: SettingsKeys.defaultAIProvider,
            value: AIProviderKind.openRouter.rawValue
        )
        let boolCommand = AISettingsBoolRuntimeCommand(
            key: SettingsKeys.localModelEnabled,
            value: true
        )

        #expect(stringCommand.key == SettingsKeys.defaultAIProvider)
        #expect(stringCommand.value == AIProviderKind.openRouter.rawValue)
        #expect(boolCommand.key == SettingsKeys.localModelEnabled)
        #expect(boolCommand.value)
    }
}
