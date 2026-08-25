// ATLANTIX 4.0 BUILD 137 — TOTAL STREAMING REBUILD
import Foundation
import SwiftUI
import AVKit
import AVFoundation
import UIKit
import ImageIO
import SafariServices
import Combine


// MARK: - Image loading optimized for smooth scrolling
private final class PosterImageCache {
    static let shared = PosterImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 250
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func insert(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

private struct OptimizedImagePhase {
    let image: Image?
}

private struct OptimizedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (OptimizedImagePhase) -> Content
    @State private var uiImage: UIImage?

    var body: some View {
        content(OptimizedImagePhase(image: uiImage.map { Image(uiImage: $0) }))
            .task(id: url) {
                guard let url else {
                    uiImage = nil
                    return
                }
                if let cached = PosterImageCache.shared.image(for: url) {
                    uiImage = cached
                    return
                }
                do {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.timeoutInterval = 20
                    let (data, _) = try await URLSession.shared.data(for: request)
                    try Task.checkCancellation()
                    let decoded = await Task.detached(priority: .utility) {
                        Self.downsample(data: data, maxPixelSize: 900)
                    }.value
                    try Task.checkCancellation()
                    if let decoded {
                        PosterImageCache.shared.insert(decoded, for: url)
                        uiImage = decoded
                    }
                } catch is CancellationError {
                    // The card left the screen: avoid unnecessary work.
                } catch {
                    uiImage = nil
                }
            }
    }

    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - AtlantiX 4.0 Build 137 — TOTAL STREAMING DESIGN SYSTEM
// Deep-black cinema surfaces with a single AtlantiX red accent.
private let atxPrimary = Color(red: 0.90, green: 0.02, blue: 0.10)
private let atxSecondary = Color(red: 0.62, green: 0.00, blue: 0.055)
private let atxCyan = Color.white
private let atxMint = Color(red: 0.36, green: 0.82, blue: 0.48)
private let atxOrange = Color(red: 1.0, green: 0.68, blue: 0.18)
private let atxCanvas = Color.black
private let atxSurface = Color(red: 0.075, green: 0.075, blue: 0.078)
private let atxSurfaceSoft = Color(red: 0.115, green: 0.115, blue: 0.12)
private let atxStroke = Color.white.opacity(0.12)
private let brandGradient = LinearGradient(colors: [Color(red: 1.0, green: 0.06, blue: 0.15), atxPrimary, atxSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
private let pageBackground = Color.black

private struct StreamingBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(colors: [Color.black, Color(red: 0.055, green: 0.055, blue: 0.06), Color.black], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [atxPrimary.opacity(0.10), .clear], center: .topLeading, startRadius: 10, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func streamingPanel(radius: CGFloat = 24) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(atxSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(atxStroke, lineWidth: 1))
    }

    func atxDashboardCard(radius: CGFloat = 24) -> some View {
        self
            .background(atxSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(atxStroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.28), radius: 20, y: 10)
    }
}

private func accentGradient(for seed: String) -> LinearGradient {
    let palettes: [[Color]] = [
        [Color(red: 0.12, green: 0.12, blue: 0.13), atxPrimary.opacity(0.78)],
        [Color(red: 0.18, green: 0.02, blue: 0.04), Color(red: 0.055, green: 0.055, blue: 0.06)],
        [Color(red: 0.10, green: 0.10, blue: 0.11), Color(red: 0.38, green: 0.0, blue: 0.04)]
    ]
    let value = abs(seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
    return LinearGradient(colors: palettes[value % palettes.count], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private func normalizedTrailerURL(_ value: String?) -> URL? {
    guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    if value.hasPrefix("http://") || value.hasPrefix("https://") { return URL(string: value) }
    if value.contains("youtube.com") || value.contains("youtu.be") { return URL(string: "https://" + value) }
    value = value.replacingOccurrences(of: " ", with: "")
    return URL(string: "https://www.youtube.com/watch?v=\(value)")
}

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
    enum AppTab: String, CaseIterable {
        case home = "Home"
        case live = "Diretta"
        case movies = "Film"
        case series = "Serie"
        case downloads = "Download"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .live: return "dot.radiowaves.left.and.right"
            case .movies: return "film.fill"
            case .series: return "rectangle.stack.fill"
            case .downloads: return "arrow.down.circle.fill"
            }
        }
    }

    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack { HomeDashboardV4(selectedTab: $selectedTab) }
                case .live:
                    NavigationStack { ContentBrowser(type: .live) }
                case .movies:
                    NavigationStack { ContentBrowser(type: .movies) }
                case .series:
                    NavigationStack { ContentBrowser(type: .series) }
                case .downloads:
                    NavigationStack { DownloadsView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selectedTab = tab }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: selectedTab == tab ? .bold : .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 9, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .overlay(alignment: .top) {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(atxPrimary)
                                    .frame(width: 28, height: 3)
                                    .padding(.top, 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 5)
            .background(Color.black)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct HomeDashboardV4: View {
    @EnvironmentObject var session: AppSession
    @Binding var selectedTab: MainTabView.AppTab
    @State private var showSearch = false
    @State private var feature: FeaturedContent?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .zIndex(100)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        filterStrip
                        heroStage
                        if !session.continueWatching.isEmpty { continueRail }
                        posterRail(title: "Film da non perdere", movies: Array(session.allMovies.prefix(24)), series: [])
                        posterRail(title: "Serie TV da scoprire", movies: [], series: Array(session.allSeries.prefix(24)))
                        activityRail
                        libraryRail
                    }
                    .padding(.bottom, 108)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSearch) { NavigationStack { GlobalSearchView() } }
        .task(id: session.allMovies.count + session.allSeries.count) { pickFeature() }
    }

    // Minimal streaming-style top bar: branding left, actions right.
    private var topBar: some View {
        HStack(spacing: 13) {
            BrandMark(size: 32)
            Spacer(minLength: 8)

            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { Task { await session.refreshSafely() } } label: {
                Image(systemName: session.isRefreshing ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(session.isRefreshing)

            NavigationLink { SettingsView() } label: {
                ZStack {
                    Circle().fill(brandGradient)
                    Text(String(session.username.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.98))
    }

    // AtlantiX 4.0 Build 136 — total streaming rebuild.
    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { selectedTab = .series } label: { filterChip("Serie TV") }
                Button { selectedTab = .movies } label: { filterChip("Film") }
                NavigationLink { CategoriesHubView() } label: { filterChip("Categorie", chevron: true) }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .padding(.top, 5)
    }

    private func filterChip(_ title: String, chevron: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption.weight(.semibold))
            if chevron { Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    @ViewBuilder private var heroStage: some View {
        if let feature {
            ZStack(alignment: .bottom) {
                OptimizedAsyncImage(url: URL(string: feature.imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { accentGradient(for: feature.title) }
                }
                .frame(height: 520)
                .frame(maxWidth: .infinity)
                .clipped()
                .allowsHitTesting(false)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.10), .black.opacity(0.86), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(spacing: 12) {
                    Text(feature.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 18)

                    HStack(spacing: 7) {
                        Text(feature.kind)
                        Text("•")
                        Text("AtlantiX")
                        Text("•")
                        Text("In evidenza")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 10) {
                        NavigationLink { feature.destination(session: session) } label: {
                            Label("Riproduci", systemImage: "play.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)

                        Button {
                            toggleHeroFavorite()
                        } label: {
                            Label(isHeroFavorite ? "Nella mia lista" : "La mia lista", systemImage: isHeroFavorite ? "checkmark" : "plus")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, 18)
            }
            .frame(height: 520)
            .clipped()
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: 360)
                .overlay(Text("Sincronizza il catalogo per iniziare").font(.headline).foregroundStyle(.white.opacity(0.55)))
                .padding(.horizontal, 16)
        }
    }

    private var continueRail: some View {
        VStack(alignment: .leading, spacing: 11) {
            streamingSectionTitle("Continua a guardare")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(session.continueWatching.prefix(12)) { progress in
                        if let descriptor = session.descriptor(from: progress) {
                            NavigationLink {
                                PlayerScreen(title: descriptor.title, url: session.streamURL(type: descriptor.kind, id: descriptor.streamID, ext: descriptor.fileExtension), isLive: false, resume: descriptor)
                            } label: {
                                ContinueWatchingCard(progress: progress)
                                    .frame(width: 220)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder private func posterRail(title: String, movies: [VODStream], series: [SeriesItem]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            streamingSectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 9) {
                    ForEach(movies) { movie in
                        NavigationLink { MovieDetailView(item: movie) } label: {
                            ModernPosterCard(title: movie.name, imageURL: movie.streamIcon, badge: movie.rating, typeLabel: "FILM")
                                .frame(width: 112)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(series) { item in
                        NavigationLink { SeriesDetailView(item: item) } label: {
                            ModernPosterCard(title: item.name, imageURL: item.cover, badge: item.rating, typeLabel: "SERIE")
                                .frame(width: 112)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var activityRail: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                streamingSectionTitle("Visti di recente")
                Spacer()
                NavigationLink { WatchHistoryView() } label: {
                    Text("Vedi tutto").font(.caption.bold()).foregroundStyle(.white.opacity(0.70))
                }
                .padding(.trailing, 16)
            }
            if session.accountWatchHistory.isEmpty {
                Text("La cronologia comparirà qui dopo la prima visione.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 9) {
                        ForEach(session.accountWatchHistory.prefix(12)) { item in
                            HistoryPosterCard(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var libraryRail: some View {
        VStack(alignment: .leading, spacing: 11) {
            streamingSectionTitle("La tua libreria")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    NavigationLink { FavoritesView() } label: { libraryButton("La mia lista", "plus", atxPrimary) }
                    NavigationLink { WatchHistoryView() } label: { libraryButton("Cronologia", "clock.arrow.circlepath", atxPrimary) }
                    Button { selectedTab = .downloads } label: { libraryButton("Download", "arrow.down", atxMint) }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
    }

    private func libraryButton(_ title: String, _ icon: String, _ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(accent)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .frame(width: 138, height: 82, alignment: .leading)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
    }

    private func streamingSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
    }

    private var isHeroFavorite: Bool {
        guard let feature else { return false }
        switch feature {
        case .movie(let item): return session.isFavorite(kind: .movies, streamID: item.streamID)
        case .series(let item): return session.isFavorite(kind: .series, streamID: item.seriesID)
        }
    }

    private func toggleHeroFavorite() {
        guard let feature else { return }
        switch feature {
        case .movie(let item):
            session.toggleFavorite(kind: .movies, streamID: item.streamID, title: item.name, imageURL: item.streamIcon, fileExtension: item.containerExtension)
        case .series(let item):
            session.toggleFavorite(kind: .series, streamID: item.seriesID, title: item.name, imageURL: item.cover)
        }
    }

    @MainActor private func pickFeature() {
        if let movie = session.allMovies.first(where: { !(($0.streamIcon ?? "").isEmpty) }) { feature = .movie(movie) }
        else if let series = session.allSeries.first(where: { !(($0.cover ?? "").isEmpty) }) { feature = .series(series) }
        else { feature = nil }
    }
}


private struct CategoriesHubView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Categorie")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 18)

                    NavigationLink { ContentBrowser(type: .movies) } label: {
                        categoryHubRow("Film", "film.fill", atxSecondary)
                    }
                    NavigationLink { ContentBrowser(type: .series) } label: {
                        categoryHubRow("Serie TV", "rectangle.stack.fill", atxPrimary)
                    }
                    NavigationLink { ContentBrowser(type: .live) } label: {
                        categoryHubRow("Diretta", "dot.radiowaves.left.and.right", atxCyan)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryHubRow(_ title: String, _ icon: String, _ accent: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(accent)
                .frame(width: 54, height: 54)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
    }
}

private struct DiscoverV4: View {
    @EnvironmentObject var session: AppSession
    @State private var showSearch = false

    var body: some View {
        ZStack {
            StreamingBackdrop()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SCOPRI").font(.caption2.weight(.black)).tracking(1.8).foregroundStyle(atxCyan)
                        Text("Cosa vuoi guardare?").font(.system(size: 31, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("Tutto il catalogo AtlantiX in un unico posto.").font(.caption).foregroundStyle(.white.opacity(0.46))
                    }
                    .padding(.horizontal, 18).padding(.top, 18)

                    Button { showSearch = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass").font(.headline.bold())
                            Text("Cerca canali, film, serie...").foregroundStyle(.white.opacity(0.42))
                            Spacer()
                        }
                        .padding(.horizontal, 16).frame(height: 54)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07)))
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)

                    NavigationLink { ContentBrowser(type: .movies) } label: { discoverHero("Film", "film.stack.fill", session.allMovies.count, atxSecondary) }
                    NavigationLink { ContentBrowser(type: .series) } label: { discoverHero("Serie TV", "rectangle.stack.fill", session.allSeries.count, atxPrimary) }
                    NavigationLink { FavoritesView() } label: { discoverHero("La mia lista", "heart.fill", session.accountFavorites.count, atxPrimary) }
                    NavigationLink { WatchHistoryView() } label: { discoverHero("Cronologia", "clock.arrow.circlepath", session.accountWatchHistory.count, atxCyan) }
                    Spacer(minLength: 110)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSearch) { NavigationStack { GlobalSearchView() } }
    }

    private func discoverHero(_ title: String, _ icon: String, _ count: Int, _ accent: Color) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon).font(.title2.bold()).foregroundStyle(accent)
                .frame(width: 58, height: 58).background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.black)).foregroundStyle(.white)
                Text("\(count.formatted()) contenuti").font(.caption).foregroundStyle(.white.opacity(0.43))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.headline.bold()).foregroundStyle(.white.opacity(0.24))
        }
        .padding(16)
        .background(atxSurface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.07)))
        .padding(.horizontal, 16)
    }
}

struct HomeView: View {
    @EnvironmentObject var session: AppSession
    @State private var featuredIndex = 0
    @State private var showSearch = false

    // Home data is snapshotted only when the playlist/history really changes.
    // This avoids sorting and filtering thousands of items during every scroll redraw.
    @State private var features: [FeaturedContent] = []
    @State private var recentMovies: [VODStream] = []
    @State private var recentSeries: [SeriesItem] = []
    @State private var recommendedSeries: [SeriesItem] = []
    @State private var topRatedMovies: [VODStream] = []
    @State private var trendingSeries: [SeriesItem] = []

    private var featured: FeaturedContent? {
        guard !features.isEmpty else { return nil }
        return features[min(featuredIndex, features.count - 1)]
    }

    private var homeDataVersion: String {
        [
            session.allMovies.count,
            session.allSeries.count,
            session.accountWatchHistory.count,
            session.accountFavorites.count
        ].map(String.init).joined(separator: "-")
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .zIndex(20)
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        hero
                            .zIndex(0)
                        quickActions
                        if !session.accountWatchHistory.isEmpty { historyRail }
                        if !session.continueWatching.isEmpty { continueWatchingRail }
                        if !trendingSeries.isEmpty { customSeriesRail("In tendenza", trendingSeries) }
                        if !recentMovies.isEmpty { movieRail }
                        if !topRatedMovies.isEmpty { customMovieRail("Più votati", topRatedMovies) }
                        if !recommendedSeries.isEmpty { customSeriesRail("Consigliati per te", recommendedSeries) }
                        if !session.accountFavorites.isEmpty { favoritesRail }
                        if !recentSeries.isEmpty { seriesRail }
                        updateStatus
                    }
                    .padding(.top, 0)
                    .padding(.bottom, 110)
                }
                
            }
            if session.isRefreshing { loadingOverlay.zIndex(50) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSearch) { NavigationStack { GlobalSearchView() } }
        .alert("Attenzione", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
        .task(id: homeDataVersion) {
            rebuildHomeSnapshot()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, features.count > 1, !session.isRefreshing else { continue }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        featuredIndex = (featuredIndex + 1) % features.count
                    }
                }
            }
        }
    }

    @MainActor
    private func rebuildHomeSnapshot() {
        let sortedMovies = session.allMovies.sorted {
            numericDateValue($0.added) > numericDateValue($1.added)
        }
        let sortedSeries = session.allSeries.sorted {
            seriesSortValue($0) > seriesSortValue($1)
        }

        recentMovies = Array(sortedMovies.prefix(10))
        recentSeries = Array(sortedSeries.prefix(10))

        let featureMovies = sortedMovies
            .filter { !(($0.streamIcon ?? "").isEmpty) }
            .prefix(4)
            .map(FeaturedContent.movie)
        let featureSeries = sortedSeries
            .filter { !(($0.cover ?? "").isEmpty) }
            .prefix(4)
            .map(FeaturedContent.series)
        features = Array(featureMovies) + Array(featureSeries)
        if featuredIndex >= features.count { featuredIndex = 0 }

        topRatedMovies = Array(session.allMovies.sorted {
            (Double($0.rating ?? "") ?? 0) > (Double($1.rating ?? "") ?? 0)
        }.prefix(8))

        let seriesByID = Dictionary(uniqueKeysWithValues: session.allSeries.map { ($0.seriesID, $0) })
        let watchedSeries = session.accountWatchHistory
            .filter { $0.kind == ContentType.series.rawValue }
            .compactMap { seriesByID[$0.streamID] }
        let favoriteSeries = session.accountFavorites
            .filter { $0.kind == ContentType.series.rawValue }
            .compactMap { seriesByID[$0.streamID] }

        trendingSeries = deduplicatedSeries(watchedSeries + recentSeries, limit: 8)
        recommendedSeries = deduplicatedSeries(favoriteSeries + recentSeries, limit: 8)
    }

    private func deduplicatedSeries(_ items: [SeriesItem], limit: Int) -> [SeriesItem] {
        var seen = Set<Int>()
        return Array(items.filter { seen.insert($0.seriesID).inserted }.prefix(limit))
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(brandGradient).frame(width: 42, height: 42)
                BrandMark(size: 27)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("ATLANTIX").font(.system(size: 14, weight: .black)).tracking(2.1).foregroundStyle(.white)
                Text("Ciao, \(session.username)").font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.46)).lineLimit(1)
            }
            Spacer()
            compactCircleButton("magnifyingglass") { showSearch = true }
            compactCircleButton(session.isRefreshing ? "hourglass" : "arrow.clockwise") { Task { await session.refreshSafely() } }.disabled(session.isRefreshing)
            NavigationLink { SettingsView() } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: Circle())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.86))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }


    private var lastUpdateText: String {
        guard let date = session.lastRefresh else { return "Playlist pronta" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "'Aggiornato oggi alle' HH:mm" : "'Aggiornato il' dd/MM 'alle' HH:mm"
        return formatter.string(from: date)
    }

    private var lastUpdateCompactText: String {
        guard let date = session.lastRefresh else { return "Playlist pronta" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "'oggi' HH:mm" : "dd/MM HH:mm"
        return formatter.string(from: date)
    }

    private var accountShortcuts: some View {
        HStack(spacing: 14) {
            NavigationLink { FavoritesView() } label: {
                shortcutCard(
                    title: "La mia lista",
                    subtitle: session.accountFavorites.isEmpty ? "Nessun preferito" : "\(session.accountFavorites.count) contenuti",
                    icon: session.accountFavorites.isEmpty ? "heart" : "heart.fill",
                    accent: atxPrimary
                )
            }
            .buttonStyle(.plain)

            NavigationLink { WatchHistoryView() } label: {
                shortcutCard(
                    title: "Cronologia",
                    subtitle: session.accountWatchHistory.isEmpty ? "Nessun contenuto" : "\(session.accountWatchHistory.count) visti",
                    icon: "clock.arrow.circlepath",
                    accent: atxPrimary
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
        .background(Color.white.opacity(0.06))
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
                    .foregroundStyle(icon == "heart.fill" ? atxPrimary : Color.primary)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.08)))
                if badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(atxPrimary)
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

    private func compactCircleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.headline.bold())
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .zIndex(30)
    }

    @ViewBuilder private var hero: some View {
        if let featured {
            ZStack(alignment: .bottomLeading) {
                OptimizedAsyncImage(url: URL(string: featured.imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { heroFallback }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 500)
                .clipped()
                LinearGradient(colors: [.clear, Color.black.opacity(0.05), Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [Color.black.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)

                VStack(alignment: .leading, spacing: 12) {
                    Text(featured.title.uppercased())
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(featured.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        NavigationLink { featured.destination(session: session) } label: {
                            Label("Guarda", systemImage: "play.fill")
                                .font(.subheadline.bold()).foregroundStyle(.black)
                                .padding(.horizontal, 20).frame(height: 46)
                                .background(Color.white, in: Capsule())
                        }
                        NavigationLink { featured.destination(session: session) } label: {
                            Image(systemName: "info.circle.fill").font(.title3).foregroundStyle(.white)
                                .frame(width: 46, height: 46).background(Color.white.opacity(0.15), in: Circle())
                        }
                        Button { toggleFeaturedFavorite(featured) } label: {
                            Image(systemName: isFeaturedFavorite(featured) ? "checkmark" : "plus")
                                .font(.title3.bold()).foregroundStyle(.white)
                                .frame(width: 46, height: 46).background(Color.white.opacity(0.15), in: Circle())
                        }.buttonStyle(.plain)
                    }
                    if features.count > 1 {
                        HStack(spacing: 5) {
                            ForEach(0..<min(features.count, 8), id: \.self) { index in
                                Capsule().fill(index == featuredIndex % features.count ? Color.white : Color.white.opacity(0.30))
                                    .frame(width: index == featuredIndex % features.count ? 24 : 6, height: 5)
                            }
                        }.padding(.top, 2)
                    }
                }
                .padding(20)
            }
            .frame(height: 500)
            .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        } else {
            heroFallback.frame(height: 420)
        }
    }


    private func isFeaturedFavorite(_ featured: FeaturedContent) -> Bool {
        switch featured {
        case .movie(let item): return session.isFavorite(kind: .movies, streamID: item.streamID)
        case .series(let item): return session.isFavorite(kind: .series, streamID: item.seriesID)
        }
    }

    private func toggleFeaturedFavorite(_ featured: FeaturedContent) {
        switch featured {
        case .movie(let item):
            session.toggleFavorite(kind: .movies, streamID: item.streamID, title: item.name, imageURL: item.streamIcon, fileExtension: item.containerExtension)
        case .series(let item):
            session.toggleFavorite(kind: .series, streamID: item.seriesID, title: item.name, imageURL: item.cover)
        }
    }

    private var heroFallback: some View {
        LinearGradient(colors: [atxSecondary, atxPrimary, Color(red: 0.04, green: 0.05, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.subheadline.bold()).foregroundStyle(atxPrimary)
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis").font(.caption2).foregroundStyle(.secondary)
            }
            Text(value.formatted()).font(.system(size: 24, weight: .black, design: .rounded))
            Text(title.uppercased()).font(.system(size: 9, weight: .black)).tracking(1).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(atxStroke))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Scopri")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickLink("Diretta", "dot.radiowaves.left.and.right", .live)
                    quickLink("Film", "film.fill", .movies)
                    quickLink("Serie", "rectangle.stack.fill", .series)
                    NavigationLink { FavoritesView() } label: {
                        Label("La mia lista", systemImage: "heart.fill")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 16).frame(height: 46)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.08)))
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 16)
            }
        }
    }


    private func quickLink(_ title: String, _ icon: String, _ type: ContentType) -> some View {
        NavigationLink { ContentBrowser(type: type) } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline.bold())
                Text(title).font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).frame(height: 46)
            .background(type == .live ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.white.opacity(0.08)), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08)))
        }.buttonStyle(.plain)
    }


    private var favoritesRail: some View {
        MediaRail(title: "La mia lista") {
            ForEach(session.accountFavorites.prefix(8)) { favorite in
                favoriteHomeLink(favorite)
            }
            NavigationLink { FavoritesView() } label: {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 34))
                    Text("Vedi tutti").font(.subheadline.bold())
                }
                .foregroundStyle(atxPrimary)
                .frame(width: 138, height: 205)
                .background(Color.white.opacity(0.06))
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
            ForEach(Array(session.accountWatchHistory.prefix(8))) { item in
                HistoryPosterCard(item: item)
            }
            NavigationLink { WatchHistoryView() } label: {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath").font(.title)
                    Text("Vedi tutto").font(.caption.bold())
                }
                .foregroundStyle(.primary)
                .frame(width: 120, height: 176)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var continueWatchingRail: some View {
        MediaRail(title: "Continua a guardare") {
            ForEach(session.continueWatching.prefix(8)) { progress in
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

    private func sectionTitle(_ title: String) -> some View { HStack(spacing: 6) { Text(title).font(.title3.bold()); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary) }.padding(.horizontal, 20) }
    private var loadingOverlay: some View {
        Color.black.opacity(0.42).ignoresSafeArea().overlay(
            VStack(spacing: 14) { ProgressView().scaleEffect(1.25).tint(.white); Text("Aggiornamento playlist…").font(.headline).foregroundStyle(.primary) }
                .padding(26).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        )
    }
}

private func customMovieRail(_ title: String, _ items: [VODStream]) -> some View {
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

private func customSeriesRail(_ title: String, _ items: [SeriesItem]) -> some View {
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
            HStack(spacing: 6) { Text(title).font(.title3.bold()); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary) }.foregroundStyle(.primary).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) { LazyHStack(spacing: 10) { content }.padding(.horizontal, 20) }
        }
    }
}

