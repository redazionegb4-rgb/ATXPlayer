import SwiftUI
import AVKit

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { ContentBrowser(type: .live) }.tabItem { Label("Diretta", systemImage: "dot.radiowaves.left.and.right") }
            NavigationStack { ContentBrowser(type: .movies) }.tabItem { Label("Film", systemImage: "film.fill") }
            NavigationStack { ContentBrowser(type: .series) }.tabItem { Label("Serie", systemImage: "rectangle.stack.fill") }
            NavigationStack { SettingsView() }.tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }.tint(.purple)
    }
}

struct HomeView: View {
    @EnvironmentObject var session: AppSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.purple, .indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bentornato").font(.caption).foregroundStyle(.white.opacity(0.75))
                        Text(session.username).font(.largeTitle.bold()).foregroundStyle(.white)
                        Text("Scegli cosa guardare oggi").foregroundStyle(.white.opacity(0.8))
                    }.padding(24)
                }.frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 28)).padding(.horizontal)
                HStack(spacing: 12) {
                    stat("TV", value: session.liveCategories.count, icon: "tv.fill")
                    stat("Film", value: session.movieCategories.count, icon: "film.fill")
                    stat("Serie", value: session.seriesCategories.count, icon: "rectangle.stack.fill")
                }.padding(.horizontal)
                Text("Esplora").font(.title2.bold()).padding(.horizontal)
                VStack(spacing: 12) {
                    NavigationLink { ContentBrowser(type: .live) } label: { homeRow("TV in diretta", "Canali e programmi live", "dot.radiowaves.left.and.right") }
                    NavigationLink { ContentBrowser(type: .movies) } label: { homeRow("Film", "Scopri il catalogo disponibile", "film.fill") }
                    NavigationLink { ContentBrowser(type: .series) } label: { homeRow("Serie TV", "Tutte le tue serie", "rectangle.stack.fill") }
                }.padding(.horizontal)
            }.padding(.vertical)
        }.navigationTitle("ATX Player")
    }
    private func stat(_ title: String, value: Int, icon: String) -> some View { VStack(spacing: 7) { Image(systemName: icon).font(.title3); Text("\(value)").font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 16).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 20)) }
    private func homeRow(_ title: String, _ subtitle: String, _ icon: String) -> some View { HStack(spacing: 15) { ZStack { RoundedRectangle(cornerRadius: 15).fill(.purple.opacity(0.15)); Image(systemName: icon).foregroundStyle(.purple) }.frame(width: 54, height: 54); VStack(alignment: .leading) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }.padding(14).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 20)) }
}

