import SwiftUI
import AVKit

private let brandGradient = LinearGradient(colors: [.cyan, .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { ContentBrowser(type: .live) }.tabItem { Label("Diretta", systemImage: "dot.radiowaves.left.and.right") }
            NavigationStack { ContentBrowser(type: .movies) }.tabItem { Label("Film", systemImage: "film.fill") }
            NavigationStack { ContentBrowser(type: .series) }.tabItem { Label("Serie", systemImage: "rectangle.stack.fill") }
            NavigationStack { SettingsView() }.tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }
        .tint(.purple)
    }
}

struct HomeView: View {
    @EnvironmentObject var session: AppSession
    private let posterColumns = [GridItem(.fixed(136), spacing: 14)]

    var featuredMovie: VODStream? { session.allMovies.first(where: { !($0.streamIcon ?? "").isEmpty }) ?? session.allMovies.first }
    var recentMovies: [VODStream] { Array(session.allMovies.sorted { ($0.added ?? "") > ($1.added ?? "") }.prefix(12)) }
    var recentSeries: [SeriesItem] { Array(session.allSeries.prefix(12)) }
    var livePreview: [LiveStream] { Array(session.allLive.filter { !($0.streamIcon ?? "").isEmpty }.prefix(10)) }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    topBar
                    hero
                    counters
                    quickActions
                    if !recentMovies.isEmpty { movieRail }
                    if !recentSeries.isEmpty { seriesRail }
                    if !livePreview.isEmpty { liveRail }
                    lastUpdate
                }
                .padding(.bottom, 28)
            }
            .refreshable { await session.refreshSafely() }

            if session.isRefreshing {
                Color.black.opacity(0.28).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView().scaleEffect(1.25).tint(.white)
                    Text("Aggiornamento playlist…").font(.headline).foregroundStyle(.white)
                }
                .padding(28)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Attenzione", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
    }

    private var topBar: some View {
        HStack(spacing: 13) {
            BrandMark(size: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text("ATLANTIX").font(.headline.weight(.black)).tracking(1.5)
                Text("Bentornato, \(session.username)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await session.refreshSafely() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = URL(string: featuredMovie?.streamIcon ?? "") {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { heroFallback }
                }
            } else { heroFallback }
            LinearGradient(colors: [.clear, .black.opacity(0.18), .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 9) {
                Text("IN EVIDENZA").font(.caption2.bold()).tracking(1.8).foregroundStyle(.cyan)
                Text(featuredMovie?.name ?? "Il tuo intrattenimento")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(featuredMovie?.plot ?? "Film, serie e dirette in un'unica esperienza.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                if let movie = featuredMovie {
                    NavigationLink { PlayerScreen(title: movie.name, url: session.streamURL(type: .movies, id: movie.streamID, ext: movie.containerExtension)) } label: {
                        Label("Riproduci", systemImage: "play.fill")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 17).padding(.vertical, 10)
                            .background(.white).foregroundStyle(.black).clipShape(Capsule())
                    }
                }
            }
            .padding(22)
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.08)))
        .padding(.horizontal, 20)
    }

    private var heroFallback: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.12), .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "play.rectangle.fill").font(.system(size: 80)).foregroundStyle(.white.opacity(0.18))
        }
    }

    private var counters: some View {
        HStack(spacing: 11) {
            stat("Canali", session.allLive.count, "tv.fill")
            stat("Film", session.allMovies.count, "film.fill")
            stat("Serie", session.allSeries.count, "rectangle.stack.fill")
        }
        .padding(.horizontal, 20)
    }

    private func stat(_ title: String, _ value: Int, _ icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.title3).foregroundStyle(brandGradient)
            Text(value.formatted()).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Esplora")
            HStack(spacing: 12) {
                quickLink("Diretta", "dot.radiowaves.left.and.right", .live)
                quickLink("Film", "film.fill", .movies)
                quickLink("Serie", "rectangle.stack.fill", .series)
            }
            .padding(.horizontal, 20)
        }
    }

    private func quickLink(_ title: String, _ icon: String, _ type: ContentType) -> some View {
        NavigationLink { ContentBrowser(type: type) } label: {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(.white)
                Text(title).font(.subheadline.bold()).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 19)
            .background(brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var movieRail: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Film aggiunti di recente")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: posterColumns, spacing: 14) {
                    ForEach(recentMovies) { item in
                        NavigationLink { PlayerScreen(title: item.name, url: session.streamURL(type: .movies, id: item.streamID, ext: item.containerExtension)) } label: {
                            PosterCard(title: item.name, imageURL: item.streamIcon, badge: item.rating).frame(width: 136)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 250)
        }
    }

    private var seriesRail: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Serie TV")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recentSeries) { item in
                        NavigationLink { SeriesPlaceholderView(item: item) } label: {
                            PosterCard(title: item.name, imageURL: item.cover, badge: item.rating).frame(width: 136)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var liveRail: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("In diretta")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 13) {
                    ForEach(livePreview) { item in
                        NavigationLink { PlayerScreen(title: item.name, url: session.streamURL(type: .live, id: item.streamID)) } label: {
                            PosterCard(title: item.name, imageURL: item.streamIcon, badge: "LIVE", landscape: true).frame(width: 190)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.title3.bold()).padding(.horizontal, 20)
    }

    private var lastUpdate: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Playlist aggiornata")
            Spacer()
            Text(session.lastRefresh?.formatted(date: .omitted, time: .shortened) ?? "—")
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 20)
    }
}

