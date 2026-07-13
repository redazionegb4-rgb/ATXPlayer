import SwiftUI
import AVKit
import AVFoundation
import UIKit

private let brandGradient = LinearGradient(colors: [.cyan, .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
private let pageBackground = Color(uiColor: .systemBackground)

private func numericDateValue(_ value: String?) -> Double {
    guard let value, !value.isEmpty else { return 0 }
    if let number = Double(value) { return number }
    let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "dd-MM-yyyy", "dd/MM/yyyy"]
    for format in formats {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = format
        if let date = formatter.date(from: value) { return date.timeIntervalSince1970 }
    }
    return 0
}

private func seriesSortValue(_ item: SeriesItem) -> Double {
    max(numericDateValue(item.added), numericDateValue(item.lastModified), Double(item.num ?? 0))
}

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
    @State private var featuredIndex = 0
    @State private var showSearch = false
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    private var features: [FeaturedContent] {
        let movies = session.allMovies.filter { !($0.streamIcon ?? "").isEmpty }.prefix(25).map { FeaturedContent.movie($0) }
        let series = session.allSeries.filter { !($0.cover ?? "").isEmpty }.prefix(25).map { FeaturedContent.series($0) }
        return (Array(movies) + Array(series)).shuffled()
    }
    private var featured: FeaturedContent? { features.isEmpty ? nil : features[featuredIndex % features.count] }
    private var recentMovies: [VODStream] { Array(session.allMovies.sorted { numericDateValue($0.added) > numericDateValue($1.added) }.prefix(16)) }
    private var recentSeries: [SeriesItem] { Array(session.allSeries.sorted { seriesSortValue($0) > seriesSortValue($1) }.prefix(16)) }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .zIndex(20)
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        hero
                            .zIndex(0)
                        counters
                        quickActions
                        if !session.continueWatching.isEmpty { continueWatchingRail }
                        if !recentSeries.isEmpty { seriesRail }
                        if !recentMovies.isEmpty { movieRail }
                        updateStatus
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                }
                .refreshable { await session.refreshSafely() }
            }
            if session.isRefreshing { loadingOverlay.zIndex(50) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSearch) { NavigationStack { GlobalSearchView() } }
        .onReceive(timer) { _ in
            guard features.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.65)) { featuredIndex = (featuredIndex + 1) % features.count }
        }
        .alert("Attenzione", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            BrandMark(size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("ATLANTIX").font(.headline.weight(.black)).tracking(1.7)
                Text("Ciao, \(session.username)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            circleButton("magnifyingglass") { showSearch = true }
            circleButton("arrow.clockwise") { Task { await session.refreshSafely() } }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
        .contentShape(Rectangle())
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.headline.bold())
                .frame(width: 48, height: 48)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .zIndex(30)
    }

    @ViewBuilder private var hero: some View {
        if let featured {
            NavigationLink { featured.destination(session: session) } label: {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: featured.imageURL ?? "")) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { heroFallback }
                    }
                    .frame(maxWidth: .infinity).frame(height: 300).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.18), .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(featured.kind).font(.caption2.bold()).tracking(2).foregroundStyle(.cyan)
                        Text(featured.title).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                        Text(featured.subtitle).font(.caption).foregroundStyle(.white.opacity(0.78)).lineLimit(2)
                        Label("Apri dettaglio", systemImage: "play.circle.fill").font(.caption.bold()).foregroundStyle(.white).padding(.top, 3)
                    }.padding(22)
                }
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.primary.opacity(0.08)))
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        } else {
            heroFallback.frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 28)).padding(.horizontal, 20)
        }
    }

    private var heroFallback: some View {
        LinearGradient(colors: [.indigo, .purple, Color(red: 0.04, green: 0.05, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "play.circle.fill").font(.system(size: 82)).foregroundStyle(.white.opacity(0.2)))
    }

    private var counters: some View {
        HStack(spacing: 10) {
            stat("Canali", session.allLive.count, "tv.fill")
            stat("Film", session.allMovies.count, "film.fill")
            stat("Serie", session.allSeries.count, "rectangle.stack.fill")
        }.padding(.horizontal, 20)
    }

    private func stat(_ title: String, _ value: Int, _ icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.title3).foregroundStyle(brandGradient)
            Text(value.formatted()).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Color(uiColor: .secondarySystemBackground))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color.primary.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Esplora")
            HStack(spacing: 11) {
                quickLink("Diretta", "dot.radiowaves.left.and.right", .live)
                quickLink("Film", "film.fill", .movies)
                quickLink("Serie", "rectangle.stack.fill", .series)
            }.padding(.horizontal, 20)
        }
    }

    private func quickLink(_ title: String, _ icon: String, _ type: ContentType) -> some View {
        NavigationLink { ContentBrowser(type: type) } label: {
            VStack(spacing: 10) { Image(systemName: icon).font(.title2); Text(title).font(.subheadline.bold()) }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 19)
                .background(brandGradient).clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }.buttonStyle(.plain)
    }

    private var continueWatchingRail: some View {
        MediaRail(title: "Continua a guardare") {
            ForEach(session.continueWatching.prefix(12)) { progress in
                if let descriptor = session.descriptor(from: progress) {
                    NavigationLink {
                        PlayerScreen(
                            title: descriptor.title,
                            url: session.streamURL(type: descriptor.kind, id: descriptor.streamID, ext: descriptor.fileExtension),
                            isLive: false,
                            resume: descriptor
                        )
                    } label: {
                        ContinueWatchingCard(progress: progress)
                            .frame(width: 230)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var movieRail: some View {
        MediaRail(title: "Ultimi film aggiunti") {
            ForEach(recentMovies) { item in
                NavigationLink { MovieDetailView(item: item) } label: { PosterCard(title: item.name, imageURL: item.streamIcon, badge: item.rating).frame(width: 138) }
            }
        }
    }

    private var seriesRail: some View {
        MediaRail(title: "Ultime serie TV aggiunte") {
            ForEach(recentSeries) { item in
                NavigationLink { SeriesDetailView(item: item) } label: { PosterCard(title: item.name, imageURL: item.cover, badge: item.rating).frame(width: 138) }
            }
        }
    }

    private var updateStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Playlist aggiornata").foregroundStyle(.secondary); Spacer()
            Text(session.lastRefresh?.formatted(date: .omitted, time: .shortened) ?? "—").foregroundStyle(.secondary)
        }.font(.caption).padding(.horizontal, 22)
    }

    private func sectionTitle(_ title: String) -> some View { Text(title).font(.title3.bold()).padding(.horizontal, 20) }
    private var loadingOverlay: some View {
        Color.black.opacity(0.42).ignoresSafeArea().overlay(
            VStack(spacing: 14) { ProgressView().scaleEffect(1.25).tint(.white); Text("Aggiornamento playlist…").font(.headline).foregroundStyle(.primary) }
                .padding(26).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        )
    }
}

private enum FeaturedContent {
    case movie(VODStream), series(SeriesItem)
    var title: String { switch self { case .movie(let x): return x.name; case .series(let x): return x.name } }
    var imageURL: String? { switch self { case .movie(let x): return x.streamIcon; case .series(let x): return x.cover } }
    var subtitle: String { switch self { case .movie(let x): return x.plot ?? "Guarda questo film"; case .series(let x): return x.plot ?? "Scopri questa serie TV" } }
    var kind: String { switch self { case .movie: return "FILM IN EVIDENZA"; case .series: return "SERIE IN EVIDENZA" } }
    @ViewBuilder func destination(session: AppSession) -> some View { switch self { case .movie(let x): MovieDetailView(item: x); case .series(let x): SeriesDetailView(item: x) } }
}

struct MediaRail<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.title3.bold()).foregroundStyle(.primary).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) { LazyHStack(spacing: 14) { content }.padding(.horizontal, 20) }
        }
    }
}

