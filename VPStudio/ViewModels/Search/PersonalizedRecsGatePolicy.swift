import Foundation

/// Pure gate for the Trakt-personalized "For You" affordance.
///
/// Personalized recommendations only make sense once the user has connected
/// Trakt *and* opted into history sync — otherwise there is no recently-watched
/// signal to weight, and the request degrades to the generic "Curate For Me".
enum PersonalizedRecsGatePolicy {
    static func isEnabled(hasTraktToken: Bool, historySyncEnabled: Bool) -> Bool {
        hasTraktToken && historySyncEnabled
    }
}
