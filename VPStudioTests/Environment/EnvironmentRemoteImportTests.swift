import Foundation
import Synchronization
import Testing
@testable import VPStudio

@Suite("EnvironmentCatalogManager Remote Import Tests", .serialized)
struct EnvironmentRemoteImportTests {

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    @Test
    func importEnvironmentFromRemoteSuccess() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-success.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR DATA".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/cinema.hdr")!
        )

        #expect(result.name == "cinema")
        #expect(result.sourceType == .imported)
        #expect(result.assetPath.hasSuffix(".hdr"))
    }

    @Test
    func importEnvironmentFromRemoteInfersExtensionlessHDRDownloadFromContentType() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-extensionless-hdr.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "image/vnd.radiance"]
                )!
                return (Data("HDR DATA".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/download?asset=cinema")!
        )

        #expect(result.assetPath.hasSuffix(".hdr"))
        #expect(FileManager.default.fileExists(atPath: result.assetPath))
    }

    @Test
    func importEnvironmentFromRemoteUsesFinalResponseURLNameAfterRedirect() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-final-url-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { _ in
                let finalURL = URL(string: "https://cdn.example.com/redirected-cinema-hall.hdr")!
                let response = HTTPURLResponse(url: finalURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR DATA".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/download")!
        )

        #expect(result.name == "redirected-cinema-hall")
        #expect(result.assetPath.hasSuffix(".hdr"))
    }

    @Test
    func importEnvironmentFromRemoteRejectsUnsupportedContentTypeBeforeValidation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-spoofed-content-type.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let validatorCallCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in
                validatorCallCount.withLock { $0 += 1 }
                return true
            },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/plain"]
                )!
                return (Data("not an hdr".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/spoofed.hdr")!
            )
            Issue.record("Expected unsupported file type for mismatched remote content type")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(validatorCallCount.withLock { $0 } == 0)
    }

    @Test
    func importEnvironmentFromRemoteWithPreferredName() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/some-path.hdr")!,
            preferredName: "My Custom Cinema"
        )

        #expect(result.name == "My Custom Cinema")
    }

    @Test
    func importEnvironmentFromRemoteSanitizesPreferredDisplayName() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-sanitized-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/some-path.hdr")!,
            preferredName: "  Cinema/\nHall\tHDRI:4K  "
        )

        #expect(result.name == "Cinema Hall HDRI 4K")
    }

    @Test
    func importEnvironmentFromRemoteSanitizesEncodedSourceName() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-encoded-source-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/Cinema%2FHall%0AName.hdr")!
        )

        #expect(result.name == "Cinema Hall Name")
    }

    @Test
    func importEnvironmentFromRemoteCapsLongPreferredDisplayName() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-long-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/very-long.hdr")!,
            preferredName: String(repeating: "A", count: 120)
        )

        #expect(result.name.count == 80)
    }

    @Test
    func importEnvironmentFromRemoteWithLicenseAndAttribution() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-metadata.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/env.hdr")!,
            licenseName: "CC0 1.0 Universal",
            sourceAttributionURL: "https://polyhaven.com/a/sky"
        )

        #expect(result.licenseName == "CC0 1.0 Universal")
        #expect(result.sourceAttributionURL == "https://polyhaven.com/a/sky")
    }

    @Test
    func importEnvironmentFromRemoteSanitizesPersistedMetadata() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-sanitized-metadata.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/env.hdr")!,
            licenseName: "  CC0  ",
            sourceAttributionURL: " javascript:alert(1) ",
            previewImagePath: "/etc/passwd"
        )

        #expect(result.licenseName == "CC0")
        #expect(result.sourceAttributionURL == nil)
        #expect(result.previewImagePath == nil)
    }

    @Test
    func importEnvironmentFromRemoteDropsDirectoryPreviewImagePath() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-directory-preview.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        let previewDirectory = envDir.appendingPathComponent("preview.jpg", isDirectory: true)
        try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: envDir,
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/env.hdr")!,
            previewImagePath: previewDirectory.path
        )

        #expect(result.previewImagePath == nil)
    }

    @Test
    func importEnvironmentFromRemoteDropsInsecureAttributionURL() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-http-attribution.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/env.hdr")!,
            sourceAttributionURL: "http://example.com/insecure-source"
        )

        #expect(result.sourceAttributionURL == nil)
    }

    @Test
    func importEnvironmentFromRemoteDropsAttributionURLWithSensitiveQuery() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-secret-attribution.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        for parameterName in ["apikey", "api-key", "client_secret", "clientSecret", "secret", "password", "jwt", "refreshToken", "authToken", "session", "x-amz-signature"] {
            let result = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/env.hdr")!,
                sourceAttributionURL: "https://example.com/source?\(parameterName)=secret"
            )

            #expect(result.sourceAttributionURL == nil)
        }
    }

    @Test
    func importEnvironmentFromRemoteHTTPError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-http-error.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/notfound.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("404") || reason.contains("HTTP 404"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteNetworkError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-network-error.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        struct NetworkError: LocalizedError {
            var errorDescription: String? {
                "Request failed for https://example.com/error.hdr?api-key=environment-fixture-token"
            }
        }
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { _ in throw NetworkError() }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/error.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("REDACTED"))
            #expect(!reason.contains("environment-fixture-token"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteEmptyData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-empty-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/empty.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("No data") || reason.contains("empty"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteRejectsOversizeContentLength() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-oversize-content-length.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Length": "\(EnvironmentImportValidationPolicy.maxFileSizeBytes + 1)"
                    ]
                )!
                return (Data("HDR".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/huge.hdr")!
            )
            Issue.record("Expected unsupported file type error")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteRejectsNonHTTPSBeforeFetching() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-reject-non-https.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fetchCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                fetchCount.withLock { $0 += 1 }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        for rawURL in [
            "http://example.com/insecure.hdr",
            "file:///tmp/local.hdr",
            "ftp://example.com/legacy.hdr"
        ] {
            do {
                _ = try await manager.importEnvironment(fromRemote: URL(string: rawURL)!)
                Issue.record("Expected HTTPS rejection for \(rawURL)")
            } catch EnvironmentCatalogError.downloadFailed(let reason) {
                #expect(reason.contains("HTTPS"))
            } catch {
                Issue.record("Unexpected error for \(rawURL): \(error)")
            }
        }

        #expect(fetchCount.withLock { $0 } == 0)
    }

    @Test
    func importEnvironmentFromRemoteRejectsCredentialURLBeforeFetching() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-reject-credentials.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fetchCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                fetchCount.withLock { $0 += 1 }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://user:password@example.com/secret.hdr")!
            )
            Issue.record("Expected credential URL rejection")
        } catch EnvironmentCatalogError.downloadFailed {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(fetchCount.withLock { $0 } == 0)
    }

    @Test
    func importEnvironmentFromRemoteRejectsSensitiveQueryURLBeforeFetching() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-reject-secret-query.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fetchCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                fetchCount.withLock { $0 += 1 }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        for parameterName in ["token", "client_secret", "clientSecret", "secret", "password", "jwt", "refreshToken", "authToken", "sid", "x-amz-signature"] {
            do {
                _ = try await manager.importEnvironment(
                    fromRemote: URL(string: "https://example.com/secret.hdr?\(parameterName)=secret")!
                )
                Issue.record("Expected sensitive query URL rejection for \(parameterName)")
            } catch EnvironmentCatalogError.downloadFailed {
                #expect(Bool(true))
            } catch {
                Issue.record("Unexpected error for \(parameterName): \(error)")
            }
        }

        #expect(fetchCount.withLock { $0 } == 0)
    }

    @Test
    func importEnvironmentFromRemoteRejectsPrivateNetworkHostsBeforeFetching() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-reject-private-hosts.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fetchCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                fetchCount.withLock { $0 += 1 }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        for rawURL in [
            "https://localhost/sky.hdr",
            "https://127.0.0.1/sky.hdr",
            "https://10.0.0.8/sky.hdr",
            "https://172.20.10.4/sky.hdr",
            "https://192.168.1.2/sky.hdr",
            "https://[::1]/sky.hdr",
            "https://[fd00::1]/sky.hdr",
            "https://preview.local/sky.hdr",
        ] {
            do {
                _ = try await manager.importEnvironment(fromRemote: URL(string: rawURL)!)
                Issue.record("Expected private host rejection for \(rawURL)")
            } catch EnvironmentCatalogError.downloadFailed {
                #expect(Bool(true))
            } catch {
                Issue.record("Unexpected error for \(rawURL): \(error)")
            }
        }

        #expect(fetchCount.withLock { $0 } == 0)
    }

    @Test
    func remoteRedirectPolicyRejectsUnsafeTargetsBeforeFollow() async throws {
        let safeTargets = [
            "https://example.com/cinema.hdr",
            "https://cdn.example.com/download?asset=cinema",
        ]
        for rawURL in safeTargets {
            let request = URLRequest(url: try #require(URL(string: rawURL)))
            #expect(EnvironmentCatalogManager.validatedRemoteRedirectRequest(request) != nil)
        }

        let unsafeTargets = [
            "http://example.com/cinema.hdr",
            "https://user:password@example.com/cinema.hdr",
            "https://example.com/cinema.hdr?access_token=secret",
            "https://127.0.0.1/cinema.hdr",
            "https://0x7f000001/cinema.hdr",
            "https://[::ffff:127.0.0.1]/cinema.hdr",
            "https://example.com/cinema.txt",
        ]
        for rawURL in unsafeTargets {
            let request = URLRequest(url: try #require(URL(string: rawURL)))
            #expect(EnvironmentCatalogManager.validatedRemoteRedirectRequest(request) == nil)
        }
    }

    @Test
    func importEnvironmentFromRemoteRejectsDowngradedFinalResponseURLBeforeValidation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-reject-downgrade.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fetchCount = Mutex(0)
        let validatorCallCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in
                validatorCallCount.withLock { $0 += 1 }
                return true
            },
            remoteDataFetcher: { _ in
                fetchCount.withLock { $0 += 1 }
                let downgradedURL = URL(string: "http://example.com/redirected.hdr")!
                let response = HTTPURLResponse(
                    url: downgradedURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data("HDR".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/start.hdr")!
            )
            Issue.record("Expected HTTPS downgrade rejection")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("HTTPS"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(fetchCount.withLock { $0 } == 1)
        #expect(validatorCallCount.withLock { $0 } == 0)
    }

    @Test
    func importEnvironmentFromRemoteRejectsSensitiveFinalResponseURLBeforeValidation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-reject-secret-final-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fetchCount = Mutex(0)
        let validatorCallCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in
                validatorCallCount.withLock { $0 += 1 }
                return true
            },
            remoteDataFetcher: { _ in
                fetchCount.withLock { $0 += 1 }
                let finalURL = URL(string: "https://example.com/redirected.hdr?access_token=secret")!
                let response = HTTPURLResponse(
                    url: finalURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data("HDR".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/start.hdr")!
            )
            Issue.record("Expected sensitive final URL rejection")
        } catch EnvironmentCatalogError.downloadFailed {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(fetchCount.withLock { $0 } == 1)
        #expect(validatorCallCount.withLock { $0 } == 0)
    }

    @Test
    func importEnvironmentFromRemoteRejectsUnsupportedFinalResponseExtensionBeforeValidation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-reject-unsupported-final-extension.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fetchCount = Mutex(0)
        let validatorCallCount = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in
                validatorCallCount.withLock { $0 += 1 }
                return true
            },
            remoteDataFetcher: { _ in
                fetchCount.withLock { $0 += 1 }
                let finalURL = URL(string: "https://example.com/redirected.txt")!
                let response = HTTPURLResponse(
                    url: finalURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "image/vnd.radiance"]
                )!
                return (Data("HDR".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/start")!
            )
            Issue.record("Expected unsupported final response extension rejection")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(fetchCount.withLock { $0 } == 1)
        #expect(validatorCallCount.withLock { $0 } == 0)
    }

    @Test
    func importEnvironmentFromRemoteWithURLProtocolHarness() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-harness.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let session = URLProtocolHarness.makeSession { request in
            #expect(request.url?.absoluteString.contains("example.com") == true)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("HDR content".utf8))
        }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                try await session.data(for: URLRequest(url: url))
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/harness-test.hdr")!
        )

        #expect(result.assetPath.hasSuffix(".hdr"))
        #expect(FileManager.default.fileExists(atPath: result.assetPath))
    }

    @Test
    func importEnvironmentFromRemoteHTTP500() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-500.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (Data("Internal Server Error".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/500.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("500"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteWithHDRIYawOffsetOverride() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-yaw-override.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/yaw-test.hdr")!,
            hdriYawOffset: 180.0
        )

        #expect(result.hdriYawOffset == 180.0)
    }

    @Test
    func importCuratedPresetAlreadyExistsReturnsExisting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "curated-exists.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("HDR".utf8))
        }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                try await session.data(for: URLRequest(url: url))
            }
        )

        let preset = CuratedEnvironmentPreset(
            id: "existing-preset",
            name: "Test Theater",
            description: "A test theater",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/theater.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0"
        )

        let first = try await manager.importCuratedPreset(preset)
        let second = try await manager.importCuratedPreset(preset)

        #expect(first.id == second.id)
    }

    @Test
    func importCuratedPresetCreatesNewIfNotExists() async throws {
        let (database, rootDir) = try await makeDatabase(named: "curated-new.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let preset = CuratedEnvironmentPreset(
            id: "new-preset",
            name: "New Theater",
            description: "A new theater",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/new.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultHdriYawOffset: 45.0
        )

        let imported = try await manager.importCuratedPreset(preset)

        #expect(imported.name == "New Theater")
        #expect(imported.hdriYawOffset == 45.0)
    }
}