struct ContentBrowser: View {
    @EnvironmentObject var session: AppSession
    let type: ContentType
    @State private var search = ""

    private var categories: [Category] {
        type == .live ? session.liveCategories : type == .movies ? session.movieCategories : session.seriesCategories
    }
    private var title: String { type == .live ? "Diretta" : type == .movies ? "Film" : "Serie TV" }
    private var filtered: [Category] {
        search.isEmpty ? categories : categories.filter { $0.categoryName.localizedCaseInsensitiveContains(search) }
    }
    private var totalCount: Int {
        type == .live ? session.allLive.count : type == .movies ? session.allMovies.count : session.allSeries.count
    }
    private let tiles = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    searchField

                    NavigationLink { ItemGrid(type: type, category: nil) } label: {
                        ZStack(alignment: .bottomLeading) {
                            Rectangle().fill(LinearGradient(colors: [atxPrimary.opacity(0.82), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TUTTO")
                                    .font(.caption2.weight(.black)).tracking(1.5).foregroundStyle(.white.opacity(0.72))
                                Text("Tutto il catalogo")
                                    .font(.title3.weight(.black)).foregroundStyle(.white)
                                Text("\(totalCount.formatted()) contenuti")
                                    .font(.caption).foregroundStyle(.white.opacity(0.62))
                            }
                            .padding(16)
                        }
                        .frame(height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    Text("Categorie")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: tiles, spacing: 10) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, category in
                            NavigationLink { ItemGrid(type: type, category: category) } label: {
                                categoryTile(category, index: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [atxPrimary.opacity(0.34), Color.black.opacity(0.94)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 170)
            VStack(alignment: .leading, spacing: 7) {
                BrandMark(size: 34)
                Text(title)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(type == .live ? "Tutto ciò che è in onda, adesso." : type == .movies ? "Film, novità e titoli da scoprire." : "Serie, stagioni ed episodi in un unico posto.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.60))
                Text("\(totalCount.formatted()) contenuti • \(categories.count.formatted()) categorie")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.50))
            TextField("Cerca categorie", text: $search)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.45)) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    private func categoryCount(_ category: Category) -> Int {
        if type == .live { return session.allLive.filter { $0.categoryID == category.categoryID }.count }
        if type == .movies { return session.allMovies.filter { $0.categoryID == category.categoryID }.count }
        return session.allSeries.filter { $0.categoryID == category.categoryID }.count
    }

    private func categoryTile(_ category: Category, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: index.isMultiple(of: 3) ? [atxPrimary.opacity(0.58), atxSurface] : [atxSurfaceSoft, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: type == .live ? "dot.radiowaves.left.and.right" : type == .movies ? "film.fill" : "rectangle.stack.fill")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(.white.opacity(0.10))
                .offset(x: 76, y: -28)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.categoryName)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(categoryCount(category).formatted()) contenuti")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(14)
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
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
    @State private var visibleLive: [LiveStream] = []
    @State private var visibleVOD: [VODStream] = []
    @State private var visibleSeries: [SeriesItem] = []
    private var columns: [GridItem] {
        type == .live
        ? [GridItem(.flexible(), spacing: 14)]
        : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        ZStack {
            StreamingBackdrop()
            if type == .live {
                VStack(spacing: 0) {
                    itemHeader
                    inlineSearch
                    gridContent(topPadding: 16)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        catalogHero
                        catalogControls

                        if loading {
                            ProgressView("Caricamento…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 80)
                        } else if let error {
                            EmptyStateView(title: "Errore", icon: "wifi.exclamationmark", message: error)
                                .padding(.vertical, 45)
                        } else if resultCount == 0 {
                            EmptyStateView(title: "Nessun risultato", icon: "magnifyingglass", message: "Prova con un altro termine di ricerca.")
                                .padding(.vertical, 45)
                        } else {
                            HStack {
                                Text(search.isEmpty ? "Tutti i titoli" : "Risultati")
                                    .font(.title3.weight(.black))
                                Spacer()
                                Text("\(resultCount.formatted())")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.07), in: Capsule())
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 22)
                            .padding(.bottom, 14)

                            LazyVGrid(columns: columns, spacing: 22) { contentCards }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 125)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load(forceNetwork: false) }
        .onChange(of: search) { _ in rebuildVisibleItems() }
        .onChange(of: newestFirst) { _ in rebuildVisibleItems() }
    }

    @ViewBuilder
    private func gridContent(topPadding: CGFloat) -> some View {
        Group {
            if loading { Spacer(); ProgressView("Caricamento…"); Spacer() }
            else if let error { Spacer(); EmptyStateView(title: "Errore", icon: "wifi.exclamationmark", message: error); Spacer() }
            else if resultCount == 0 { Spacer(); EmptyStateView(title: "Nessun risultato", icon: "magnifyingglass", message: "Prova con un altro termine di ricerca."); Spacer() }
            else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 18) { contentCards }
                        .padding(.horizontal, 16)
                        .padding(.top, topPadding)
                        .padding(.bottom, 125)
                }
            }
        }
    }

    private var catalogHeroImage: String? {
        if type == .movies { return visibleVOD.first?.streamIcon ?? vod.first?.streamIcon }
        return visibleSeries.first?.cover ?? series.first?.cover
    }

    private var catalogHero: some View {
        ZStack(alignment: .bottomLeading) {
            OptimizedAsyncImage(url: URL(string: catalogHeroImage ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { accentGradient(for: category?.categoryName ?? "Atlantix") }
            }
            .frame(maxWidth: .infinity).frame(height: 280).clipped()
            LinearGradient(colors: [Color.black.opacity(0.08), Color.black.opacity(0.96)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 9) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.headline.bold()).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(Color.black.opacity(0.46), in: Circle())
                }.buttonStyle(.plain).padding(.bottom, 45)
                Text(type == .movies ? "FILM" : "SERIE TV").font(.caption2.weight(.black)).tracking(1.5).foregroundStyle(atxCyan)
                Text(category?.categoryName ?? "Tutti i contenuti").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                Text("\(resultCount.formatted()) titoli").font(.caption).foregroundStyle(.white.opacity(0.55))
            }.padding(18)
        }.frame(height: 280)
    }


