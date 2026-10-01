import Foundation
import ffmpegkit

/// Local compatibility bridge for containers AVPlayer cannot open directly.
/// FFmpeg runs on-device and remuxes the original URL into a local HLS playlist.
/// Video is stream-copied whenever possible; audio is normalized to AAC.
final class FFmpegLocalRemuxer {
    static let shared = FFmpegLocalRemuxer()
    private let queue = DispatchQueue(label: "com.dmb.atxplayer.ffmpeg-remux", qos: .userInitiated)
    private var generation = UUID()
    private var activeSession: FFmpegSession?
    private var activeDirectory: URL?

    private init() {}

    func stop() {
        generation = UUID()
        activeSession?.cancel()
        activeSession = nil
        if let activeDirectory { try? FileManager.default.removeItem(at: activeDirectory) }
        activeDirectory = nil
    }

    func prepare(source: URL, isLive: Bool, completion: @escaping (Result<URL, Error>) -> Void) {
        stop()
        let token = UUID()
        generation = token

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ATXFFmpeg-\(token.uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            completion(.failure(error)); return
        }
        activeDirectory = directory
        let playlist = directory.appendingPathComponent("stream.m3u8")
        let segmentPattern = directory.appendingPathComponent("seg-%06d.ts").path

        var args = [
            "-hide_banner", "-loglevel", "warning", "-y",
            "-rw_timeout", "15000000",
            "-i", source.absoluteString,
            "-map", "0:v:0?", "-map", "0:a:0?",
            "-c:v", "copy",
            "-c:a", "aac", "-ac", "2", "-b:a", "192k",
            "-f", "hls", "-hls_time", isLive ? "2" : "4",
            "-hls_segment_filename", segmentPattern
        ]
        if isLive {
            args += ["-hls_list_size", "8", "-hls_flags", "delete_segments+independent_segments+temp_file"]
        } else {
            args += ["-hls_list_size", "0", "-hls_playlist_type", "event", "-hls_flags", "independent_segments+temp_file"]
        }
        args.append(playlist.path)

        activeSession = FFmpegKit.executeWithArgumentsAsync(args, withCompleteCallback: { [weak self] session in
            guard let self, self.generation == token else { return }
            // If no playable playlist was ever produced, try a VideoToolbox H.264 fallback.
            if !FileManager.default.fileExists(atPath: playlist.path) {
                self.startVideoToolboxFallback(source: source, isLive: isLive, directory: directory, playlist: playlist, token: token, completion: completion)
            }
        })

        waitUntilPlayable(playlist: playlist, directory: directory, token: token, completion: completion)
    }

    private func startVideoToolboxFallback(source: URL, isLive: Bool, directory: URL, playlist: URL, token: UUID, completion: @escaping (Result<URL, Error>) -> Void) {
        guard generation == token else { return }
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let segmentPattern = directory.appendingPathComponent("seg-%06d.ts").path
        var args = [
            "-hide_banner", "-loglevel", "warning", "-y",
            "-rw_timeout", "15000000", "-i", source.absoluteString,
            "-map", "0:v:0?", "-map", "0:a:0?",
            "-c:v", "h264_videotoolbox", "-b:v", "6000k", "-allow_sw", "1",
            "-c:a", "aac", "-ac", "2", "-b:a", "192k",
            "-f", "hls", "-hls_time", isLive ? "2" : "4",
            "-hls_segment_filename", segmentPattern
        ]
        if isLive {
            args += ["-hls_list_size", "8", "-hls_flags", "delete_segments+independent_segments+temp_file"]
        } else {
            args += ["-hls_list_size", "0", "-hls_playlist_type", "event", "-hls_flags", "independent_segments+temp_file"]
        }
        args.append(playlist.path)
        activeSession = FFmpegKit.executeWithArgumentsAsync(args, withCompleteCallback: { [weak self] _ in
            guard let self, self.generation == token else { return }
            if !FileManager.default.fileExists(atPath: playlist.path) {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ATXFFmpeg", code: 2, userInfo: [NSLocalizedDescriptionKey: "Il contenuto non può essere convertito localmente."])))
                }
            }
        })
        waitUntilPlayable(playlist: playlist, directory: directory, token: token, completion: completion)
    }

    private func waitUntilPlayable(playlist: URL, directory: URL, token: UUID, completion: @escaping (Result<URL, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            for _ in 0..<240 { // up to ~30 seconds
                guard self.generation == token else { return }
                let hasPlaylist = FileManager.default.fileExists(atPath: playlist.path)
                let segments = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
                    .filter { $0.pathExtension.lowercased() == "ts" } ?? []
                if hasPlaylist && !segments.isEmpty {
                    DispatchQueue.main.async { completion(.success(playlist)) }
                    return
                }
                Thread.sleep(forTimeInterval: 0.125)
            }
        }
    }
}
