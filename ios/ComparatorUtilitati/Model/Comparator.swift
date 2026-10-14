import Foundation

/// O parte din prețul final, în lei/kWh fără TVA.
struct Componenta: Hashable, Identifiable {
    let nume: String
    let valoare: Double
    var id: String { nume }
}

/// Un rând din clasament, gata de afișat.
struct Rand: Identifiable, Hashable {
    let id: String
    let categorie: Categorie
    let furnizor: String
    let oferta: String
    /// Codul ofertei în comparatorul ANRE.
    var cod: String? = nil
    /// Cost lunar mediu estimat (energie) sau abonamentul lunar (telecom), în lei.
    let lunar: Double
    /// Preț final lei/kWh cu TVA (doar la energie).
    var pretKwh: Double? = nil
    /// Componenta fixă, lei/lună cu TVA.
    var fixLuna: Double = 0
    /// ex. „1,0439 lei/kWh” sau „6,25 €”
    let pretUnitar: String?
    var dupaPromo: String? = nil
    var detalii: String? = nil
    var contract: String? = nil
    var expira: String? = nil
    var link: URL? = nil
    var pdf: URL? = nil
    var serviciuUniversal = false
    var componente: [Componenta] = []
    var tva: Double = 21
    var tip: String? = nil
    var durata: String? = nil
    var garantii: String? = nil

    var anual: Double { lunar * 12 }
}

enum Categorie: String, CaseIterable, Identifiable, Codable {
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

struct Energie {
    let curent: [Rand]
    let gaz: [Rand]

    func randuri(_ c: Categorie) -> [Rand] { c == .gaz ? gaz : curent }
}

enum Comparator {
    /// Cât din consumul anual cade în fiecare lună (ianuarie … decembrie).
    /// Curent: aproape constant, puțin mai mult iarna. Gaz: încălzirea face ca iarna să conteze mult mai mult.
    static let profilCurent: [Double] = [1.12, 1.05, 1.00, 0.95, 0.90, 0.92, 1.00, 1.00, 0.92, 0.98, 1.05, 1.11].map { $0 / 12 }
    static let profilGaz: [Double] = [17, 15, 12, 7, 4, 3, 3, 3, 4, 7, 11, 14].map { $0 / 100 }
    static let luni = ["ian", "feb", "mar", "apr", "mai", "iun", "iul", "aug", "sep", "oct", "noi", "dec"]

    /// Costul pe fiecare lună a anului, pentru un consum lunar mediu.
    static func costPeLuni(pretKwh: Double, fixLuna: Double, kwhMediu: Double, categorie: Categorie) -> [Double] {
        let profil = categorie == .gaz ? profilGaz : profilCurent
        return profil.map { pretKwh * kwhMediu * 12 * $0 + fixLuna }
    }

