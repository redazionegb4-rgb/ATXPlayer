import SwiftUI
import Foundation

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var baseURL = ""
    @Published var username = ""
    @Published var password = ""
    @Published var userInfo: UserInfo?
    @Published var liveCategories: [Category] = []
    @Published var movieCategories: [Category] = []
    @Published var seriesCategories: [Category] = []
    @Published var allLive: [LiveStream] = []
    @Published var allMovies: [VODStream] = []
    @Published var allSeries: [SeriesItem] = []
    @Published var lastRefresh: Date?
    @Published var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "dark"
    @Published var autoLogin = UserDefaults.standard.bool(forKey: "autoLogin")
    @Published var refreshOnLaunch = UserDefaults.standard.object(forKey: "refreshOnLaunch") as? Bool ?? true
    @Published var autoplay = UserDefaults.standard.object(forKey: "autoplay") as? Bool ?? true
    @Published var parentalControl = UserDefaults.standard.bool(forKey: "parentalControl")

    var colorScheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }

    init() {
        if autoLogin, let u = KeychainStore.read("username"), let p = KeychainStore.read("password") {
            username = u
            password = p
            Task { await signIn() }
        }
    }

    func signIn() async {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            errorMessage = "Inserisci username e password."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let config = try await APIClient.shared.fetchConfig()
            guard config.enabled else { throw APIError.disabled(config.message) }
            let login = try await APIClient.shared.login(baseURL: config.dns, username: username, password: password)
            guard login.userInfo?.auth == 1, (login.userInfo?.status ?? "").lowercased() == "active" else { throw APIError.invalidCredentials }
            baseURL = config.dns.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            userInfo = login.userInfo
            KeychainStore.save(username, for: "username")
            KeychainStore.save(password, for: "password")
            try await reloadPlaylist()
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reloadPlaylist() async throws {
        isRefreshing = true
        defer { isRefreshing = false }
        async let a = APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .live)
        async let b = APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .movies)
        async let c = APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .series)
        async let d = APIClient.shared.liveStreams(baseURL: baseURL, username: username, password: password)
        async let e = APIClient.shared.vodStreams(baseURL: baseURL, username: username, password: password)
        async let f = APIClient.shared.series(baseURL: baseURL, username: username, password: password)
        (liveCategories, movieCategories, seriesCategories, allLive, allMovies, allSeries) = try await (a, b, c, d, e, f)
        lastRefresh = Date()
    }

    func refreshSafely() async {
        errorMessage = nil
        do { try await reloadPlaylist() }
        catch { errorMessage = error.localizedDescription }
    }

    func signOut() {
        isAuthenticated = false
        userInfo = nil
        liveCategories = []
        movieCategories = []
        seriesCategories = []
        allLive = []
        allMovies = []
        allSeries = []
        if !autoLogin {
            KeychainStore.delete("username")
            KeychainStore.delete("password")
        }
    }

    func setAppearance(_ value: String) { appearance = value; UserDefaults.standard.set(value, forKey: "appearance") }
    func setAutoLogin(_ value: Bool) { autoLogin = value; UserDefaults.standard.set(value, forKey: "autoLogin") }
    func setRefreshOnLaunch(_ value: Bool) { refreshOnLaunch = value; UserDefaults.standard.set(value, forKey: "refreshOnLaunch") }
    func setAutoplay(_ value: Bool) { autoplay = value; UserDefaults.standard.set(value, forKey: "autoplay") }
    func setParentalControl(_ value: Bool) { parentalControl = value; UserDefaults.standard.set(value, forKey: "parentalControl") }

    func streamURL(type: ContentType, id: Int, ext: String? = nil) -> URL? {
        let path: String
        switch type {
        case .live: path = "live/\(username)/\(password)/\(id).m3u8"
        case .movies: path = "movie/\(username)/\(password)/\(id).\(ext ?? "mp4")"
        case .series: path = "series/\(username)/\(password)/\(id).\(ext ?? "mp4")"
        }
        return URL(string: "\(baseURL)/\(path)")
    }
}
