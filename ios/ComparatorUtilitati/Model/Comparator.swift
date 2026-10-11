import Foundation

/// Un rând din clasament, gata de afișat.
struct Rand: Identifiable, Hashable {
    let id: String
    let furnizor: String
    let oferta: String
    /// Cost lunar estimat în lei (sau abonamentul lunar, la telecom).
    let lunar: Double
    /// ex. „1,0400 lei/kWh” sau „6,25 €”
    let pretUnitar: String?
    /// ex. „apoi 26,39 lei după 12 luni”
    let dupaPromo: String?
    let detalii: String?
    let contract: String?
    let expira: String?
    let link: URL?
    var pdf: URL? = nil
    var serviciuUniversal = false
}

enum Categorie: String, CaseIterable, Identifiable {
    case curent, gaz, internet, tv, mobil
    var id: String { rawValue }

    var titlu: String {
        switch self {
        case .curent: "Energie electrică"
        case .gaz: "Gaze naturale"
        case .internet: "Internet fix"
        case .tv: "Cablu TV"
        case .mobil: "Telefonie mobilă"
        }
    }

    var scurt: String {
        switch self {
        case .curent: "Curent"
        case .gaz: "Gaz"
        case .internet: "Internet"
        case .tv: "TV"
        case .mobil: "Mobil"
        }
    }

    var simbol: String {
        switch self {
        case .curent: "bolt.fill"
        case .gaz: "flame.fill"
        case .internet: "wifi"
        case .tv: "tv.fill"
        case .mobil: "iphone"
        }
    }
}

struct Rezultat {
    let locatie: Locatie
    let curent: [Rand]
    let gaz: [Rand]
    let internet: [Rand]
    let tv: [Rand]
    let mobil: [Rand]

    func randuri(_ c: Categorie) -> [Rand] {
        switch c {
        case .curent: curent
        case .gaz: gaz
        case .internet: internet
        case .tv: tv
        case .mobil: mobil
        }
    }

    /// Suma celor mai ieftine oferte din fiecare categorie.
    var total: Double {
        Categorie.allCases
            .filter { $0 != .gaz || locatie.t0 != nil }
            .compactMap { randuri($0).first?.lunar }
            .reduce(0, +)
    }
}

enum Comparator {
    static func calculeaza(telecom d: Oferte, anre: Anre?, _ loc: Locatie, kwhCurent: Double, kwhGaz: Double, azi: Date = .now) -> Rezultat {
        let ziua = Format.iso(azi)
        func activa(_ panaLa: String?) -> Bool { panaLa.map { $0 >= ziua } ?? true }
        func url(_ s: String?) -> URL? { s.flatMap { URL(string: $0) } }

        let curent = (anre?.curent?[loc.zonaCurent] ?? [])
            .filter { activa($0.pana) }
            .map { o -> Rand in
                Rand(id: "el-\(o.c)-\(o.f)", furnizor: Format.furnizor(o.f), oferta: o.o,
                     lunar: o.p * kwhCurent + o.fz,
                     pretUnitar: "\(Format.lei(o.p, zecimale: 4)) lei/kWh" + (o.fz > 0 ? " + \(Format.lei(o.fz)) lei/lună fix" : ""),
                     dupaPromo: nil, detalii: o.tip, contract: o.durata.map { "contract \($0)" }, expira: o.pana,
                     link: url(o.link), pdf: url(o.pdf), serviciuUniversal: o.su ?? false)
            }
            .sorted { $0.lunar < $1.lunar }

        var gaz: [Rand] = []
        if let g = anre?.gaz, let j = loc.judetAnre, let jg = g.judete[j] {
            let t0 = loc.t0 ?? jg.t0
            let dupaCod = Dictionary(g.oferte.map { ($0.c, $0) }, uniquingKeysWith: { a, _ in a })
            gaz = jg.oferte.compactMap { dupaCod[$0] }
                .filter { activa($0.pana) }
                .map { o -> Rand in
                    let p = o.pret(t0: t0)
                    let fz = o.fz ?? 0
                    return Rand(id: "gaz-\(o.c)-\(o.f)", furnizor: Format.furnizor(o.f), oferta: o.o,
                                lunar: p * kwhGaz + fz,
                                pretUnitar: "\(Format.lei(p, zecimale: 4)) lei/kWh" + (fz > 0 ? " + \(Format.lei(fz)) lei/lună fix" : ""),
                                dupaPromo: nil, detalii: [o.tip, o.garantii].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                                contract: o.durata.map { "contract \($0)" }, expira: o.pana, link: url(o.link))
                }
                .sorted { $0.lunar < $1.lunar }
        }

        func telecom(_ lista: [OfertaTelecom], _ prefix: String) -> [Rand] {
            lista.compactMap { o -> Rand? in
                guard let lunar = o.ron ?? o.eur.map({ $0 * d.cursEur }) else { return nil }
                let dupa = o.eurDupa.map { e -> String in
                    let luni = o.luniPromo.map { " după \($0) luni" } ?? ""
                    return "apoi \(Format.lei(e * d.cursEur)) lei\(luni)"
                }
                let detalii = [o.include, o.nota].compactMap { $0 }.joined(separator: "\n")
                return Rand(id: "\(prefix)-\(o.operatorName)-\(o.oferta)", furnizor: o.operatorName, oferta: o.oferta,
                            lunar: lunar, pretUnitar: o.eur.map { "\(Format.lei($0)) €" },
                            dupaPromo: dupa, detalii: detalii, contract: o.contract, expira: nil,
                            link: url(o.link))
            }
            .sorted { $0.lunar < $1.lunar }
        }

        return Rezultat(locatie: loc, curent: curent, gaz: gaz,
                        internet: telecom(d.internet, "net"), tv: telecom(d.tv, "tv"), mobil: telecom(d.mobil, "mob"))
    }
}

enum Format {
    private static let ro = Locale(identifier: "ro_RO")

    static func lei(_ v: Double, zecimale: Int = 2) -> String {
        v.formatted(.number.precision(.fractionLength(zecimale)).locale(ro))
    }

    private static let isoFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func iso(_ d: Date) -> String { isoFmt.string(from: d) }

    /// „SPEEH HIDROELECTRICA” → „Speeh Hidroelectrica”; numele scrise deja cu litere mici rămân cum sunt.
    static func furnizor(_ s: String) -> String {
        if s.contains(where: \.isLowercase) { return s }
        var t = Geografie.titlu(s)
        for (a, b) in [(" Srl", " SRL"), (" Sa", " SA"), (" S.r.l.", " S.R.L."), (" S.a.", " S.A.")] where t.hasSuffix(a) {
            t = String(t.dropLast(a.count)) + b
        }
        return t
    }

    /// „2026-10-31” → „31 oct.” (sau „31 octombrie 2026” cu an)
    static func data(_ s: String, cuAn: Bool = false) -> String {
        guard let d = isoFmt.date(from: s) else { return s }
        let f = DateFormatter()
        f.locale = ro
        f.dateFormat = cuAn ? "d MMMM yyyy" : "d MMM"
        return f.string(from: d)
    }
}
