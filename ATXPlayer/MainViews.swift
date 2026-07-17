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
    @EnvironmentObject var session: AppSession
    @State private var miniPlayerDescriptor: PlaybackDescriptor?

    private var latestProgress: PlaybackProgress? { session.continueWatching.first }

    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { ContentBrowser(type: .live) }.tabItem { Label("Diretta", systemImage: "dot.radiowaves.left.and.right") }
            NavigationStack { ContentBrowser(type: .movies) }.tabItem { Label("Film", systemImage: "film.fill") }
            NavigationStack { ContentBrowser(type: .series) }.tabItem { Label("Serie", systemImage: "rectangle.stack.fill") }
            NavigationStack { SettingsView() }.tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }
        .tint(.purple)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let progress = latestProgress, let descriptor = session.descriptor(from: progress) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: progress.imageURL ?? "")) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { brandGradient }
                    }
                    .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 10)).clipped()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(progress.title).font(.subheadline.bold()).lineLimit(1)
                        ProgressView(value: progress.fraction).tint(.purple)
                    }
                    Spacer()
                    Button { miniPlayerDescriptor = descriptor } label: {
                        Image(systemName: "play.fill").font(.headline).frame(width: 38, height: 38).background(Color.purple, in: Circle()).foregroundStyle(.white)
                    }
                    Button { session.removeProgress(for: descriptor) } label: {
                        Image(systemName: "xmark").foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .sheet(item: $miniPlayerDescriptor) { descriptor in
            NavigationStack {
                PlayerScreen(title: descriptor.title, url: session.streamURL(type: descriptor.kind, id: descriptor.streamID, ext: descriptor.fileExtension), isLive: descriptor.kind == .live, resume: descriptor)
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var session: AppSession
    @State private var featuredIndex = 0
    @State private var showSearch = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    private var features: [FeaturedContent] {
        let movies = session.allMovies.filter { !($0.streamIcon ?? "").isEmpty }.prefix(25).map { FeaturedContent.movie($0) }
        let series = session.allSeries.filter { !($0.cover ?? "").isEmpty }.prefix(25).map { FeaturedContent.series($0) }
        return (Array(movies) + Array(series)).shuffled()
    }
    private var featured: FeaturedContent? { features.isEmpty ? nil : features[featuredIndex % features.count] }
    private var recentMovies: [VODStream] { Array(session.allMovies.sorted { numericDateValue($0.added) > numericDateValue($1.added) }.prefix(16)) }
    private var recentSeries: [SeriesItem] { Array(session.allSeries.sorted { seriesSortValue($0) > seriesSortValue($1) }.prefix(16)) }
    private var popularMovies: [VODStream] {
        let ids = session.accountWatchHistory.filter { $0.kind == ContentType.movies.rawValue }.map(\.streamID)
        let watched = ids.compactMap { id in session.allMovies.first { $0.streamID == id } }
        return Array((watched + recentMovies).reduce(into: [Int: VODStream]()) { $0[$1.streamID] = $1 }.values.prefix(12))
    }
    private var recommendedSeries: [SeriesItem] {
        let favorites = session.accountFavorites.filter { $0.kind == ContentType.series.rawValue }.compactMap { fav in session.allSeries.first { $0.seriesID == fav.streamID } }
        return Array((favorites + recentSeries).reduce(into: [Int: SeriesItem]()) { $0[$1.seriesID] = $1 }.values.shuffled().prefix(12))
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .zIndex(20)
                    .offset(y: appeared || reduceMotion ? 0 : -18)
                    .opacity(appeared ? 1 : 0)
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        accountShortcuts
                        hero
                            .zIndex(0)
                        counters
                        quickActions
                        if !session.accountFavorites.isEmpty { favoritesRail }
                        if !session.accountWatchHistory.isEmpty { historyRail }
                        if !session.continueWatching.isEmpty { continueWatchingRail }
                        if !popularMovies.isEmpty { movieRail("Più popolari per te", popularMovies) }
                        if !recommendedSeries.isEmpty { seriesRail("Consigliati per te", recommendedSeries) }
                        if !recentSeries.isEmpty { seriesRail }
                        if !recentMovies.isEmpty { movieRail }
                        updateStatus
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 24)
                }
                
            }
            if session.isRefreshing { loadingOverlay.zIndex(50) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSearch) { NavigationStack { GlobalSearchView() } }
        .onAppear { withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.65)) { appeared = true } }
        .onReceive(timer) { _ in
            guard features.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.65)) { featuredIndex = (featuredIndex + 1) % features.count }
        }
        .alert("Attenzione", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            BrandMark(size: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text("ATLANTIX")
                    .font(.title3.weight(.black))
                    .tracking(2.0)
                    .lineLimit(1)
                Text("Bentornato, \(session.username)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(lastUpdateText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            circleButton("magnifyingglass") { showSearch = true }
            circleButton(session.isRefreshing ? "hourglass" : "arrow.clockwise") {
                Task { await session.refreshSafely() }
            }
            .disabled(session.isRefreshing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 13)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
        .contentShape(Rectangle())
    }

    private var lastUpdateText: String {
        guard let date = session.lastRefresh else { return "Playlist pronta" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "'Aggiornato oggi alle' HH:mm" : "'Aggiornato il' dd/MM 'alle' HH:mm"
        return formatter.string(from: date)
    }

    private var accountShortcuts: some View {
        HStack(spacing: 14) {
            NavigationLink { FavoritesView() } label: {
                shortcutCard(
                    title: "La mia lista",
                    subtitle: session.accountFavorites.isEmpty ? "Nessun preferito" : "\(session.accountFavorites.count) contenuti",
                    icon: session.accountFavorites.isEmpty ? "heart" : "heart.fill",
                    accent: .pink
                )
            }
            .buttonStyle(.plain)

            NavigationLink { WatchHistoryView() } label: {
                shortcutCard(
                    title: "Cronologia",
                    subtitle: session.accountWatchHistory.isEmpty ? "Nessun contenuto" : "\(session.accountWatchHistory.count) visti",
                    icon: "clock.arrow.circlepath",
                    accent: .purple
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private func shortcutCard(title: String, subtitle: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.07)))
    }

    private func toolButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolLabel(title: title, icon: icon, badge: 0)
        }
        .buttonStyle(.plain)
    }

    private func toolLabel(title: String, icon: String, badge: Int) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.headline.bold())
                    .foregroundStyle(icon == "heart.fill" ? Color.pink : Color.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.08)))
                if badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.pink)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
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

    private var favoritesRail: some View {
        MediaRail(title: "La mia lista") {
            ForEach(session.accountFavorites.prefix(12)) { favorite in
                favoriteHomeLink(favorite)
            }
            NavigationLink { FavoritesView() } label: {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 34))
                    Text("Vedi tutti").font(.subheadline.bold())
                }
                .foregroundStyle(.purple)
                .frame(width: 138, height: 205)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func favoriteHomeLink(_ favorite: FavoriteItem) -> some View {
        if favorite.kind == ContentType.live.rawValue,
           let item = session.allLive.first(where: { $0.streamID == favorite.streamID }) {
            NavigationLink { LiveDetailView(item: item) } label: {
                PosterCard(title: favorite.title, imageURL: favorite.imageURL, badge: "LIVE").frame(width: 138)
            }.buttonStyle(.plain)
        } else if favorite.kind == ContentType.movies.rawValue,
                  let item = session.allMovies.first(where: { $0.streamID == favorite.streamID }) {
            NavigationLink { MovieDetailView(item: item) } label: {
                PosterCard(title: favorite.title, imageURL: favorite.imageURL, badge: nil).frame(width: 138)
            }.buttonStyle(.plain)
        } else if favorite.kind == ContentType.series.rawValue,
                  let item = session.allSeries.first(where: { $0.seriesID == favorite.streamID }) {
            NavigationLink { SeriesDetailView(item: item) } label: {
                PosterCard(title: favorite.title, imageURL: favorite.imageURL, badge: nil).frame(width: 138)
            }.buttonStyle(.plain)
        } else {
            PosterCard(title: favorite.title, imageURL: favorite.imageURL, badge: nil).frame(width: 138)
        }
    }

    private var historyRail: some View {
        MediaRail(title: "Visti di recente") {
            ForEach(Array(session.accountWatchHistory.prefix(12))) { item in
                HistoryPosterCard(item: item)
            }
            NavigationLink { WatchHistoryView() } label: {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath").font(.title)
                    Text("Vedi tutto").font(.caption.bold())
                }
                .foregroundStyle(.primary)
                .frame(width: 120, height: 176)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
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

private func movieRail(_ title: String, _ items: [VODStream]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        NavigationLink { MovieDetailView(item: item) } label: { PosterCard(title: item.name, imageURL: item.streamIcon, badge: item.rating).frame(width: 138) }
                    }
                }.padding(.horizontal)
            }
        }
    }

