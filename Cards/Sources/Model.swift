import Foundation

/// The archive server, set by CARDS_SERVER_URL in Config.xcconfig (gitignored).
enum Server {
    static let base: URL = {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "CardsServerURL") as? String,
              let url = URL(string: s), url.host != nil else {
            fatalError("Set CARDS_SERVER_URL in Config.xcconfig (see Config.example.xcconfig)")
        }
        return url
    }()
    static func image(_ file: String) -> URL { base.appendingPathComponent("img").appendingPathComponent(file) }
}

/// One card, as `gen.py` embeds it in `index.html` (`const CARDS = [...]`).
struct Card: Identifiable, Hashable, Decodable {
    let id: String
    let folder: String
    let sub: String?
    let year: Int?
    let title: String
    let fileName: String
    let status: String
    let flag: String
    let images: [String]
    let coverIndex: Int
    let fields: [Field]
    let paragraphs: [String]
    let haystack: String

    struct Field: Hashable {
        let key: String
        let value: String
    }

    enum CodingKeys: String, CodingKey {
        case id, f, sub, y, t, n, st, fl, im, cv, fd, p, q
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        folder = try c.decode(String.self, forKey: .f)
        sub = try c.decodeIfPresent(String.self, forKey: .sub)
        year = try c.decodeIfPresent(Int.self, forKey: .y)
        title = try c.decode(String.self, forKey: .t)
        fileName = (try? c.decode(String.self, forKey: .n)) ?? ""
        status = (try? c.decode(String.self, forKey: .st)) ?? "ok"
        flag = (try? c.decode(String.self, forKey: .fl)) ?? ""
        images = (try? c.decode([String].self, forKey: .im)) ?? []
        coverIndex = (try? c.decode(Int.self, forKey: .cv)) ?? 0
        let raw = (try? c.decode([[String?]].self, forKey: .fd)) ?? []
        fields = raw.compactMap { pair in
            guard pair.count >= 2, let k = pair[0], let v = pair[1], !v.isEmpty else { return nil }
            return Field(key: k, value: v)
        }
        paragraphs = (try? c.decode([String].self, forKey: .p)) ?? []
        haystack = (try? c.decode(String.self, forKey: .q)) ?? title.lowercased()
    }

    var cover: String? {
        guard !images.isEmpty else { return nil }
        return images[min(max(coverIndex, 0), images.count - 1)]
    }

    var yearText: String { year.map(String.init) ?? "—" }

    func matches(_ words: [String]) -> Bool {
        words.allSatisfy { haystack.contains($0) }
    }
}

struct CardSection: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let blurb: String
    var cards: [Card]
}

struct Archive {
    let sections: [CardSection]
    let cardCount: Int
    let pageCount: Int
    let yearRange: ClosedRange<Int>?

    enum ParseError: LocalizedError {
        case noData
        var errorDescription: String? { "The page didn't contain any card data." }
    }

    /// Parses the generated `index.html`: card data from the `CARDS` literal, section
    /// order and blurbs from the rendered `<section class="folder">` headers.
    static func parse(html: String) throws -> Archive {
        guard let start = html.range(of: "const CARDS = ") else { throw ParseError.noData }
        let tail = html[start.upperBound...]
        guard let end = tail.range(of: "];\n") ?? tail.range(of: "];") else { throw ParseError.noData }
        let json = tail[..<end.lowerBound] + "]"
        let cards = try JSONDecoder().decode([Card].self, from: Data(json.utf8))

        var order: [String] = []
        var blurbs: [String: String] = [:]
        let sectionPattern = try NSRegularExpression(
            pattern: #"<section class="folder" data-folder="([^"]*)"><header class="fhead"><h2>[^<]*</h2><p class="fblurb">([^<]*)</p>"#)
        let ns = html as NSString
        for m in sectionPattern.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let name = unescape(ns.substring(with: m.range(at: 1)))
            if !order.contains(name) { order.append(name) }
            blurbs[name] = unescape(ns.substring(with: m.range(at: 2)))
        }

        var byFolder: [String: [Card]] = [:]
        for c in cards { byFolder[c.folder, default: []].append(c) }
        for c in cards where !order.contains(c.folder) { order.append(c.folder) }

        let sections: [CardSection] = order.compactMap { name in
            guard let list = byFolder[name], !list.isEmpty else { return nil }
            let sorted = list.sorted { a, b in
                switch (a.year, b.year) {
                case let (x?, y?) where x != y: return x < y
                case (nil, _?): return false
                case (_?, nil): return true
                default: return a.title.lowercased() < b.title.lowercased()
                }
            }
            return CardSection(name: name, blurb: blurbs[name] ?? "", cards: sorted)
        }
        let years = cards.compactMap(\.year)
        return Archive(
            sections: sections,
            cardCount: cards.count,
            pageCount: cards.reduce(0) { $0 + $1.images.count },
            yearRange: years.min().flatMap { lo in years.max().map { lo...$0 } })
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&#x27;", with: "'")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&amp;", with: "&")
    }
}
