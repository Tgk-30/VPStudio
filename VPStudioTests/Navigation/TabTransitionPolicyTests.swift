import Testing
import CoreFoundation
@testable import VPStudio

@Suite("TabTransitionPolicy Constants")
struct TabTransitionPolicyTests {
    @Test("Scale effect value")
    func scaleEffect() {
        #expect(TabTransitionPolicy.scaleEffect == 0.98)
    }

    @Test("Spring response value")
    func springResponse() {
        #expect(TabTransitionPolicy.springResponse == 0.35)
    }

    @Test("Spring damping value")
    func springDamping() {
        #expect(TabTransitionPolicy.springDamping == 0.82)
    }

    @Test("Scale effect is between 0 and 1")
    func scaleEffectRange() {
        #expect(TabTransitionPolicy.scaleEffect > 0 && TabTransitionPolicy.scaleEffect < 1)
    }

    @Test("Spring damping is between 0 and 1")
    func springDampingRange() {
        #expect(TabTransitionPolicy.springDamping > 0 && TabTransitionPolicy.springDamping < 1)
    }

    @Test("Spring response is positive")
    func springResponsePositive() {
        #expect(TabTransitionPolicy.springResponse > 0)
    }
}
