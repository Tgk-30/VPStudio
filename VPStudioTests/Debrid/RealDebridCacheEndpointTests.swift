import Foundation
import Testing
@testable import VPStudio

@Suite("RealDebridCacheEndpoint")
struct RealDebridCacheEndpointTests {

    @Test func disabledCacheEndpointDetects403WithMessage() {
        let error = DebridError.httpError(403, "disabled_endpoint")
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == true)
    }

    @Test func disabledCacheEndpointDetectsCaseInsensitive() {
        let error = DebridError.httpError(403, "DISABLED_ENDPOINT")
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == true)
    }

    @Test func disabledCacheEndpointDetectsMixedCase() {
        let error = DebridError.httpError(403, "Disabled_Endpoint")
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == true)
    }

    @Test func disabledCacheEndpointRequires403Status() {
        let error = DebridError.httpError(401, "disabled_endpoint")
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == false)
    }

    @Test func disabledCacheEndpointRequiresCorrectMessage() {
        let error = DebridError.httpError(403, "forbidden")
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == false)
    }

    @Test func nonHttpErrorReturnsFalse() {
        let error = DebridError.unauthorized
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == false)
    }

    @Test func invalidHashReturnsFalse() {
        let error = DebridError.invalidHash("abc")
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == false)
    }

    @Test func rateLimitedReturnsFalse() {
        let error = DebridError.rateLimited
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == false)
    }

    @Test func networkErrorReturnsFalse() {
        let error = DebridError.networkError("timeout")
        #expect(RealDebridService.isDisabledCacheEndpoint(error) == false)
    }
}
