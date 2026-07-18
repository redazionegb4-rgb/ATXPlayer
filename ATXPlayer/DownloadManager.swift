import Foundation
import AVFoundation

struct OfflineDownload: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case movie, episode }
    enum State: String, Codable { case queued, downloading, paused, completed, failed }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let imageURL: String?
    let remoteURL: URL
    var localFileName: String?
    var progress: Double
    var state: State
    var createdAt: Date
    var errorMessage: String?

    var localURL: URL? {
        guard let localFileName else { return nil }
        return DownloadManager.downloadsDirectory.appendingPathComponent(localFileName)
    }
}

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    static let downloadsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("AtlantiXDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    @Published private(set) var items: [OfflineDownload] = []
    @Published var allowCellular = true

    private var session: URLSession!
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var resumeData: [String: Data] = [:]
    private let storeURL = downloadsDirectory.appendingPathComponent("downloads.json")
    private let cellularKey = "atlantix.downloads.allowCellular"

    override private init() {
        super.init()
        allowCellular = UserDefaults.standard.object(forKey: cellularKey) as? Bool ?? true
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        load()
        repairInterruptedDownloads()
    }

    func setAllowCellular(_ value: Bool) {
        allowCellular = value
        UserDefaults.standard.set(value, forKey: cellularKey)
    }

    func contains(id: String) -> Bool { items.contains { $0.id == id } }

    func downloadMovie(id: Int, title: String, imageURL: String?, remoteURL: URL) {
        enqueue(id: "movie-\(id)", kind: .movie, title: title, subtitle: "Film", imageURL: imageURL, remoteURL: remoteURL)
    }

    func downloadEpisode(id: Int, title: String, series: String, season: String, episode: Int, imageURL: String?, remoteURL: URL) {
        enqueue(id: "episode-\(id)", kind: .episode, title: title, subtitle: "\(series) • S\(season) E\(episode)", imageURL: imageURL, remoteURL: remoteURL)
    }

    private func enqueue(id: String, kind: OfflineDownload.Kind, title: String, subtitle: String?, imageURL: String?, remoteURL: URL) {
        if let existing = items.first(where: { $0.id == id }) {
            if existing.state == .failed || existing.state == .paused { resume(id: id) }
            return
        }
        let item = OfflineDownload(id: id, kind: kind, title: title, subtitle: subtitle, imageURL: imageURL, remoteURL: remoteURL, localFileName: nil, progress: 0, state: .queued, createdAt: Date(), errorMessage: nil)
        items.insert(item, at: 0)
        save()
        start(id: id)
    }

    func start(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var request = URLRequest(url: items[index].remoteURL)
        request.allowsCellularAccess = allowCellular
        let task: URLSessionDownloadTask
        if let data = resumeData.removeValue(forKey: id) {
            task = session.downloadTask(withResumeData: data)
        } else {
            task = session.downloadTask(with: request)
        }
        task.taskDescription = id
        tasks[id] = task
        items[index].state = .downloading
        items[index].errorMessage = nil
        save()
        task.resume()
    }

    func pause(id: String) {
        guard let task = tasks[id], let index = items.firstIndex(where: { $0.id == id }) else { return }
        task.cancel { [weak self] data in
            Task { @MainActor in
                guard let self else { return }
                if let data { self.resumeData[id] = data }
                self.tasks[id] = nil
                self.items[index].state = .paused
                self.save()
            }
        }
    }

    func resume(id: String) { start(id: id) }

    func delete(id: String) {
        tasks[id]?.cancel()
        tasks[id] = nil
        resumeData[id] = nil
        if let item = items.first(where: { $0.id == id }), let url = item.localURL { try? FileManager.default.removeItem(at: url) }
        items.removeAll { $0.id == id }
        save()
    }

    func deleteAllCompleted() {
        let completed = items.filter { $0.state == .completed }
        completed.forEach { if let url = $0.localURL { try? FileManager.default.removeItem(at: url) } }
        items.removeAll { $0.state == .completed }
        save()
    }

    var activeItems: [OfflineDownload] { items.filter { $0.state != .completed } }
    var movies: [OfflineDownload] { items.filter { $0.kind == .movie && $0.state == .completed } }
    var episodes: [OfflineDownload] { items.filter { $0.kind == .episode && $0.state == .completed } }

    var usedBytes: Int64 {
        items.compactMap(\.localURL).reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return total + size
        }
    }

    private func update(id: String, _ change: (inout OfflineDownload) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
        save()
    }

    private func repairInterruptedDownloads() {
        for index in items.indices where items[index].state == .downloading || items[index].state == .queued {
            items[index].state = .paused
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL), let decoded = try? JSONDecoder().decode([OfflineDownload].self, from: data) else { return }
        items = decoded.filter { item in
            item.state != .completed || (item.localURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in self.update(id: id) { $0.progress = min(max(progress, 0), 1); $0.state = .downloading } }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        Task { @MainActor in
            guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
            let ext = self.items[index].remoteURL.pathExtension.isEmpty ? "mp4" : self.items[index].remoteURL.pathExtension
            let safeName = id.replacingOccurrences(of: "/", with: "-") + "." + ext
            let destination = Self.downloadsDirectory.appendingPathComponent(safeName)
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.moveItem(at: location, to: destination)
                self.items[index].localFileName = safeName
                self.items[index].progress = 1
                self.items[index].state = .completed
                self.items[index].errorMessage = nil
            } catch {
                self.items[index].state = .failed
                self.items[index].errorMessage = error.localizedDescription
            }
            self.tasks[id] = nil
            self.save()
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription, let error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        Task { @MainActor in
            self.tasks[id] = nil
            self.update(id: id) { $0.state = .failed; $0.errorMessage = error.localizedDescription }
        }
    }
}
