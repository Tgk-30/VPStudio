import Foundation
import Testing
@testable import VPStudio

@Suite("TMDB Response Model Coverage")
struct TMDBResponseModelCoverageTests {
    @Test
    func pagedSearchResponseDecodesMovieAndSeriesPreviews() throws {
        let data = Data("""
        {
          "page": 2,
          "total_pages": 4,
          "total_results": 8,
          "results": [
            {
              "id": 949,
              "title": "Heat",
              "media_type": "movie",
              "overview": "A crew takes scores in Los Angeles.",
              "poster_path": "/heat.jpg",
              "backdrop_path": "/heat-backdrop.jpg",
              "release_date": "1995-12-15",
              "vote_average": 8.1
            },
            {
              "id": 95396,
              "name": "Severance",
              "media_type": "tv",
              "overview": "Work and life are divided.",
              "first_air_date": "2022-02-18",
              "vote_average": 8.7
            }
          ]
        }
        """.utf8)

        let response = try decoder.decode(TMDBPagedResponse<TMDBSearchResult>.self, from: data)
        let previews = response.results.compactMap { $0.toMediaPreview() }

        #expect(response.page == 2)
        #expect(response.totalPages == 4)
        #expect(response.totalResults == 8)
        #expect(previews.map(\.id) == ["movie-tmdb-949", "series-tmdb-95396"])
        #expect(previews.map(\.title) == ["Heat", "Severance"])
        #expect(previews.map(\.year) == [1995, 2022])
    }

    @Test
    func searchResultPreviewConversionRejectsUnsupportedOrUntitledPayloads() throws {
        let unsupported = try decoder.decode(
            TMDBSearchResult.self,
            from: Data(#"{"id":1,"title":"A Person","media_type":"person"}"#.utf8)
        )
        let untitled = try decoder.decode(
            TMDBSearchResult.self,
            from: Data(#"{"id":2,"media_type":"movie"}"#.utf8)
        )

        #expect(unsupported.toMediaPreview() == nil)
        #expect(untitled.toMediaPreview() == nil)
    }

    @Test
    func genreSeasonAndEpisodeResponsesDecodeSnakeCasePayloads() throws {
        let genres = try decoder.decode(
            TMDBGenresResponse.self,
            from: Data(#"{"genres":[{"id":878,"name":"Science Fiction"},{"id":18,"name":"Drama"}]}"#.utf8)
        )
        let tvDetails = try decoder.decode(
            TMDBTVDetailResponse.self,
            from: Data("""
            {
              "id": 95396,
              "seasons": [
                {
                  "id": 3001,
                  "season_number": 1,
                  "name": "Season 1",
                  "overview": "The first season.",
                  "poster_path": "/season.jpg",
                  "episode_count": 9,
                  "air_date": "2022-02-18"
                }
              ]
            }
            """.utf8)
        )
        let season = try decoder.decode(
            TMDBSeasonResponse.self,
            from: Data("""
            {
              "episodes": [
                {
                  "id": 4001,
                  "episode_number": 1,
                  "name": "Good News About Hell",
                  "overview": "Mark starts a new day.",
                  "air_date": "2022-02-18",
                  "still_path": "/still.jpg",
                  "runtime": 57
                }
              ]
            }
            """.utf8)
        )

        #expect(genres.genres.map(\.name) == ["Science Fiction", "Drama"])
        let decodedSeason: TMDBSeason? = tvDetails.seasons?.first
        let decodedEpisode: TMDBEpisode? = season.episodes.first

        #expect(tvDetails.id == 95396)
        #expect(decodedSeason?.seasonNumber == 1)
        #expect(decodedSeason?.episodeCount == 9)
        #expect(decodedEpisode?.episodeNumber == 1)
        #expect(decodedEpisode?.stillPath == "/still.jpg")
        #expect(decodedEpisode?.runtime == 57)
    }

    @Test
    func findResponseSeparatesMovieAndTVResults() throws {
        let response = try decoder.decode(
            TMDBFindResponse.self,
            from: Data("""
            {
              "movie_results": [
                {"id": 438631, "title": "Dune", "release_date": "2021-09-15"}
              ],
              "tv_results": [
                {"id": 76479, "name": "The Boys", "first_air_date": "2019-07-25"}
              ]
            }
            """.utf8)
        )

        #expect(response.movieResults.first?.toMediaPreview()?.id == "movie-tmdb-438631")
        #expect(response.tvResults.first?.toMediaPreview()?.id == "series-tmdb-76479")
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
