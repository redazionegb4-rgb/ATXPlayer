import Foundation

actor APIClient {
    static let shared = APIClient()
    private let configURL = URL(string: "https://3-cuo.icu/atxios/config.json")!
    private let activationURL = URL(string: "https://3-cuo.icu/atxios/panel/api/activate.php")!

    func fetchConfig() async throws -> RemoteConfig {
        var request = URLRequest(url: configURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(RemoteConfig.self, from: data)
    }

    func activate(code: String) async throws -> ActivationResponse {
        var request = URLRequest(url: activationURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverUnavailable }
        let decoded = try? JSONDecoder().decode(ActivationResponse.self, from: data)
        guard 200..<300 ~= http.statusCode else {
            throw APIError.activation(decoded?.message ?? "Codice non valido.")
        }
        guard let decoded, decoded.success, decoded.username != nil, decoded.password != nil else {
            throw APIError.activation(decoded?.message ?? "Risposta di attivazione non valida.")
        }
        return decoded
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

enum ContentType: String, CaseIterable {
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