struct ContentBrowser: View {
    @EnvironmentObject var session: AppSession
    let type: ContentType
    @State private var search = ""

    private var categories: [Category] { type == .live ? session.liveCategories : type == .movies ? session.movieCategories : session.seriesCategories }
    private var title: String { type == .live ? "TV in diretta" : type == .movies ? "Film" : "Serie TV" }
    private var subtitle: String { type == .live ? "Canali e programmi live" : type == .movies ? "Sfoglia il catalogo dei film" : "Stagioni ed episodi" }
    private var filtered: [Category] { search.isEmpty ? categories : categories.filter { $0.categoryName.localizedCaseInsensitiveContains(search) } }
    private var icon: String { type == .live ? "dot.radiowaves.left.and.right" : type == .movies ? "film.fill" : "rectangle.stack.fill" }
    private var totalCount: Int { type == .live ? session.allLive.count : type == .movies ? session.allMovies.count : session.allSeries.count }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                browserHeader
                searchField
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink { ItemGrid(type: type, category: nil) } label: {
                            categoryTile("Tutti", "square.grid.2x2.fill", totalCount, featured: true)
                        }
                        ForEach(filtered) { category in
                            NavigationLink { ItemGrid(type: type, category: category) } label: {
                                categoryTile(category.categoryName, icon, count(for: category), featured: false)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var browserHeader: some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 18).fill(brandGradient); Image(systemName: icon).font(.title2.bold()).foregroundStyle(.white) }
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 27, weight: .bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                Text("\(totalCount.formatted()) contenuti").font(.caption.bold()).foregroundStyle(.purple)
            }
            Spacer()
            Button { Task { await session.refreshSafely() } } label: {
                Image(systemName: "arrow.clockwise").font(.headline.bold()).frame(width: 46, height: 46)
                    .background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Cerca una categoria", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } }
        }
        .padding(.horizontal, 16).frame(height: 50)
        .background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.primary.opacity(0.06)))
        .padding(.horizontal, 16)
    }

    private func count(for category: Category) -> Int {
        switch type {
        case .live: return session.allLive.filter { $0.categoryID == category.categoryID }.count
        case .movies: return session.allMovies.filter { $0.categoryID == category.categoryID }.count
        case .series: return session.allSeries.filter { $0.categoryID == category.categoryID }.count
        }
    }

    private func categoryTile(_ title: String, _ icon: String, _ count: Int, featured: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack { RoundedRectangle(cornerRadius: 14).fill(featured ? brandGradient : LinearGradient(colors: [.purple.opacity(0.85), .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)); Image(systemName: icon).foregroundStyle(.white) }
                    .frame(width: 46, height: 46)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
            Text(title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
            Text("\(count.formatted()) contenuti").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.primary.opacity(0.06)))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ItemGrid: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let type: ContentType
    let category: Category?
    @State private var live: [LiveStream] = []
    @State private var vod: [VODStream] = []
    @State private var series: [SeriesItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var search = ""
    @State private var newestFirst = true
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                itemHeader
                inlineSearch
                if type != .live { sortControl }
                Group {
                    if loading { Spacer(); ProgressView("Caricamento…"); Spacer() }
                    else if let error { Spacer(); EmptyStateView(title: "Errore", icon: "wifi.exclamationmark", message: error); Spacer() }
                    else if resultCount == 0 { Spacer(); EmptyStateView(title: "Nessun risultato", icon: "magnifyingglass", message: "Prova con un altro termine di ricerca."); Spacer() }
                    else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: 18) { contentCards }
                                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 125)
                        }
                        .refreshable { await load(forceNetwork: true) }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load(forceNetwork: false) }
    }

    private var itemHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3.bold()).frame(width: 46, height: 46)
                    .background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle())
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(category?.categoryName ?? "Tutti i contenuti").font(.headline.bold()).lineLimit(1)
                Text("\(resultCount.formatted()) risultati").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: type == .live ? "dot.radiowaves.left.and.right" : type == .movies ? "film.fill" : "rectangle.stack.fill")
                .foregroundStyle(brandGradient).font(.title3)
        }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
    }

    private var inlineSearch: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Cerca in questa categoria", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } }
        }
        .padding(.horizontal, 16).frame(height: 50)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.primary.opacity(0.06)))
        .padding(.horizontal, 16)
    }

    private var sortControl: some View {
        HStack {
            Label("Ordina per aggiunta", systemImage: "arrow.up.arrow.down")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Menu {
                Button { newestFirst = true } label: {
                    Label("Ultimi aggiunti", systemImage: newestFirst ? "checkmark" : "clock.arrow.circlepath")
                }
                Button { newestFirst = false } label: {
                    Label("Meno recenti", systemImage: !newestFirst ? "checkmark" : "clock")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(newestFirst ? "Ultimi aggiunti" : "Meno recenti")
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(.purple)
            }
        }
        .padding(.horizontal, 18).padding(.top, 12)
    }

    private var resultCount: Int {
        if type == .live { return live.filter(matchLive).count }
        if type == .movies { return vod.filter(matchMovie).count }
        return series.filter(matchSeries).count
    }

    @ViewBuilder private var contentCards: some View {
        if type == .live {
            ForEach(live.filter(matchLive)) { item in
                NavigationLink { LiveDetailView(item: item) } label: { LiveChannelCard(item: item) }.buttonStyle(.plain)
            }
        } else if type == .movies {
            ForEach(vod.filter(matchMovie).sorted { newestFirst ? numericDateValue($0.added) > numericDateValue($1.added) : numericDateValue($0.added) < numericDateValue($1.added) }) { item in
                NavigationLink { MovieDetailView(item: item) } label: { ModernPosterCard(title: item.name, imageURL: item.streamIcon, badge: item.rating, typeLabel: "FILM") }.buttonStyle(.plain)
            }
        } else {
            ForEach(series.filter(matchSeries).sorted { newestFirst ? seriesSortValue($0) > seriesSortValue($1) : seriesSortValue($0) < seriesSortValue($1) }) { item in
                NavigationLink { SeriesDetailView(item: item) } label: { ModernPosterCard(title: item.name, imageURL: item.cover, badge: item.rating, typeLabel: "SERIE") }.buttonStyle(.plain)
            }
        }
    }

    private func matchLive(_ x: LiveStream) -> Bool { search.isEmpty || x.name.localizedCaseInsensitiveContains(search) }
    private func matchMovie(_ x: VODStream) -> Bool { search.isEmpty || x.name.localizedCaseInsensitiveContains(search) || (x.genre ?? "").localizedCaseInsensitiveContains(search) }
    private func matchSeries(_ x: SeriesItem) -> Bool { search.isEmpty || x.name.localizedCaseInsensitiveContains(search) || (x.genre ?? "").localizedCaseInsensitiveContains(search) }

    private func load(forceNetwork: Bool) async {
        loading = true; error = nil
        do {
            switch type {
            case .live:
                live = category == nil ? session.allLive : session.allLive.filter { $0.categoryID == category?.categoryID }
                if forceNetwork || live.isEmpty { live = try await APIClient.shared.liveStreams(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID) }
            case .movies:
                vod = category == nil ? session.allMovies : session.allMovies.filter { $0.categoryID == category?.categoryID }
                if forceNetwork || vod.isEmpty { vod = try await APIClient.shared.vodStreams(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID) }
            case .series:
                series = category == nil ? session.allSeries : session.allSeries.filter { $0.categoryID == category?.categoryID }
                if forceNetwork || series.isEmpty { series = try await APIClient.shared.series(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID) }
            }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct ModernPosterCard: View {
    let title: String
    let imageURL: String?
    let badge: String?
    let typeLabel: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { ZStack { brandGradient; Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8)) } }
                }
                .frame(maxWidth: .infinity).aspectRatio(0.68, contentMode: .fit).clipped()
                if let badge, !badge.isEmpty { Text(badge).font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5).background(.black.opacity(0.72)).clipShape(Capsule()).padding(8) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(typeLabel).font(.caption2.bold()).foregroundStyle(.purple)
            Text(title).font(.subheadline.bold()).lineLimit(2).multilineTextAlignment(.leading)
        }
    }
}

