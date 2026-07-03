import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("AI Settings macOS Render Coverage", .serialized)
struct AISettingsMacRenderCoverageTests {
    @Test
    func aiSettingsHostsProviderUsageFeedbackAndLocalModelBranchesOnMacOS() {
        let appState = AppState(testHooks: .init())
        let usage = AIUsageSummary(
            totalInputTokens: 31_000,
            totalOutputTokens: 10_500,
            totalCostUSD: 0.0487,
            byProvider: [
                .anthropic: ProviderUsage(inputTokens: 12_000, outputTokens: 4_000, costUSD: 0.0134, requestCount: 3),
                .openAI: ProviderUsage(inputTokens: 8_000, outputTokens: 2_000, costUSD: 0.0089, requestCount: 2),
                .minimax: ProviderUsage(inputTokens: 7_000, outputTokens: 2_200, costUSD: 0.0201, requestCount: 1),
            ],
            requestCount: 6
        )
        let localModels = [
            makeLocalModel(id: "local-ready", displayName: "Ready Local", status: .downloaded, isDefault: true),
            makeLocalModel(id: "local-downloading", displayName: "Downloading Local", status: .downloading, progress: 0.41),
            makeLocalModel(id: "local-available", displayName: "Available Local", status: .available),
            makeLocalModel(id: "local-failed", displayName: "Failed Local", status: .failed),
            makeLocalModel(id: "local-corrupted", displayName: "Corrupted Local", status: .corrupted),
            makeLocalModel(id: "local-paused", displayName: "Paused Local", status: .paused, progress: 0.24),
        ]

        let variants: [(String, AISettingsView)] = [
            ("Configured OpenAI provider", AISettingsView(
                initialOpenAIKey: "fixture-openai-key",
                initialOllamaURL: "http://localhost:11434",
                initialSelectedProvider: .openAI,
                initialPreferredProvider: .anthropic,
                disablesAutomaticTasks: true
            )),
            ("Provider limit warning", AISettingsView(
                initialAnthropicKey: "fixture-anthropic-key",
                initialOpenAIKey: "fixture-openai-key",
                initialGeminiKey: "fixture-gemini-key",
                initialSelectedProvider: .mistral,
                initialPreferredProvider: .anthropic,
                disablesAutomaticTasks: true
            )),
            ("OpenRouter model refresh progress", AISettingsView(
                initialOpenRouterKey: "fixture-openrouter-key",
                initialSelectedProvider: .openRouter,
                initialPreferredProvider: .anthropic,
                initialIsFetchingModels: true,
                disablesAutomaticTasks: true
            )),
            ("Usage and feedback rows", AISettingsView(
                initialAnthropicKey: "fixture-anthropic-key",
                initialSelectedProvider: .anthropic,
                initialPreferredProvider: .anthropic,
                initialSessionUsage: usage,
                initialLifetimeUsage: usage,
                initialDiscoverAIEnabled: true,
                initialAIAutoGenerate: true,
                initialFeedbackScaleMode: .oneToTen,
                initialLikedTitles: ["Arrival", "Moon"],
                initialDislikedTitles: ["Battlefield Earth"],
                initialRecentRatings: ["Arrival (9/10)", "Moon (8/10)"],
                disablesAutomaticTasks: true
            )),
            ("Ollama warning branch", AISettingsView(
                initialOllamaURL: "http://example.com:11434",
                initialSelectedProvider: .ollama,
                initialPreferredProvider: .ollama,
                disablesAutomaticTasks: true
            )),
            ("Local model actions", AISettingsView(
                initialSelectedProvider: .local,
                initialPreferredProvider: .local,
                initialLocalModelEnabled: true,
                initialLocalModels: localModels,
                disablesAutomaticTasks: true
            )),
            ("Local model enabled without downloaded models", AISettingsView(
                initialSelectedProvider: .local,
                initialPreferredProvider: .local,
                initialLocalModelEnabled: true,
                initialLocalModels: [
                    makeLocalModel(id: "local-waiting", displayName: "Waiting Local", status: .available),
                    makeLocalModel(id: "local-broken", displayName: "Broken Local", status: .failed),
                ],
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in variants {
            let size = host(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 2_200)
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    private func host<Content: View>(_ view: Content) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: 980, height: 2_200)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 2_200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        window.orderOut(nil)
        Self.retainedWindows.append(window)
        if Self.retainedWindows.count > 8 {
            Self.retainedWindows.removeFirst(Self.retainedWindows.count - 8)
        }
        return size
    }

    private func makeLocalModel(
        id: String,
        displayName: String,
        status: LocalModelStatus,
        progress: Double = 0,
        isDefault: Bool = false
    ) -> LocalModelDescriptor {
        let now = Date(timeIntervalSince1970: 1_000)
        return LocalModelDescriptor(
            id: id,
            displayName: displayName,
            huggingFaceRepo: id,
            revision: "main",
            parameterCount: "360M",
            quantization: "4bit",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: status,
            downloadProgress: progress,
            downloadedBytes: 0,
            totalBytes: 700_000_000,
            lastProgressAt: now,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: status == .downloaded ? "/tmp/\(id)" : nil,
            partialDownloadPath: status == .paused ? "/tmp/\(id).partial" : nil,
            isDefault: isDefault,
            createdAt: now,
            updatedAt: now
        )
    }

    private static var retainedWindows: [NSWindow] = []
}
#endif