    private var catalogControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.40))
                TextField(type == .movies ? "Cerca film" : "Cerca serie", text: $search).foregroundStyle(.white).textInputAutocapitalization(.never).autocorrectionDisabled()
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.35)) } }
            }
            .padding(.horizontal, 14).frame(height: 48).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
            Menu {
                Button { newestFirst = true } label: { Label("Più recenti", systemImage: newestFirst ? "checkmark" : "clock") }
                Button { newestFirst = false } label: { Label("Meno recenti", systemImage: !newestFirst ? "checkmark" : "clock.arrow.circlepath") }
            } label: {
                Image(systemName: "arrow.up.arrow.down").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 48, height: 48).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
            }
        }.padding(.horizontal, 16).padding(.top, 14)
    }


    private var itemHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 48, height: 48).background(Color.white.opacity(0.08), in: Circle())
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(category?.categoryName ?? "Tutti i canali").font(.title3.weight(.black)).foregroundStyle(.white).lineLimit(1)
                Text("\(resultCount.formatted()) canali live").font(.caption).foregroundStyle(.white.opacity(0.45))
            }
            Spacer(); Circle().fill(Color.red).frame(width: 8, height: 8)
        }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
    }


    private var inlineSearch: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.42))
            TextField("Cerca canale", text: $search).foregroundStyle(.white).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.35)) } }
        }.padding(.horizontal, 14).frame(height: 48).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 16)
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
                .font(.subheadline.weight(.semibold)).foregroundStyle(atxPrimary)
            }
        }
        .padding(.horizontal, 18).padding(.top, 12)
    }

    private var resultCount: Int {
        if type == .live { return visibleLive.count }
        if type == .movies { return visibleVOD.count }
        return visibleSeries.count
    }

    @ViewBuilder private var contentCards: some View {
        if type == .live {
            ForEach(visibleLive) { item in
                NavigationLink { LiveDetailView(item: item) } label: { LiveChannelCard(item: item) }.buttonStyle(.plain)
            }
        } else if type == .movies {
            ForEach(visibleVOD) { item in
                NavigationLink { MovieDetailView(item: item) } label: { ModernPosterCard(title: item.name, imageURL: item.streamIcon, badge: item.rating, typeLabel: "FILM") }.buttonStyle(.plain)
            }
        } else {
            ForEach(visibleSeries) { item in
                NavigationLink { SeriesDetailView(item: item) } label: { ModernPosterCard(title: item.name, imageURL: item.cover, badge: item.rating, typeLabel: "SERIE") }.buttonStyle(.plain)
            }
        }
    }

    private func matchLive(_ x: LiveStream) -> Bool { search.isEmpty || x.name.localizedCaseInsensitiveContains(search) }
    private func matchMovie(_ x: VODStream) -> Bool { search.isEmpty || x.name.localizedCaseInsensitiveContains(search) || (x.genre ?? "").localizedCaseInsensitiveContains(search) }
    private func matchSeries(_ x: SeriesItem) -> Bool { search.isEmpty || x.name.localizedCaseInsensitiveContains(search) || (x.genre ?? "").localizedCaseInsensitiveContains(search) }

    private func rebuildVisibleItems() {
        switch type {
        case .live:
            visibleLive = live.filter(matchLive)
        case .movies:
            visibleVOD = vod.filter(matchMovie).sorted {
                newestFirst ? numericDateValue($0.added) > numericDateValue($1.added) : numericDateValue($0.added) < numericDateValue($1.added)
            }
        case .series:
            visibleSeries = series.filter(matchSeries).sorted {
                newestFirst ? seriesSortValue($0) > seriesSortValue($1) : seriesSortValue($0) < seriesSortValue($1)
            }
        }
    }

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
        rebuildVisibleItems()
        loading = false
    }
}