struct LiveChannelCard: View {
    let item: LiveStream
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                AsyncImage(url: URL(string: item.streamIcon ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFit().padding(16) }
                    else { Image(systemName: "tv.fill").font(.system(size: 42)).foregroundStyle(brandGradient) }
                }
            }
            .frame(maxWidth: .infinity).aspectRatio(1.35, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) { Text("LIVE").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5).background(.red).clipShape(Capsule()).padding(8) }
            Text(item.name).font(.subheadline.bold()).lineLimit(2).multilineTextAlignment(.leading)
        }
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
                    else { ZStack { brandGradient; Image(systemName: landscape ? "tv.fill" : "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.75)) } }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(landscape ? 1.45 : 0.70, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).clipped()
                if let badge, !badge.isEmpty {
                    Text(badge).font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.black.opacity(0.78)).foregroundStyle(.white).clipShape(Capsule()).padding(8)
                }
            }
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
    }
}

struct ContinueWatchingCard: View {
    let progress: PlaybackProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: progress.imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { ZStack { brandGradient; Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8)) } }
                }
                .frame(width: 230, height: 130)
                .clipped()

                VStack(spacing: 0) {
                    Spacer()
                    ProgressView(value: progress.fraction)
                        .tint(.purple)
                        .background(Color.white.opacity(0.25))
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(progress.title).font(.subheadline.bold()).lineLimit(1).foregroundStyle(.primary)
            HStack {
                Text(progress.subtitle ?? "Riprendi la visione").lineLimit(1)
                Spacer()
                Text(formatTime(progress.position))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}

struct MovieDetailView: View {
    @EnvironmentObject var session: AppSession
    let item: VODStream
    @State private var details: VODInfoResponse?
    @State private var loadingInfo = true

    private var info: VODDetails? { details?.info }
    private var metadata: [String] {
        [info?.genre ?? item.genre, info?.releaseDate ?? item.releaseDate, info?.duration ?? item.duration, (info?.rating ?? item.rating).map { "★ \($0)" }].compactMap { value in
            guard let value, !value.isEmpty else { return nil }; return value
        }
    }

    var body: some View {
        MediaDetailLayout(
            title: info?.name ?? item.name,
            imageURL: info?.movieImage ?? item.streamIcon,
            plot: info?.plot ?? item.plot,
            metadata: metadata,
            extraInfo: [
                ("Regia", info?.director ?? item.director),
                ("Cast", info?.cast ?? item.cast)
            ]
        ) {
            let movieID = details?.movieData?.streamID ?? item.streamID
            let movieExt = details?.movieData?.containerExtension ?? item.containerExtension
            let descriptor = PlaybackDescriptor(
                kind: .movies,
                streamID: movieID,
                title: info?.name ?? item.name,
                subtitle: "Film",
                imageURL: info?.movieImage ?? item.streamIcon,
                fileExtension: movieExt
            )
            NavigationLink {
                PlayerScreen(
                    title: info?.name ?? item.name,
                    url: session.streamURL(type: .movies, id: movieID, ext: movieExt),
                    isLive: false,
                    resume: descriptor
                )
            } label: {
                playButton(session.savedProgress(for: descriptor) == nil ? "Guarda film" : "Riprendi film")
            }
        }
        .overlay(alignment: .topTrailing) {
            if loadingInfo { ProgressView().tint(.white).padding(22) }
        }
        .task {
            details = try? await APIClient.shared.vodInfo(baseURL: session.baseURL, username: session.username, password: session.password, vodID: item.streamID)
            loadingInfo = false
        }
    }
}

struct LiveDetailView: View {
    @EnvironmentObject var session: AppSession
    let item: LiveStream
    @State private var epg: [EPGListing] = []
    @State private var loadingEPG = true
    @State private var epgError: String?

    private var currentProgram: EPGListing? {
        let now = Date().timeIntervalSince1970
        return epg.first { listing in
            guard let start = listing.startTimestamp.flatMap(TimeInterval.init),
                  let stop = listing.stopTimestamp.flatMap(TimeInterval.init) else { return false }
            return start <= now && now < stop
        } ?? epg.first
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    liveHero
                    NavigationLink {
                        PlayerScreen(title: item.name, url: directURL, isLive: true)
                    } label: {
                        playButton("Guarda in diretta")
                    }

                    Text("Guida TV").font(.title2.bold()).foregroundStyle(.primary)
                    epgSection
                }
                .padding(18)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEPG() }
    }

    private var liveHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            AsyncImage(url: URL(string: item.streamIcon ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit().padding(22)
                } else {
                    ZStack { brandGradient; Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 54)).foregroundStyle(.white) }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            Text(item.name).font(.title.bold()).foregroundStyle(.primary)
            if let program = currentProgram {
                VStack(alignment: .leading, spacing: 6) {
                    Label("IN ONDA", systemImage: "livephoto").font(.caption.bold()).foregroundStyle(.purple)
                    Text(program.title ?? "Programma in corso").font(.title3.bold()).foregroundStyle(.primary)
                    Text(timeRange(program)).font(.subheadline).foregroundStyle(.secondary)
                    if let description = program.description, !description.isEmpty {
                        Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
                    }
                }
            }
        }
    }

    @ViewBuilder private var epgSection: some View {
        if loadingEPG {
            HStack { Spacer(); ProgressView("Caricamento programmazione…"); Spacer() }.padding(.vertical, 28)
        } else if let epgError {
            EmptyStateView(title: "EPG non disponibile", icon: "calendar.badge.exclamationmark", message: epgError)
        } else if epg.isEmpty {
            EmptyStateView(title: "Nessuna programmazione", icon: "calendar", message: "Il server non ha fornito la guida TV per questo canale.")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(epg, id: \.listID) { program in
                    EPGProgramRow(program: program, isCurrent: program.listID == currentProgram?.listID)
                }
            }
        }
    }

    private func loadEPG() async {
        loadingEPG = true
        epgError = nil
        do {
            epg = try await APIClient.shared.shortEPG(
                baseURL: session.baseURL,
                username: session.username,
                password: session.password,
                streamID: item.streamID,
                limit: 12
            )
        } catch {
            epgError = error.localizedDescription
        }
        loadingEPG = false
    }

    private func timeRange(_ program: EPGListing) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let start = program.startTimestamp.flatMap(TimeInterval.init),
           let stop = program.stopTimestamp.flatMap(TimeInterval.init) {
            return "\(formatter.string(from: Date(timeIntervalSince1970: start))) – \(formatter.string(from: Date(timeIntervalSince1970: stop)))"
        }
        return [program.start, program.end].compactMap { $0 }.joined(separator: " – ")
    }

    private var directURL: URL? {
        if let source = item.directSource, !source.isEmpty { return URL(string: source) }
        return session.streamURL(type: .live, id: item.streamID)
    }
}

