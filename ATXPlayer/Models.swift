import Foundation

private extension KeyedDecodingContainer {
    func flexibleString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return String(value) }
        return nil
    }

    func flexibleInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        return nil
    }

    func flexibleDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}

struct RemoteConfig: Codable {
    let enabled: Bool
    let dns: String
    let message: String
}

struct LoginResponse: Codable {
    let userInfo: UserInfo?
    let serverInfo: ServerInfo?
    enum CodingKeys: String, CodingKey { case userInfo = "user_info", serverInfo = "server_info" }
}

struct UserInfo: Codable {
    let username: String?
    let password: String?
    let message: String?
    let auth: Int?
    let status: String?
    let expDate: String?
    let activeCons: String?
    let maxConnections: String?
    let allowedOutputFormats: [String]?

    enum CodingKeys: String, CodingKey {
        case username, password, message, auth, status
        case expDate = "exp_date", activeCons = "active_cons", maxConnections = "max_connections"
        case allowedOutputFormats = "allowed_output_formats"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        username = c.flexibleString(forKey: .username)
        password = c.flexibleString(forKey: .password)
        message = c.flexibleString(forKey: .message)
        auth = c.flexibleInt(forKey: .auth)
        status = c.flexibleString(forKey: .status)
        expDate = c.flexibleString(forKey: .expDate)
        activeCons = c.flexibleString(forKey: .activeCons)
        maxConnections = c.flexibleString(forKey: .maxConnections)
        allowedOutputFormats = try? c.decodeIfPresent([String].self, forKey: .allowedOutputFormats)
    }
}

struct ServerInfo: Codable {
    let url: String?, port: String?, httpsPort: String?, serverProtocol: String?, timezone: String?, timestampNow: Int?
    enum CodingKeys: String, CodingKey {
        case url, port, timezone
        case httpsPort = "https_port", serverProtocol = "server_protocol", timestampNow = "timestamp_now"
    }
}

struct Category: Codable, Identifiable, Hashable {
    let categoryID: String
    let categoryName: String
    let parentID: Int?
    var id: String { categoryID }
    enum CodingKeys: String, CodingKey { case categoryID = "category_id", categoryName = "category_name", parentID = "parent_id" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryID = c.flexibleString(forKey: .categoryID) ?? UUID().uuidString
        categoryName = c.flexibleString(forKey: .categoryName) ?? "Senza nome"
        parentID = c.flexibleInt(forKey: .parentID)
    }
}

struct LiveStream: Codable, Identifiable, Hashable {
    let num: Int?, name: String, streamType: String?, streamID: Int, streamIcon: String?, epgChannelID: String?, added: String?, categoryID: String?, customSID: String?, tvArchive: Int?, directSource: String?
    var id: Int { streamID }
    enum CodingKeys: String, CodingKey {
        case num, name, added
        case streamType = "stream_type", streamID = "stream_id", streamIcon = "stream_icon", epgChannelID = "epg_channel_id", categoryID = "category_id", customSID = "custom_sid", tvArchive = "tv_archive", directSource = "direct_source"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = c.flexibleInt(forKey: .num)
        name = c.flexibleString(forKey: .name) ?? "Canale"
        streamType = c.flexibleString(forKey: .streamType)
        streamID = c.flexibleInt(forKey: .streamID) ?? abs(name.hashValue)
        streamIcon = c.flexibleString(forKey: .streamIcon)
        epgChannelID = c.flexibleString(forKey: .epgChannelID)
        added = c.flexibleString(forKey: .added)
        categoryID = c.flexibleString(forKey: .categoryID)
        customSID = c.flexibleString(forKey: .customSID)
        tvArchive = c.flexibleInt(forKey: .tvArchive)
        directSource = c.flexibleString(forKey: .directSource)
    }
}

struct VODStream: Codable, Identifiable, Hashable {
    let num: Int?, name: String, streamType: String?, streamID: Int, streamIcon: String?, rating: String?, rating5Based: Double?, added: String?, categoryID: String?, containerExtension: String?, plot: String?, cast: String?, director: String?, genre: String?, releaseDate: String?, duration: String?
    var id: Int { streamID }
    enum CodingKeys: String, CodingKey {
        case num, name, rating, added, plot, cast, director, genre, duration
        case streamType = "stream_type", streamID = "stream_id", streamIcon = "stream_icon", rating5Based = "rating_5based", categoryID = "category_id", containerExtension = "container_extension", releaseDate = "release_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = c.flexibleInt(forKey: .num)
        name = c.flexibleString(forKey: .name) ?? "Film"
        streamType = c.flexibleString(forKey: .streamType)
        streamID = c.flexibleInt(forKey: .streamID) ?? abs(name.hashValue)
        streamIcon = c.flexibleString(forKey: .streamIcon)
        rating = c.flexibleString(forKey: .rating)
        rating5Based = c.flexibleDouble(forKey: .rating5Based)
        added = c.flexibleString(forKey: .added)
        categoryID = c.flexibleString(forKey: .categoryID)
        containerExtension = c.flexibleString(forKey: .containerExtension)
        plot = c.flexibleString(forKey: .plot)
        cast = c.flexibleString(forKey: .cast)
        director = c.flexibleString(forKey: .director)
        genre = c.flexibleString(forKey: .genre)
        releaseDate = c.flexibleString(forKey: .releaseDate)
        duration = c.flexibleString(forKey: .duration)
    }
}