struct ModernPosterCard: View {
    let title: String
    let imageURL: String?
    let badge: String?
    let typeLabel: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                OptimizedAsyncImage(url: URL(string: imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { accentGradient(for: title) }
                }
                .aspectRatio(0.67, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .trailing, spacing: 4) {
                    if let badge, !badge.isEmpty {
                        Text("★ \(badge)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(Color.black.opacity(0.74), in: Capsule())
                    }
                    Text(typeLabel)
                        .font(.system(size: 7, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(atxPrimary, in: Capsule())
                }
                .padding(6)
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}
struct LiveChannelCard: View {
    let item: LiveStream
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.075, green: 0.075, blue: 0.08))
            HStack(spacing: 13) {
                OptimizedAsyncImage(url: URL(string: item.streamIcon ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFit().padding(9) }
                    else { Image(systemName: "tv.fill").font(.title2).foregroundStyle(.white.opacity(0.62)) }
                }
                .frame(width: 78, height: 60)
                .background(Color.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(atxPrimary).frame(width: 7, height: 7)
                        Text("LIVE").font(.system(size: 9, weight: .black)).tracking(1.2).foregroundStyle(atxPrimary)
                    }
                    Text(item.name).font(.headline.weight(.bold)).foregroundStyle(.white).lineLimit(2)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.caption.bold()).foregroundStyle(.black)
                    .frame(width: 40, height: 40).background(Color.white, in: Circle())
            }
            .padding(12)
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.07), lineWidth: 1))
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
                OptimizedAsyncImage(url: URL(string: imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { ZStack { brandGradient; Image(systemName: landscape ? "tv.fill" : "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.75)) } }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(landscape ? 1.45 : 0.70, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous)).clipped()
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
                OptimizedAsyncImage(url: URL(string: progress.imageURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { ZStack { brandGradient; Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8)) } }
                }
                .frame(width: 230, height: 130)
                .clipped()

                VStack(spacing: 0) {
                    Spacer()
                    ProgressView(value: progress.fraction)
                        .tint(atxPrimary)
                        .background(Color.white.opacity(0.25))
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
    @Environment(\.dismiss) private var dismiss
    let item: VODStream
    @State private var details: VODInfoResponse?
    @State private var loadingInfo = true
    @State private var showTrailer = false

    private var info: VODDetails? { details?.info }
    private var title: String { info?.name ?? item.name }
    private var imageURL: String? { info?.movieImage ?? item.streamIcon }
    private var plot: String? { info?.plot ?? item.plot }
    private var genre: String? { info?.genre ?? item.genre }
    private var castNames: [String] {
        Array((info?.cast ?? item.cast ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(10))
    }
    private var trailerURL: URL? { normalizedTrailerURL(info?.youtubeTrailer) }
    private var movieID: Int { details?.movieData?.streamID ?? item.streamID }
    private var movieExt: String? { details?.movieData?.containerExtension ?? item.containerExtension }
    private var descriptor: PlaybackDescriptor { PlaybackDescriptor(kind: .movies, streamID: movieID, title: title, subtitle: "Film", imageURL: imageURL, fileExtension: movieExt) }
    private var relatedMovies: [VODStream] {
        guard let genre, !genre.isEmpty else { return [] }
        let tokens = genre.lowercased().split(separator: ",").map(String.init)
        return Array(session.allMovies.filter { movie in
            movie.streamID != item.streamID && tokens.contains { (movie.genre ?? "").lowercased().contains($0.trimmingCharacters(in: .whitespaces)) }
        }.prefix(14))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    hero
                    primaryActions

                    if let plot, !plot.isEmpty {
                        Text(plot)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineSpacing(4)
                            .padding(.horizontal, 16)
                    }

                    metadata

                    if !castNames.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Cast").font(.headline.bold()).foregroundStyle(.white)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(castNames, id: \.self) { actor in
                                        NavigationLink { ActorView(name: actor) } label: {
                                            Text(actor).font(.caption.weight(.semibold)).foregroundStyle(.white)
                                                .padding(.horizontal, 12).frame(height: 34)
                                                .background(Color.white.opacity(0.09), in: Capsule())
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }.padding(.horizontal, 16)
                    }

                    if !relatedMovies.isEmpty { customMovieRail("Altri titoli simili", relatedMovies) }
                }
                .padding(.bottom, 110)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Color.black.opacity(0.58), in: Circle())
            }.buttonStyle(.plain).padding(.leading, 14).padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            if loadingInfo { ProgressView().tint(.white).padding(20) }
        }
        .task {
            details = try? await APIClient.shared.vodInfo(baseURL: session.baseURL, username: session.username, password: session.password, vodID: item.streamID)
            loadingInfo = false
        }
        .sheet(isPresented: $showTrailer) { if let trailerURL { SafariView(url: trailerURL).ignoresSafeArea() } }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            OptimizedAsyncImage(url: URL(string: imageURL ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { accentGradient(for: title) }
            }
            .frame(height: 500).frame(maxWidth: .infinity).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.14), .black.opacity(0.92), .black], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text("FILM").font(.caption2.weight(.black)).tracking(1.6).foregroundStyle(atxPrimary)
                Text(title).font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(3)
                HStack(spacing: 8) {
                    if let rating = info?.rating ?? item.rating, !rating.isEmpty { Text("★ \(rating)") }
                    if let duration = info?.duration ?? item.duration, !duration.isEmpty { Text(duration) }
                    if let genre, !genre.isEmpty { Text(genre.components(separatedBy: ",").first ?? genre) }
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.72))
            }.padding(.horizontal, 16).padding(.bottom, 18)
        }
    }

    private var primaryActions: some View {
        VStack(spacing: 10) {
            NavigationLink {
                PlayerScreen(title: title, url: session.streamURL(type: .movies, id: movieID, ext: movieExt), isLive: false, resume: descriptor)
            } label: {
                Label(session.savedProgress(for: descriptor) == nil ? "Riproduci" : "Riprendi", systemImage: "play.fill")
                    .font(.headline.bold()).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 48).background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)

            HStack(spacing: 8) {
                Button {
                    session.toggleFavorite(kind: .movies, streamID: item.streamID, title: item.name, imageURL: item.streamIcon, fileExtension: item.containerExtension)
                } label: {
                    Label(session.isFavorite(kind: .movies, streamID: item.streamID) ? "Nella mia lista" : "La mia lista", systemImage: session.isFavorite(kind: .movies, streamID: item.streamID) ? "checkmark" : "plus")
                        .frame(maxWidth: .infinity)
                }
                if trailerURL != nil {
                    Button { showTrailer = true } label: { Label("Trailer", systemImage: "play.rectangle") .frame(maxWidth: .infinity) }
                }
            }
            .font(.subheadline.bold()).foregroundStyle(.white)
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            DownloadActionButton(title: title, subtitle: "Film", imageURL: imageURL, remoteURL: session.streamURL(type: .movies, id: movieID, ext: movieExt), fileExtension: movieExt ?? "mp4")
        }
        .padding(.horizontal, 16)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let director = info?.director ?? item.director, !director.isEmpty {
                HStack(alignment: .top) { Text("Regia:").foregroundStyle(.white.opacity(0.45)); Text(director).foregroundStyle(.white.opacity(0.78)) }
            }
            if let genre, !genre.isEmpty {
                HStack(alignment: .top) { Text("Generi:").foregroundStyle(.white.opacity(0.45)); Text(genre).foregroundStyle(.white.opacity(0.78)) }
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
    }
}

struct ActorView: View {
    @EnvironmentObject var session: AppSession
    let name: String
    private var movies: [VODStream] { Array(session.allMovies.filter { ($0.cast ?? "").localizedCaseInsensitiveContains(name) }.prefix(30)) }
    private var series: [SeriesItem] { Array(session.allSeries.filter { ($0.cast ?? "").localizedCaseInsensitiveContains(name) }.prefix(30)) }
    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 74)).foregroundStyle(accentGradient(for: name))
                        VStack(alignment: .leading) { Text(name).font(.title.bold()); Text("Filmografia disponibile").foregroundStyle(.secondary) }
                    }.padding(.horizontal)
                    if !movies.isEmpty { customMovieRail("Film", movies) }
                    if !series.isEmpty { customSeriesRail("Serie TV", series) }
                    if movies.isEmpty && series.isEmpty { EmptyStateView(title: "Nessun contenuto", icon: "person.crop.circle.badge.questionmark", message: "Non sono presenti altri titoli associati a questo interprete.") }
                }.padding(.vertical)
            }
        }.navigationTitle(name).navigationBarTitleDisplayMode(.inline)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}

