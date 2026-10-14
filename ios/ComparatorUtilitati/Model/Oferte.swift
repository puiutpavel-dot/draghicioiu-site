import Foundation

// MARK: - Telecom (oferte.json, editat manual)

struct Oferte: Codable {
    let actualizat: String
    let cursEur: Double
    let internet: [OfertaTelecom]
    let tv: [OfertaTelecom]
    let mobil: [OfertaTelecom]

    enum CodingKeys: String, CodingKey {
        case actualizat, internet, tv, mobil
        case cursEur = "curs_eur"
    }
}

/// Abonament lunar: în euro (cu TVA) sau în lei.
struct OfertaTelecom: Codable, Hashable {
    let operatorName: String
    let oferta: String
    let eur: Double?
    let ron: Double?
    let eurDupa: Double?
    let luniPromo: Int?
    let include: String
    let contract: String?
    let nota: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case oferta, eur, ron, include, contract, nota, link
        case operatorName = "operator"
        case eurDupa = "eur_dupa"
        case luniPromo = "luni_promo"
    }
}

// MARK: - Curent și gaz (anre.json, preluat zilnic din comparatorul ANRE)

struct Anre: Codable {
    let actualizat: String
    let zi: String?
    /// zona de distribuție → oferte
    let curent: [String: [OfertaCurent]]?
    let gaz: Gaz?

    struct Gaz: Codable {
        let oferte: [OfertaGaz]
        /// județ (ex. „BUCURESTI”) → codurile ofertelor disponibile + tariful de distribuție la reședință
        let judete: [String: JudetGaz]
    }

    struct JudetGaz: Codable {
        let oferte: [String]
        let t0: Double
    }
}

struct OfertaCurent: Codable, Hashable {
    let f: String          // furnizor
    let o: String          // denumirea ofertei
    let c: String          // codul ofertei
    let p: Double          // preț final lei/kWh cu TVA (fără componenta fixă)
    let fz: Double         // componenta fixă, lei/lună cu TVA
    let tip: String?
    let su: Bool?          // serviciu universal
    let pana: String?      // valabilă până la (yyyy-MM-dd)
    let durata: String?
    let link: String?
    let pdf: String?
    /// lei/kWh fără TVA: energie, distribuție, transport, servicii de sistem, cogenerare, certificate verzi, acciză
    let comp: [Double]?
    let tva: Double?
}

struct OfertaGaz: Codable, Hashable {
    let f: String
    let o: String
    let c: String
    let pg: Double         // preț gaz, lei/MWh fără TVA
    let tt: Double         // tarif transport, lei/MWh
    let acc: Double?
    let tva: Double?
    let fz: Double?
    let tip: String?
    let pana: String?
    let durata: String?
    let garantii: String?
    let link: String?

    /// Preț final lei/kWh cu TVA pentru un tarif de distribuție dat (lei/MWh).
    func pret(t0: Double) -> Double {
        (pg + tt + t0 + (acc ?? 0)) * (1 + (tva ?? 21) / 100) / 1000
    }
}

// MARK: - Localități cu rețea de gaz (gaz-localitati.json)

struct LocalitatiGaz: Codable {
    let actualizat: String
    let judete: [String: [LocalitateGaz]]
    let resedinte: [String: Int]?
}

/// [siruta, localitate, localitatea principală (comuna), tarif distribuție lei/MWh sau null]
struct LocalitateGaz: Codable, Hashable, Identifiable {
    let siruta: Int
    let nume: String
    let principala: String
    let t0: Double?
    var id: Int { siruta }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        siruta = try c.decode(Int.self)
        nume = try c.decode(String.self)
        principala = (try? c.decodeIfPresent(String.self)) ?? nume
        t0 = try? c.decodeIfPresent(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(siruta)
        try c.encode(nume)
        try c.encode(principala)
        try c.encode(t0)
    }
}

// MARK: - Coduri poștale (cp/NN.json)

struct FisierCoduri: Codable {
    /// numele județului în comparatorul ANRE (ex. „CLUJ”)
    let judet: String
    let cp: [String: IntrareCod]
}

/// [localitate, siruta ANRE (dacă localitatea are rețea de gaz)]
struct IntrareCod: Codable {
    let localitate: String
    let siruta: Int?

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        localitate = try c.decode(String.self)
        siruta = c.isAtEnd ? nil : try? c.decodeIfPresent(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(localitate)
        if let siruta { try c.encode(siruta) }
    }
}

// MARK: - Istoric (istoric.json, un punct pe zi)

struct Istoric: Codable {
    let actualizat: String?
    /// "yyyy-MM-dd" → cel mai mic preț al zilei
    let zile: [String: Punct]

    struct Punct: Codable {
        /// zona de distribuție → cel mai mic preț final la curent, lei/kWh cu TVA
        let curent: [String: Double]
        /// județ ANRE → cel mai mic preț gaz + transport + acciză, lei/MWh fără distribuție și TVA
        let gaz: [String: Double]
    }
}