private func seriesRail(_ title: String, _ items: [SeriesItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        NavigationLink { SeriesDetailView(item: item) } label: { PosterCard(title: item.name, imageURL: item.cover, badge: item.rating).frame(width: 138) }
                    }
                }.padding(.horizontal)
            }
        }
    }
enum FeaturedContent {
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
            Button {
                Task { await session.reloadSection(type) }
            } label: {
                ZStack {
                    Circle().fill(Color(uiColor: .secondarySystemBackground))
                    if session.isRefreshing {
                        ProgressView().tint(.primary)
                    } else {
                        Image(systemName: "arrow.clockwise").font(.headline.bold())
                    }
                }
                .frame(width: 50, height: 50)
                .overlay(Circle().stroke(Color.primary.opacity(0.08)))
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(session.isRefreshing)
            .zIndex(20)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    session.toggleFavorite(kind: .movies, streamID: item.streamID, title: item.name, imageURL: item.streamIcon, fileExtension: item.containerExtension)
                } label: {
                    Image(systemName: session.isFavorite(kind: .movies, streamID: item.streamID) ? "heart.fill" : "heart")
                }
                .accessibilityLabel("Preferito")
            }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    session.toggleFavorite(kind: .live, streamID: item.streamID, title: item.name, imageURL: item.streamIcon)
                } label: {
                    Image(systemName: session.isFavorite(kind: .live, streamID: item.streamID) ? "heart.fill" : "heart")
                }
                .accessibilityLabel("Preferito")
            }
        }
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
                        seasonNavigation
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
                            ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                                let descriptor = PlaybackDescriptor(
                                    kind: .series,
                                    streamID: episode.id,
                                    title: episode.title,
                                    subtitle: "\(item.name) • S\(selectedSeason) E\(episode.episodeNum)",
                                    imageURL: episode.info?.movieImage ?? item.cover,
                                    fileExtension: episode.containerExtension
                                )
                                let queue = episodes.map { queuedEpisode in
                                    let queuedDescriptor = PlaybackDescriptor(
                                        kind: .series,
                                        streamID: queuedEpisode.id,
                                        title: queuedEpisode.title,
                                        subtitle: "\(item.name) • S\(selectedSeason) E\(queuedEpisode.episodeNum)",
                                        imageURL: queuedEpisode.info?.movieImage ?? item.cover,
                                        fileExtension: queuedEpisode.containerExtension
                                    )
                                    return PlaybackQueueItem(
                                        id: String(queuedEpisode.id),
                                        title: queuedEpisode.title,
                                        url: session.streamURL(type: .series, id: queuedEpisode.id, ext: queuedEpisode.containerExtension),
                                        descriptor: queuedDescriptor
                                    )
                                }
                                NavigationLink {
                                    PlayerScreen(
                                        title: episode.title,
                                        url: session.streamURL(type: .series, id: episode.id, ext: episode.containerExtension),
                                        isLive: false,
                                        resume: descriptor,
                                        episodeQueue: queue,
                                        startIndex: index
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    session.toggleFavorite(kind: .series, streamID: item.seriesID, title: item.name, imageURL: item.cover)
                } label: {
                    Image(systemName: session.isFavorite(kind: .series, streamID: item.seriesID) ? "heart.fill" : "heart")
                }
                .accessibilityLabel("Preferito")
            }
        }
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

    private var selectedSeasonIndex: Int? { seasons.firstIndex(of: selectedSeason) }

    private var seasonNavigation: some View {
        HStack(spacing: 12) {
            Button { selectPreviousSeason() } label: {
                Label("Precedente", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(selectedSeasonIndex == nil || selectedSeasonIndex == 0)

            Button { selectNextSeason() } label: {
                Label("Successiva", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(selectedSeasonIndex == nil || selectedSeasonIndex == seasons.count - 1)
        }
        .padding(.horizontal)
    }

    private func selectPreviousSeason() {
        guard let index = selectedSeasonIndex, index > 0 else { return }
        selectedSeason = seasons[index - 1]
        UserDefaults.standard.set(selectedSeason, forKey: "lastSeason_\(session.accessCode)_\(item.seriesID)")
    }

    private func selectNextSeason() {
        guard let index = selectedSeasonIndex, index + 1 < seasons.count else { return }
        selectedSeason = seasons[index + 1]
        UserDefaults.standard.set(selectedSeason, forKey: "lastSeason_\(session.accessCode)_\(item.seriesID)")
    }

    private func load() async {
        loading = true; error = nil
        do {
            info = try await APIClient.shared.seriesInfo(baseURL: session.baseURL, username: session.username, password: session.password, seriesID: item.seriesID)
            let savedSeason = UserDefaults.standard.string(forKey: "lastSeason_\(session.accessCode)_\(item.seriesID)")
            selectedSeason = seasons.contains(savedSeason ?? "") ? (savedSeason ?? "") : (seasons.first ?? "")
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

struct PlaybackQueueItem: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL?
    let descriptor: PlaybackDescriptor
}

struct PlayerScreen: View {
    @EnvironmentObject var session: AppSession
    let title: String
    let url: URL?
    let isLive: Bool
    var resume: PlaybackDescriptor? = nil
    var episodeQueue: [PlaybackQueueItem] = []
    var startIndex: Int = 0

    @State private var player: AVPlayer?
    @State private var failed = false
    @State private var pictureInPictureActive = false
    @State private var showResumePrompt = false
    @State private var pendingResumePosition: Double = 0
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?
    @State private var currentQueueIndex: Int
    @State private var displayedTitle: String
    @State private var currentDescriptor: PlaybackDescriptor?
    @State private var showNextEpisodeCountdown = false
    @State private var nextEpisodeCountdown = 3
    @State private var autoAdvanceCancelled = false

    init(title: String, url: URL?, isLive: Bool, resume: PlaybackDescriptor? = nil, episodeQueue: [PlaybackQueueItem] = [], startIndex: Int = 0) {
        self.title = title
        self.url = url
        self.isLive = isLive
        self.resume = resume
        self.episodeQueue = episodeQueue
        self.startIndex = startIndex
        _currentQueueIndex = State(initialValue: startIndex)
        _displayedTitle = State(initialValue: title)
        _currentDescriptor = State(initialValue: resume)
    }

    private var currentURL: URL? {
        guard !episodeQueue.isEmpty, episodeQueue.indices.contains(currentQueueIndex) else { return url }
        return episodeQueue[currentQueueIndex].url
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                NativePlayerController(player: player, pictureInPictureActive: $pictureInPictureActive)
                    .ignoresSafeArea(edges: .bottom)
            } else if failed || currentURL == nil {
                EmptyStateView(title: "Riproduzione non disponibile", icon: "play.slash", message: "Il flusso potrebbe essere offline o in un formato non supportato.").foregroundStyle(.primary)
            } else {
                ProgressView("Apertura player…").tint(.white).foregroundStyle(.primary)
            }

            if showNextEpisodeCountdown, let next = nextQueueItem {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        nextEpisodeOverlay(next)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 74)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: showNextEpisodeCountdown)
            }
        }
        .navigationTitle(displayedTitle)
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

    private var nextQueueItem: PlaybackQueueItem? {
        let index = currentQueueIndex + 1
        guard episodeQueue.indices.contains(index) else { return nil }
        return episodeQueue[index]
    }

    @ViewBuilder
    private func nextEpisodeOverlay(_ next: PlaybackQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROSSIMO EPISODIO")
                .font(.caption.bold())
                .foregroundStyle(.cyan)
            Text(next.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
            Text("Riproduzione tra \(nextEpisodeCountdown)")
                .font(.title2.bold())
                .foregroundStyle(.white)
            ProgressView(value: Double(3 - nextEpisodeCountdown), total: 3)
                .tint(.purple)
            HStack(spacing: 10) {
                Button { playNextEpisodeIfAvailable() } label: {
                    Label("Riproduci ora", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.purple, in: Capsule())
                }
                Button("Annulla") {
                    autoAdvanceCancelled = true
                    showNextEpisodeCountdown = false
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.13), in: Capsule())
            }
            .foregroundStyle(.white)
        }
        .padding(18)
        .frame(maxWidth: 350, alignment: .leading)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.purple.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 18)
    }

    private func configurePlayer() {
        guard player == nil else { return }
        guard let currentURL else { failed = true; return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try audioSession.setActive(true)
        } catch { }

        if !episodeQueue.isEmpty, episodeQueue.indices.contains(currentQueueIndex) {
            displayedTitle = episodeQueue[currentQueueIndex].title
            currentDescriptor = episodeQueue[currentQueueIndex].descriptor
        }

        if let currentDescriptor { session.recordHistory(for: currentDescriptor) }

        let item = AVPlayerItem(url: currentURL)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        installObservers(on: newPlayer, item: item)

        if !isLive, let currentDescriptor, let saved = session.savedProgress(for: currentDescriptor), saved.position >= 20 {
            pendingResumePosition = saved.position
            showResumePrompt = true
        } else {
            newPlayer.play()
        }

        validate(item: item, player: newPlayer)
    }

    private func validate(item: AVPlayerItem, player: AVPlayer) {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if item.status == .failed {
                failed = true
                player.pause()
                self.player = nil
            }
        }
    }

    private func installObservers(on player: AVPlayer, item: AVPlayerItem) {
        removeObservers(from: player)
        guard !isLive, let currentDescriptor else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { time in
            let duration = item.duration.seconds
            session.recordProgress(for: currentDescriptor, position: time.seconds, duration: duration)

            guard nextQueueItem != nil, duration.isFinite, duration > 0, !autoAdvanceCancelled else { return }
            let remaining = duration - time.seconds
            if remaining <= 3.2, remaining > 0 {
                let value = max(1, min(3, Int(ceil(remaining))))
                nextEpisodeCountdown = value
                showNextEpisodeCountdown = true
            } else if remaining > 3.2 {
                showNextEpisodeCountdown = false
                nextEpisodeCountdown = 3
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            session.removeProgress(for: currentDescriptor)
            if !autoAdvanceCancelled {
                playNextEpisodeIfAvailable()
            } else {
                showNextEpisodeCountdown = false
            }
        }
    }

    private func playNextEpisodeIfAvailable() {
        let nextIndex = currentQueueIndex + 1
        guard !episodeQueue.isEmpty, episodeQueue.indices.contains(nextIndex), let nextURL = episodeQueue[nextIndex].url, let player else { return }

        removeObservers(from: player)
        showNextEpisodeCountdown = false
        nextEpisodeCountdown = 3
        autoAdvanceCancelled = false
        currentQueueIndex = nextIndex
        let next = episodeQueue[nextIndex]
        displayedTitle = next.title
        currentDescriptor = next.descriptor
        session.recordHistory(for: next.descriptor)
        failed = false

        let nextItem = AVPlayerItem(url: nextURL)
        player.replaceCurrentItem(with: nextItem)
        installObservers(on: player, item: nextItem)
        player.play()
        validate(item: nextItem, player: player)
    }

    private func removeObservers(from player: AVPlayer?) {
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
    }

    private func closePlayerIfNeeded() {
        guard !pictureInPictureActive else { return }
        if let currentDescriptor, let player {
            session.recordProgress(for: currentDescriptor, position: player.currentTime().seconds, duration: player.currentItem?.duration.seconds ?? 0)
        }
        removeObservers(from: player)
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

struct FavoritesView: View {
    @EnvironmentObject var session: AppSession
    @State private var showClearConfirmation = false
    @State private var selectedFilter = "Tutti"
    @State private var sortAlphabetically = false

    private var liveItems: [FavoriteItem] { session.accountFavorites.filter { $0.kind == ContentType.live.rawValue } }
    private var movieItems: [FavoriteItem] { session.accountFavorites.filter { $0.kind == ContentType.movies.rawValue } }
    private var seriesItems: [FavoriteItem] { session.accountFavorites.filter { $0.kind == ContentType.series.rawValue } }
    private var visibleItems: [FavoriteItem] {
        let source: [FavoriteItem]
        switch selectedFilter {
        case "Diretta": source = liveItems
        case "Film": source = movieItems
        case "Serie": source = seriesItems
        default: source = session.accountFavorites
        }
        return sortAlphabetically ? source.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending } : source.sorted { $0.addedAt > $1.addedAt }
    }

    var body: some View {
        Group {
            if session.accountFavorites.isEmpty {
                EmptyStateView(title: "Nessun preferito", icon: "heart", message: "Aggiungi film, serie e canali alla tua lista usando il cuore nelle pagine dettaglio.")
            } else {
                List {
                    Section {
                        HStack(spacing: 12) {
                            summaryItem("Diretta", liveItems.count, "dot.radiowaves.left.and.right")
                            summaryItem("Film", movieItems.count, "film.fill")
                            summaryItem("Serie", seriesItems.count, "rectangle.stack.fill")
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    }
                    Section {
                        Picker("Categoria", selection: $selectedFilter) {
                            ForEach(["Tutti", "Diretta", "Film", "Serie"], id: \.self) { Text($0) }
                        }.pickerStyle(.segmented)
                        Toggle("Ordine alfabetico", isOn: $sortAlphabetically)
                    }
                    Section(selectedFilter) {
                        ForEach(visibleItems) { favorite in favoriteRow(favorite) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("La mia lista")
        .toolbar {
            if !session.accountFavorites.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showClearConfirmation = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Svuota la mia lista")
                }
            }
        }
        .alert("Svuotare La mia lista?", isPresented: $showClearConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Rimuovi tutto", role: .destructive) { session.clearAccountFavorites() }
        } message: {
            Text("Tutti i preferiti di questo account verranno rimossi.")
        }
    }

    private func summaryItem(_ title: String, _ count: Int, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(.purple)
            Text("\(count)").font(.headline.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func favoriteRow(_ favorite: FavoriteItem) -> some View {
        HStack(spacing: 8) {
            favoriteNavigation(favorite)
            Button(role: .destructive) { session.removeFavorite(id: favorite.id) } label: {
                Image(systemName: "trash.fill")
                    .foregroundStyle(.red)
                    .frame(width: 38, height: 38)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rimuovi dai preferiti")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { session.removeFavorite(id: favorite.id) } label: {
                Label("Rimuovi", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func favoriteNavigation(_ favorite: FavoriteItem) -> some View {
        if favorite.kind == ContentType.live.rawValue,
           let item = session.allLive.first(where: { $0.streamID == favorite.streamID }) {
            NavigationLink { LiveDetailView(item: item) } label: {
                FavoriteRowContent(favorite: favorite, icon: "dot.radiowaves.left.and.right")
            }
        } else if favorite.kind == ContentType.movies.rawValue,
                  let item = session.allMovies.first(where: { $0.streamID == favorite.streamID }) {
            NavigationLink { MovieDetailView(item: item) } label: {
                FavoriteRowContent(favorite: favorite, icon: "film.fill")
            }
        } else if favorite.kind == ContentType.series.rawValue,
                  let item = session.allSeries.first(where: { $0.seriesID == favorite.streamID }) {
            NavigationLink { SeriesDetailView(item: item) } label: {
                FavoriteRowContent(favorite: favorite, icon: "rectangle.stack.fill")
            }
        } else {
            FavoriteRowContent(favorite: favorite, icon: "heart.fill")
        }
    }
}

struct FavoriteRowContent: View {
    let favorite: FavoriteItem
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: favorite.imageURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color(uiColor: .secondarySystemBackground)
                        Image(systemName: icon).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(favorite.title)
                .font(.headline)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct WatchHistoryView: View {
    @EnvironmentObject var session: AppSession
    @State private var showClearConfirmation = false
    @State private var selectedFilter = "Tutti"
    @State private var sortAlphabetically = false

    var body: some View {
        Group {
            if session.accountWatchHistory.isEmpty {
                EmptyStateView(title: "Cronologia vuota", icon: "clock.arrow.circlepath", message: "I film e gli episodi avviati compariranno qui.")
            } else {
                List {
                    ForEach(session.accountWatchHistory) { item in
                        HStack(spacing: 8) {
                            HistoryNavigation(item: item)
                            Button(role: .destructive) { session.removeHistory(id: item.id) } label: {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(.red)
                                    .frame(width: 38, height: 38)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { session.removeHistory(id: item.id) } label: {
                                Label("Rimuovi", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Cronologia")
        .toolbar {
            if !session.accountWatchHistory.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showClearConfirmation = true } label: { Image(systemName: "trash") }
                }
            }
        }
        .alert("Cancellare la cronologia?", isPresented: $showClearConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Cancella tutto", role: .destructive) { session.clearAccountWatchHistory() }
        } message: {
            Text("Verranno rimossi tutti i contenuti visti da questo account.")
        }
    }
}

struct HistoryNavigation: View {
    @EnvironmentObject var session: AppSession
    let item: WatchHistoryItem

    private var descriptor: PlaybackDescriptor? {
        guard let kind = ContentType(rawValue: item.kind) else { return nil }
        return PlaybackDescriptor(kind: kind, streamID: item.streamID, title: item.title, subtitle: item.subtitle, imageURL: item.imageURL, fileExtension: item.fileExtension)
    }

    var body: some View {
        if let descriptor {
            NavigationLink {
                PlayerScreen(
                    title: item.title,
                    url: session.streamURL(type: descriptor.kind, id: descriptor.streamID, ext: descriptor.fileExtension),
                    isLive: false,
                    resume: descriptor
                )
            } label: {
                HistoryRowContent(item: item)
            }
        } else {
            HistoryRowContent(item: item)
        }
    }
}

struct HistoryRowContent: View {
    let item: WatchHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.imageURL ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { ZStack { Color(uiColor: .secondarySystemBackground); Image(systemName: "play.rectangle.fill").foregroundStyle(.secondary) } }
            }
            .frame(width: 70, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).lineLimit(2)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(item.watchedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.purple)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct HistoryPosterCard: View {
    @EnvironmentObject var session: AppSession
    let item: WatchHistoryItem

    private var descriptor: PlaybackDescriptor? {
        guard let kind = ContentType(rawValue: item.kind) else { return nil }
        return PlaybackDescriptor(kind: kind, streamID: item.streamID, title: item.title, subtitle: item.subtitle, imageURL: item.imageURL, fileExtension: item.fileExtension)
    }

    var body: some View {
        Group {
            if let descriptor {
                NavigationLink {
                    PlayerScreen(
                        title: item.title,
                        url: session.streamURL(type: descriptor.kind, id: descriptor.streamID, ext: descriptor.fileExtension),
                        isLive: false,
                        resume: descriptor
                    )
                } label: { card }
            } else {
                card
            }
        }
        .buttonStyle(.plain)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 7) {
            AsyncImage(url: URL(string: item.imageURL ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { ZStack { brandGradient; Image(systemName: "play.rectangle.fill").foregroundStyle(.white) } }
            }
            .frame(width: 120, height: 145)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipped()
            Text(item.title).font(.caption.bold()).lineLimit(2).frame(width: 120, alignment: .leading)
        }
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
            Section("Aspetto") { Picker("Tema", selection: Binding(get: { session.appearance }, set: { session.setAppearance($0) })) { Text("Automatico").tag("system"); Text("Chiaro").tag("light"); Text("Scuro").tag("dark") }; Toggle("Animazioni dell’interfaccia", isOn: Binding(get: { session.interfaceAnimations }, set: { session.setInterfaceAnimations($0) })) }
            Section("Raccolta") {
                NavigationLink { FavoritesView() } label: {
                    Label("La mia lista", systemImage: "heart.fill")
                }
                NavigationLink { WatchHistoryView() } label: {
                    Label("Cronologia", systemImage: "clock.arrow.circlepath")
                }
            }
            Section("Sicurezza") { Toggle("Controllo genitori", isOn: Binding(get: { session.parentalControl }, set: { session.setParentalControl($0) })) }
            Section { Button("Esci dall'account", role: .destructive) { showLogout = true } }
        }
        .navigationTitle("Impostazioni")
        .alert("Vuoi uscire dall'account?", isPresented: $showLogout) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) { session.signOut() }
        } message: {
            Text("Dovrai inserire nuovamente nome utente e password per entrare.")
        }
    }
    private var expiry: String { guard let timestamp = session.userInfo?.expDate, let seconds = TimeInterval(timestamp) else { return "—" }; return Date(timeIntervalSince1970: seconds).formatted(date: .abbreviated, time: .omitted) }
}

struct EmptyStateView: View {
    let title: String; let icon: String; let message: String
    var body: some View { VStack(spacing: 14) { Image(systemName: icon).font(.system(size: 46)).foregroundStyle(.secondary); Text(title).font(.title3.bold()); Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(32) }
}
