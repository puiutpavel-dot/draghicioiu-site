import Foundation
import Observation

/// Încarcă ofertele: întâi din cache sau din copia inclusă în aplicație, apoi live de pe draghicioiu.ro.
@MainActor
@Observable
final class Store {
    static let sursa = URL(string: "https://draghicioiu.ro/comparator-utilitati/oferte.json")!
    static let site = URL(string: "https://draghicioiu.ro/comparator-utilitati/")!

    private(set) var oferte: Oferte?
    private(set) var seIncarca = false
    private(set) var eroareRetea = false

    private static var fisierCache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("oferte.json")
    }

    init() {
        oferte = Self.decodeaza(try? Data(contentsOf: Self.fisierCache))
            ?? Self.decodeaza(Bundle.main.url(forResource: "oferte", withExtension: "json").flatMap { try? Data(contentsOf: $0) })
    }

    func reincarca() async {
        guard !seIncarca else { return }
        seIncarca = true
        defer { seIncarca = false }
        do {
            var req = URLRequest(url: Self.sursa)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 20
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200, let noi = Self.decodeaza(data) else {
                eroareRetea = true
                return
            }
            // Nu înlocuim date mai noi cu unele mai vechi (ex. cache CDN întârziat).
            if let vechi = oferte, vechi.actualizat > noi.actualizat {
                eroareRetea = false
                return
            }
            oferte = noi
            eroareRetea = false
            try? data.write(to: Self.fisierCache, options: .atomic)
        } catch {
            eroareRetea = true
        }
    }

    private static func decodeaza(_ data: Data?) -> Oferte? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Oferte.self, from: data)
    }
}