struct ContentBrowser: View {
    @EnvironmentObject var session: AppSession
    let type: ContentType
    var categories: [Category] { type == .live ? session.liveCategories : type == .movies ? session.movieCategories : session.seriesCategories }
    var title: String { type == .live ? "TV in diretta" : type == .movies ? "Film" : "Serie TV" }
    var body: some View {
        List {
            NavigationLink { ItemGrid(type: type, category: nil) } label: { Label("Tutti", systemImage: "square.grid.2x2.fill") }
            ForEach(categories) { cat in NavigationLink { ItemGrid(type: type, category: cat) } label: { VStack(alignment: .leading, spacing: 3) { Text(cat.categoryName).font(.headline); Text("Apri categoria").font(.caption).foregroundStyle(.secondary) } } }
        }.navigationTitle(title).searchable(text: .constant(""))
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
        }.navigationTitle(category?.categoryName ?? "Tutti").searchable(text: $search).task { await load() }
    }

    @ViewBuilder var contentCards: some View {
        if type == .live {
            ForEach(live.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in NavigationLink { PlayerScreen(title: item.name, url: session.streamURL(type: .live, id: item.streamID)) } label: { PosterCard(title: item.name, imageURL: item.streamIcon, badge: "LIVE", landscape: true) } }
        } else if type == .movies {
            ForEach(vod.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in NavigationLink { PlayerScreen(title: item.name, url: session.streamURL(type: .movies, id: item.streamID, ext: item.containerExtension)) } label: { PosterCard(title: item.name, imageURL: item.streamIcon, badge: item.rating) } }
        } else {
            ForEach(series.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in NavigationLink { SeriesPlaceholderView(item: item) } label: { PosterCard(title: item.name, imageURL: item.cover, badge: item.rating) } }
        }
    }

    func load() async {
        loading = true
        do {
            switch type {
            case .live: live = try await APIClient.shared.liveStreams(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID)
            case .movies: vod = try await APIClient.shared.vodStreams(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID)
            case .series: series = try await APIClient.shared.series(baseURL: session.baseURL, username: session.username, password: session.password, categoryID: category?.categoryID)
            }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PosterCard: View {
    let title: String; let imageURL: String?; let badge: String?; var landscape = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: imageURL ?? "")) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() } else { ZStack { LinearGradient(colors: [.purple.opacity(0.45), .black], startPoint: .topLeading, endPoint: .bottomTrailing); Image(systemName: landscape ? "tv.fill" : "play.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.65)) } }
                }.frame(height: landscape ? 105 : 205).clipShape(RoundedRectangle(cornerRadius: 18)).clipped()
                if let badge, !badge.isEmpty { Text(badge).font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 5).background(.black.opacity(0.72)).foregroundStyle(.white).clipShape(Capsule()).padding(8) }
            }
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(.primary)
        }
    }
}

struct PlayerScreen: View {
    let title: String; let url: URL?
    @State private var player: AVPlayer?
    var body: some View {
        ZStack { Color.black.ignoresSafeArea(); if let player { VideoPlayer(player: player).onAppear { player.play() }.onDisappear { player.pause() } } else { EmptyStateView(title: "Flusso non disponibile", icon: "play.slash", message: "Controlla il collegamento o riprova più tardi.") } }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline).task { if let url { player = AVPlayer(url: url) } }
    }
}

struct SeriesPlaceholderView: View {
    let item: SeriesItem
    var body: some View { ScrollView { VStack(spacing: 18) { AsyncImage(url: URL(string: item.cover ?? "")) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(maxHeight: 420).clipShape(RoundedRectangle(cornerRadius: 24)); Text(item.name).font(.title.bold()); if let plot = item.plot { Text(plot).foregroundStyle(.secondary) }; EmptyStateView(title: "Episodi", icon: "rectangle.stack", message: "Il caricamento dettagliato delle stagioni sarà incluso nel prossimo aggiornamento.") }.padding() }.navigationTitle(item.name).navigationBarTitleDisplayMode(.inline) }
}

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Username", value: session.username)
                LabeledContent("Stato", value: session.userInfo?.status ?? "—")
                LabeledContent("Scadenza", value: expiry)
                Toggle("Accesso automatico", isOn: Binding(get: { session.autoLogin }, set: { session.setAutoLogin($0) }))
            }
            Section("Aspetto") {
                Picker("Tema", selection: Binding(get: { session.appearance }, set: { session.setAppearance($0) })) { Text("Automatico").tag("system"); Text("Chiaro").tag("light"); Text("Scuro").tag("dark") }
            }
            Section("Riproduzione") { Label("Picture in Picture supportato", systemImage: "pip.fill"); Label("AirPlay supportato", systemImage: "airplayvideo") }
            Section("Informazioni") { LabeledContent("Versione", value: "1.0 (Build 1)"); Text("ATX Player è un lettore e non include né vende contenuti multimediali.").font(.footnote).foregroundStyle(.secondary) }
            Section { Button("Esci dall’account", role: .destructive) { session.signOut() } }
        }.navigationTitle("Impostazioni")
    }
    var expiry: String { guard let value = session.userInfo?.expDate, let seconds = TimeInterval(value) else { return "Illimitata" }; return Date(timeIntervalSince1970: seconds).formatted(date: .abbreviated, time: .omitted) }
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
        }.padding(30)
    }
}
