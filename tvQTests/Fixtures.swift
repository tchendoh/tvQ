import Foundation

/// Réponses d'API pour les tests de décodage, abrégées (quelques éléments par liste)
/// mais conformes au format réel, champs superflus et valeurs null comprises.
/// Pour les rafraîchir : remplacer par une réponse réelle capturée (curl), abrégée.
enum Fixtures {
    /// GET /3/tv/1399?append_to_response=external_ids
    static let tmdbShowDetails = #"""
    {
      "adult": false,
      "backdrop_path": "/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg",
      "created_by": [{"id": 9813, "credit_id": "5256c8c219c2956ff604858a", "name": "David Benioff", "gender": 2, "profile_path": "/xvNN5huL0X8yJ7h3IZfGG4O2zBD.jpg"}],
      "episode_run_time": [],
      "first_air_date": "2011-04-17",
      "genres": [{"id": 10765, "name": "Sci-Fi & Fantasy"}, {"id": 18, "name": "Drama"}],
      "homepage": "https://www.hbo.com/game-of-thrones",
      "id": 1399,
      "in_production": false,
      "languages": ["en"],
      "last_air_date": "2019-05-19",
      "name": "Game of Thrones",
      "networks": [{"id": 49, "logo_path": "/tuomPhY2UtuPTqqFnKMVHvSb724.png", "name": "HBO", "origin_country": "US"}],
      "next_episode_to_air": null,
      "number_of_episodes": 73,
      "number_of_seasons": 8,
      "origin_country": ["US"],
      "original_language": "en",
      "original_name": "Game of Thrones",
      "overview": "Seven noble families fight for control of the mythical land of Westeros.",
      "popularity": 393.112,
      "poster_path": "/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
      "status": "Ended",
      "tagline": "Winter is coming.",
      "type": "Scripted",
      "vote_average": 8.456,
      "vote_count": 25000,
      "external_ids": {"imdb_id": "tt0944947", "freebase_mid": "/m/0524b41", "freebase_id": null, "tvdb_id": 121361, "tvrage_id": 24493, "wikidata_id": "Q23572", "facebook_id": null, "instagram_id": null, "twitter_id": null}
    }
    """#

    /// Série récente sans IMDB ID ni diffuseur : cas réel pour les productions locales.
    static let tmdbShowDetailsMinimal = #"""
    {
      "backdrop_path": null,
      "genres": [],
      "id": 250000,
      "name": "Nouvelle série",
      "networks": [],
      "number_of_seasons": 0,
      "original_language": "fr",
      "overview": "",
      "poster_path": null,
      "status": "Planned",
      "external_ids": {"imdb_id": null, "tvdb_id": null}
    }
    """#

    /// GET /3/tv/1399/season/8
    static let tmdbSeason = #"""
    {
      "_id": "5c0a8ab4925141626b0b0f7b",
      "air_date": "2019-04-14",
      "episodes": [
        {"air_date": "2019-04-14", "episode_number": 1, "episode_type": "standard", "id": 1551825, "name": "Winterfell", "overview": "Jon and Daenerys arrive in Winterfell.", "production_code": "801", "runtime": 54, "season_number": 8, "show_id": 1399, "still_path": "/3cTjfqKNKBWkkRzPwlFRj1b4x6v.jpg", "vote_average": 7.6, "vote_count": 300, "crew": [], "guest_stars": []},
        {"air_date": null, "episode_number": 2, "episode_type": "standard", "id": 1551826, "name": "Épisode 2", "overview": "", "production_code": "", "runtime": null, "season_number": 8, "show_id": 1399, "still_path": null, "vote_average": 0.0, "vote_count": 0, "crew": [], "guest_stars": []}
      ],
      "name": "Season 8",
      "overview": "",
      "id": 107971,
      "poster_path": "/39FHkTLnNMjNgCHHqPoXEXbqfjP.jpg",
      "season_number": 8,
      "vote_average": 6.4
    }
    """#

    /// GET /3/trending/tv/week (même forme pour search/tv, on_the_air, airing_today)
    static let tmdbSearchResults = #"""
    {
      "page": 1,
      "results": [
        {"adult": false, "backdrop_path": "/backdrop.jpg", "id": 1399, "name": "Game of Thrones", "original_language": "en", "original_name": "Game of Thrones", "overview": "Seven noble families...", "poster_path": "/poster.jpg", "media_type": "tv", "genre_ids": [10765, 18], "popularity": 393.1, "first_air_date": "2011-04-17", "vote_average": 8.4, "vote_count": 25000, "origin_country": ["US"]},
        {"adult": false, "backdrop_path": null, "id": 22980, "name": "Talk-show", "original_language": "en", "original_name": "Talk-show", "overview": "", "poster_path": null, "media_type": "tv", "genre_ids": [10767], "popularity": 50.0, "first_air_date": "2015-09-08", "vote_average": 6.0, "vote_count": 100, "origin_country": ["US"]}
      ],
      "total_pages": 50,
      "total_results": 1000
    }
    """#

    /// GET /3/tv/1399/watch/providers
    static let tmdbWatchProviders = #"""
    {
      "id": 1399,
      "results": {
        "CA": {
          "link": "https://www.themoviedb.org/tv/1399-game-of-thrones/watch?locale=CA",
          "flatrate": [{"logo_path": "/gJ3yVMWouaVj6iHd59TISJ1TlM5.jpg", "provider_id": 230, "provider_name": "Crave", "display_priority": 2}],
          "buy": [
            {"logo_path": "/9ghgSC0MA082EL6HLCW3GalykFD.jpg", "provider_id": 2, "provider_name": "Apple TV", "display_priority": 4},
            {"logo_path": "/8z7rC8uIDaTM91X0ZfkRf04ydj2.jpg", "provider_id": 3, "provider_name": "Google Play Movies", "display_priority": 10}
          ]
        },
        "US": {
          "link": "https://www.themoviedb.org/tv/1399-game-of-thrones/watch?locale=US",
          "flatrate": [{"logo_path": "/x.jpg", "provider_id": 1899, "provider_name": "HBO Max", "display_priority": 1}]
        }
      }
    }
    """#

    /// GET https://api.tvmaze.com/lookup/shows?imdb=tt0944947
    static let tvmazeLookup = #"""
    {
      "id": 82,
      "url": "https://www.tvmaze.com/shows/82/game-of-thrones",
      "name": "Game of Thrones",
      "type": "Scripted",
      "language": "English",
      "genres": ["Drama", "Adventure", "Fantasy"],
      "status": "Ended",
      "runtime": 60,
      "averageRuntime": 61,
      "premiered": "2011-04-17",
      "ended": "2019-05-19",
      "officialSite": "http://www.hbo.com/game-of-thrones",
      "schedule": {"time": "21:00", "days": ["Sunday"]},
      "rating": {"average": 8.9},
      "weight": 99,
      "network": {"id": 8, "name": "HBO", "country": {"name": "United States", "code": "US", "timezone": "America/New_York"}, "officialSite": "https://www.hbo.com/"},
      "webChannel": null,
      "dvdCountry": null,
      "externals": {"tvrage": 24493, "thetvdb": 121361, "imdb": "tt0944947"},
      "image": {"medium": "https://static.tvmaze.com/uploads/images/medium_portrait/190/476117.jpg", "original": "https://static.tvmaze.com/uploads/images/original_untouched/190/476117.jpg"},
      "summary": "<p>Based on the bestselling book series...</p>",
      "updated": 1704794122,
      "_links": {"self": {"href": "https://api.tvmaze.com/shows/82"}}
    }
    """#

    /// GET https://api.tvmaze.com/shows/82/episodes?specials=1 (un épisode régulier, un spécial)
    static let tvmazeEpisodes = #"""
    [
      {"id": 1623968, "url": "https://www.tvmaze.com/episodes/1623968/game-of-thrones-8x01-winterfell", "name": "Winterfell", "season": 8, "number": 1, "type": "regular", "airdate": "2019-04-14", "airtime": "21:00", "airstamp": "2019-04-15T01:00:00+00:00", "runtime": 54, "rating": {"average": 7.6}, "image": null, "summary": "<p>Jon and Daenerys arrive in Winterfell.</p>", "_links": {"self": {"href": "https://api.tvmaze.com/episodes/1623968"}}},
      {"id": 1806037, "url": "https://www.tvmaze.com/episodes/1806037/game-of-thrones-s08-special-the-last-watch", "name": "The Last Watch", "season": 8, "number": null, "type": "significant_special", "airdate": "2019-05-26", "airtime": "21:00", "airstamp": null, "runtime": null, "rating": {"average": null}, "image": null, "summary": null, "_links": {"self": {"href": "https://api.tvmaze.com/episodes/1806037"}}}
    ]
    """#
}
