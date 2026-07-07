import Foundation

enum TorrentProvider: String, CaseIterable, Sendable {
    case yts, solid, pirateBay, x1337, torrentGalaxy, nyaa, kickass, limeTorrents, eztv, rarbg, rutor, iDope
    case isohunt, softArchive, zooqle, animeTime, animeTosho, anirena, bitsearch, corp
    case cloudTorrents, cpasbien, extratorrent, fitgirl, gamesTorrents, megaPeer, torrentFunk

    var displayName: String {
        switch self {
        case .yts: return "YTS"
        case .solid: return "SolidTorrents"
        case .pirateBay: return "Pirate Bay"
        case .x1337: return "1337x"
        case .torrentGalaxy: return "TorrentGalaxy"
        case .nyaa: return "Nyaa"
        case .kickass: return "Kickass"
        case .limeTorrents: return "LimeTorrents"
        case .eztv: return "EZTV"
        case .rarbg: return "RARBG"
        case .rutor: return "RuTor"
        case .iDope: return "iDope"
        case .isohunt: return "Isohunt"
        case .softArchive: return "SoftArchive"
        case .zooqle: return "Zooqle"
        case .animeTime: return "AnimeTime"
        case .animeTosho: return "AnimeTosho"
        case .anirena: return "AniRena"
        case .bitsearch: return "BitSearch"
        case .corp: return "Corp"
        case .cloudTorrents: return "CloudTorrents"
        case .cpasbien: return "Cpasbien"
        case .extratorrent: return "ExtraTorrent"
        case .fitgirl: return "FitGirl"
        case .gamesTorrents: return "GamesTorrents"
        case .megaPeer: return "MegaPeer"
        case .torrentFunk: return "TorrentFunk"
        }
    }
}

enum TorrentCategory: String, CaseIterable, Sendable {
    case all, movies, series, games, music, books, apps, anime

    var displayName: String {
        switch self {
        case .all: return "All"
        case .movies: return "Movies"
        case .series: return "Series/TV"
        case .games: return "Games"
        case .music: return "Music"
        case .books: return "Books"
        case .apps: return "Apps"
        case .anime: return "Anime"
        }
    }
}