struct EPGProgramRow: View {
    let program: EPGListing
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 3) {
                Text(startTime).font(.headline.monospacedDigit()).foregroundStyle(isCurrent ? .purple : .primary)
                Text(endTime).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(width: 54, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(isCurrent ? Color.purple : Color.secondary.opacity(0.25))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(program.title ?? "Programma").font(.headline).foregroundStyle(.primary).lineLimit(2)
                    Spacer()
                    if isCurrent { Text("ORA").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.purple).clipShape(Capsule()) }
                }
                if let description = program.description, !description.isEmpty {
                    Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isCurrent ? Color.purple.opacity(0.45) : Color.primary.opacity(0.05)))
    }

    private var startTime: String { format(program.startTimestamp, fallback: program.start) }
    private var endTime: String { format(program.stopTimestamp, fallback: program.end) }

    private func format(_ timestamp: String?, fallback: String?) -> String {
        if let timestamp, let seconds = TimeInterval(timestamp) {
            let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
            return formatter.string(from: Date(timeIntervalSince1970: seconds))
        }
        guard let fallback else { return "--:--" }
        if fallback.count >= 16 { return String(fallback.dropFirst(11).prefix(5)) }
        return fallback
    }
}

struct SeriesDetailView: View {
    @EnvironmentObject var session: AppSession
    let item: SeriesItem
    @State private var info: SeriesInfoResponse?
    @State private var selectedSeason = ""
    @State private var loading = true
    @State private var error: String?

