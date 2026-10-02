import Foundation
import Network

final class LocalHLSHTTPServer {
    private let root: URL
    private let queue = DispatchQueue(label: "com.dmb.atxplayer.localhls")
    private var listener: NWListener?
    private(set) var port: UInt16

    init(root: URL) {
        self.root = root
        self.port = UInt16.random(in: 49152...64000)
    }

    var playlistURL: URL {
        URL(string: "http://127.0.0.1:\(port)/stream.m3u8")!
    }

    func start() throws {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "ATXLocalHLS", code: 1)
        }
        let listener = try NWListener(using: .tcp, on: endpointPort)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let firstLine = request.components(separatedBy: "\r\n").first ?? ""
            let parts = firstLine.split(separator: " ")
            guard parts.count >= 2 else {
                self.send(status: "400 Bad Request", body: Data(), type: "text/plain", connection: connection)
                return
            }

            let rawPath = String(parts[1]).split(separator: "?").first.map(String.init) ?? "/"
            let name = rawPath.removingPercentEncoding?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
            guard !name.isEmpty, !name.contains("..") else {
                self.send(status: "404 Not Found", body: Data(), type: "text/plain", connection: connection)
                return
            }

            let fileURL = self.root.appendingPathComponent(name)
            guard let body = try? Data(contentsOf: fileURL) else {
                self.send(status: "404 Not Found", body: Data(), type: "text/plain", connection: connection)
                return
            }

            let ext = fileURL.pathExtension.lowercased()
            let type: String
            switch ext {
            case "m3u8": type = "application/vnd.apple.mpegurl"
            case "m4s", "mp4": type = "video/mp4"
            case "ts": type = "video/mp2t"
            default: type = "application/octet-stream"
            }
            self.send(status: "200 OK", body: body, type: type, connection: connection)
        }
    }

    private func send(status: String, body: Data, type: String, connection: NWConnection) {
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(type)\r
        Content-Length: \(body.count)\r
        Cache-Control: no-cache, no-store, must-revalidate\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        """
        var packet = Data(header.utf8)
        packet.append(body)
        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }
}