actor TorrentSearchService {
    static let shared = TorrentSearchService()
    private let httpClient = HTTPClient.shared

    private init() {}

    func search(query: String, providers: [TorrentProvider], category: TorrentCategory = .all) async -> [TorrentSearchResult] {
        var allResults: [TorrentSearchResult] = []

        await withTaskGroup(of: [TorrentSearchResult].self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return try await self.searchProvider(provider, query: query)
                    } catch {
                        AppLogger.error("Search failed for \(provider.displayName): \(error)", category: .torrent)
                        return []
                    }
                }
            }

            for await results in group {
                allResults.append(contentsOf: results)
            }
        }

        allResults.sort { $0.seeders > $1.seeders }
        return allResults
    }

    private func searchProvider(_ provider: TorrentProvider, query: String) async throws -> [TorrentSearchResult] {
        switch provider {
        case .yts:
            return try await searchYTS(query: query)
        case .solid:
            return try await searchSolidTorrents(query: query)
        case .pirateBay:
            return try await searchPirateBay(query: query)
        case .x1337:
            return try await search1337x(query: query)
        case .torrentGalaxy:
            return try await searchTorrentGalaxy(query: query)
        case .nyaa:
            return try await searchNyaa(query: query)
        case .kickass:
            return try await searchKickass(query: query)
        case .limeTorrents:
            return try await searchLimeTorrents(query: query)
        case .eztv:
            return try await searchEZTV(query: query)
        case .iDope:
            return try await searchIDope(query: query)
        default:
            return []
        }
    }

    private func searchYTS(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://yts.mx/api/v2/list_movies.json?query_term=\(encoded)&limit=50"
        let data = try await httpClient.get(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataDict = json?["data"] as? [String: Any],
              let movies = dataDict["movies"] as? [[String: Any]] else { return [] }

        return movies.compactMap { movie -> TorrentSearchResult? in
            guard let title = movie["title"] as? String,
                  let torrents = movie["torrents"] as? [[String: Any]],
                  let first = torrents.first else { return nil }
            let magnet = extractMagnet(from: first)
            return TorrentSearchResult(
                provider: "YTS",
                title: title,
                magnetLink: magnet,
                seeders: first["seeds"] as? Int ?? 0,
                leechers: first["peers"] as? Int ?? 0,
                size: first["size"] as? String ?? "",
                category: "Movies",
                uploadDate: movie["date_uploaded"] as? String ?? ""
            )
        }
    }

    private func searchSolidTorrents(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://api.solidtorrents.net/api/v1/search?q=\(encoded)&sort=seeders&order=desc"
        let data = try await httpClient.get(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return json.compactMap { item in
            guard let title = item["name"] as? String,
                  let magnet = item["magnet"] as? String else { return nil }
            return TorrentSearchResult(
                provider: "SolidTorrents",
                title: title,
                magnetLink: magnet,
                seeders: item["seeders"] as? Int ?? 0,
                leechers: item["leechers"] as? Int ?? 0,
                size: item["size"] as? String ?? "",
                category: item["category"] as? String ?? "",
                uploadDate: item["uploadDate"] as? String ?? ""
            )
        }
    }

    private func searchPirateBay(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apibay.org/q.php?q=\(encoded)&cat=0"
        let data = try await httpClient.get(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return json.compactMap { item in
            guard let id = item["id"] as? String, id != "0",
                  let name = item["name"] as? String else { return nil }
            let magnet = "magnet:?xt=urn:btih:\(item["info_hash"] as? String ?? "")&dn=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            return TorrentSearchResult(
                provider: "Pirate Bay",
                title: name,
                magnetLink: magnet,
                seeders: Int(item["seeders"] as? String ?? "0") ?? 0,
                leechers: Int(item["leechers"] as? String ?? "0") ?? 0,
                size: item["size"] as? String ?? "",
                category: item["category"] as? String ?? "",
                uploadDate: ""
            )
        }
    }

    private func search1337x(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apilist.one/api/1337x/search?q=\(encoded)&sort=seeders&order=desc"
        return try await searchViaAPIList(url: url, provider: "1337x")
    }

    private func searchTorrentGalaxy(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apilist.one/api/torrentgalaxy/search?q=\(encoded)&sort=seeders&order=desc"
        return try await searchViaAPIList(url: url, provider: "TorrentGalaxy")
    }

    private func searchNyaa(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apilist.one/api/nyaa/search?q=\(encoded)&sort=seeders&order=desc"
        return try await searchViaAPIList(url: url, provider: "Nyaa")
    }

    private func searchKickass(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apilist.one/api/kickass/search?q=\(encoded)&sort=seeders&order=desc"
        return try await searchViaAPIList(url: url, provider: "Kickass")
    }

    private func searchLimeTorrents(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apilist.one/api/limetorrents/search?q=\(encoded)&sort=seeders&order=desc"
        return try await searchViaAPIList(url: url, provider: "LimeTorrents")
    }

    private func searchEZTV(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apilist.one/api/eztv/search?q=\(encoded)&sort=seeders&order=desc"
        return try await searchViaAPIList(url: url, provider: "EZTV")
    }

    private func searchIDope(query: String) async throws -> [TorrentSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://apilist.one/api/idope/search?q=\(encoded)&sort=seeders&order=desc"
        return try await searchViaAPIList(url: url, provider: "iDope")
    }

    private func searchViaAPIList(url: String, provider: String) async throws -> [TorrentSearchResult] {
        let data = try await httpClient.get(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]] ?? json as? [[String: Any]] ?? []
        return results.compactMap { item in
            guard let title = item["name"] as? String ?? item["title"] as? String,
                  let magnet = item["magnet"] as? String ?? item["magnetLink"] as? String else { return nil }
            return TorrentSearchResult(
                provider: provider,
                title: title,
                magnetLink: magnet,
                seeders: item["seeders"] as? Int ?? 0,
                leechers: item["leechers"] as? Int ?? 0,
                size: item["size"] as? String ?? "",
                category: item["category"] as? String ?? "",
                uploadDate: item["uploadDate"] as? String ?? ""
            )
        }
    }

    private func extractMagnet(from torrentDict: [String: Any]) -> String {
        let hash = torrentDict["hash"] as? String ?? ""
        let quality = torrentDict["quality"] as? String ?? ""
        let type = torrentDict["type"] as? String ?? ""
        return "magnet:?xt=urn:btih:\(hash)&dn=\(quality).\(type)"
    }
}
