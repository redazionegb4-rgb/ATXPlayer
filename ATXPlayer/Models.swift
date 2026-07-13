import Foundation

struct RemoteConfig: Codable {
    let enabled: Bool
    let dns: String
    let message: String
}

struct LoginResponse: Codable {
    let userInfo: UserInfo?
    let serverInfo: ServerInfo?

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
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
        case expDate = "exp_date"
        case activeCons = "active_cons"
        case maxConnections = "max_connections"
        case allowedOutputFormats = "allowed_output_formats"
    }
}

struct ServerInfo: Codable {
    let url: String?
    let port: String?
    let httpsPort: String?
    let serverProtocol: String?
    let timezone: String?
    let timestampNow: Int?

    enum CodingKeys: String, CodingKey {
        case url, port, timezone
        case httpsPort = "https_port"
        case serverProtocol = "server_protocol"
        case timestampNow = "timestamp_now"
    }
}

struct Category: Codable, Identifiable, Hashable {
    let categoryID: String
    let categoryName: String
    let parentID: Int?
    var id: String { categoryID }

    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
        case parentID = "parent_id"
    }
}

struct LiveStream: Codable, Identifiable, Hashable {
    let num: Int?
    let name: String
    let streamType: String?
    let streamID: Int
    let streamIcon: String?
    let epgChannelID: String?
    let added: String?
    let categoryID: String?
    let customSID: String?
    let tvArchive: Int?
    let directSource: String?
    var id: Int { streamID }

    enum CodingKeys: String, CodingKey {
        case num, name, added
        case streamType = "stream_type"
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelID = "epg_channel_id"
        case categoryID = "category_id"
        case customSID = "custom_sid"
        case tvArchive = "tv_archive"
        case directSource = "direct_source"
    }
}

struct VODStream: Codable, Identifiable, Hashable {
    let num: Int?
    let name: String
    let streamType: String?
    let streamID: Int
    let streamIcon: String?
    let rating: String?
    let rating5Based: Double?
    let added: String?
    let categoryID: String?
    let containerExtension: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let duration: String?
    var id: Int { streamID }

    enum CodingKeys: String, CodingKey {
        case num, name, rating, added, plot, cast, director, genre, duration
        case streamType = "stream_type"
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case rating5Based = "rating_5based"
        case categoryID = "category_id"
        case containerExtension = "container_extension"
        case releaseDate = "release_date"
    }
}

struct SeriesItem: Codable, Identifiable, Hashable {
    let num: Int?
    let name: String
    let seriesID: Int
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let rating: String?
    let categoryID: String?
    var id: Int { seriesID }

    enum CodingKeys: String, CodingKey {
        case num, name, cover, plot, cast, director, genre, rating
        case seriesID = "series_id"
        case releaseDate = "releaseDate"
        case categoryID = "category_id"
    }
}

struct EPGListing: Codable, Identifiable {
    let id: String?
    let epgID: String?
    let title: String?
    let lang: String?
    let start: String?
    let end: String?
    let description: String?
    let startTimestamp: String?
    let stopTimestamp: String?
    var listID: String { id ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case id, title, lang, start, end, description
        case epgID = "epg_id"
        case startTimestamp = "start_timestamp"
        case stopTimestamp = "stop_timestamp"
    }
}

struct ShortEPGResponse: Codable {
    let epgListings: [EPGListing]?
    enum CodingKeys: String, CodingKey { case epgListings = "epg_listings" }
}
