import Foundation
import OSLog
import Network

/// Multi-provider AI assistant for recommendations and conversation
actor AIAssistantManager {
    private static let logger = Logger(subsystem: "VPStudio", category: "AI")
    private let database: DatabaseManager
    private var providers: [AIProviderKind: any AIProvider] = [:]
    private var configuredModels: [AIProviderKind: String] = [:]
    private let contextAssembler = AssistantContextAssembler()
    private(set) var lastUsagePersistenceErrorMessage: String?

    nonisolated static let defaultProviderResolutionOrder: [AIProviderKind] = [
        .anthropic,
        .openAI,
        .gemini,
        .openRouter,
        .mistral,
        .minimax,
        .ollama,
        .local,
    ]

    init(database: DatabaseManager) {
        self.database = database
    }

    var hasConfiguredProvider: Bool {
        !usableProviders().isEmpty
    }

    func registerProvider(kind: AIProviderKind, provider: any AIProvider) {
        providers[kind] = provider
        configuredModels[kind] = Self.inferredModelID(from: provider) ?? AIModelCatalog.defaultModel(for: kind)?.id
    }

    func clearProviders() {
        providers.removeAll()
        configuredModels.removeAll()
    }

    nonisolated static func resolvedDefaultProvider(
        preferredProvider: AIProviderKind?,
        availableProviders: [AIProviderKind]
    ) -> AIProviderKind? {
        let availableSet = Set(availableProviders)
        guard !availableSet.isEmpty else { return nil }

        if let preferredProvider, availableSet.contains(preferredProvider) {
            return preferredProvider
        }

        for candidate in defaultProviderResolutionOrder where availableSet.contains(candidate) {
            return candidate
        }

        return availableProviders.sorted { $0.rawValue < $1.rawValue }.first
    }

    func configure(provider: AIProviderKind, apiKey: String, baseURL: String? = nil, model: String? = nil) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuredModel = model?.trimmingCharacters(in: .whitespacesAndNewlines)

        if provider != .ollama && trimmedAPIKey.isEmpty {
            providers.removeValue(forKey: provider)
            configuredModels.removeValue(forKey: provider)
            Self.logger.info("Skipped \(provider.rawValue) configuration because the API key was empty.")
            return
        }

        let catalogDefaultModelID = AIModelCatalog.defaultModel(for: provider)?.id
        let resolvedModel = Self.resolvedModelID(
            provider: provider,
            catalogDefault: catalogDefaultModelID,
            configuredModel: configuredModel
        )

        switch provider {
        case .anthropic:
            providers[.anthropic] = AnthropicProvider(apiKey: trimmedAPIKey, model: resolvedModel)
        case .openAI:
            providers[.openAI] = OpenAIProvider(apiKey: trimmedAPIKey, model: resolvedModel)
        case .ollama:
            let resolvedBaseURL = (baseURL ?? "http://localhost:11434")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resolvedBaseURL.isEmpty else {
                providers.removeValue(forKey: .ollama)
                configuredModels.removeValue(forKey: .ollama)
                Self.logger.info("Skipped Ollama configuration because the endpoint was empty.")
                return
            }

            if let warning = AIOllamaEndpointPolicy.warningMessage(for: resolvedBaseURL) {
                providers.removeValue(forKey: .ollama)
                configuredModels.removeValue(forKey: .ollama)
                if warning.contains("Plain HTTP is only allowed") {
                    Self.logger.error(
                        "Rejected insecure Ollama endpoint: \(resolvedBaseURL, privacy: .public)"
                    )
                } else {
                    Self.logger.info(
                        "Skipped Ollama configuration because the endpoint was invalid."
                    )
                }
                return
            }

            providers[.ollama] = OllamaProvider(
                baseURL: resolvedBaseURL,
                model: resolvedModel
            )
        case .gemini:
            providers[.gemini] = GeminiProvider(apiKey: trimmedAPIKey, model: resolvedModel)
        case .openRouter:
            providers[.openRouter] = OpenRouterProvider(
                apiKey: trimmedAPIKey,
                model: resolvedModel
            )
        case .mistral:
            providers[.mistral] = MistralProvider(apiKey: trimmedAPIKey, model: resolvedModel)
        case .minimax:
            providers[.minimax] = MiniMaxProvider(apiKey: trimmedAPIKey, model: resolvedModel)
        case .local:
            break // Local provider is registered directly via registerProvider in AppState
        }

        configuredModels[provider] = resolvedModel
    }

    /// Ask the AI a question with optional context
    func ask(prompt: String, provider: AIProviderKind? = nil, context: AssistantContext? = nil) async throws -> AIProviderResponse {
        let selectedProvider = await resolvedProvider(for: provider)
        guard let kind = selectedProvider, let aiProvider = providers[kind] else {
            throw AIError.noProviderConfigured
        }

        let assembledNotes = await assembledContextNotes()
        let resolvedContext = await contextualizedContext(from: context)
        let systemPrompt = buildSystemPrompt(
            context: resolvedContext,
            assembledNotes: assembledNotes,
            budgetTokens: promptBudgetTokens(for: kind)
        )
        let response = try await aiProvider.complete(system: systemPrompt, userMessage: prompt)
        await logUsage(response: response, requestType: .ask)
        return response
    }

    private func resolvedProvider(for requestedProvider: AIProviderKind?) async -> AIProviderKind? {
        let availableProviders = usableProviders()
        guard !availableProviders.isEmpty else { return nil }

        if let requestedProvider {
            return Self.resolvedDefaultProvider(
                preferredProvider: requestedProvider,
                availableProviders: Array(availableProviders.keys)
            )
        }

        let preferredProvider = await preferredDefaultProvider()
        return Self.resolvedDefaultProvider(
            preferredProvider: preferredProvider,
            availableProviders: Array(availableProviders.keys)
        )
    }

    private func preferredDefaultProvider() async -> AIProviderKind? {
        guard let rawValue = try? await database.getSetting(key: SettingsKeys.defaultAIProvider) else {
            return nil
        }
        return AIProviderKind(rawValue: rawValue)
    }

    /// Get movie/show recommendations based on user taste
    func getRecommendations(
        context: AssistantContext,
        provider: AIProviderKind? = nil,
        excludingTitles: [String] = []
    ) async throws -> [AIMovieRecommendation] {
        var promptParts = [
            "Based on my viewing history and preferences, recommend 10 movies or TV shows I'd enjoy.",
            "Focus on titles I haven't seen yet.",
            "For each, provide: title, year, type (movie/series), and a brief reason why I'd like it.",
            "Format as JSON array with keys: title, year, type, reason, tmdbId.",
            "Only include tmdbId when you are highly confident it is correct. Otherwise use null.",
        ]
        if let mood = context.currentMood {
            promptParts.insert("I'm currently in the mood for: \(mood).", at: 1)
        }
        if !excludingTitles.isEmpty {
            let exclusions = excludingTitles
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(12)
                .joined(separator: ", ")
            if !exclusions.isEmpty {
                promptParts.append("Do not recommend any of these titles again: \(exclusions).")
                promptParts.append("Return a meaningfully different list from those excluded titles.")
            }
        }
        let prompt = promptParts.joined(separator: " ")

        let response = try await ask(prompt: prompt, provider: provider, context: context)

        return try parseRecommendations(from: response.content)
    }

    /// Get recommendations for a free-form natural-language query (first-class
    /// NL search). The user prompt is built by `NaturalLanguageSearchPolicy` so
    /// the literal phrase is embedded verbatim, then flows through the existing
    /// `ask(...)` pipeline — so the user's DB taste profile and Trakt-synced
    /// watch history still inject via `contextualizedContext`, and the JSON
    /// response is parsed by the shared `parseRecommendations`.
    func getRecommendations(
        forNaturalLanguageQuery query: String,
        provider: AIProviderKind? = nil,
        excludingTitles: [String] = []
    ) async throws -> [AIMovieRecommendation] {
        let prompt = NaturalLanguageSearchPolicy.recommendationPrompt(
            from: query,
            excluding: excludingTitles
        )
        let response = try await ask(prompt: prompt, provider: provider, context: AssistantContext())
        return try parseRecommendations(from: response.content)
    }

    /// Get personalized "For You" recommendations that explicitly weight the
    /// user's recently-watched Trakt history. Reuses the shared context pipeline
    /// (`contextualizedContext` autoloads watch history, ratings, watchlist, …)
    /// and the JSON parser; the prompt just tells the model to lean on the most
    /// recent history when ranking.
    func getPersonalizedRecommendations(
        provider: AIProviderKind? = nil,
        excludingTitles: [String] = []
    ) async throws -> [AIMovieRecommendation] {
        var promptParts = [
            "Recommend 10 movies or TV shows tailored to me personally.",
            "Weight my most recently watched titles most heavily — lean into the patterns in my recent viewing history while still respecting my longer-term favorites and ratings.",
            "Focus on titles I haven't seen yet.",
            "For each, provide: title, year, type (movie/series), and a brief reason connecting it to what I've recently watched.",
            "Format as JSON array with keys: title, year, type, reason, tmdbId.",
            "Only include tmdbId when you are highly confident it is correct. Otherwise use null.",
        ]
        let exclusions = excludingTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(12)
            .joined(separator: ", ")
        if !exclusions.isEmpty {
            promptParts.append("Do not recommend any of these titles again: \(exclusions).")
            promptParts.append("Return a meaningfully different list from those excluded titles.")
        }
        let prompt = promptParts.joined(separator: " ")

        let response = try await ask(prompt: prompt, provider: provider, context: AssistantContext())
        return try parseRecommendations(from: response.content)
    }

    /// Personalized analysis of a specific movie/show for the user
    func getPersonalizedAnalysis(
        title: String,
        year: Int?,
        type: MediaType,
        genres: [String],
        overview: String?
    ) async throws -> AIPersonalizedAnalysis {
        let yearStr = year.map { " (\($0))" } ?? ""
        let genreStr = genres.isEmpty ? "" : " Genres: \(genres.joined(separator: ", "))."
        let overviewStr = overview.flatMap { $0.isEmpty ? nil : " Synopsis: \($0)" } ?? ""

        let prompt = """
        Analyze this \(type == .movie ? "movie" : "TV show") for me personally based on my taste profile:

        Title: \(title)\(yearStr)
        Type: \(type == .movie ? "Movie" : "TV Series")\(genreStr)\(overviewStr)

        Respond with ONLY a JSON object (no markdown, no explanation) with these exact keys:
        - "personalizedDescription": A 2-3 sentence description tailored to what I'd specifically appreciate or dislike about it based on my preferences.
        - "predictedRating": A number 1-10 predicting how I'd rate it.
        - "verdict": One of "strong_yes", "yes", "maybe", "no", "strong_no".
        - "reasons": An array of 2-4 short bullet points explaining why.
        """

        let response = try await ask(prompt: prompt, context: AssistantContext())
        return try parsePersonalizedAnalysis(from: response.content)
    }

    nonisolated static func resolvedModelID(
        provider: AIProviderKind,
        catalogDefault: String?,
        configuredModel: String?
    ) -> String {
        let trimmedConfiguredModel = configuredModel?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedConfiguredModel, !trimmedConfiguredModel.isEmpty {
            return normalizedModelID(provider: provider, modelID: trimmedConfiguredModel)
        }

        let trimmedCatalogDefault = catalogDefault?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedModelID(
            provider: provider,
            modelID: trimmedCatalogDefault ?? fallbackModelID(for: provider)
        )
    }

    private nonisolated static func normalizedModelID(provider: AIProviderKind, modelID: String) -> String {
        guard provider == .openRouter else { return modelID }
        return AIModelCatalog.providerNativeOpenRouterModelID(modelID)
    }

    nonisolated static func fallbackModelID(for provider: AIProviderKind) -> String {
        if let catalogDefault = AIModelCatalog.defaultModel(for: provider)?.id {
            return catalogDefault
        }

        switch provider {
        case .anthropic:
            return AIModelCatalog.claudeSonnet4.id
        case .openAI:
            return AIModelCatalog.gpt54.id
        case .gemini:
            return AIModelCatalog.gemini25Flash.id
        case .ollama:
            return AIModelCatalog.llama31.id
        case .openRouter:
            return AIModelCatalog.openRouterGeminiFlashLite.id
        case .mistral:
            return AIModelCatalog.mistralSmallLatest.id
        case .minimax:
            return AIModelCatalog.minimaxM2.id
        case .local:
            return AIModelCatalog.localSmolLM2.id
        }
    }

    nonisolated static func availableDefaultProviders(
        configuredCloudProviders: [AIProviderKind],
        hasOllamaEndpoint: Bool,
        hasUsableLocalProvider: Bool
    ) -> [AIProviderKind] {
        var available = configuredCloudProviders
        if hasOllamaEndpoint {
            available.append(.ollama)
        }
        if hasUsableLocalProvider {
            available.append(.local)
        }

        var seen = Set<AIProviderKind>()
        return defaultProviderResolutionOrder.filter { provider in
            guard available.contains(provider), !seen.contains(provider) else { return false }
            seen.insert(provider)
            return true
        }
    }

    private func parsePersonalizedAnalysis(from content: String) throws -> AIPersonalizedAnalysis {
        let candidates = [content] + fencedCodeBlockCandidates(from: content) + bracketedJSONArrayCandidates(from: content)

        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let analysis = try? decodePersonalizedAnalysis(from: data) {
                return analysis
            }
            if let json = try? JSONSerialization.jsonObject(with: data),
               let analysis = parsePersonalizedContainer(from: json) {
                return analysis
            }
        }

        // Try extracting JSON object from braces
        if let firstBrace = content.firstIndex(of: "{"),
           let lastBrace = content.lastIndex(of: "}"),
           firstBrace < lastBrace {
            let slice = String(content[firstBrace...lastBrace])
            if let sliceData = slice.data(using: .utf8) {
                if let analysis = try? decodePersonalizedAnalysis(from: sliceData) {
                    return analysis
                }
                if let json = try? JSONSerialization.jsonObject(with: sliceData),
                   let analysis = parsePersonalizedContainer(from: json) {
                    return analysis
                }
            }
        }

        throw AIError.invalidResponse
    }

    private func parsePersonalizedContainer(from value: Any) -> AIPersonalizedAnalysis? {
        func collect(from rawValue: Any) -> AIPersonalizedAnalysis? {
            if let direct = decodePersonalizedAnalysis(from: rawValue) {
                return direct
            }

            if let array = rawValue as? [Any] {
                for element in array {
                    if let parsed = collect(from: element) {
                        return parsed
                    }
                }
                return nil
            }

            guard let object = rawValue as? [String: Any] else { return nil }
            for (_, nestedValue) in object {
                if let parsed = collect(from: nestedValue) {
                    return parsed
                }
            }
            return nil
        }

        return collect(from: value)
    }

    private func decodePersonalizedAnalysis(from value: Any) -> AIPersonalizedAnalysis? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }

        do {
            return try decodePersonalizedAnalysis(from: data)
        } catch {
            return nil
        }
    }

    private func decodePersonalizedAnalysis(from data: Data) throws -> AIPersonalizedAnalysis? {
        struct RawAnalysis: Decodable {
            let personalizedDescription: String
            let predictedRating: Double
            let verdict: String
            let reasons: [String]

            private enum CodingKeys: String, CodingKey {
                case personalizedDescription
                case predictedRating
                case verdict
                case reasons
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                personalizedDescription = try container.decode(String.self, forKey: .personalizedDescription)

                if let ratingNumber = try? container.decode(Double.self, forKey: .predictedRating) {
                    predictedRating = ratingNumber
                } else if let ratingString = try? container.decode(String.self, forKey: .predictedRating) {
                    let trimmedRating = ratingString.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let parsedRating = Double(trimmedRating) else {
                        throw DecodingError.dataCorruptedError(
                            forKey: .predictedRating,
                            in: container,
                            debugDescription: "Invalid predictedRating value"
                        )
                    }
                    predictedRating = parsedRating
                } else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .predictedRating,
                        in: container,
                        debugDescription: "Missing or invalid predictedRating value"
                    )
                }

                verdict = try container.decode(String.self, forKey: .verdict)

                if let reasonsArray = try? container.decode([String].self, forKey: .reasons) {
                    reasons = reasonsArray
                } else if let reasonsString = try? container.decode(String.self, forKey: .reasons) {
                    reasons = [reasonsString]
                } else if let reasonsArray = try? container.decode([ReasonValue].self, forKey: .reasons) {
                    reasons = reasonsArray.compactMap(\.stringValue)
                } else {
                    reasons = []
                }
            }

            private enum ReasonValue: Decodable {
                case string(String)
                case integer(Int)
                case decimal(Double)
                case boolean(Bool)
                case none

                var stringValue: String? {
                    switch self {
                    case .string(let value):
                        return value
                    case .integer(let value):
                        return String(value)
                    case .decimal(let value):
                        return String(value)
                    case .boolean(let value):
                        return String(value)
                    case .none:
                        return nil
                    }
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let string = try? container.decode(String.self) {
                        self = .string(string)
                    } else if let integer = try? container.decode(Int.self) {
                        self = .integer(integer)
                    } else if let decimal = try? container.decode(Double.self) {
                        if decimal == decimal.rounded() {
                            self = .integer(Int(decimal))
                        } else {
                            self = .decimal(decimal)
                        }
                    } else if let bool = try? container.decode(Bool.self) {
                        self = .boolean(bool)
                    } else if container.decodeNil() {
                        self = .none
                    } else {
                        self = .none
                    }
                }
            }
        }

        guard let raw = try? JSONDecoder().decode(RawAnalysis.self, from: data) else { return nil }
        let normalizedVerdict = raw.verdict
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .compactMap { char in
                if char == "-" || char == "_" || char.isWhitespace {
                    return "_"
                }
                if char.isLetter || char.isNumber {
                    return String(char)
                }
                return nil
            }
            .joined()
            .split(whereSeparator: { $0 == "_" })
            .joined(separator: "_")
        guard let verdict = AIPersonalizedAnalysis.Verdict(rawValue: normalizedVerdict) else {
            return nil
        }

        return AIPersonalizedAnalysis(
            personalizedDescription: raw.personalizedDescription,
            predictedRating: raw.predictedRating,
            verdict: verdict,
            reasons: raw.reasons
        )
    }

    /// Compare recommendations across providers
    func compareProviders(prompt: String, context: AssistantContext?) async throws -> AICompareResult {
        let providersCopy = usableProviders()
        var results: [AIProviderKind: AIProviderResponse] = [:]
        var errors: [AIProviderKind: String] = [:]

        let assembledNotes = await assembledContextNotes()
        let resolvedContext = await contextualizedContext(from: context)
        let systemPrompt = buildSystemPrompt(
            context: resolvedContext,
            assembledNotes: assembledNotes,
            budgetTokens: promptBudgetTokens(for: Array(providersCopy.keys))
        )

        await withTaskGroup(of: (AIProviderKind, Result<AIProviderResponse, Error>).self) { group in
            for (kind, provider) in providersCopy {
                group.addTask {
                    do {
                        let response = try await provider.complete(system: systemPrompt, userMessage: prompt)
                        return (kind, .success(response))
                    } catch {
                        return (kind, .failure(error))
                    }
                }
            }
            for await (kind, result) in group {
                switch result {
                case .success(let response):
                    results[kind] = response
                case .failure(let error):
                    errors[kind] = error.localizedDescription
                }
            }
        }

        for (_, response) in results {
            await logUsage(response: response, requestType: .compare)
        }

        return AICompareResult(prompt: prompt, responses: results, errors: errors)
    }

    /// Build contextual system prompt, merging assembled context notes with any ad-hoc context.
    private func buildSystemPrompt(
        context: AssistantContext?,
        assembledNotes: [String] = [],
        budgetTokens: Int
    ) -> String {
        var parts = [
            "You are VPStudio AI, a knowledgeable movie and TV show assistant.",
            "You help users discover content they'll love based on their preferences.",
            "Provide specific, actionable recommendations with reasoning.",
        ]

        // Overlay any ad-hoc context from the caller first so request-scoped data is
        // preserved when the prompt needs to be trimmed to a model-specific budget.
        if let ctx = context {
            if !ctx.recentlyWatched.isEmpty {
                parts.append("Recently watched: \(ctx.recentlyWatched.joined(separator: ", "))")
            }
            if !ctx.historyTitles.isEmpty {
                parts.append("History titles: \(ctx.historyTitles.joined(separator: ", "))")
            }
            if !ctx.favoriteGenres.isEmpty {
                parts.append("Favorite genres: \(ctx.favoriteGenres.joined(separator: ", "))")
            }
            if !ctx.dislikedGenres.isEmpty {
                parts.append("Dislikes: \(ctx.dislikedGenres.joined(separator: ", "))")
            }
            if !ctx.watchlistTitles.isEmpty {
                parts.append("Watchlist titles: \(ctx.watchlistTitles.joined(separator: ", "))")
            }
            if !ctx.favoriteTitles.isEmpty {
                parts.append("Favorite titles: \(ctx.favoriteTitles.joined(separator: ", "))")
            }
            if let feedbackScaleMode = ctx.feedbackScaleMode {
                parts.append("Rating scale preference: \(feedbackScaleMode.displayName)")
            }
            if !ctx.likedTitles.isEmpty {
                parts.append("Liked titles: \(ctx.likedTitles.joined(separator: ", "))")
            }
            if !ctx.dislikedTitles.isEmpty {
                parts.append("Disliked titles: \(ctx.dislikedTitles.joined(separator: ", "))")
            }
            if !ctx.ratedTitles.isEmpty {
                parts.append("Recent ratings: \(ctx.ratedTitles.joined(separator: ", "))")
            }
            if let mood = ctx.currentMood {
                parts.append("Current mood: \(mood)")
            }
        }

        // Inject assembled context notes (from periodic indexing) after caller-supplied data.
        for note in assembledNotes {
            parts.append(note)
        }

        return AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: budgetTokens)
    }

    private func parseRecommendations(from content: String) throws -> [AIMovieRecommendation] {
        guard let data = recommendationData(from: content) else {
            throw AIError.invalidResponse
        }

        struct RawRec: Decodable {
            let title: String
            let year: Int?
            let type: String?
            let reason: String?
            let tmdbId: Int?

            private enum CodingKeys: String, CodingKey {
                case title
                case year
                case type
                case reason
                case tmdbId
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                title = try container.decode(String.self, forKey: .title)
                if let yearNumber = try? container.decodeIfPresent(Int.self, forKey: .year) {
                    year = yearNumber
                } else if let yearString = try? container.decodeIfPresent(String.self, forKey: .year) {
                    let trimmedYearString = yearString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let parsedYear = Int(trimmedYearString) {
                        year = parsedYear
                    } else if let parsedYearDouble = Double(trimmedYearString),
                              parsedYearDouble.truncatingRemainder(dividingBy: 1) == 0 {
                        year = Int(exactly: parsedYearDouble) // nil (not a trap) if out of Int range
                    } else {
                        year = nil
                    }
                } else if let yearDouble = try? container.decodeIfPresent(Double.self, forKey: .year),
                          yearDouble.truncatingRemainder(dividingBy: 1) == 0 {
                    year = Int(exactly: yearDouble) // nil (not a trap) if out of Int range
                } else {
                    year = nil
                }
                type = try container.decodeIfPresent(String.self, forKey: .type)
                if let reasonString = try? container.decodeIfPresent(String.self, forKey: .reason) {
                    reason = reasonString
                } else if let reasonArray = try? container.decodeIfPresent([String].self, forKey: .reason) {
                    reason = reasonArray.joined(separator: "; ")
                } else if let reasonArray = try? container.decodeIfPresent([ReasonValue].self, forKey: .reason) {
                    reason = reasonArray.compactMap(\.stringValue).joined(separator: "; ")
                } else if let reasonInt = try? container.decodeIfPresent(Int.self, forKey: .reason) {
                    reason = String(reasonInt)
                } else if let reasonDouble = try? container.decodeIfPresent(Double.self, forKey: .reason) {
                    reason = String(reasonDouble)
                } else {
                    reason = nil
                }

                if let intId = try? container.decodeIfPresent(Int.self, forKey: .tmdbId) {
                    tmdbId = intId
                } else if let stringId = try? container.decodeIfPresent(String.self, forKey: .tmdbId) {
                    let trimmedIdString = stringId.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let parsedId = Int(trimmedIdString) {
                        tmdbId = parsedId
                    } else if let parsedIdDouble = Double(trimmedIdString),
                              parsedIdDouble.truncatingRemainder(dividingBy: 1) == 0 {
                        tmdbId = Int(exactly: parsedIdDouble) // nil (not a trap) if out of Int range
                    } else {
                        tmdbId = nil
                    }
                } else if let doubleId = try? container.decodeIfPresent(Double.self, forKey: .tmdbId),
                          doubleId.truncatingRemainder(dividingBy: 1) == 0 {
                    tmdbId = Int(exactly: doubleId) // nil (not a trap) if out of Int range
                } else {
                    tmdbId = nil
                }
            }

            private enum ReasonValue: Decodable {
                case string(String)
                case number(Int)
                case decimal(Double)
                case boolean(Bool)
                case none

                var stringValue: String? {
                    switch self {
                    case .string(let value):
                        return value
                    case .number(let value):
                        return String(value)
                    case .decimal(let value):
                        return String(value)
                    case .boolean(let value):
                        return String(value)
                    case .none:
                        return nil
                    }
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let string = try? container.decode(String.self) {
                        self = .string(string)
                    } else if let decimal = try? container.decode(Double.self) {
                        if decimal.rounded() == decimal {
                            self = .number(Int(decimal))
                        } else {
                            self = .decimal(decimal)
                        }
                    } else if let boolean = try? container.decode(Bool.self) {
                        self = .boolean(boolean)
                    } else if container.decodeNil() {
                        self = .none
                    } else {
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: "Reason value is not supported"
                        )
                    }
                }
            }
        }

        struct FailableRawRec: Decodable {
            let value: RawRec?

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                value = try? container.decode(RawRec.self)
            }
        }

        func mapRecommendations(_ raws: [RawRec]) -> [AIMovieRecommendation] {
            return raws.compactMap { raw in
                let normalizedTitle = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedTitle.isEmpty else { return nil }

                let normalizedType = (raw.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isSeriesType = [
                    "series",
                    "show",
                    "tv",
                    "tv series",
                    "tvseries",
                    "tv_show",
                    "tv-show",
                    "tv show",
                    "television",
                ].contains(normalizedType)
                return AIMovieRecommendation(
                    title: normalizedTitle,
                    year: raw.year,
                    type: isSeriesType ? .series : .movie,
                    reason: raw.reason ?? "",
                    tmdbId: raw.tmdbId
                )
            }
        }

        func deduplicatedRecommendations(_ recommendations: [AIMovieRecommendation]) -> [AIMovieRecommendation] {
            var seen = Set<String>()
            var deduplicated: [AIMovieRecommendation] = []
            for recommendation in recommendations {
                let normalizedTitle = recommendation.title
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let key = [
                    normalizedTitle,
                    "\(recommendation.year ?? 0)",
                    "\(recommendation.tmdbId ?? 0)",
                    recommendation.type.rawValue
                ].joined(separator: "|")

                if seen.insert(key).inserted {
                    deduplicated.append(recommendation)
                }
            }

            return deduplicated
        }

        struct RecommendationContainer: Decodable {
            let recommendations: [FailableRawRec]?
            let data: [FailableRawRec]?
            let results: [FailableRawRec]?
            let recommendation: FailableRawRec?
            let result: FailableRawRec?
            let item: FailableRawRec?
            let items: [FailableRawRec]?

            private enum CodingKeys: String, CodingKey {
                case recommendations
                case data
                case results
                case recommendation
                case result
                case item
                case items
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                recommendations = try? container.decodeIfPresent([FailableRawRec].self, forKey: .recommendations)
                data = try? container.decodeIfPresent([FailableRawRec].self, forKey: .data)
                results = try? container.decodeIfPresent([FailableRawRec].self, forKey: .results)
                recommendation = try? container.decodeIfPresent(FailableRawRec.self, forKey: .recommendation)
                result = try? container.decodeIfPresent(FailableRawRec.self, forKey: .result)
                item = try? container.decodeIfPresent(FailableRawRec.self, forKey: .item)
                items = try? container.decodeIfPresent([FailableRawRec].self, forKey: .items)
            }
        }

        func mapValidatedRecommendations(_ raws: [FailableRawRec]) -> [AIMovieRecommendation]? {
            let mapped = mapRecommendations(raws.compactMap { $0.value })
            return mapped.isEmpty ? nil : mapped
        }

        func decodeRawRecommendation(_ value: Any) -> FailableRawRec? {
            guard JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value) else {
                return nil
            }

            guard let decoded = try? JSONDecoder().decode(FailableRawRec.self, from: data),
                  decoded.value != nil else {
                return nil
            }

            return decoded
        }

        func parseRecommendationContainer(from value: Any) -> [FailableRawRec] {
            var collected: [FailableRawRec] = []
            let arrayKeys = ["recommendations", "data", "results", "items"]
            let singleKeys = ["recommendation", "result", "item"]

            func collectArray(_ array: [Any]) {
                for child in array {
                    if let parsed = decodeRawRecommendation(child) {
                        collected.append(parsed)
                    } else {
                        collect(from: child)
                    }
                }
            }

            func collect(from rawValue: Any) {
                if let array = rawValue as? [Any] {
                    if array.isEmpty {
                        return
                    }
                    collectArray(array)
                    return
                }

                guard let object = rawValue as? [String: Any] else { return }
                if let parsedObject = decodeRawRecommendation(object) {
                    collected.append(parsedObject)
                    return
                }

                for (key, nestedValue) in object {
                    if arrayKeys.contains(key), let nestedArray = nestedValue as? [Any] {
                        collectArray(nestedArray)
                        continue
                    }

                    if singleKeys.contains(key), let parsedValue = decodeRawRecommendation(nestedValue) {
                        collected.append(parsedValue)
                        continue
                    }

                    collect(from: nestedValue)
                }
            }

            collect(from: value)
            return collected
        }

        if let topLevel = try? JSONSerialization.jsonObject(with: data),
           let parsedNested = mapValidatedRecommendations(parseRecommendationContainer(from: topLevel)) {
            return deduplicatedRecommendations(parsedNested)
        }

        let raws = try JSONDecoder().decode([FailableRawRec].self, from: data).compactMap(\.value)

        guard !raws.isEmpty else {
            throw AIError.invalidResponse
        }

        return mapRecommendations(raws)
    }

    private func recommendationData(from content: String) -> Data? {
        let candidates = [content] + fencedCodeBlockCandidates(from: content) + bracketedJSONArrayCandidates(from: content)

        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if (try? JSONSerialization.jsonObject(with: data)) != nil {
                return data
            }
        }

        return nil
    }

    private func fencedCodeBlockCandidates(from content: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "```(?:json)?\\s*([\\s\\S]*?)```", options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        return matches.compactMap { match in
            guard let blockRange = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[blockRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func bracketedJSONArrayCandidates(from content: String) -> [String] {
        guard let lastBracket = content.lastIndex(of: "]") else { return [] }
        var results: [String] = []
        for (index, char) in content.enumerated() where char == "[" {
            let start = content.index(content.startIndex, offsetBy: index)
            guard start <= lastBracket else { break }
            let slice = String(content[start...lastBracket]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !slice.isEmpty {
                results.append(slice)
            }
        }
        return results
    }

    private func contextualizedContext(from context: AssistantContext?) async -> AssistantContext {
        var merged = context ?? AssistantContext()

        do {
            let watchlistEntries = try await database.fetchLibraryEntries(listType: .watchlist)
            let favoriteEntries = try await database.fetchLibraryEntries(listType: .favorites)
            let historyEntries = try await database.fetchWatchHistory(limit: 120)
            let ratingEvents = try await database.fetchTasteEvents(eventType: .rated, limit: 300)
            let feedbackScaleRaw = try await database.getSetting(key: SettingsKeys.feedbackScaleMode)
            let configuredFeedbackScale = FeedbackScaleMode.fromStoredValue(feedbackScaleRaw)
            let database = self.database

            let ratingMediaIDs = ratingEvents.compactMap(\.mediaId)
            let allMediaIDs = Set(watchlistEntries.map(\.mediaId) + favoriteEntries.map(\.mediaId) + ratingMediaIDs)
            var titleByMediaID: [String: String] = [:]
            await withTaskGroup(of: (String, String?).self) { group in
                for mediaID in allMediaIDs {
                    group.addTask {
                        let title = try? await database.fetchMediaItem(id: mediaID)?.title
                        return (mediaID, title)
                    }
                }
                for await (mediaID, title) in group {
                    if let title, !title.isEmpty {
                        titleByMediaID[mediaID] = title
                    }
                }
            }

            let watchlistTitles = watchlistEntries.compactMap { titleByMediaID[$0.mediaId] }
            let favoriteTitles = favoriteEntries.compactMap { titleByMediaID[$0.mediaId] }
            let historyTitles = historyEntries.map(\.title)
            let feedbackSummary = summarizedFeedback(
                events: ratingEvents,
                titleByMediaID: titleByMediaID,
                defaultScale: configuredFeedbackScale
            )

            merged.watchlistTitles = mergeUnique(current: merged.watchlistTitles, incoming: watchlistTitles)
            merged.favoriteTitles = mergeUnique(current: merged.favoriteTitles, incoming: favoriteTitles)
            merged.historyTitles = mergeUnique(current: merged.historyTitles, incoming: historyTitles)
            merged.recentlyWatched = mergeUnique(current: merged.recentlyWatched, incoming: Array(historyTitles.prefix(20)))
            if merged.feedbackScaleMode == nil {
                merged.feedbackScaleMode = configuredFeedbackScale
            }
            merged.likedTitles = mergeUnique(current: merged.likedTitles, incoming: feedbackSummary.likedTitles)
            merged.dislikedTitles = mergeUnique(current: merged.dislikedTitles, incoming: feedbackSummary.dislikedTitles)
            merged.ratedTitles = mergeUnique(current: merged.ratedTitles, incoming: feedbackSummary.ratedTitles)
        } catch {
            return merged
        }

        return merged
    }

    private func mergeUnique(current: [String], incoming: [String]) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []

        for title in current + incoming {
            let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized.lowercased()).inserted {
                merged.append(normalized)
            }
        }

        return merged
    }

    private func summarizedFeedback(
        events: [TasteEvent],
        titleByMediaID: [String: String],
        defaultScale: FeedbackScaleMode
    ) -> (likedTitles: [String], dislikedTitles: [String], ratedTitles: [String]) {
        var likedTitles: [String] = []
        var dislikedTitles: [String] = []
        var ratedTitles: [String] = []

        var likedSeen = Set<String>()
        var dislikedSeen = Set<String>()
        var ratedSeen = Set<String>()

        for event in events {
            guard let value = event.feedbackValue else { continue }
            let scale = (event.feedbackScale ?? defaultScale).canonicalMode
            let title = feedbackTitle(for: event, titleByMediaID: titleByMediaID)
            guard !title.isEmpty else { continue }

            switch scale.sentiment(for: value) {
            case .liked:
                let key = title.lowercased()
                if likedSeen.insert(key).inserted {
                    likedTitles.append(title)
                }
            case .disliked:
                let key = title.lowercased()
                if dislikedSeen.insert(key).inserted {
                    dislikedTitles.append(title)
                }
            case .neutral:
                break
            }

            let rating = "\(title) (\(scale.format(value)))"
            let ratingKey = rating.lowercased()
            if ratedTitles.count < 40, ratedSeen.insert(ratingKey).inserted {
                ratedTitles.append(rating)
            }
        }

        return (likedTitles, dislikedTitles, ratedTitles)
    }

    private func feedbackTitle(
        for event: TasteEvent,
        titleByMediaID: [String: String]
    ) -> String {
        if let metadataTitle = event.metadata["title"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !metadataTitle.isEmpty {
            return metadataTitle
        }
        if let mediaID = event.mediaId,
           let mediaTitle = titleByMediaID[mediaID] {
            return mediaTitle
        }
        return event.mediaId ?? ""
    }

    // MARK: - Context Assembly

    /// Fetches assembled context notes from the `AssistantContextAssembler`.
    /// Returns an empty array on failure to avoid blocking the request.
    private func assembledContextNotes() async -> [String] {
        do {
            let snapshot = try await contextAssembler.cachedOrAssemble(from: database)
            return snapshot.contextNotes
        } catch {
            return []
        }
    }

    private func usableProviders() -> [AIProviderKind: any AIProvider] {
        Dictionary(uniqueKeysWithValues: providers.filter { kind, provider in
            providerIsUsable(kind: kind, provider: provider)
        })
    }

    private func providerIsUsable(kind: AIProviderKind, provider: any AIProvider) -> Bool {
        guard kind == .local else { return true }

        guard let modelID = Self.inferredModelID(from: provider), !modelID.isEmpty else {
            return false
        }

        return Self.localModelArtifactsExist(modelID: modelID)
    }

    func promptBudgetTokens(for provider: AIProviderKind) -> Int {
        let configuredModelID = configuredModels[provider] ?? AIModelCatalog.defaultModel(for: provider)?.id
        let maxContextTokens = configuredModelID.flatMap { AIModelCatalog.model(byID: $0)?.maxContextTokens }
            ?? AIModelCatalog.defaultModel(for: provider)?.maxContextTokens
            ?? 4096

        return max(512, maxContextTokens / 2)
    }

    func promptBudgetTokens(for providers: [AIProviderKind]) -> Int {
        let budgets = providers.map { promptBudgetTokens(for: $0) }
        return budgets.min() ?? 4096
    }

    private nonisolated static func inferredModelID(from provider: any AIProvider) -> String? {
        let mirror = Mirror(reflecting: provider)
        for child in mirror.children {
            if child.label == "modelID", let modelID = child.value as? String, !modelID.isEmpty {
                return modelID
            }
        }
        return nil
    }

    private nonisolated static func localModelArtifactsExist(modelID: String) -> Bool {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        let sanitizedDirectoryName = modelID.replacingOccurrences(of: "/", with: "_")
        let sanitizedCacheName = modelID.replacingOccurrences(of: "/", with: "--")

        let candidateURLs = [
            appSupport?.appendingPathComponent("VPStudio/Models", isDirectory: true)
                .appendingPathComponent(sanitizedDirectoryName, isDirectory: true),
            caches?.appendingPathComponent("huggingface/hub", isDirectory: true)
                .appendingPathComponent("models--\(sanitizedCacheName)", isDirectory: true),
        ].compactMap { $0 }

        return candidateURLs.contains(where: { fileManager.fileExists(atPath: $0.path) })
    }

    /// Invalidates the assembler's cached snapshot, forcing a rebuild on the next request.
    func invalidateContextCache() async {
        await contextAssembler.invalidateCache()
    }

    // MARK: - Usage Tracking

    private func logUsage(response: AIProviderResponse, requestType: AIRequestType) async {
        let cost = AIModelCatalog.estimateCost(
            modelID: response.model,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens
        )
        let record = AIUsageRecord(
            provider: response.provider,
            model: response.model,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens,
            estimatedCostUSD: cost,
            requestType: requestType
        )
        do {
            try await database.saveAIUsageRecord(record)
            lastUsagePersistenceErrorMessage = nil
        } catch {
            lastUsagePersistenceErrorMessage = error.localizedDescription
            Self.logger.error(
                "Failed to persist AI usage record: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

typealias AIHTTPSleep = @Sendable (TimeInterval) async throws -> Void

enum AIHTTPTransport {
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    static let defaultSleep: AIHTTPSleep = { delay in
        let boundedDelay = max(delay, 0)
        let nanoseconds = UInt64((boundedDelay * 1_000_000_000).rounded())
        try await Task.sleep(nanoseconds: nanoseconds)
    }

    static func perform(
        _ request: URLRequest,
        using session: URLSession,
        maxRateLimitRetries: Int = 1,
        sleep: AIHTTPSleep = defaultSleep
    ) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0

        while true {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }

            guard http.statusCode == 429 else {
                return (data, http)
            }

            guard attempt < maxRateLimitRetries else {
                throw AIError.rateLimited
            }

            attempt += 1
            try await sleep(retryDelay(from: http, attempt: attempt))
        }
    }

    static func retryDelay(from response: HTTPURLResponse, attempt: Int) -> TimeInterval {
        if let retryAfter = retryAfterInterval(from: response.value(forHTTPHeaderField: "Retry-After")) {
            return min(max(retryAfter, 0), 30)
        }

        let backoff = pow(2.0, Double(max(attempt - 1, 0)))
        return min(max(backoff, 0.25), 8)
    }

    static func retryAfterInterval(from headerValue: String?) -> TimeInterval? {
        guard let trimmedHeader = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedHeader.isEmpty else {
            return nil
        }

        if let seconds = Double(trimmedHeader) {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        guard let retryDate = formatter.date(from: trimmedHeader) else {
            return nil
        }

        return retryDate.timeIntervalSinceNow
    }
}

enum AIOllamaEndpointPolicy {
    static func isAllowedBaseURL(_ baseURL: String) -> Bool {
        warningMessage(for: baseURL) == nil
    }

    static func appendingPath(to baseURL: String, path: String) -> URL? {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedBaseURL) else { return nil }

        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else { return components.url }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baseSegments = basePath.split(separator: "/").map(String.init)
        let appendedSegments = normalizedPath.split(separator: "/").map(String.init)
        let fullSegments: [String]

        if baseSegments.count > 0 && appendedSegments.starts(with: baseSegments) {
            fullSegments = baseSegments + appendedSegments.dropFirst(baseSegments.count)
        } else {
            fullSegments = baseSegments + appendedSegments
        }

        if fullSegments.isEmpty {
            return components.url
        }

        if basePath.isEmpty {
            components.path = "/\(normalizedPath)"
        } else {
            components.path = "/\(fullSegments.joined(separator: "/"))"
        }

        components.fragment = nil
        return components.url
    }

    static func warningMessage(for baseURL: String) -> String? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return "Enter a valid Ollama server URL."
        }

        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            return "Enter a valid Ollama server URL."
        }

        if scheme == "http" {
            return isLocalHost(host)
                ? nil
                : "Remote Ollama endpoints must use HTTPS. Plain HTTP is only allowed for localhost and loopback addresses."
        }

        return nil
    }

    private static func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" {
            return true
        }

        if let ipv4 = IPv4Address(host), ipv4.rawValue[0] == 127 {
            return true
        }

        if let ipv6 = IPv6Address(host), ipv6.isLoopback {
            return true
        }

        return false
    }
}

// MARK: - AI Provider Protocol

protocol AIProvider: Sendable {
    var providerKind: AIProviderKind { get }
    func complete(system: String, userMessage: String) async throws -> AIProviderResponse
}

// MARK: - Context

struct AssistantContext: Sendable {
    var recentlyWatched: [String] = []
    var historyTitles: [String] = []
    var favoriteGenres: [String] = []
    var dislikedGenres: [String] = []
    var currentMood: String?
    var watchlistTitles: [String] = []
    var favoriteTitles: [String] = []
    var feedbackScaleMode: FeedbackScaleMode?
    var likedTitles: [String] = []
    var dislikedTitles: [String] = []
    var ratedTitles: [String] = []
}

// MARK: - Errors

enum AIError: LocalizedError {
    case noProviderConfigured
    case invalidResponse
    case httpError(Int, String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noProviderConfigured: return "No AI provider configured"
        case .invalidResponse: return "Invalid AI response"
        case .httpError(let code, let msg): return "AI API error HTTP \(code): \(msg)"
        case .rateLimited: return "AI rate limited, try again shortly"
        }
    }
}
