import Foundation

@MainActor
final class MKVRemuxService: ObservableObject {
    static let shared = MKVRemuxService()
    @Published private(set) var preparing = false
    private var generation = UUID()
    private var outputURL: URL?

    private init() {}

    func cancel() {
        generation = UUID()
        preparing = false
        if let outputURL { try? FileManager.default.removeItem(at: outputURL) }
        outputURL = nil
    }

    func prepare(_ source: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        cancel()
        let token = UUID(); generation = token; preparing = true
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("ATX-\(token.uuidString).mp4")
        outputURL = out
        let input = source.absoluteString
        DispatchQueue.global(qos: .userInitiated).async {
            let code = input.withCString { inPtr in
                out.path.withCString { outPtr in atx_remux_to_mp4(inPtr, outPtr) }
            }
            DispatchQueue.main.async {
                guard self.generation == token else { return }
                self.preparing = false
                if code == 0, FileManager.default.fileExists(atPath: out.path) {
                    completion(.success(out))
                } else {
                    try? FileManager.default.removeItem(at: out)
                    completion(.failure(NSError(domain: "ATXMKV", code: Int(code), userInfo: [NSLocalizedDescriptionKey: "Questo MKV contiene codec che AVPlayer non può riprodurre dopo il remux."])))
                }
            }
        }
    }
}