struct SeriesItem: Codable, Identifiable, Hashable {
    let num: Int?, name: String, seriesID: Int, cover: String?, plot: String?, cast: String?, director: String?, genre: String?, releaseDate: String?, rating: String?, categoryID: String?, added: String?, lastModified: String?
    var id: Int { seriesID }
    enum CodingKeys: String, CodingKey {
        case num, name, cover, plot, cast, director, genre, rating
        case seriesID = "series_id", releaseDate = "releaseDate", categoryID = "category_id", added, lastModified = "last_modified"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = c.flexibleInt(forKey: .num)
        name = c.flexibleString(forKey: .name) ?? "Serie"
        seriesID = c.flexibleInt(forKey: .seriesID) ?? abs(name.hashValue)
        cover = c.flexibleString(forKey: .cover)
        plot = c.flexibleString(forKey: .plot)
        cast = c.flexibleString(forKey: .cast)
        director = c.flexibleString(forKey: .director)
        genre = c.flexibleString(forKey: .genre)
        releaseDate = c.flexibleString(forKey: .releaseDate)
        rating = c.flexibleString(forKey: .rating)
        categoryID = c.flexibleString(forKey: .categoryID)
        added = c.flexibleString(forKey: .added)
        lastModified = c.flexibleString(forKey: .lastModified)
    }
}

struct VODInfoResponse: Decodable {
    let info: VODDetails?
    let movieData: VODMovieData?
    enum CodingKeys: String, CodingKey { case info; case movieData = "movie_data" }
}

struct VODDetails: Decodable {
    let name: String?, movieImage: String?, plot: String?, cast: String?, director: String?, genre: String?, releaseDate: String?, duration: String?, rating: String?, youtubeTrailer: String?
    enum CodingKeys: String, CodingKey {
        case name, plot, cast, director, genre, duration, rating
        case movieImage = "movie_image", releaseDate = "releasedate", youtubeTrailer = "youtube_trailer"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.flexibleString(forKey: .name)
        movieImage = c.flexibleString(forKey: .movieImage)
        plot = c.flexibleString(forKey: .plot)
        cast = c.flexibleString(forKey: .cast)
        director = c.flexibleString(forKey: .director)
        genre = c.flexibleString(forKey: .genre)
        releaseDate = c.flexibleString(forKey: .releaseDate)
        duration = c.flexibleString(forKey: .duration)
        rating = c.flexibleString(forKey: .rating)
        youtubeTrailer = c.flexibleString(forKey: .youtubeTrailer)
    }
}

struct VODMovieData: Decodable {
    let name: String?, streamID: Int?, containerExtension: String?
    enum CodingKeys: String, CodingKey { case name; case streamID = "stream_id", containerExtension = "container_extension" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.flexibleString(forKey: .name)
        streamID = c.flexibleInt(forKey: .streamID)
        containerExtension = c.flexibleString(forKey: .containerExtension)
    }
}

struct EPGListing: Codable, Identifiable {
    let id: String?, epgID: String?, title: String?, lang: String?, start: String?, end: String?, description: String?, startTimestamp: String?, stopTimestamp: String?
    var listID: String { id ?? UUID().uuidString }
    enum CodingKeys: String, CodingKey { case id, title, lang, start, end, description; case epgID = "epg_id", startTimestamp = "start_timestamp", stopTimestamp = "stop_timestamp" }
}

struct ShortEPGResponse: Codable {
    let epgListings: [EPGListing]?
    enum CodingKeys: String, CodingKey { case epgListings = "epg_listings" }
}


struct SeriesInfoResponse: Decodable {
    let info: SeriesDetails?
    let episodes: [String: [Episode]]

    enum CodingKeys: String, CodingKey { case info, episodes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        info = try? c.decodeIfPresent(SeriesDetails.self, forKey: .info)
        episodes = (try? c.decodeIfPresent([String: [Episode]].self, forKey: .episodes)) ?? [:]
    }
}

struct SeriesDetails: Decodable {
    let name: String?
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let rating: String?

    enum CodingKeys: String, CodingKey {
        case name, cover, plot, cast, director, genre, rating
        case releaseDate = "releaseDate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.flexibleString(forKey: .name)
        cover = c.flexibleString(forKey: .cover)
        plot = c.flexibleString(forKey: .plot)
        cast = c.flexibleString(forKey: .cast)
        director = c.flexibleString(forKey: .director)
        genre = c.flexibleString(forKey: .genre)
        releaseDate = c.flexibleString(forKey: .releaseDate)
        rating = c.flexibleString(forKey: .rating)
    }
}

struct Episode: Decodable, Identifiable, Hashable {
    let id: Int
    let episodeNum: Int
    let title: String
    let containerExtension: String?
    let season: Int?
    let info: EpisodeInfo?

    enum CodingKeys: String, CodingKey {
        case id, title, season, info
        case episodeNum = "episode_num"
        case containerExtension = "container_extension"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexibleInt(forKey: .id) ?? 0
        episodeNum = c.flexibleInt(forKey: .episodeNum) ?? 0
        title = c.flexibleString(forKey: .title) ?? "Episodio \(episodeNum)"
        containerExtension = c.flexibleString(forKey: .containerExtension)
        season = c.flexibleInt(forKey: .season)
        info = try? c.decodeIfPresent(EpisodeInfo.self, forKey: .info)
    }
}

struct EpisodeInfo: Decodable, Hashable {
    let plot: String?
    let duration: String?
    let movieImage: String?
    let rating: String?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case plot, duration, rating
        case movieImage = "movie_image"
        case releaseDate = "releasedate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plot = c.flexibleString(forKey: .plot)
        duration = c.flexibleString(forKey: .duration)
        movieImage = c.flexibleString(forKey: .movieImage)
        rating = c.flexibleString(forKey: .rating)
        releaseDate = c.flexibleString(forKey: .releaseDate)
    }
}