struct LiveDetailView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let item: LiveStream
    @State private var epg: [EPGListing] = []
    @State private var loadingEPG = true
    @State private var epgError: String?

    private var currentProgram: EPGListing? {
        let now = Date().timeIntervalSince1970
        return epg.first { listing in
            guard let start = listing.startTimestamp.flatMap(TimeInterval.init), let stop = listing.stopTimestamp.flatMap(TimeInterval.init) else { return false }
            return start <= now && now < stop
        } ?? epg.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    hero
                    actions
                    if let program = currentProgram { nowPlaying(program) }
                    Text("Programmazione").font(.system(size: 22, weight: .black)).foregroundStyle(.white).padding(.horizontal, 16)
                    epgSection.padding(.horizontal, 16)
                }
                .padding(.bottom, 110)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: { Image(systemName: "chevron.left").font(.headline.bold()).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.black.opacity(0.58), in: Circle()) }
                .buttonStyle(.plain).padding(.leading, 14).padding(.top, 8)
        }
        .task { await loadEPG() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [atxPrimary.opacity(0.30), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
            OptimizedAsyncImage(url: URL(string: item.streamIcon ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFit().padding(55) }
                else { BrandMark(size: 92) }
            }
            .frame(maxWidth: .infinity).frame(height: 330)
            LinearGradient(colors: [.clear, Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) { Circle().fill(atxPrimary).frame(width: 8, height: 8); Text("IN DIRETTA").font(.caption2.weight(.black)).tracking(1.2).foregroundStyle(atxPrimary) }
                Text(item.name).font(.system(size: 30, weight: .black)).foregroundStyle(.white).lineLimit(3)
            }.padding(16)
        }.frame(height: 330)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            NavigationLink { PlayerScreen(title: item.name, url: directURL, isLive: true) } label: {
                Label("Riproduci", systemImage: "play.fill").font(.headline.bold()).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 48).background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)
            Button {
                session.toggleFavorite(kind: .live, streamID: item.streamID, title: item.name, imageURL: item.streamIcon)
            } label: {
                Image(systemName: session.isFavorite(kind: .live, streamID: item.streamID) ? "checkmark" : "plus")
                    .font(.headline.bold()).foregroundStyle(.white).frame(width: 48, height: 48).background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)
        }.padding(.horizontal, 16)
    }

    private func nowPlaying(_ program: EPGListing) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ORA IN ONDA").font(.caption2.weight(.black)).tracking(1.2).foregroundStyle(atxPrimary)
            Text(program.title ?? "Programma in corso").font(.title3.bold()).foregroundStyle(.white)
            Text(timeRange(program)).font(.caption).foregroundStyle(.white.opacity(0.50))
            if let description = program.description, !description.isEmpty { Text(description).font(.subheadline).foregroundStyle(.white.opacity(0.68)).lineLimit(4) }
        }.padding(.horizontal, 16)
    }

    @ViewBuilder private var epgSection: some View {
        if loadingEPG { HStack { Spacer(); ProgressView("Caricamento…").tint(.white); Spacer() }.padding(.vertical, 28) }
        else if let epgError { EmptyStateView(title: "EPG non disponibile", icon: "calendar.badge.exclamationmark", message: epgError) }
        else if epg.isEmpty { EmptyStateView(title: "Nessuna programmazione", icon: "calendar", message: "Il server non ha fornito la guida TV per questo canale.") }
        else {
            LazyVStack(spacing: 0) {
                ForEach(Array(epg.enumerated()), id: \.element.listID) { index, program in
                    EPGProgramRow(program: program, isCurrent: program.listID == currentProgram?.listID)
                    if index < epg.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
                }
            }
        }
    }

    private func loadEPG() async {
        loadingEPG = true; epgError = nil
        do { epg = try await APIClient.shared.shortEPG(baseURL: session.baseURL, username: session.username, password: session.password, streamID: item.streamID, limit: 12) }
        catch { epgError = error.localizedDescription }
        loadingEPG = false
    }
    private func timeRange(_ program: EPGListing) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        if let start = program.startTimestamp.flatMap(TimeInterval.init), let stop = program.stopTimestamp.flatMap(TimeInterval.init) {
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
                Text(startTime).font(.headline.monospacedDigit()).foregroundStyle(isCurrent ? atxPrimary : .primary)
                Text(endTime).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(width: 54, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(isCurrent ? atxPrimary : Color.secondary.opacity(0.25))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(program.title ?? "Programma").font(.headline).foregroundStyle(.primary).lineLimit(2)
                    Spacer()
                    if isCurrent { Text("ORA").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4).background(atxPrimary).clipShape(Capsule()) }
                }
                if let description = program.description, !description.isEmpty {
                    Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isCurrent ? atxPrimary.opacity(0.45) : Color.primary.opacity(0.05)))
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
    @Environment(\.dismiss) private var dismiss
    let item: SeriesItem
    @State private var info: SeriesInfoResponse?
    @State private var selectedSeason = ""
    @State private var loading = true
    @State private var error: String?

    private var seasons: [String] { (info?.episodes.keys.map { $0 } ?? []).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) } }
    private var episodes: [Episode] { info?.episodes[selectedSeason] ?? [] }
    private var details: SeriesDetails? { info?.info }
    private var title: String { details?.name ?? item.name }
    private var cover: String? { details?.cover ?? item.cover }
    private var plot: String? { details?.plot ?? item.plot }
    private var genre: String? { details?.genre ?? item.genre }
    private var seriesCast: [String] {
        Array((details?.cast ?? item.cast ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(10))
    }
    private var relatedSeries: [SeriesItem] {
        guard let genre, !genre.isEmpty else { return [] }
        let tokens = genre.lowercased().split(separator: ",").map(String.init)
        return Array(session.allSeries.filter { candidate in
            candidate.seriesID != item.seriesID && tokens.contains { (candidate.genre ?? "").lowercased().contains($0.trimmingCharacters(in: .whitespaces)) }
        }.prefix(14))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    hero
                    actions

                    if let plot, !plot.isEmpty {
                        Text(plot).font(.subheadline).foregroundStyle(.white.opacity(0.72)).lineSpacing(4).padding(.horizontal, 16)
                    }

                    if !seriesCast.isEmpty { castRail }

                    if loading {
                        ProgressView("Caricamento stagioni…").tint(.white).frame(maxWidth: .infinity).padding(30)
                    } else if let error {
                        EmptyStateView(title: "Episodi non disponibili", icon: "rectangle.stack.badge.exclamationmark", message: error)
                    } else if seasons.isEmpty {
                        EmptyStateView(title: "Nessun episodio", icon: "rectangle.stack", message: "Il server non ha restituito stagioni o episodi per questa serie.")
                    } else {
                        seasonBar
                        Text("Episodi")
                            .font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 16)
                        LazyVStack(spacing: 0) {
                            ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                                episodeLine(episode, index: index)
                                if index < episodes.count - 1 { Divider().overlay(Color.white.opacity(0.08)).padding(.leading, 146) }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !relatedSeries.isEmpty { customSeriesRail("Altre serie simili", relatedSeries) }
                }
                .padding(.bottom, 110)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Color.black.opacity(0.58), in: Circle())
            }.buttonStyle(.plain).padding(.leading, 14).padding(.top, 8)
        }
        .task { await load() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            OptimizedAsyncImage(url: URL(string: cover ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { accentGradient(for: title) }
            }
            .frame(height: 500).frame(maxWidth: .infinity).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.18), .black.opacity(0.94), .black], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text("SERIE TV").font(.caption2.weight(.black)).tracking(1.6).foregroundStyle(atxPrimary)
                Text(title).font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(3)
                HStack(spacing: 8) {
                    if let rating = details?.rating ?? item.rating, !rating.isEmpty { Text("★ \(rating)") }
                    if let genre, !genre.isEmpty { Text(genre.components(separatedBy: ",").first ?? genre) }
                    if !seasons.isEmpty { Text("\(seasons.count) stagioni") }
                }.font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.70))
            }.padding(.horizontal, 16).padding(.bottom, 18)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                session.toggleFavorite(kind: .series, streamID: item.seriesID, title: item.name, imageURL: item.cover)
            } label: {
                Label(session.isFavorite(kind: .series, streamID: item.seriesID) ? "Nella mia lista" : "La mia lista", systemImage: session.isFavorite(kind: .series, streamID: item.seriesID) ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline.bold()).foregroundStyle(.white)
        .padding(.horizontal, 16)
    }

    private var castRail: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Cast").font(.headline.bold()).foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seriesCast, id: \.self) { actor in
                        NavigationLink { ActorView(name: actor) } label: {
                            Text(actor).font(.caption.weight(.semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 12).frame(height: 34).background(Color.white.opacity(0.09), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }.padding(.horizontal, 16)
    }

    private var seasonBar: some View {
        HStack {
            Menu {
                ForEach(seasons, id: \.self) { season in
                    Button { selectedSeason = season; UserDefaults.standard.set(season, forKey: "lastSeason_\(session.accessCode)_\(item.seriesID)") } label: {
                        if season == selectedSeason { Label("Stagione \(season)", systemImage: "checkmark") }
                        else { Text("Stagione \(season)") }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text("Stagione \(selectedSeason)").font(.headline.bold())
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
                .foregroundStyle(.white)
            }
            Spacer()
            Text("\(episodes.count) episodi").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 16)
    }

    private func episodeLine(_ episode: Episode, index: Int) -> some View {
        let descriptor = PlaybackDescriptor(kind: .series, streamID: episode.id, title: episode.title, subtitle: "\(item.name) • S\(selectedSeason) E\(episode.episodeNum)", imageURL: episode.info?.movieImage ?? item.cover, fileExtension: episode.containerExtension)
        let queue = episodes.map { queuedEpisode in
            let queuedDescriptor = PlaybackDescriptor(kind: .series, streamID: queuedEpisode.id, title: queuedEpisode.title, subtitle: "\(item.name) • S\(selectedSeason) E\(queuedEpisode.episodeNum)", imageURL: queuedEpisode.info?.movieImage ?? item.cover, fileExtension: queuedEpisode.containerExtension)
            return PlaybackQueueItem(id: String(queuedEpisode.id), title: queuedEpisode.title, url: session.streamURL(type: .series, id: queuedEpisode.id, ext: queuedEpisode.containerExtension), descriptor: queuedDescriptor)
        }
        return HStack(spacing: 12) {
            NavigationLink {
                PlayerScreen(title: episode.title, url: session.streamURL(type: .series, id: episode.id, ext: episode.containerExtension), isLive: false, resume: descriptor, episodeQueue: queue, startIndex: index)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        OptimizedAsyncImage(url: URL(string: episode.info?.movieImage ?? item.cover ?? "")) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { accentGradient(for: episode.title) }
                        }
                        .frame(width: 126, height: 72).clipped()
                        Image(systemName: "play.fill").font(.caption.bold()).foregroundStyle(.white)
                            .frame(width: 34, height: 34).background(Color.black.opacity(0.62), in: Circle())
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("E\(episode.episodeNum) • \(episode.title)").font(.subheadline.bold()).foregroundStyle(.white).lineLimit(2)
                        if let duration = episode.info?.duration, !duration.isEmpty { Text(duration).font(.caption2).foregroundStyle(.white.opacity(0.46)) }
                        if let progress = session.savedProgress(for: descriptor) { ProgressView(value: progress.fraction).tint(atxPrimary) }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            DownloadIconButton(title: episode.title, subtitle: "\(item.name) • S\(selectedSeason) E\(episode.episodeNum)", imageURL: episode.info?.movieImage ?? item.cover, remoteURL: session.streamURL(type: .series, id: episode.id, ext: episode.containerExtension), fileExtension: episode.containerExtension ?? "mp4")
        }
        .padding(.vertical, 10)
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
        ZStack(alignment: .bottomLeading) {
            OptimizedAsyncImage(url: URL(string: cover ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { accentGradient(for: title) }
            }
            .frame(maxWidth: .infinity).frame(height: 380).clipped()
            LinearGradient(colors: [.clear, Color.black.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text("SERIE TV").font(.caption2.weight(.black)).tracking(1.5).foregroundStyle(atxCyan)
                Text(title).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(3)
                if let genre, !genre.isEmpty { Text(genre).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.60)).lineLimit(2) }
                if let plot, !plot.isEmpty { Text(plot).font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(3) }
            }.padding(18)
        }.frame(height: 380).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).padding(.horizontal, 16).padding(.top, 8)
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let fallbackImage: String?
    let progress: PlaybackProgress?
    var body: some View {
        HStack(spacing: 14) {
            OptimizedAsyncImage(url: URL(string: episode.info?.movieImage ?? fallbackImage ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { ZStack { brandGradient; Image(systemName: "play.fill").foregroundStyle(.primary) } }
            }.frame(width: 126, height: 76).clipShape(RoundedRectangle(cornerRadius: 14)).clipped()
            VStack(alignment: .leading, spacing: 5) {
                Text("Episodio \(episode.episodeNum)").font(.caption.bold()).foregroundStyle(atxPrimary)
                Text(episode.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                HStack(spacing: 8) {
                    if let duration = episode.info?.duration, !duration.isEmpty { Label(duration, systemImage: "clock").font(.caption2).foregroundStyle(.secondary) }
                    if let rating = episode.info?.rating, !rating.isEmpty { Text("★ \(rating)").font(.caption2.bold()).foregroundStyle(.orange) }
                }
                if let date = episode.info?.releaseDate, !date.isEmpty { Text(date).font(.caption2).foregroundStyle(.secondary) }
                if let plot = episode.info?.plot, !plot.isEmpty { Text(plot).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
                if let progress {
                    ProgressView(value: progress.fraction).tint(atxPrimary)
                    Text("Riprendi da \(formatTime(progress.position))").font(.caption2).foregroundStyle(atxPrimary)
                }
            }; Spacer(); Image(systemName: progress == nil ? "play.circle.fill" : "arrow.clockwise.circle.fill").font(.title2).foregroundStyle(.primary)
        }.padding(12).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 20))
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
        self.title = title; self.imageURL = imageURL; self.plot = plot; self.metadata = metadata; self.extraInfo = extraInfo; self.action = action()
    }

    var body: some View {
        ZStack {
            StreamingBackdrop()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    hero
                    VStack(alignment: .leading, spacing: 18) {
                        action
                        if let plot, !plot.isEmpty {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("Trama").font(.title2.bold())
                                Text(plot).foregroundStyle(.secondary).lineSpacing(5)
                            }.padding(18).streamingPanel(radius: 22)
                        }
                        ForEach(extraInfo.filter { !($0.1 ?? "").isEmpty }, id: \.0) { entry in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(entry.0.uppercased()).font(.caption.bold()).foregroundStyle(atxPrimary)
                                Text(entry.1 ?? "").font(.subheadline).foregroundStyle(.secondary).lineSpacing(4)
                            }.padding(18).streamingPanel(radius: 22)
                        }
                    }.padding(.horizontal, 16)
                }.padding(.bottom, 120)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            OptimizedAsyncImage(url: URL(string: imageURL ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { ZStack { brandGradient; Image(systemName: "play.rectangle.fill").font(.system(size: 72)).foregroundStyle(.white.opacity(0.75)) } }
            }
            .frame(height: 430).clipped()
            LinearGradient(colors: [.clear, Color(uiColor: .systemBackground).opacity(0.35), Color(uiColor: .systemBackground)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 32, weight: .black, design: .rounded)).lineLimit(3).minimumScaleFactor(0.75)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(metadata.enumerated()), id: \.offset) { _, value in
                            Text(value).font(.caption.bold()).padding(.horizontal, 11).padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: Capsule()).foregroundStyle(.primary)
                        }
                    }
                }
            }.padding(.horizontal, 18).padding(.bottom, 18)
        }
    }
}