struct ContentBrowser: View {
    @EnvironmentObject var session: AppSession
    let type: ContentType
    var categories: [Category] { type == .live ? session.liveCategories : type == .movies ? session.movieCategories : session.seriesCategories }
    var title: String { type == .live ? "TV in diretta" : type == .movies ? "Film" : "Serie TV" }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                NavigationLink { ItemGrid(type: type, category: nil) } label: { categoryRow("Tutti i contenuti", "square.grid.2x2.fill") }
                ForEach(categories) { category in
                    NavigationLink { ItemGrid(type: type, category: category) } label: { categoryRow(category.categoryName, icon) }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await session.refreshSafely() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    private var icon: String { type == .live ? "tv.fill" : type == .movies ? "film.fill" : "rectangle.stack.fill" }
    private func categoryRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 15).fill(brandGradient); Image(systemName: icon).foregroundStyle(.white) }.frame(width: 52, height: 52)
            Text(title).font(.headline).foregroundStyle(.primary).lineLimit(2)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(14).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 21))
    }
}

struct ItemGrid: View {
    @EnvironmentObject var session: AppSession
    let type: ContentType
    let category: Category?
    @State private var live: [LiveStream] = []
    @State private var vod: [VODStream] = []
    @State private var series: [SeriesItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var search = ""
    let columns = [GridItem(.adaptive(minimum: 145), spacing: 14)]

    var body: some View {
        Group {
            if loading { ProgressView("Caricamento…") }
            else if let error { EmptyStateView(title: "Errore", icon: "wifi.exclamationmark", message: error) }
            else { ScrollView { LazyVGrid(columns: columns, spacing: 16) { contentCards }.padding() } }
        }
        .navigationTitle(category?.categoryName ?? "Tutti")
        .searchable(text: $search, prompt: "Cerca")
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder var contentCards: some View {
        if type == .live {
            ForEach(live.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                NavigationLink { PlayerScreen(title: item.name, url: session.streamURL(type: .live, id: item.streamID)) } label: { PosterCard(title: item.name, imageURL: item.streamIcon, badge: "LIVE", landscape: true) }
            }
        } else if type == .movies {
            ForEach(vod.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                NavigationLink { PlayerScreen(title: item.name, url: session.streamURL(type: .movies, id: item.streamID, ext: item.containerExtension)) } label: { PosterCard(title: item.name, imageURL: item.streamIcon, badge: item.rating) }
            }
        } else {
            ForEach(series.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                NavigationLink { SeriesPlaceholderView(item: item) } label: { PosterCard(title: item.name, imageURL: item.cover, badge: item.rating) }
            }
        }
    }

    func load() async {
        loading = true
        error = nil
        do {
            switch type {
            case .live: live = category == nil ? session.allLive : try await APIClient.shared.liveStreams(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID)
            case .movies: vod = category == nil ? session.allMovies : try await APIClient.shared.vodStreams(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID)
            case .series: series = category == nil ? session.allSeries : try await APIClient.shared.series(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID)
            }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PosterCard: View {
    let title: String
    let imageURL: String?
    let badge: String?
    var landscape = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else {
                        ZStack {
                            LinearGradient(colors: [.purple.opacity(0.65), .indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: landscape ? "tv.fill" : "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .frame(height: landscape ? 108 : 202)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .clipped()
                if let badge, !badge.isEmpty {
                    Text(badge).font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 5).background(.black.opacity(0.75)).foregroundStyle(.white).clipShape(Capsule()).padding(8)
                }
            }
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(.primary)
        }
    }
}

struct PlayerScreen: View {
    @EnvironmentObject var session: AppSession
    let title: String
    let url: URL?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .onAppear { if session.autoplay { player.play() } }
                    .onDisappear { player.pause() }
            } else {
                EmptyStateView(title: "Flusso non disponibile", icon: "play.slash", message: "Controlla il collegamento o riprova più tardi.")
                    .foregroundStyle(.white)
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .task { if let url { player = AVPlayer(url: url) } }
    }
}

struct SeriesPlaceholderView: View {
    let item: SeriesItem
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AsyncImage(url: URL(string: item.cover ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() } else { ProgressView() }
                }
                .frame(maxHeight: 420).clipShape(RoundedRectangle(cornerRadius: 24))
                Text(item.name).font(.title.bold())
                if let plot = item.plot { Text(plot).foregroundStyle(.secondary) }
                EmptyStateView(title: "Episodi", icon: "rectangle.stack", message: "La playlist ha fornito la serie. Il dettaglio di stagioni ed episodi verrà completato nel prossimo aggiornamento.")
            }
            .padding()
        }
        .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @State private var showLogout = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    BrandMark(size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.username).font(.headline)
                        Label(session.userInfo?.status ?? "—", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                        Text("Scadenza: \(expiry)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button { Task { await session.refreshSafely() } } label: {
                    Label(session.isRefreshing ? "Aggiornamento…" : "Aggiorna playlist", systemImage: "arrow.clockwise")
                }
                .disabled(session.isRefreshing)
                LabeledContent("Ultimo aggiornamento", value: session.lastRefresh?.formatted(date: .abbreviated, time: .shortened) ?? "—")
            } header: { Text("Account") }

            Section("Riproduzione") {
                Toggle("Riproduzione automatica", isOn: Binding(get: { session.autoplay }, set: { session.setAutoplay($0) }))
                Toggle("Aggiorna all'apertura", isOn: Binding(get: { session.refreshOnLaunch }, set: { session.setRefreshOnLaunch($0) }))
                Label("Picture in Picture", systemImage: "pip.fill")
                Label("AirPlay", systemImage: "airplayvideo")
            }

            Section("Aspetto") {
                Picker("Tema", selection: Binding(get: { session.appearance }, set: { session.setAppearance($0) })) {
                    Text("Automatico").tag("system")
                    Text("Chiaro").tag("light")
                    Text("Scuro").tag("dark")
                }
            }

            Section("Sicurezza") {
                Toggle("Controllo genitori", isOn: Binding(get: { session.parentalControl }, set: { session.setParentalControl($0) }))
                Toggle("Accesso automatico", isOn: Binding(get: { session.autoLogin }, set: { session.setAutoLogin($0) }))
            }

            Section("Archivio") {
                Button { URLCache.shared.removeAllCachedResponses() } label: { Label("Svuota cache immagini", systemImage: "trash") }
                LabeledContent("Canali", value: session.allLive.count.formatted())
                LabeledContent("Film", value: session.allMovies.count.formatted())
                LabeledContent("Serie", value: session.allSeries.count.formatted())
            }

            Section("Informazioni") {
                LabeledContent("Versione", value: "1.0 (Build 3)")
                Text("AtlantiX è un player multimediale e non include né vende contenuti.").font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Button("Esci dall'account", role: .destructive) { showLogout = true }
            }
        }
        .navigationTitle("Impostazioni")
        .confirmationDialog("Vuoi uscire dall'account?", isPresented: $showLogout) {
            Button("Esci", role: .destructive) { session.signOut() }
            Button("Annulla", role: .cancel) { }
        }
    }

    var expiry: String {
        guard let value = session.userInfo?.expDate, let seconds = TimeInterval(value) else { return "Illimitata" }
        return Date(timeIntervalSince1970: seconds).formatted(date: .abbreviated, time: .omitted)
    }
}

struct EmptyStateView: View {
    let title: String
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(30)
    }
}
