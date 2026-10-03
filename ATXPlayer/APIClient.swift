import Foundation

actor APIClient {
    static let shared = APIClient()
    private let configURL = URL(string: "https://3-cuo.icu/atxios/config.json")!
    private let remoteAccessURL = URL(string: "https://3-cuo.icu/atxremote/api.php")!

    func fetchConfig() async throws -> RemoteConfig {
        var request = URLRequest(url: configURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(RemoteConfig.self, from: data)
    }

    func remoteLine(deviceCode: String) async throws -> RemoteLineResponse {
        var components = URLComponents(url: remoteAccessURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "action", value: "device"), URLQueryItem(name: "code", value: deviceCode)]
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        do {
            let result = try JSONDecoder().decode(RemoteLineResponse.self, from: data)
            if !result.found { throw APIError.activation(result.message ?? "Nessuna linea associata a questo dispositivo.") }
            return result
        } catch let e as APIError { throw e }
        catch { throw APIError.invalidResponse }
    }

    func appMessages() async throws -> [ATXAppMessage] {
        var components = URLComponents(url: remoteAccessURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "action", value: "messages"), URLQueryItem(name: "platform", value: "ios")]
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(ATXMessagesResponse.self, from: data).messages
    }

    func login(baseURL: String, username: String, password: String) async throws -> LoginResponse {
        try await request(baseURL: baseURL, username: username, password: password, action: nil)
    }

    func categories(baseURL: String, username: String, password: String, type: ContentType) async throws -> [Category] {
        try await request(baseURL: baseURL, username: username, password: password, action: type.categoryAction)
    }

    func liveStreams(baseURL: String, username: String, password: String, categoryID: String? = nil) async throws -> [LiveStream] {
        try await request(baseURL: baseURL, username: username, password: password, action: "get_live_streams", categoryID: categoryID)
    }

    func vodStreams(baseURL: String, username: String, password: String, categoryID: String? = nil) async throws -> [VODStream] {
        try await request(baseURL: baseURL, username: username, password: password, action: "get_vod_streams", categoryID: categoryID)
    }

    func series(baseURL: String, username: String, password: String, categoryID: String? = nil) async throws -> [SeriesItem] {
        try await request(baseURL: baseURL, username: username, password: password, action: "get_series", categoryID: categoryID)
    }

    func shortEPG(baseURL: String, username: String, password: String, streamID: Int, limit: Int = 12) async throws -> [EPGListing] {
        let response: ShortEPGResponse = try await request(
            baseURL: baseURL,
            username: username,
            password: password,
            action: "get_short_epg",
            streamID: streamID,
            limit: limit
        )
        return response.epgListings ?? []
    }

    func seriesInfo(baseURL: String, username: String, password: String, seriesID: Int) async throws -> SeriesInfoResponse {
        try await request(baseURL: baseURL, username: username, password: password, action: "get_series_info", seriesID: seriesID)
    }

    func vodInfo(baseURL: String, username: String, password: String, vodID: Int) async throws -> VODInfoResponse {
        try await request(baseURL: baseURL, username: username, password: password, action: "get_vod_info", vodID: vodID)
    }

    private func request<T: Decodable>(baseURL: String, username: String, password: String, action: String?, categoryID: String? = nil, streamID: Int? = nil, seriesID: Int? = nil, vodID: Int? = nil, limit: Int? = nil) async throws -> T {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/player_api.php") else { throw APIError.invalidURL }
        var query = [URLQueryItem(name: "username", value: username), URLQueryItem(name: "password", value: password)]
        if let action { query.append(URLQueryItem(name: "action", value: action)) }
        if let categoryID { query.append(URLQueryItem(name: "category_id", value: categoryID)) }
        if let streamID { query.append(URLQueryItem(name: "stream_id", value: String(streamID))) }
        if let seriesID { query.append(URLQueryItem(name: "series_id", value: String(seriesID))) }
        if let vodID { query.append(URLQueryItem(name: "vod_id", value: String(vodID))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        components.queryItems = query
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.invalidResponse }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw APIError.serverUnavailable }
    }
}

enum ContentType: String, CaseIterable, Hashable {
    case live, movies, series
    var categoryAction: String {
        switch self { case .live: return "get_live_categories"; case .movies: return "get_vod_categories"; case .series: return "get_series_categories" }
    }
}

enum APIError: LocalizedError {
    case invalidURL, serverUnavailable, invalidResponse, disabled(String), invalidCredentials, activation(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Indirizzo del servizio non valido."
        case .serverUnavailable: return "Il servizio non è raggiungibile."
        case .invalidResponse: return "Risposta del server non valida."
        case .disabled(let message): return message.isEmpty ? "Servizio temporaneamente disattivato." : message
        case .invalidCredentials: return "Username o password non validi."
        case .activation(let message): return message
        }
    }
}

struct RemoteLineResponse: Codable { let found: Bool; let active: Bool; let username: String; let password: String; let message: String? }


struct ATXMessagesResponse: Codable { let messages: [ATXAppMessage] }
struct ATXAppMessage: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let kind: String
    let platform: String
    let active: Bool
    let start_at: String?
    let expires_at: String?
    let button_title: String?
    let button_url: String?
    let created_at: String?
    let updated_at: String?
}