private func playButton(_ title: String) -> some View {
    Label(title, systemImage: "play.fill").font(.headline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(brandGradient).clipShape(RoundedRectangle(cornerRadius: 18))
}

struct NativePlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    let isLive: Bool
    @Binding var pictureInPictureActive: Bool

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        @Binding var pictureInPictureActive: Bool
        private var timeControlObservation: NSKeyValueObservation?
        private var itemStatusObservation: NSKeyValueObservation?
        private var startupWorkItems: [DispatchWorkItem] = []
        private weak var observedPlayer: AVPlayer?
        private var isLive = false
        private var startupDeadline = Date.distantPast

        init(pictureInPictureActive: Binding<Bool>) {
            _pictureInPictureActive = pictureInPictureActive
        }

        deinit {
            stopObserving()
        }

        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            pictureInPictureActive = true
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            pictureInPictureActive = false
            resumePlayback(on: playerViewController.player)
        }

        func configureAutoplay(for player: AVPlayer, isLive: Bool) {
            // L’avvio dei Live viene gestito esclusivamente da PlayerScreen.
            // Evitiamo observer e richiami concorrenti a play(), che potevano
            // lasciare AVPlayer con il primo fotogramma fermo.
            if observedPlayer !== player || self.isLive != isLive {
                stopObserving()
                observedPlayer = player
                self.isLive = isLive
            }
        }

        private func cancelStartupRetries() {
            startupWorkItems.forEach { $0.cancel() }
            startupWorkItems.removeAll()
        }

        private func stopObserving() {
            cancelStartupRetries()
            timeControlObservation?.invalidate()
            itemStatusObservation?.invalidate()
            timeControlObservation = nil
            itemStatusObservation = nil
            observedPlayer = nil
        }

        private func resumePlayback(on player: AVPlayer?) {
            guard let player else { return }
            player.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                guard player.timeControlStatus != .playing else { return }
                player.play()
                if player.rate == 0 { player.rate = 1.0 }
            }
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

        context.coordinator.configureAutoplay(for: player, isLive: isLive)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
        controller.allowsPictureInPicturePlayback = AVPictureInPictureController.isPictureInPictureSupported()
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        context.coordinator.configureAutoplay(for: player, isLive: isLive)
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
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var livePlaybackStarted = false
    @State private var liveStartupAttempts = 0
    @State private var liveStartupTask: Task<Void, Never>?

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
                NativePlayerController(player: player, isLive: isLive, pictureInPictureActive: $pictureInPictureActive)
                    .ignoresSafeArea(edges: .bottom)
                    .opacity(isLive && !livePlaybackStarted ? 0.001 : 1)

                if isLive && !livePlaybackStarted {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text("Avvio diretta…")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
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
                player?.seek(to: .zero) { _ in
                    if let player { startPlayback(player) }
                }
            }
            Button("Riprendi da \(formatTime(pendingResumePosition))") {
                let target = CMTime(seconds: pendingResumePosition, preferredTimescale: 600)
                player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    if let player { startPlayback(player) }
                }
            }
        } message: {
            Text("Hai già iniziato questo contenuto.")
        }
        .task { configurePlayer() }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                resumePlaybackIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            resumePlaybackIfNeeded(delay: 0.25)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            resumePlaybackIfNeeded(delay: 0.12)
        }
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
                .foregroundStyle(.white)
            Text(next.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
            Text("Riproduzione tra \(nextEpisodeCountdown)")
                .font(.title2.bold())
                .foregroundStyle(.white)
            ProgressView(value: Double(3 - nextEpisodeCountdown), total: 3)
                .tint(atxPrimary)
            HStack(spacing: 10) {
                Button { playNextEpisodeIfAvailable() } label: {
                    Label("Riproduci ora", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(atxPrimary, in: Capsule())
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
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(atxPrimary.opacity(0.8), lineWidth: 1))
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

        let assetOptions: [String: Any] = [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ]
        let asset = AVURLAsset(url: currentURL, options: assetOptions)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = isLive ? 1.25 : 3.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = isLive
        if isLive {
            // Buffer molto ridotto, ma non azzerato: migliora la compatibilità
            // con i server HLS più lenti senza ritardare visibilmente l'avvio.
            item.preferredPeakBitRate = 0
            livePlaybackStarted = false
            liveStartupAttempts = 0
        }
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.preventsDisplaySleepDuringVideoPlayback = true
        player = newPlayer
        installObservers(on: newPlayer, item: item)

        if !isLive, let currentDescriptor, let saved = session.savedProgress(for: currentDescriptor), saved.position >= 20 {
            pendingResumePosition = saved.position
            showResumePrompt = true
        } else {
            startPlayback(newPlayer)
        }

        validate(item: item, player: newPlayer)
    }

    private func startPlayback(_ player: AVPlayer) {
        if isLive {
            startLivePlayback(player)
            return
        }

        player.playImmediately(atRate: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard self.player === player, player.timeControlStatus != .playing else { return }
            player.pause()
            player.playImmediately(atRate: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            guard self.player === player, player.timeControlStatus != .playing else { return }
            player.playImmediately(atRate: 1.0)
        }
    }


    private func startLivePlayback(_ player: AVPlayer) {
        liveStartupTask?.cancel()
        livePlaybackStarted = false
        liveStartupAttempts = 0

        player.currentItem?.preferredForwardBufferDuration = 1.25
        player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        liveStartupTask = Task { @MainActor in
            // Attende che AVPlayerItem sia realmente pronto prima di avviare.
            // Questo evita il caso in cui appare il primo fotogramma ma il
            // flusso resta fermo finché l’utente non tocca i controlli.
            let readyDeadline = Date().addingTimeInterval(8)
            while player.currentItem?.status == .unknown && Date() < readyDeadline {
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
                guard !Task.isCancelled, self.player === player else { return }
            }

            guard !Task.isCancelled, self.player === player else { return }
            guard player.currentItem?.status != .failed else {
                self.failed = true
                return
            }

            player.play()

            // Controlliamo l’avanzamento reale del flusso, non il solo rate.
            // Se il primo fotogramma resta bloccato, eseguiamo al massimo due
            // cicli pausa/play, equivalenti al gesto che lo sbloccava a mano.
            var lastTime = player.currentTime().seconds
            for attempt in 0..<3 {
                do { try await Task.sleep(nanoseconds: attempt == 0 ? 900_000_000 : 1_200_000_000) } catch { return }
                guard !Task.isCancelled, self.player === player else { return }

                let currentTime = player.currentTime().seconds
                let advanced = currentTime.isFinite && lastTime.isFinite && currentTime > lastTime + 0.03
                if advanced || player.timeControlStatus == .playing {
                    self.livePlaybackStarted = true
                    self.liveStartupAttempts = 0
                    return
                }

                self.liveStartupAttempts += 1
                if attempt < 2 {
                    player.pause()
                    do { try await Task.sleep(nanoseconds: 120_000_000) } catch { return }
                    guard !Task.isCancelled, self.player === player else { return }
                    player.play()
                    lastTime = player.currentTime().seconds
                }
            }

            guard !Task.isCancelled, self.player === player else { return }
            self.livePlaybackStarted = player.timeControlStatus == .playing
        }
    }

    private func resumePlaybackIfNeeded(delay: Double = 0.0) {
        guard !failed, let player else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.player === player else { return }
            self.startPlayback(player)
        }
    }

    private func validate(item: AVPlayerItem, player: AVPlayer) {
        Task {
            try? await Task.sleep(nanoseconds: isLive ? 8_000_000_000 : 2_000_000_000)
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
        nextItem.preferredForwardBufferDuration = 3.0
        player.replaceCurrentItem(with: nextItem)
        installObservers(on: player, item: nextItem)
        startPlayback(player)
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
        liveStartupTask?.cancel()
        liveStartupTask = nil
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
    @State private var selectedType = "Tutto"
    @AppStorage("recentSearches") private var recentSearchesData = ""

    private var recentSearches: [String] { recentSearchesData.split(separator: "|").map(String.init).filter { !$0.isEmpty } }
    private var movies: [VODStream] {
        guard !search.isEmpty, selectedType == "Tutto" || selectedType == "Film" else { return [] }
        return Array(session.allMovies.filter { $0.name.localizedCaseInsensitiveContains(search) }.prefix(40))
    }
    private var series: [SeriesItem] {
        guard !search.isEmpty, selectedType == "Tutto" || selectedType == "Serie" else { return [] }
        return Array(session.allSeries.filter { $0.name.localizedCaseInsensitiveContains(search) }.prefix(40))
    }
    private var live: [LiveStream] {
        guard !search.isEmpty, selectedType == "Tutto" || selectedType == "Diretta" else { return [] }
        return Array(session.allLive.filter { $0.name.localizedCaseInsensitiveContains(search) }.prefix(40))
    }
    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.55))
                        TextField("Titoli, persone e generi", text: $search)
                            .foregroundStyle(.white).textInputAutocapitalization(.never).autocorrectionDisabled()
                        if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.42)) }.buttonStyle(.plain) }
                    }
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 16)

                    HStack(spacing: 8) {
                        ForEach(["Tutto","Film","Serie","Diretta"], id: \.self) { kind in
                            Button { selectedType = kind } label: {
                                Text(kind).font(.caption.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 12).frame(height: 34)
                                    .background(selectedType == kind ? atxPrimary : Color.white.opacity(0.08), in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 16)

                    if search.isEmpty {
                        if !recentSearches.isEmpty {
                            Text("Ricerche recenti").font(.headline.bold()).foregroundStyle(.white).padding(.horizontal, 16)
                            ForEach(recentSearches, id: \.self) { value in
                                Button { search = value } label: {
                                    HStack { Image(systemName: "clock"); Text(value); Spacer(); Image(systemName: "arrow.up.left") }
                                        .font(.subheadline).foregroundStyle(.white.opacity(0.72)).padding(.horizontal, 16).frame(height: 44)
                                }.buttonStyle(.plain)
                            }
                        }
                        Text("Cerca film, serie TV e canali live nel tuo catalogo.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.45)).padding(.horizontal, 16).padding(.top, 10)
                    } else {
                        if !movies.isEmpty { posterSection("Film", movies.map { ($0.name, $0.streamIcon, AnyView(MovieDetailView(item: $0))) }) }
                        if !series.isEmpty { posterSection("Serie TV", series.map { ($0.name, $0.cover, AnyView(SeriesDetailView(item: $0))) }) }
                        if !live.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Diretta").font(.headline.bold()).foregroundStyle(.white).padding(.horizontal, 16)
                                ForEach(live) { item in
                                    NavigationLink { LiveDetailView(item: item) } label: { LiveChannelCard(item: item) }.buttonStyle(.plain).padding(.horizontal, 16)
                                }
                            }
                        }
                        if movies.isEmpty && series.isEmpty && live.isEmpty { EmptyStateView(title: "Nessun risultato", icon: "magnifyingglass", message: "Prova con un altro titolo.") }
                    }
                }.padding(.top, 12).padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topTrailing) { Button("Chiudi") { dismiss() }.font(.caption.bold()).foregroundStyle(.white).padding(.trailing, 16).padding(.top, 8).opacity(0) }
        .onSubmit(of: .search) { saveSearch(search) }
    }

    @ViewBuilder private func posterSection(_ title: String, _ items: [(String, String?, AnyView)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline.bold()).foregroundStyle(.white).padding(.horizontal, 16)
            LazyVGrid(columns: cols, spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    NavigationLink { item.2 } label: { ModernPosterCard(title: item.0, imageURL: item.1, badge: nil, typeLabel: title == "Film" ? "FILM" : "SERIE") }
                        .buttonStyle(.plain)
                }
            }.padding(.horizontal, 16)
        }
    }

    private func saveSearch(_ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var values = recentSearches.filter { $0.caseInsensitiveCompare(clean) != .orderedSame }
        values.insert(clean, at: 0)
        recentSearchesData = values.prefix(6).joined(separator: "|")
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) { self.spacing = spacing; self.content = content() }
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: spacing)], spacing: spacing) { content }
    }
}

