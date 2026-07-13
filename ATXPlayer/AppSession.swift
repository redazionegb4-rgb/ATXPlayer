import SwiftUI
import Foundation



struct PlaybackProgress: Codable, Identifiable, Hashable {
    let id: String
    let ownerCode: String
    let kind: String
    let streamID: Int
    let title: String
    let subtitle: String?
    let imageURL: String?
    let fileExtension: String?
    var position: Double
    var duration: Double
    var updatedAt: Date

    var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }
}

struct PlaybackDescriptor: Hashable {
    let kind: ContentType
    let streamID: Int
    let title: String
    let subtitle: String?
    let imageURL: String?
    let fileExtension: String?

    var keyPart: String { "\(kind.rawValue):\(streamID)" }
}

private struct PlaylistCache: Codable {
    let liveCategories: [Category]
    let movieCategories: [Category]
    let seriesCategories: [Category]
    let allLive: [LiveStream]
    let allMovies: [VODStream]
    let allSeries: [SeriesItem]
    let lastRefresh: Date?
}

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var baseURL = ""
    @Published var accessCode = ""
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
    @Published var autoLogin = UserDefaults.standard.object(forKey: "autoLogin") as? Bool ?? true
    @Published var refreshOnLaunch = UserDefaults.standard.object(forKey: "refreshOnLaunch") as? Bool ?? false
    @Published var autoplay = UserDefaults.standard.object(forKey: "autoplay") as? Bool ?? true
    @Published var parentalControl = UserDefaults.standard.bool(forKey: "parentalControl")
    @Published private(set) var playbackProgress: [PlaybackProgress] = []

    var colorScheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }

    init() {
        let hasSession = UserDefaults.standard.bool(forKey: "hasSavedSession")
        loadPlaylistCache()
        loadPlaybackProgress()
        if hasSession, let code = KeychainStore.read("accessCode") {
            accessCode = code
            baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? ""
            isAuthenticated = true
            Task { await restoreSession() }
        }
    }

    private func restoreSession() async {
        do {
            let activation = try await APIClient.shared.activate(code: accessCode)
            guard let activatedUsername = activation.username, let activatedPassword = activation.password else {
                throw APIError.activation("Playlist non valida.")
            }
            username = activatedUsername
            password = activatedPassword
            let config = try await APIClient.shared.fetchConfig()
            guard config.enabled else { throw APIError.disabled(config.message) }
            baseURL = config.dns.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            UserDefaults.standard.set(baseURL, forKey: "baseURL")
            let login: LoginResponse
            do {
                login = try await APIClient.shared.login(baseURL: baseURL, username: username, password: password)
            } catch {
                throw APIError.activation("Playlist non valida.")
            }
            guard login.userInfo?.auth == 1, (login.userInfo?.status ?? "").lowercased() == "active" else {
                throw APIError.activation("Playlist non valida.")
            }
            userInfo = login.userInfo
            if refreshOnLaunch || (allLive.isEmpty && allMovies.isEmpty && allSeries.isEmpty) { await reloadPlaylist() }
        } catch {
            isAuthenticated = false
            errorMessage = error.localizedDescription
            UserDefaults.standard.set(false, forKey: "hasSavedSession")
        }
    }

    func signIn() async {
        let code = accessCode.filter(\.isNumber)
        guard code.count == 6 else {
            errorMessage = "Inserisci il codice di accesso di 6 cifre."
            return
        }
        accessCode = code
        isLoading = true
        errorMessage = nil
        do {
            let activation = try await APIClient.shared.activate(code: code)
            guard let activatedUsername = activation.username, let activatedPassword = activation.password else {
                throw APIError.activation("Playlist non valida.")
            }
            username = activatedUsername
            password = activatedPassword
            let config = try await APIClient.shared.fetchConfig()
            guard config.enabled else { throw APIError.disabled(config.message) }
            let login: LoginResponse
            do {
                login = try await APIClient.shared.login(baseURL: config.dns, username: username, password: password)
            } catch {
                // Il codice esiste nel pannello, ma le credenziali associate non
                // producono una playlist valida/raggiungibile dal dispositivo.
                throw APIError.activation("Playlist non valida.")
            }
            guard login.userInfo?.auth == 1, (login.userInfo?.status ?? "").lowercased() == "active" else {
                throw APIError.activation("Playlist non valida.")
            }
            baseURL = config.dns.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            UserDefaults.standard.set(baseURL, forKey: "baseURL")
            userInfo = login.userInfo
            KeychainStore.save(code, for: "accessCode")
            UserDefaults.standard.set(true, forKey: "hasSavedSession")
            UserDefaults.standard.set(true, forKey: "autoLogin")
            autoLogin = true
            isAuthenticated = true
            if allLive.isEmpty && allMovies.isEmpty && allSeries.isEmpty { await reloadPlaylist() }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reloadPlaylist() async {
        guard !baseURL.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var loadedSections = 0

        do { liveCategories = try await APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .live); loadedSections += 1 } catch { }
        do { movieCategories = try await APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .movies); loadedSections += 1 } catch { }
        do { seriesCategories = try await APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .series); loadedSections += 1 } catch { }
        do { allLive = try await APIClient.shared.liveStreams(baseURL: baseURL, username: username, password: password); loadedSections += 1 } catch { }
        do { allMovies = try await APIClient.shared.vodStreams(baseURL: baseURL, username: username, password: password); loadedSections += 1 } catch { }
        do { allSeries = try await APIClient.shared.series(baseURL: baseURL, username: username, password: password); loadedSections += 1 } catch { }

        if loadedSections > 0 {
            lastRefresh = Date()
            savePlaylistCache()
            errorMessage = nil
        } else {
            errorMessage = "Playlist non caricata. Tocca Aggiorna playlist e riprova."
        }
    }

    func reloadSection(_ type: ContentType) async {
        guard !baseURL.isEmpty else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        var loaded = false
        switch type {
        case .live:
            do { liveCategories = try await APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .live); loaded = true } catch { }
            do { allLive = try await APIClient.shared.liveStreams(baseURL: baseURL, username: username, password: password); loaded = true } catch { }
        case .movies:
            do { movieCategories = try await APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .movies); loaded = true } catch { }
            do { allMovies = try await APIClient.shared.vodStreams(baseURL: baseURL, username: username, password: password); loaded = true } catch { }
        case .series:
            do { seriesCategories = try await APIClient.shared.categories(baseURL: baseURL, username: username, password: password, type: .series); loaded = true } catch { }
            do { allSeries = try await APIClient.shared.series(baseURL: baseURL, username: username, password: password); loaded = true } catch { }
        }

        if loaded {
            lastRefresh = Date()
            savePlaylistCache()
        } else {
            errorMessage = "Impossibile aggiornare questa sezione. Riprova tra poco."
        }
    }

    func refreshSafely() async { errorMessage = nil; await reloadPlaylist() }

    func signOut() {
        isAuthenticated = false
        userInfo = nil
        liveCategories = []; movieCategories = []; seriesCategories = []
        allLive = []; allMovies = []; allSeries = []
        baseURL = ""
        UserDefaults.standard.set(false, forKey: "hasSavedSession")
        UserDefaults.standard.removeObject(forKey: "baseURL")
        try? FileManager.default.removeItem(at: cacheURL)
        KeychainStore.delete("accessCode")
        KeychainStore.delete("username")
        KeychainStore.delete("password")
        accessCode = ""; username = ""; password = ""
    }

    private var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("atlantix-playlist-cache.json")
    }

    private func savePlaylistCache() {
        let cache = PlaylistCache(liveCategories: liveCategories, movieCategories: movieCategories, seriesCategories: seriesCategories, allLive: allLive, allMovies: allMovies, allSeries: allSeries, lastRefresh: lastRefresh)
        if let data = try? JSONEncoder().encode(cache) { try? data.write(to: cacheURL, options: .atomic) }
    }

    private func loadPlaylistCache() {
        guard let data = try? Data(contentsOf: cacheURL), let cache = try? JSONDecoder().decode(PlaylistCache.self, from: data) else { return }
        liveCategories = cache.liveCategories
        movieCategories = cache.movieCategories
        seriesCategories = cache.seriesCategories
        allLive = cache.allLive
        allMovies = cache.allMovies
        allSeries = cache.allSeries
        lastRefresh = cache.lastRefresh
    }

    var continueWatching: [PlaybackProgress] {
        playbackProgress
            .filter { $0.ownerCode == accessCode && $0.position >= 20 && $0.duration > 0 && $0.fraction < 0.94 }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func savedProgress(for descriptor: PlaybackDescriptor) -> PlaybackProgress? {
        let key = playbackKey(for: descriptor)
        return playbackProgress.first { $0.id == key }
    }

    func recordProgress(for descriptor: PlaybackDescriptor, position: Double, duration: Double) {
        guard descriptor.kind != .live, position.isFinite, duration.isFinite, duration > 0 else { return }
        let key = playbackKey(for: descriptor)
        if position < 15 || position / duration >= 0.94 || duration - position < 75 {
            playbackProgress.removeAll { $0.id == key }
        } else if let index = playbackProgress.firstIndex(where: { $0.id == key }) {
            playbackProgress[index].position = position
            playbackProgress[index].duration = duration
            playbackProgress[index].updatedAt = Date()
        } else {
            playbackProgress.append(PlaybackProgress(
                id: key,
                ownerCode: accessCode,
                kind: descriptor.kind.rawValue,
                streamID: descriptor.streamID,
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                imageURL: descriptor.imageURL,
                fileExtension: descriptor.fileExtension,
                position: position,
                duration: duration,
                updatedAt: Date()
            ))
        }
        savePlaybackProgress()
    }

    func removeProgress(for descriptor: PlaybackDescriptor) {
        playbackProgress.removeAll { $0.id == playbackKey(for: descriptor) }
        savePlaybackProgress()
    }

    func descriptor(from progress: PlaybackProgress) -> PlaybackDescriptor? {
        guard let kind = ContentType(rawValue: progress.kind) else { return nil }
        return PlaybackDescriptor(kind: kind, streamID: progress.streamID, title: progress.title, subtitle: progress.subtitle, imageURL: progress.imageURL, fileExtension: progress.fileExtension)
    }

    private func playbackKey(for descriptor: PlaybackDescriptor) -> String {
        "\(accessCode):\(descriptor.keyPart)"
    }

    private var playbackProgressURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("atlantix-playback-progress.json")
    }

    private func loadPlaybackProgress() {
        guard let data = try? Data(contentsOf: playbackProgressURL),
              let values = try? JSONDecoder().decode([PlaybackProgress].self, from: data) else { return }
        playbackProgress = values
    }

    private func savePlaybackProgress() {
        guard let data = try? JSONEncoder().encode(playbackProgress) else { return }
        try? data.write(to: playbackProgressURL, options: .atomic)
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
