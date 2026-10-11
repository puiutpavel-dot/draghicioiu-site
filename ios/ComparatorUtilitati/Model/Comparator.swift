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
        Categorie.allCases.compactMap { randuri($0).first?.lunar }.reduce(0, +)
    }
}

enum Comparator {
    static func calculeaza(_ d: Oferte, _ loc: Locatie, kwhCurent: Double, kwhGaz: Double, azi: Date = .now) -> Rezultat {
        let ziua = Format.iso(azi)
        func activa(_ panaLa: String?) -> Bool { panaLa.map { $0 >= ziua } ?? true }

        let curent = d.electricitate
            .filter { activa($0.panaLa) }
            .compactMap { o -> Rand? in
                guard let p = o.pret[loc.zonaCurent] else { return nil }
                return Rand(id: "el-\(o.furnizor)-\(o.oferta)", furnizor: o.furnizor, oferta: o.oferta,
                            lunar: p * kwhCurent, pretUnitar: "\(Format.lei(p, zecimale: 4)) lei/kWh",
                            dupaPromo: nil, detalii: o.nota, contract: nil, expira: o.panaLa,
                            link: o.link.flatMap { URL(string: $0) })
            }
            .sorted { $0.lunar < $1.lunar }

        let gaz = d.gaze
            .filter { activa($0.panaLa) }
            .filter { o in loc.operatorGaz.map { o.arii.contains($0) } ?? true }
            .map { o in
                Rand(id: "gaz-\(o.furnizor)-\(o.oferta)", furnizor: o.furnizor, oferta: o.oferta,
                     lunar: o.pret * kwhGaz, pretUnitar: "\(Format.lei(o.pret, zecimale: 4)) lei/kWh",
                     dupaPromo: nil, detalii: o.nota, contract: nil, expira: o.panaLa,
                     link: o.link.flatMap { URL(string: $0) })
            }
            .sorted { $0.lunar < $1.lunar }

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
                            link: o.link.flatMap { URL(string: $0) })
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

    /// „2026-10-31” → „31 oct.” (sau „31 octombrie 2026” cu an)
    static func data(_ s: String, cuAn: Bool = false) -> String {
        guard let d = isoFmt.date(from: s) else { return s }
        let f = DateFormatter()
        f.locale = ro
        f.dateFormat = cuAn ? "d MMMM yyyy" : "d MMM"
        return f.string(from: d)
    }
}