struct SearchResultRow: View {
    let title: String; let subtitle: String; let imageURL: String?
    var body: some View {
        HStack(spacing: 14) {
            OptimizedAsyncImage(url: URL(string: imageURL ?? "")) { phase in if let image = phase.image { image.resizable().scaledToFill() } else { brandGradient } }
                .frame(width: 104, height: 66).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).clipped()
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline).foregroundStyle(.primary).lineLimit(2); Text(subtitle.uppercased()).font(.caption2.bold()).foregroundStyle(atxPrimary) }
            Spacer(); Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.secondary)
        }.padding(12).streamingPanel(radius: 18).padding(.horizontal, 16)
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
            Image(systemName: icon).foregroundStyle(atxPrimary)
            Text("\(count)").font(.headline.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
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
            OptimizedAsyncImage(url: URL(string: favorite.imageURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.white.opacity(0.06)
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
    private var filtered: [WatchHistoryItem] {
        selectedFilter == "Tutti" ? session.accountWatchHistory : session.accountWatchHistory.filter { selectedFilter == "Film" ? $0.kind == ContentType.movies.rawValue : $0.kind == ContentType.series.rawValue }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [atxPrimary.opacity(0.30), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 160)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Cronologia").font(.system(size: 34, weight: .black)).foregroundStyle(.white)
                            Text("Riprendi quello che hai già iniziato").font(.subheadline).foregroundStyle(.white.opacity(0.56))
                        }.padding(16)
                    }
                    filters.padding(.horizontal, 16)

                    if filtered.isEmpty {
                        EmptyStateView(title: "Cronologia vuota", icon: "clock.arrow.circlepath", message: "I contenuti avviati compariranno qui.").padding(.top, 50)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 12) {
                                    HistoryNavigation(item: item)
                                    Button(role: .destructive) { withAnimation { session.removeHistory(id: item.id) } } label: {
                                        Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(.white.opacity(0.55)).frame(width: 34, height: 34)
                                    }.buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                if index < filtered.count - 1 { Divider().overlay(Color.white.opacity(0.08)).padding(.leading, 16) }
                            }
                        }
                    }

                    if !session.accountWatchHistory.isEmpty {
                        Button(role: .destructive) { showClearConfirmation = true } label: {
                            Label("Cancella cronologia", systemImage: "trash")
                                .font(.subheadline.bold()).foregroundStyle(atxPrimary)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain).padding(.horizontal, 16)
                    }
                    Spacer(minLength: 100)
                }
            }
        }
        .preferredColorScheme(.dark).toolbar(.hidden, for: .navigationBar)
        .alert("Cancellare la cronologia?", isPresented: $showClearConfirmation) { Button("Annulla", role: .cancel) {}; Button("Cancella tutto", role: .destructive) { session.clearAccountWatchHistory() } }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            ForEach(["Tutti", "Film", "Serie"], id: \.self) { f in
                Button { withAnimation { selectedFilter = f } } label: {
                    Text(f).font(.subheadline.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 36)
                        .background(selectedFilter == f ? atxPrimary : Color.white.opacity(0.08), in: Capsule())
                }.buttonStyle(.plain)
            }
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
        HStack(spacing: 13) {
            OptimizedAsyncImage(url: URL(string: item.imageURL ?? "")) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { accentGradient(for: item.title) }
            }.frame(maxWidth: .infinity).aspectRatio(0.70, contentMode: .fit).clipped().clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline.bold()).foregroundStyle(.white).lineLimit(2)
                if let subtitle = item.subtitle, !subtitle.isEmpty { Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.42)).lineLimit(1) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
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
            OptimizedAsyncImage(url: URL(string: item.imageURL ?? "")) { phase in
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
    @Environment(\.dismiss) private var dismiss
    @State private var showLogout = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.headline.bold()).foregroundStyle(.white).frame(width: 44, height: 44)
                        }.buttonStyle(.plain)
                        Spacer()
                        Text("Account").font(.headline.bold()).foregroundStyle(.white)
                        Spacer(); Color.clear.frame(width: 44, height: 44)
                    }.padding(.horizontal, 10)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            BrandMark(size: 62)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.username).font(.title2.weight(.black)).foregroundStyle(.white)
                                Text(expiry).font(.caption).foregroundStyle(.white.opacity(0.48))
                            }
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            NavigationLink { FavoritesView() } label: { shortcut("La mia lista", "plus") }
                            NavigationLink { WatchHistoryView() } label: { shortcut("Cronologia", "clock.arrow.circlepath") }
                        }.buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.075), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)

                    sectionTitle("Riproduzione")
                    settingBlock {
                        SettingsToggleRow(title: "Riproduzione automatica", subtitle: "Avvia automaticamente il contenuto successivo", icon: "play.fill", isOn: Binding(get: { session.autoplay }, set: { session.setAutoplay($0) }))
                        SettingsDivider()
                        SettingsToggleRow(title: "Aggiorna all'apertura", subtitle: "Sincronizza la playlist all'avvio", icon: "arrow.clockwise", isOn: Binding(get: { session.refreshOnLaunch }, set: { session.setRefreshOnLaunch($0) }))
                        SettingsDivider()
                        SettingsInfoRow(title: "Picture in Picture", subtitle: "Continua mentre usi altre app", icon: "pip.fill")
                        SettingsDivider()
                        SettingsInfoRow(title: "AirPlay", subtitle: "Riproduci sui dispositivi compatibili", icon: "airplayvideo")
                    }

                    sectionTitle("Aspetto")
                    settingBlock {
                        Picker("Tema", selection: Binding(get: { session.appearance }, set: { session.setAppearance($0) })) {
                            Text("Auto").tag("system"); Text("Chiaro").tag("light"); Text("Scuro").tag("dark")
                        }.pickerStyle(.segmented).padding(14)
                        SettingsDivider()
                        SettingsToggleRow(title: "Animazioni", subtitle: "Transizioni dell'interfaccia", icon: "sparkles", isOn: Binding(get: { session.interfaceAnimations }, set: { session.setInterfaceAnimations($0) }))
                    }

                    sectionTitle("Sicurezza")
                    settingBlock {
                        SettingsToggleRow(title: "Controllo genitori", subtitle: "Proteggi i contenuti con restrizioni", icon: "lock.shield.fill", isOn: Binding(get: { session.parentalControl }, set: { session.setParentalControl($0) }))
                    }

                    Button(role: .destructive) { showLogout = true } label: {
                        Text("Esci da AtlantiX").font(.headline.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(atxPrimary, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain).padding(.horizontal, 16)
                    Spacer(minLength: 100)
                }.padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark).toolbar(.hidden, for: .navigationBar)
        .alert("Vuoi uscire dall'account?", isPresented: $showLogout) { Button("Annulla", role: .cancel) {}; Button("Esci", role: .destructive) { session.signOut() } }
    }

    private func shortcut(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 8) { Image(systemName: icon); Text(title) }
            .font(.caption.bold()).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 40)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
    private func sectionTitle(_ title: String) -> some View { Text(title.uppercased()).font(.caption.weight(.black)).tracking(1.2).foregroundStyle(.white.opacity(0.52)).padding(.horizontal, 16) }
    @ViewBuilder private func settingBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(red: 0.07, green: 0.07, blue: 0.075), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
    }
    private var expiry: String {
        guard let timestamp = session.userInfo?.expDate, let seconds = TimeInterval(timestamp) else { return "Nessuna scadenza" }
        return "Scadenza: " + Date(timeIntervalSince1970: seconds).formatted(date: .abbreviated, time: .omitted)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 13) {
            SettingsIcon(icon: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 13) {
            SettingsIcon(icon: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 13) {
            SettingsIcon(icon: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
    }
}

private struct SettingsIcon: View {
    let icon: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(atxPrimary.opacity(0.10))
                .frame(width: 38, height: 38)
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(atxPrimary)
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 65)
    }
}

private extension View {
    func settingsCard() -> some View {
        self
            .padding(0)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 1)
            }
    }
}

struct EmptyStateView: View {
    let title: String; let icon: String; let message: String
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(brandGradient).frame(width: 94, height: 94).blur(radius: 0)
                Circle().stroke(Color.white.opacity(0.30), lineWidth: 1).frame(width: 76, height: 76)
                Image(systemName: icon).font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
            }
            Text(title).font(.title2.bold())
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 310)
        }
        .padding(30).frame(maxWidth: .infinity).streamingPanel(radius: 28).padding(20)
    }
}

struct OfflineDownload: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let imageURL: String?
    let localFilename: String
    let createdAt: Date

    var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AtlantiXDownloads", isDirectory: true)
            .appendingPathComponent(localFilename)
    }
}

@MainActor
final class DownloadCenter: ObservableObject {
    static let shared = DownloadCenter()
    @Published private(set) var items: [OfflineDownload] = []
    @Published private(set) var activeTitles: Set<String> = []
    @Published private(set) var progressByTitle: [String: Double] = [:]
    @Published var lastError: String?

    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var progressMonitors: [String: Task<Void, Never>] = [:]
    private var currentAccountKey: String?
    private let metadataPrefix = "atlantix.offline.downloads.v3"
    private let migrationPrefix = "atlantix.offline.downloads.migrated.v3"

    private init() {
        try? FileManager.default.createDirectory(at: downloadsRootDirectory, withIntermediateDirectories: true)
    }

    /// Cambia l'archivio download quando cambia l'account autenticato.
    /// Ogni utente ha metadati e cartella fisica separati.
    func switchAccount(to username: String?) {
        cancelActiveDownloads()
        items = []
        lastError = nil

        guard let username = username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
            currentAccountKey = nil
            return
        }

