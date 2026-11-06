import Foundation
import Observation

@MainActor
@Observable
final class ArchiveStore {
    enum State {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var archive: Archive?
    private(set) var state: State = .loading
    /// Set when showing the on-disk copy because the server couldn't be reached.
    private(set) var offlineNotice: String?

    private let cacheFile: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("index.html")
    }()

    init() {
        if let html = try? String(contentsOf: cacheFile, encoding: .utf8),
           let a = try? Archive.parse(html: html) {
            archive = a
            state = .loaded
        }
    }

    func refresh() async {
        if archive == nil { state = .loading }
        do {
            var req = URLRequest(url: Server.base, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            req.setValue("text/html", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            guard let html = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            let parsed = try Archive.parse(html: html)
            archive = parsed
            state = .loaded
            offlineNotice = nil
            try? data.write(to: cacheFile, options: .atomic)
        } catch {
            if archive != nil {
                offlineNotice = "Offline — showing the last copy downloaded."
                state = .loaded
            } else {
                state = .failed("Couldn't reach \(Server.base.host ?? "the server").\n\(error.localizedDescription)")
            }
        }
    }
}