    private var seasons: [String] { (info?.episodes.keys.map { $0 } ?? []).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) } }
    private var episodes: [Episode] { info?.episodes[selectedSeason] ?? [] }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SeriesHeader(item: item, details: info?.info)
                    if loading { ProgressView("Caricamento stagioni…").tint(.white).frame(maxWidth: .infinity).padding(30) }
                    else if let error { EmptyStateView(title: "Episodi non disponibili", icon: "rectangle.stack.badge.exclamationmark", message: error) }
                    else if seasons.isEmpty { EmptyStateView(title: "Nessun episodio", icon: "rectangle.stack", message: "Il server non ha restituito stagioni o episodi per questa serie.") }
                    else {
                        seasonSelector
                        HStack {
                            Text("Episodi")
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(episodes.count) disponibili")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        LazyVStack(spacing: 14) {
                            ForEach(episodes) { episode in
                                let descriptor = PlaybackDescriptor(
                                    kind: .series,
                                    streamID: episode.id,
                                    title: episode.title,
                                    subtitle: "\(item.name) • S\(selectedSeason) E\(episode.episodeNum)",
                                    imageURL: episode.info?.movieImage ?? item.cover,
                                    fileExtension: episode.containerExtension
                                )
                                NavigationLink {
                                    PlayerScreen(
                                        title: episode.title,
                                        url: session.streamURL(type: .series, id: episode.id, ext: episode.containerExtension),
                                        isLive: false,
                                        resume: descriptor
                                    )
                                } label: {
                                    EpisodeRow(episode: episode, fallbackImage: item.cover, progress: session.savedProgress(for: descriptor))
                                }
                            }
                        }.padding(.horizontal)
                    }
                }.padding(.bottom, 100)
            }
        }
        .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }


    private var seasonSelector: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("STAGIONE SELEZIONATA")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.1)
                Text("Stagione \(selectedSeason)")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }

            Spacer()

            Menu {
                ForEach(seasons, id: \.self) { season in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSeason = season
                        }
                    } label: {
                        if season == selectedSeason {
                            Label("Stagione \(season)", systemImage: "checkmark")
                        } else {
                            Text("Stagione \(season)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.fill")
                    Text("Cambia")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.bold())
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [Color.cyan, Color.purple, Color.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func load() async {
        loading = true; error = nil
        do {
            info = try await APIClient.shared.seriesInfo(baseURL: session.baseURL, username: session.username, password: session.password, seriesID: item.seriesID)
            selectedSeason = seasons.first ?? ""
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct SeriesHeader: View {
    let item: SeriesItem
    let details: SeriesDetails?

    private var title: String { details?.name ?? item.name }
    private var cover: String? { details?.cover ?? item.cover }
    private var genre: String? { details?.genre ?? item.genre }
    private var plot: String? { details?.plot ?? item.plot }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                AsyncImage(url: URL(string: cover ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack {
                            brandGradient
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .frame(width: 142, height: 214)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .clipped()
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

                VStack(alignment: .leading, spacing: 11) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                        .minimumScaleFactor(0.78)

                    if let genre, !genre.isEmpty {
                        Label(genre, systemImage: "theatermasks.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.purple)
                            .lineLimit(3)
                    }

                    if let releaseDate = details?.releaseDate ?? item.releaseDate, !releaseDate.isEmpty {
                        Label(releaseDate, systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let rating = details?.rating ?? item.rating, !rating.isEmpty {
                        Label("★ \(rating)", systemImage: "star.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 214, alignment: .topLeading)
            }

            if let plot, !plot.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trama")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(plot)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let fallbackImage: String?
    let progress: PlaybackProgress?
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: episode.info?.movieImage ?? fallbackImage ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { ZStack { brandGradient; Image(systemName: "play.fill").foregroundStyle(.primary) } }
            }.frame(width: 126, height: 76).clipShape(RoundedRectangle(cornerRadius: 14)).clipped()
            VStack(alignment: .leading, spacing: 5) {
                Text("Episodio \(episode.episodeNum)").font(.caption.bold()).foregroundStyle(.purple)
                Text(episode.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                if let duration = episode.info?.duration { Text(duration).font(.caption).foregroundStyle(.secondary) }
                if let progress {
                    ProgressView(value: progress.fraction).tint(.purple)
                    Text("Riprendi da \(formatTime(progress.position))").font(.caption2).foregroundStyle(.purple)
                }
            }; Spacer(); Image(systemName: progress == nil ? "play.circle.fill" : "arrow.clockwise.circle.fill").font(.title2).foregroundStyle(.primary)
        }.padding(12).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct MediaDetailLayout<Action: View>: View {
    let title: String
    let imageURL: String?
    let plot: String?
    let metadata: [String]
    let extraInfo: [(String, String?)]
    @ViewBuilder let action: Action

    init(title: String, imageURL: String?, plot: String?, metadata: [String], extraInfo: [(String, String?)] = [], @ViewBuilder action: () -> Action) {
        self.title = title
        self.imageURL = imageURL
        self.plot = plot
        self.metadata = metadata
        self.extraInfo = extraInfo
        self.action = action()
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 16) {
                        AsyncImage(url: URL(string: imageURL ?? "")) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                ZStack {
                                    brandGradient
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 44, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                        }
                        .frame(width: 142, height: 214)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .clipped()
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

                        VStack(alignment: .leading, spacing: 11) {
                            Text(title)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(4)
                                .minimumScaleFactor(0.78)

                            ForEach(Array(metadata.enumerated()), id: \.offset) { _, value in
                                Text(value)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.purple)
                                    .lineLimit(3)
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 214, alignment: .topLeading)
                    }

                    action

                    if let plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trama")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Text(plot)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                    }

                    ForEach(extraInfo.filter { !($0.1 ?? "").isEmpty }, id: \.0) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.0)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(entry.1 ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func playButton(_ title: String) -> some View {
    Label(title, systemImage: "play.fill").font(.headline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(brandGradient).clipShape(RoundedRectangle(cornerRadius: 18))
}

struct NativePlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var pictureInPictureActive: Bool

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        @Binding var pictureInPictureActive: Bool

        init(pictureInPictureActive: Binding<Bool>) {
            _pictureInPictureActive = pictureInPictureActive
        }

        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            pictureInPictureActive = true
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            pictureInPictureActive = false
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            completionHandler(true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(pictureInPictureActive: $pictureInPictureActive)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = AVPictureInPictureController.isPictureInPictureSupported()
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.updatesNowPlayingInfoCenter = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
        controller.allowsPictureInPicturePlayback = AVPictureInPictureController.isPictureInPictureSupported()
        controller.canStartPictureInPictureAutomaticallyFromInline = true
    }
}

struct PlayerScreen: View {
    @EnvironmentObject var session: AppSession
    let title: String
    let url: URL?
    let isLive: Bool
    var resume: PlaybackDescriptor? = nil

    @State private var player: AVPlayer?
    @State private var failed = false
    @State private var pictureInPictureActive = false
    @State private var showResumePrompt = false
    @State private var pendingResumePosition: Double = 0
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                NativePlayerController(player: player, pictureInPictureActive: $pictureInPictureActive)
                    .ignoresSafeArea(edges: .bottom)
            } else if failed || url == nil {
                EmptyStateView(title: "Riproduzione non disponibile", icon: "play.slash", message: "Il flusso potrebbe essere offline o in un formato non supportato.").foregroundStyle(.primary)
            } else {
                ProgressView("Apertura player…").tint(.white).foregroundStyle(.primary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Riprendere la visione?", isPresented: $showResumePrompt) {
            Button("Ricomincia") {
                player?.seek(to: .zero)
                player?.play()
            }
            Button("Riprendi da \(formatTime(pendingResumePosition))") {
                let target = CMTime(seconds: pendingResumePosition, preferredTimescale: 600)
                player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in player?.play() }
            }
        } message: {
            Text("Hai già iniziato questo contenuto.")
        }
        .task { configurePlayer() }
        .onDisappear { closePlayerIfNeeded() }
    }

    private func configurePlayer() {
        guard player == nil else { return }
        guard let url else { failed = true; return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try audioSession.setActive(true)
        } catch { }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        installObservers(on: newPlayer, item: item)

        if !isLive, let resume, let saved = session.savedProgress(for: resume), saved.position >= 20 {
            pendingResumePosition = saved.position
            showResumePrompt = true
        } else {
            newPlayer.play()
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if item.status == .failed {
                failed = true
                newPlayer.pause()
                player = nil
            }
        }
    }

    private func installObservers(on player: AVPlayer, item: AVPlayerItem) {
        guard !isLive, let resume else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { time in
            let position = time.seconds
            let duration = item.duration.seconds
            session.recordProgress(for: resume, position: position, duration: duration)
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            session.removeProgress(for: resume)
        }
    }

    private func closePlayerIfNeeded() {
        guard !pictureInPictureActive else { return }
        if let resume, let player {
            session.recordProgress(for: resume, position: player.currentTime().seconds, duration: player.currentItem?.duration.seconds ?? 0)
        }
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player?.pause()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}

struct GlobalSearchView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    private var movies: [VODStream] { search.isEmpty ? [] : Array(session.allMovies.filter { $0.name.localizedCaseInsensitiveContains(search) }.prefix(30)) }
    private var series: [SeriesItem] { search.isEmpty ? [] : Array(session.allSeries.filter { $0.name.localizedCaseInsensitiveContains(search) }.prefix(30)) }
    private var live: [LiveStream] { search.isEmpty ? [] : Array(session.allLive.filter { $0.name.localizedCaseInsensitiveContains(search) }.prefix(30)) }
    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if search.isEmpty { EmptyStateView(title: "Ricerca globale", icon: "magnifyingglass", message: "Cerca contemporaneamente tra canali, film e serie TV.") }
                    if !movies.isEmpty { resultSection("Film", movies) { MovieDetailView(item: $0) } }
                    if !series.isEmpty { resultSection("Serie TV", series) { SeriesDetailView(item: $0) } }
                    if !live.isEmpty { resultSection("Canali", live) { LiveDetailView(item: $0) } }
                    if !search.isEmpty && movies.isEmpty && series.isEmpty && live.isEmpty { EmptyStateView(title: "Nessun risultato", icon: "magnifyingglass", message: "Non abbiamo trovato contenuti con questo nome.") }
                }.padding(.bottom, 40)
            }
        }
        .navigationTitle("Cerca").navigationBarTitleDisplayMode(.inline).searchable(text: $search, prompt: "Film, serie o canale")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
    }
    private func resultSection<T: Identifiable, Destination: View>(_ title: String, _ items: [T], @ViewBuilder destination: @escaping (T) -> Destination) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold()).foregroundStyle(.primary).padding(.horizontal)
            ForEach(items) { item in
                NavigationLink { destination(item) } label: { SearchResultRow(title: titleFor(item), subtitle: title, imageURL: imageFor(item)) }
            }
        }
    }
    private func titleFor<T>(_ item: T) -> String { if let x = item as? VODStream { return x.name }; if let x = item as? SeriesItem { return x.name }; if let x = item as? LiveStream { return x.name }; return "Contenuto" }
    private func imageFor<T>(_ item: T) -> String? { if let x = item as? VODStream { return x.streamIcon }; if let x = item as? SeriesItem { return x.cover }; if let x = item as? LiveStream { return x.streamIcon }; return nil }
}

struct SearchResultRow: View {
    let title: String; let subtitle: String; let imageURL: String?
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: imageURL ?? "")) { phase in if let image = phase.image { image.resizable().scaledToFill() } else { brandGradient } }
                .frame(width: 70, height: 70).clipShape(RoundedRectangle(cornerRadius: 14)).clipped()
            VStack(alignment: .leading) { Text(title).font(.headline).foregroundStyle(.primary).lineLimit(2); Text(subtitle).font(.caption).foregroundStyle(.purple) }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }.padding(.horizontal)
    }
}

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @State private var showLogout = false
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) { BrandMark(size: 58); VStack(alignment: .leading, spacing: 4) { Text(session.username).font(.headline); Label(session.userInfo?.status ?? "—", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green); Text("Scadenza: \(expiry)").font(.caption).foregroundStyle(.secondary) } }
                Button { Task { await session.refreshSafely() } } label: { Label(session.isRefreshing ? "Aggiornamento…" : "Aggiorna playlist", systemImage: "arrow.clockwise") }.disabled(session.isRefreshing)
                LabeledContent("Ultimo aggiornamento", value: session.lastRefresh?.formatted(date: .abbreviated, time: .shortened) ?? "—")
            } header: { Text("Account") }
            Section("Riproduzione") { Toggle("Riproduzione automatica", isOn: Binding(get: { session.autoplay }, set: { session.setAutoplay($0) })); Toggle("Aggiorna all'apertura", isOn: Binding(get: { session.refreshOnLaunch }, set: { session.setRefreshOnLaunch($0) })); Label("Picture in Picture", systemImage: "pip.fill"); Label("AirPlay", systemImage: "airplayvideo") }
            Section("Aspetto") { Picker("Tema", selection: Binding(get: { session.appearance }, set: { session.setAppearance($0) })) { Text("Automatico").tag("system"); Text("Chiaro").tag("light"); Text("Scuro").tag("dark") } }
            Section("Sicurezza") { Toggle("Controllo genitori", isOn: Binding(get: { session.parentalControl }, set: { session.setParentalControl($0) })) }
            Section { Button("Esci dall'account", role: .destructive) { showLogout = true } }
        }
        .navigationTitle("Impostazioni")
        .alert("Vuoi uscire dall'account?", isPresented: $showLogout) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) { session.signOut() }
        } message: {
            Text("Dovrai inserire nuovamente il codice di accesso per entrare.")
        }
    }
    private var expiry: String { guard let timestamp = session.userInfo?.expDate, let seconds = TimeInterval(timestamp) else { return "—" }; return Date(timeIntervalSince1970: seconds).formatted(date: .abbreviated, time: .omitted) }
}

struct EmptyStateView: View {
    let title: String; let icon: String; let message: String
    var body: some View { VStack(spacing: 14) { Image(systemName: icon).font(.system(size: 46)).foregroundStyle(.secondary); Text(title).font(.title3.bold()); Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(32) }
}