    /// Ofertele de curent și gaz pentru o zonă, ordonate după costul lunar estimat.
    static func energie(anre: Anre?, zona: String, judetAnre: String?, t0: Double?,
                        kwhCurent: Double, kwhGaz: Double, azi: Date = .now) -> Energie {
        let ziua = Format.iso(azi)
        func activa(_ panaLa: String?) -> Bool { panaLa.map { $0 >= ziua } ?? true }
        func url(_ s: String?) -> URL? { s.flatMap { URL(string: $0) } }

        let curent = (anre?.curent?[zona] ?? [])
            .filter { activa($0.pana) }
            .map { o -> Rand in
                var comp: [Componenta] = []
                if let c = o.comp, c.count >= 7 {
                    comp = [
                        Componenta(nume: "Energie (prețul furnizorului)", valoare: c[0]),
                        Componenta(nume: "Distribuție", valoare: c[1]),
                        Componenta(nume: "Transport și servicii de sistem", valoare: c[2] + c[3]),
                        Componenta(nume: "Certificate verzi, cogenerare, acciză", valoare: c[4] + c[5] + c[6]),
                    ]
                }
                return Rand(id: "el-\(o.c)-\(o.f)", categorie: .curent, furnizor: Format.furnizor(o.f), oferta: o.o, cod: o.c,
                            lunar: o.p * kwhCurent + o.fz, pretKwh: o.p, fixLuna: o.fz,
                            pretUnitar: "\(Format.lei(o.p, zecimale: 4)) lei/kWh" + (o.fz > 0 ? " + \(Format.lei(o.fz)) lei/lună fix" : ""),
                            expira: o.pana, link: url(o.link), pdf: url(o.pdf), serviciuUniversal: o.su ?? false,
                            componente: comp, tva: o.tva ?? 21, tip: o.tip, durata: o.durata)
            }
            .sorted { $0.lunar < $1.lunar }

        var gaz: [Rand] = []
        if let g = anre?.gaz, let j = judetAnre, let jg = g.judete[j] {
            let t0 = t0 ?? jg.t0
            let dupaCod = Dictionary(g.oferte.map { ($0.c, $0) }, uniquingKeysWith: { a, _ in a })
            gaz = jg.oferte.compactMap { dupaCod[$0] }
                .filter { activa($0.pana) }
                .map { o -> Rand in
                    let p = o.pret(t0: t0)
                    let fz = o.fz ?? 0
                    var comp = [
                        Componenta(nume: "Gaz (prețul furnizorului)", valoare: o.pg / 1000),
                        Componenta(nume: "Transport", valoare: o.tt / 1000),
                        Componenta(nume: "Distribuție (localitatea ta)", valoare: t0 / 1000),
                    ]
                    if let acc = o.acc, acc > 0 { comp.append(Componenta(nume: "Acciză", valoare: acc / 1000)) }
                    return Rand(id: "gaz-\(o.c)-\(o.f)", categorie: .gaz, furnizor: Format.furnizor(o.f), oferta: o.o, cod: o.c,
                                lunar: p * kwhGaz + fz, pretKwh: p, fixLuna: fz,
                                pretUnitar: "\(Format.lei(p, zecimale: 4)) lei/kWh" + (fz > 0 ? " + \(Format.lei(fz)) lei/lună fix" : ""),
                                expira: o.pana, link: url(o.link),
                                componente: comp, tva: o.tva ?? 21, tip: o.tip, durata: o.durata, garantii: o.garantii)
                }
                .sorted { $0.lunar < $1.lunar }
        }
        return Energie(curent: curent, gaz: gaz)
    }

    /// Costul lunar al contractului actual. Dacă oferta a fost aleasă din lista ANRE și încă e activă,
    /// se folosește prețul ei recalculat pentru localitate; altfel prețul scris de pe factură.
    static func costContract(_ c: ContractActual?, in lista: [Rand], kwh: Double) -> Double? {
        guard let c else { return nil }
        if let cod = c.cod, let r = lista.first(where: { $0.cod == cod }) { return r.lunar }
        return c.pretKwh * kwh + c.fixLuna
    }

    static func telecom(_ d: Oferte?) -> (internet: [Rand], tv: [Rand], mobil: [Rand]) {
        guard let d else { return ([], [], []) }
        func lista(_ l: [OfertaTelecom], _ cat: Categorie) -> [Rand] {
            l.compactMap { o -> Rand? in
                guard let lunar = o.ron ?? o.eur.map({ $0 * d.cursEur }) else { return nil }
                let dupa = o.eurDupa.map { e -> String in
                    let luni = o.luniPromo.map { " după \($0) luni" } ?? ""
                    return "apoi \(Format.lei(e * d.cursEur)) lei\(luni)"
                }
                return Rand(id: "\(cat.rawValue)-\(o.operatorName)-\(o.oferta)", categorie: cat, furnizor: o.operatorName, oferta: o.oferta,
                            lunar: lunar, pretUnitar: o.eur.map { "\(Format.lei($0)) €" },
                            dupaPromo: dupa, detalii: [o.include, o.nota].compactMap { $0 }.joined(separator: "\n"),
                            contract: o.contract, link: o.link.flatMap { URL(string: $0) })
            }
            .sorted { $0.lunar < $1.lunar }
        }
        return (lista(d.internet, .internet), lista(d.tv, .tv), lista(d.mobil, .mobil))
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
        f.timeZone = TimeZone(identifier: "Europe/Bucharest")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func iso(_ d: Date) -> String { isoFmt.string(from: d) }
    static func dinIso(_ s: String) -> Date? { isoFmt.date(from: String(s.prefix(10))) }

    /// Interpretează „1,45” sau „1.45”.
    static func numar(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

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
        guard let d = dinIso(s) else { return s }
        let f = DateFormatter()
        f.locale = ro
        f.timeZone = TimeZone(identifier: "Europe/Bucharest")
        f.dateFormat = cuAn ? "d MMMM yyyy" : "d MMM"
        return f.string(from: d)
    }
}
