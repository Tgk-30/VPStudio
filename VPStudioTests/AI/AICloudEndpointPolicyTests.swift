import Foundation
import Testing
@testable import VPStudio

@Suite("AI Cloud Endpoint Policy")
struct AICloudEndpointPolicyTests {
    @Test
    func permitsHTTPSCloudEndpointWithoutCredentialsQueryOrFragment() throws {
        let endpoint = try #require(AICloudEndpointPolicy.validatedEndpoint(
            from: "  https://api.example.com/v1/chat/completions  "
        ))

        #expect(endpoint.absoluteString == "https://api.example.com/v1/chat/completions")
    }

    @Test(arguments: [
        "http://api.example.com/v1/chat/completions",
        "https://localhost/v1/chat/completions",
        "https://127.0.0.1/v1/chat/completions",
        "https://10.0.0.5/v1/chat/completions",
        "https://user:pass@api.example.com/v1/chat/completions",
        "https://api.example.com:8443/v1/chat/completions",
        "https://api.example.com/v1/chat/completions?debug=true",
        "https://api.example.com/v1/chat/completions#section",
    ])
    func rejectsEndpointsThatCouldLeakCloudAPIKeys(value: String) {
        #expect(AICloudEndpointPolicy.validatedEndpoint(from: value) == nil)
    }

    @Test
    func openAICompatibleProviderRejectsUnsafeEndpointBeforeAddingBearerToken() async {
        let session = URLProtocolHarness.makeSession { request in
            Issue.record("Unsafe AI endpoint should be rejected before any network request: \(request)")
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }
        let provider = OpenAICompatibleChatProvider(
            providerKind: .minimax,
            apiKey: "secret-key",
            model: "MiniMax-M3",
            chatCompletionsURL: "http://api.example.com/v1/chat/completions",
            session: session,
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "s", userMessage: "m")
            Issue.record("Expected invalidResponse")
        } catch AIError.invalidResponse {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
