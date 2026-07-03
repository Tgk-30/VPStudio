import SwiftUI

struct DebridCloudView: View {
    @Environment(AppState.self) private var appState
    @State private var rows: [DebridCloudPolicy.AccountRow] = []
    @State private var failures: [String] = []
    @State private var isLoading = false
    @State private var surfaceError: AppError?
    private let disablesAutomaticTasks: Bool

    init(
        initialRows: [DebridCloudPolicy.AccountRow] = [],
        initialFailures: [String] = [],
        initialIsLoading: Bool = false,
        initialSurfaceError: AppError? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        _rows = State(initialValue: initialRows)
        _failures = State(initialValue: initialFailures)
        _isLoading = State(initialValue: initialIsLoading)
        _surfaceError = State(initialValue: initialSurfaceError)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        List {
            if let surfaceError {
                Section {
                    SettingsErrorBanner(error: surfaceError)
                }
            }

            Section {
                if isLoading {
                    InlineLoadingStatusView(title: "Refreshing cloud accounts...")
                } else if rows.isEmpty {
                    ContentUnavailableView(
                        "No Cloud Accounts",
                        systemImage: "cloud",
                        description: Text("Connect a debrid provider first, then refresh this page to see cloud account status.")
                    )
                } else {
                    ForEach(rows) { row in
                        accountRow(row)
                    }
                }
            } header: {
                Text("Cloud Accounts")
            }

            if !failures.isEmpty {
                Section("Needs Attention") {
                    ForEach(failures, id: \.self) { failure in
                        Label(failure, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    Label(isLoading ? "Refreshing..." : "Refresh Cloud Status", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            } footer: {
                Text("Cloud status is read-only. Provider tokens remain stored in the secure credential store.")
            }
        }
        .navigationTitle("Debrid Cloud")
        .task {
            guard !disablesAutomaticTasks else { return }
            await refresh()
        }
        .refreshable {
            await refresh()
        }
    }

    private func accountRow(_ row: DebridCloudPolicy.AccountRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(row.serviceName, systemImage: "cloud.fill")
                    .font(.headline)
                Spacer()
                GlassTag(
                    text: row.premiumSummary,
                    tintColor: row.needsAttention ? .orange : .green,
                    symbol: row.needsAttention ? "exclamationmark.circle" : "checkmark.circle"
                )
            }

            Text(row.username)
                .font(.subheadline)
            if let email = row.email, !email.isEmpty {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func refresh() async {
        isLoading = true
        surfaceError = nil
        failures = []

        do {
            let configs = try await appState.database.fetchAllDebridConfigs()
                .filter(\.isActive)
                .filter(\.supportsSharedMagnetResolveFlow)

            var nextRows: [DebridCloudPolicy.AccountRow] = []
            var nextFailures: [String] = []

            for config in configs.sorted(by: { $0.priority < $1.priority }) {
                do {
                    guard let token = try await config.resolvedToken(using: appState.secretStore) else {
                        nextFailures.append("\(config.serviceType.displayName): missing token")
                        continue
                    }
                    let service = DebridSettingsPolicy.makeDebridService(type: config.serviceType, token: token)
                    let account = try await service.getAccountInfo()
                    nextRows.append(DebridCloudPolicy.accountRow(config: config, account: account))
                } catch {
                    nextFailures.append("\(config.serviceType.displayName): \(error.localizedDescription)")
                }
            }

            rows = nextRows
            failures = nextFailures
        } catch {
            surfaceError = AppError(error)
        }

        isLoading = false
    }
}