        let accountKey = accountIdentifier(for: username)
        currentAccountKey = accountKey
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)

        if let data = UserDefaults.standard.data(forKey: metadataKey(for: accountKey)),
           let saved = try? JSONDecoder().decode([OfflineDownload].self, from: data) {
            items = saved.filter { FileManager.default.fileExists(atPath: $0.localURL.path) }
            persist()
            return
        }

        migrateLegacyDownloadsIfNeeded(to: accountKey)
        loadItems(for: accountKey)
    }

    private var downloadsRootDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AtlantiXDownloads", isDirectory: true)
    }

    private var downloadsDirectory: URL {
        downloadsRootDirectory
            .appendingPathComponent(currentAccountKey ?? "no-account", isDirectory: true)
    }

    private func metadataKey(for accountKey: String) -> String {
        "\(metadataPrefix).\(accountKey)"
    }

    private func accountIdentifier(for username: String) -> String {
        // Hash FNV-1a stabile: evita di salvare il nome utente in chiaro nel percorso.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in username.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func loadItems(for accountKey: String) {
        guard let data = UserDefaults.standard.data(forKey: metadataKey(for: accountKey)),
              let saved = try? JSONDecoder().decode([OfflineDownload].self, from: data) else {
            items = []
            return
        }
        items = saved.filter { FileManager.default.fileExists(atPath: $0.localURL.path) }
        persist()
    }

    private func migrateLegacyDownloadsIfNeeded(to accountKey: String) {
        let migrationKey = "\(migrationPrefix).\(accountKey)"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: migrationKey) }

        let legacyKeys = ["atlantix.offline.downloads.v2", "atlantix.offline.downloads.v1"]
        guard let legacyData = legacyKeys.compactMap({ UserDefaults.standard.data(forKey: $0) }).first,
              let legacyItems = try? JSONDecoder().decode([OfflineDownload].self, from: legacyData) else { return }

        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        var migrated: [OfflineDownload] = []

        for item in legacyItems {
            let oldURL = item.localURL
            guard FileManager.default.fileExists(atPath: oldURL.path) else { continue }
            let destination = downloadsDirectory.appendingPathComponent(item.localFilename)
            if oldURL != destination {
                try? FileManager.default.removeItem(at: destination)
                do { try FileManager.default.moveItem(at: oldURL, to: destination) }
                catch { continue }
            }
            migrated.append(OfflineDownload(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                imageURL: item.imageURL,
                localFilename: "\(accountKey)/\(item.localFilename)",
                createdAt: item.createdAt
            ))
        }

        items = migrated
        persist()
        legacyKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    private func cancelActiveDownloads() {
        activeTasks.values.forEach { $0.cancel() }
        progressMonitors.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        progressMonitors.removeAll()
        activeTitles.removeAll()
        progressByTitle.removeAll()
    }

    func isDownloaded(title: String) -> Bool { items.contains { $0.title == title } }
    func isDownloading(title: String) -> Bool { activeTitles.contains(title) }
    func progress(for title: String) -> Double { progressByTitle[title] ?? 0 }

    func download(title: String, subtitle: String, imageURL: String?, remoteURL: URL?, fileExtension: String) {
        guard let accountKey = currentAccountKey else {
            lastError = "Accedi al tuo account prima di scaricare un contenuto."
            return
        }
        guard let remoteURL else {
            lastError = "Indirizzo del contenuto non valido."
            return
        }
        guard !isDownloaded(title: title), !isDownloading(title: title) else { return }

        activeTitles.insert(title)
        progressByTitle[title] = 0
        lastError = nil

        let directory = downloadsDirectory
        let safeName = title.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let ext = fileExtension.isEmpty ? "mp4" : fileExtension
        let filename = "\(UUID().uuidString)_\(safeName).\(ext)"
        let relativeFilename = "\(accountKey)/\(filename)"
        let destination = directory.appendingPathComponent(filename)

        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 60 * 60
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        let task = URLSession.shared.downloadTask(with: request) { [weak self] temporaryURL, response, error in
            Task { @MainActor in
                guard let self else { return }
                self.progressMonitors[title]?.cancel()
                self.progressMonitors.removeValue(forKey: title)
                self.activeTasks.removeValue(forKey: title)

                // Se nel frattempo è cambiato account, non associare il file al nuovo utente.
                guard self.currentAccountKey == accountKey else {
                    self.activeTitles.remove(title)
                    self.progressByTitle.removeValue(forKey: title)
                    return
                }

                if let error {
                    self.activeTitles.remove(title)
                    self.progressByTitle.removeValue(forKey: title)
                    if (error as NSError).code != NSURLErrorCancelled {
                        self.lastError = "Download non riuscito: \(error.localizedDescription)"
                    }
                    return
                }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    self.activeTitles.remove(title)
                    self.progressByTitle.removeValue(forKey: title)
                    self.lastError = "Download non riuscito: errore server \(http.statusCode)."
                    return
                }
                guard let temporaryURL else {
                    self.activeTitles.remove(title)
                    self.progressByTitle.removeValue(forKey: title)
                    self.lastError = "Download non riuscito: file temporaneo mancante."
                    return
                }

                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: temporaryURL, to: destination)
                    let item = OfflineDownload(
                        id: UUID(),
                        title: title,
                        subtitle: subtitle,
                        imageURL: imageURL,
                        localFilename: relativeFilename,
                        createdAt: Date()
                    )
                    self.items.insert(item, at: 0)
                    self.progressByTitle[title] = 1
                    self.activeTitles.remove(title)
                    self.progressByTitle.removeValue(forKey: title)
                    self.persist()
                } catch {
                    self.activeTitles.remove(title)
                    self.progressByTitle.removeValue(forKey: title)
                    self.lastError = "Download non riuscito: \(error.localizedDescription)"
                }
            }
        }

        activeTasks[title] = task
        let monitor = Task { @MainActor [weak self, weak task] in
            while let task, !Task.isCancelled {
                let fraction = task.progress.fractionCompleted
                if fraction.isFinite && fraction >= 0 {
                    self?.progressByTitle[title] = min(1, fraction)
                }
                if task.state == .completed || task.state == .canceling { break }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        progressMonitors[title] = monitor
        task.resume()
    }

    func delete(_ item: OfflineDownload) {
        try? FileManager.default.removeItem(at: item.localURL)
        items.removeAll { $0.id == item.id }
        persist()
    }

    private func persist() {
        guard let accountKey = currentAccountKey,
              let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey(for: accountKey))
    }
}

struct DownloadActionButton: View {
    @StateObject private var center = DownloadCenter.shared
    let title: String
    let subtitle: String
    let imageURL: String?
    let remoteURL: URL?
    let fileExtension: String

    var body: some View {
        Button {
            center.download(title: title, subtitle: subtitle, imageURL: imageURL, remoteURL: remoteURL, fileExtension: fileExtension)
        } label: {
            VStack(spacing: 8) {
                HStack {
                    if center.isDownloading(title: title) { ProgressView().tint(.white) }
                    else { Image(systemName: center.isDownloaded(title: title) ? "checkmark.circle.fill" : "arrow.down.circle.fill") }
                    Text(center.isDownloaded(title: title) ? "Scaricato" : center.isDownloading(title: title) ? "Download in corso…" : "Scarica per guardarlo offline")
                }
                if center.isDownloading(title: title) {
                    ProgressView(value: center.progress(for: title))
                        .tint(.white)
                    Text("\(Int(center.progress(for: title) * 100))%")
                        .font(.caption.bold())
                }
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 14)
            .background(LinearGradient(colors: [atxSecondary, atxPrimary], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(center.isDownloaded(title: title) || center.isDownloading(title: title))
    }
}

struct DownloadIconButton: View {
    @StateObject private var center = DownloadCenter.shared
    let title: String
    let subtitle: String
    let imageURL: String?
    let remoteURL: URL?
    let fileExtension: String

    var body: some View {
        Button {
            center.download(title: title, subtitle: subtitle, imageURL: imageURL, remoteURL: remoteURL, fileExtension: fileExtension)
        } label: {
            ZStack {
                if center.isDownloading(title: title) {
                    ProgressView(value: center.progress(for: title))
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: center.isDownloaded(title: title) ? "checkmark.circle.fill" : "arrow.down.circle")
                }
            }
            .font(.title2)
            .frame(width: 44, height: 44)
        }
        .disabled(center.isDownloaded(title: title) || center.isDownloading(title: title))
        .accessibilityLabel("Scarica episodio")
    }
}


private struct DownloadContentCard: View {
    let item: OfflineDownload
    let seriesStyle: Bool
    let subtitle: String
    let onPlay: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPlay) {
                HStack(spacing: 13) {
                    OptimizedAsyncImage(url: URL(string: item.imageURL ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            ZStack {
                                LinearGradient(colors: [atxPrimary.opacity(0.55), atxSecondary.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: seriesStyle ? "tv.fill" : "film.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(width: seriesStyle ? 74 : 70, height: seriesStyle ? 74 : 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipped()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Label("Disponibile offline", systemImage: "checkmark.circle.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 29))
                        .foregroundStyle(atxPrimary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.vertical, 12)

            Button {
                showDeleteConfirmation = true
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Elimina")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.red)
                .frame(width: 72)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Elimina download")
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.07)))
        .confirmationDialog(
            "Eliminare questo download?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) { onDelete() }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Il contenuto verrà rimosso dal dispositivo.")
        }
    }
}

struct OfflinePlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    let item: OfflineDownload

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlayerScreen(title: item.title, url: item.localURL, isLive: false, resume: nil)
                .navigationBarBackButtonHidden(true)
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.62))
                    .clipShape(Circle())
            }
            .padding(.leading, 14)
            .padding(.top, 12)
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden(true)
    }
}

struct DownloadsView: View {
    @StateObject private var center = DownloadCenter.shared
    @State private var selectedItem: OfflineDownload?
    @State private var searchText = ""
    @State private var selectedSection: DownloadSection = .movies

    private enum DownloadSection: String, CaseIterable, Identifiable {
        case movies = "Film"
        case series = "Serie TV"
        var id: String { rawValue }
        var icon: String { self == .movies ? "film.fill" : "rectangle.stack.fill" }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var movieItems: [OfflineDownload] {
        center.items.filter { $0.subtitle == "Film" && matchesSearch($0) }
    }

    private var seriesItems: [OfflineDownload] {
        center.items.filter { $0.subtitle != "Film" && matchesSearch($0) }
    }

    private var groupedSeries: [(name: String, items: [OfflineDownload])] {
        let groups = Dictionary(grouping: seriesItems) { item in
            item.subtitle.components(separatedBy: " • ").first ?? "Serie TV"
        }
        return groups.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { ($0, groups[$0]!.sorted { $0.createdAt > $1.createdAt }) }
    }

    private var filteredCount: Int {
        selectedSection == .movies ? movieItems.count : seriesItems.count
    }

    var body: some View {
        ZStack {
            StreamingBackdrop()
            ScrollView {
                LazyVStack(spacing: 18) {
                    downloadsHeader
                    searchBar
                    sectionPicker

                    if !center.activeTitles.isEmpty {
                        activeDownloadsSection
                    }

                    if filteredCount == 0 {
                        EmptyStateView(
                            title: normalizedSearch.isEmpty ? (selectedSection == .movies ? "Nessun film scaricato" : "Nessuna serie scaricata") : "Nessun risultato",
                            icon: selectedSection.icon,
                            message: normalizedSearch.isEmpty ? "I contenuti scaricati appariranno qui e saranno disponibili anche senza connessione." : "Prova a cercare un altro titolo o episodio."
                        )
                        .padding(.top, 36)
                    } else if selectedSection == .movies {
                        movieGrid
                    } else {
                        seriesList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedItem) { item in
            OfflinePlaybackView(item: item)
        }
        .alert("Download", isPresented: Binding(get: { center.lastError != nil }, set: { if !$0 { center.lastError = nil } })) {
            Button("OK") { center.lastError = nil }
        } message: { Text(center.lastError ?? "") }
    }

    private var downloadsHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [atxSecondary, atxPrimary], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("Download")
                    .font(.system(size: 28, weight: .bold))
                Text("Guarda film e serie anche offline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 14)
    }

    private var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Cerca nei download", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.primary.opacity(0.06)))
    }

    private var sectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(DownloadSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedSection = section }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: section.icon)
                        Text(section.rawValue)
                        Text("\(section == .movies ? movieItems.count : seriesItems.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background((selectedSection == section ? Color.white : Color.secondary).opacity(0.16))
                            .clipShape(Capsule())
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(selectedSection == section ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedSection == section ? atxPrimary : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activeDownloadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Download in corso", systemImage: "arrow.down.circle")
                .font(.headline.bold())
            ForEach(Array(center.activeTitles).sorted(), id: \.self) { title in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(title).font(.subheadline.bold()).lineLimit(2)
                        Spacer()
                        Text("\(Int(center.progress(for: title) * 100))%")
                            .font(.caption.bold())
                            .foregroundStyle(atxPrimary)
                    }
                    ProgressView(value: center.progress(for: title))
                        .tint(atxPrimary)
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var movieGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(movieItems) { item in
                downloadCard(item, seriesStyle: false)
            }
        }
    }

    private var seriesList: some View {
        LazyVStack(spacing: 14) {
            ForEach(groupedSeries, id: \.name) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "rectangle.stack.fill")
                            .foregroundStyle(atxPrimary)
                        Text(group.name)
                            .font(.headline.bold())
                        Spacer()
                        Text("\(group.items.count) episodi")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    ForEach(group.items) { item in
                        downloadCard(item, seriesStyle: true)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private func downloadCard(_ item: OfflineDownload, seriesStyle: Bool) -> some View {
        DownloadContentCard(
            item: item,
            seriesStyle: seriesStyle,
            subtitle: seriesStyle ? episodeSubtitle(item) : "Film",
            onPlay: { selectedItem = item },
            onDelete: { center.delete(item) }
        )
    }

    private func matchesSearch(_ item: OfflineDownload) -> Bool {
        guard !normalizedSearch.isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(normalizedSearch) ||
            item.subtitle.localizedCaseInsensitiveContains(normalizedSearch)
    }

    private func episodeSubtitle(_ item: OfflineDownload) -> String {
        let parts = item.subtitle.components(separatedBy: " • ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " • ") : item.subtitle
    }
}

