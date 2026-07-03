import Foundation
import Testing
@testable import VPStudio

@Suite("Sync Response Value Coverage")
struct SyncResponseValueCoverageTests {
    @Test
    func traktResponseModelsDecodeMoviesShowsEpisodesListsAndRatings() throws {
        let movie: TraktMovie = try traktDecoder.decode(
            TraktMovie.self,
            from: Data(#"{"title":"Dune","year":2021,"ids":{"trakt":1,"slug":"dune-2021","imdb":"tt1160419","tmdb":438631}}"#.utf8)
        )
        let show: TraktShow = try traktDecoder.decode(
            TraktShow.self,
            from: Data(#"{"name":"Severance","year":2022,"ids":{"trakt":2,"slug":"severance","imdb":"tt11280740","tmdb":95396}}"#.utf8)
        )
        let history: TraktHistoryItem = try traktDecoder.decode(
            TraktHistoryItem.self,
            from: Data("""
            {
              "id": 11,
              "watched_at": "2024-01-02T03:04:05.000Z",
              "action": "watch",
              "show": {"title":"Severance","ids":{"trakt":2}},
              "episode": {"season":1,"number":2,"title":"Half Loop","ids":{"trakt":22}}
            }
            """.utf8)
        )
        let rating: TraktRatingItem = try traktDecoder.decode(
            TraktRatingItem.self,
            from: Data(#"{"rating":9,"rated_at":"2024-01-03T00:00:00.000Z","movie":{"title":"Dune","ids":{"trakt":1}}}"#.utf8)
        )
        let customList: TraktCustomList = try traktDecoder.decode(
            TraktCustomList.self,
            from: Data("""
            {
              "ids": {"trakt": 77, "slug": "favorites"},
              "name": "Favorites",
              "description": "Top picks",
              "privacy": "private",
              "item_count": 3,
              "updated_at": "2024-01-04T00:00:00.000Z"
            }
            """.utf8)
        )
        let listItem: TraktListItem = try traktDecoder.decode(
            TraktListItem.self,
            from: Data(#"{"rank":1,"listed_at":"2024-01-05T00:00:00.000Z","type":"movie","movie":{"title":"Dune","ids":{"trakt":1}}}"#.utf8)
        )

        #expect(movie.ids.tmdb == 438_631)
        #expect(show.title == "Severance")
        let episode: TraktEpisode? = history.episode
        let listIDs: TraktListIds = customList.ids

        #expect(episode?.number == 2)
        #expect(rating.rating == 9)
        #expect(listIDs.trakt == 77)
        #expect(customList.itemCount == 3)
        #expect(listItem.movie?.title == "Dune")
    }

    @Test
    func traktShowAndMovieDefaultMissingTitlesAndIds() throws {
        let movie: TraktMovie = try traktDecoder.decode(TraktMovie.self, from: Data(#"{}"#.utf8))
        let show: TraktShow = try traktDecoder.decode(TraktShow.self, from: Data(#"{}"#.utf8))

        #expect(movie.title == "Unknown")
        #expect(show.title == "Unknown")
        #expect(movie.ids.trakt == nil)
        #expect(show.ids.slug == nil)
    }

    @Test
    func devicePollResultCasesExposeExpectedPayloads() {
        let pending: DevicePollResult = .pending
        let slowDown: DevicePollResult = .slowDown
        let success: DevicePollResult = .success(access: "access-token", refresh: "refresh-token")

        if case .pending = pending {} else {
            Issue.record("Expected pending")
        }
        if case .slowDown = slowDown {} else {
            Issue.record("Expected slowDown")
        }
        guard case let .success(access, refresh) = success else {
            Issue.record("Expected success")
            return
        }
        #expect(access == "access-token")
        #expect(refresh == "refresh-token")
    }

    @Test
    func simklResponseModelsDecodeOAuthActionAndSyncPayloads() throws {
        let start = SimklAuthorizationSessionStart(
            url: URL(string: "https://simkl.com/oauth/authorize?client_id=client")!,
            state: "state-token"
        )
        let token: SimklOAuthTokenResponse = try JSONDecoder().decode(
            SimklOAuthTokenResponse.self,
            from: Data("""
            {
              "access_token": "access",
              "token_type": "Bearer",
              "refresh_token": "refresh",
              "expires_in": 3600,
              "scope": "read"
            }
            """.utf8)
        )
        let action: SimklActionResponse = try JSONDecoder().decode(
            SimklActionResponse.self,
            from: Data(#"{"added":{"movies":1,"shows":2},"not_found":{"movies":0,"shows":1}}"#.utf8)
        )
        let sync: SimklSyncResponse = try JSONDecoder().decode(
            SimklSyncResponse.self,
            from: Data("""
            {
              "movies": [
                {
                  "last_watched_at": "2024-01-01T00:00:00Z",
                  "status": "completed",
                  "movie": {
                    "title": "Dune",
                    "year": 2021,
                    "ids": {"simkl": 10, "imdb": "tt1160419", "tmdb": "438631"}
                  }
                }
              ],
              "shows": [
                {
                  "status": "watching",
                  "show": {
                    "title": "Severance",
                    "year": 2022,
                    "ids": {"simkl": 20, "imdb": "tt11280740", "tmdb": "95396"}
                  }
                }
              ]
            }
            """.utf8)
        )

        let firstMovie: SimklItem? = sync.movies?.first
        let media: SimklMedia? = firstMovie?.movie
        let ids: SimklIds? = media?.ids
        let added: SimklActionCount? = action.added

        #expect(start.state == "state-token")
        #expect(start.url.host() == "simkl.com")
        #expect(token.accessToken == "access")
        #expect(token.expiresIn == 3600)
        #expect(added?.shows == 2)
        #expect(action.notFound?.shows == 1)
        #expect(firstMovie?.lastWatchedAt == "2024-01-01T00:00:00Z")
        #expect(media?.title == "Dune")
        #expect(ids?.imdb == "tt1160419")
        #expect(sync.shows?.first?.show?.title == "Severance")
    }

    private var traktDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
