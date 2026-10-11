import Foundation
import Observation

/// Încarcă datele de pe draghicioiu.ro, cu cache pe telefon și copii incluse în aplicație:
/// - oferte.json          telecom (editat manual)
/// - anre.json            curent și gaz, preluate zilnic din comparatorul ANRE
/// - gaz-localitati.json  localitățile cu rețea de gaz și tariful lor de distribuție
/// - cp/NN.json           coduri poștale → localitate (la cerere, pe județ)
@MainActor
@Observable
final class Store {
    static let baza = URL(string: "https://draghicioiu.ro/comparator-utilitati/")!
    static let site = baza

    private(set) var oferte: Oferte?
    private(set) var anre: Anre?
    private(set) var localitati: LocalitatiGaz?
    private(set) var seIncarca = false
    private(set) var eroareRetea = false
    private var coduri: [String: FisierCoduri] = [:]

    init() {
        oferte = Self.citeste("oferte.json")
        anre = Self.citeste("anre.json")
        localitati = Self.citeste("gaz-localitati.json")
    }

    var gata: Bool { oferte != nil }

    /// Reîncarcă tot de pe site; ce nu reușește rămâne din cache.
    func reincarca() async {
        guard !seIncarca else { return }
        seIncarca = true
        defer { seIncarca = false }
        async let t: Oferte? = Self.descarca("oferte.json")
        async let a: Anre? = Self.descarca("anre.json")
        async let l: LocalitatiGaz? = Self.descarca("gaz-localitati.json")
        let (to, ao, lo) = await (t, a, l)
        if let to, to.actualizat >= (oferte?.actualizat ?? "") { oferte = to }
        if let ao, ao.actualizat >= (anre?.actualizat ?? "") { anre = ao }
        if let lo, lo.actualizat >= (localitati?.actualizat ?? "") { localitati = lo }
        eroareRetea = to == nil && ao == nil
    }

    /// Completează locația cu localitatea din codul poștal și rețeaua de gaz.
    /// `sirutaAleasa` = localitatea aleasă manual din listă.
    func completeaza(_ baza: Locatie, sirutaAleasa: Int? = nil) async -> Result<Locatie, Geografie.Eroare> {
        var loc = baza
        if !loc.esteBucuresti {
            let pref = String(loc.codPostal.prefix(2))
            if let f = await fisierCoduri(pref) {
                guard let e = f.cp[loc.codPostal] else { return .failure(.necunoscut) }
                loc.judetAnre = f.judet
                loc.localitate = e.localitate
                loc.siruta = e.siruta
            }
        }
        if let sirutaAleasa { loc.siruta = sirutaAleasa }
        let lista = loc.judetAnre.flatMap { localitati?.judete[$0] } ?? []
        loc.localitatiGaz = lista.sorted { $0.nume.localizedCompare($1.nume) == .orderedAscending }
        if let s = loc.siruta {
            loc.t0 = lista.first(where: { $0.siruta == s })?.t0
                ?? (s == 999_999 ? anre?.gaz?.judete["BUCURESTI"]?.t0 : nil)
            if loc.t0 == nil, !lista.contains(where: { $0.siruta == s }), s != 999_999 { loc.siruta = nil }
        }
        loc.operatorGaz = Geografie.operatorGaz(codJudet: loc.codJudet, t0: loc.t0, anre: anre)
        return .success(loc)
    }

    private func fisierCoduri(_ pref: String) async -> FisierCoduri? {
        if let f = coduri[pref] { return f }
        let nume = "cp-\(pref).json"
        var f: FisierCoduri? = await Self.descarca("cp/\(pref).json", cache: nume)
        if f == nil { f = Self.citeste(nume) }
        if let f { coduri[pref] = f }
        return f
    }

    // MARK: - Fișiere

    private static var dirCache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    /// Din cache, altfel copia inclusă în aplicație.
    private static func citeste<T: Decodable>(_ nume: String) -> T? {
        if let d = try? Data(contentsOf: dirCache.appendingPathComponent(nume)), let v = try? JSONDecoder().decode(T.self, from: d) {
            return v
        }
        let parti = nume.split(separator: ".")
        guard let url = Bundle.main.url(forResource: String(parti[0]), withExtension: "json"),
              let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    private static func descarca<T: Decodable>(_ cale: String, cache: String? = nil) async -> T? {
        var req = URLRequest(url: baza.appendingPathComponent(cale))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        guard let raspuns = try? await URLSession.shared.data(for: req) else { return nil }
        let (data, resp) = raspuns
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let v = try? JSONDecoder().decode(T.self, from: data) else { return nil }
        try? data.write(to: dirCache.appendingPathComponent(cache ?? cale), options: .atomic)
        return v
    }
}
