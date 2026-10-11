import Foundation

/// Structura fișierului oferte.json (același fișier folosit de draghicioiu.ro/comparator-utilitati).
struct Oferte: Codable {
    let actualizat: String
    let cursEur: Double
    let electricitate: [OfertaCurent]
    let gaze: [OfertaGaz]
    let internet: [OfertaTelecom]
    let tv: [OfertaTelecom]
    let mobil: [OfertaTelecom]

    enum CodingKeys: String, CodingKey {
        case actualizat, electricitate, gaze, internet, tv, mobil
        case cursEur = "curs_eur"
    }
}

/// Preț final lei/kWh pe zonă de distribuție.
struct OfertaCurent: Codable, Hashable {
    let furnizor: String
    let oferta: String
    let pret: [String: Double]
    let panaLa: String?
    let nota: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case furnizor, oferta, pret, nota, link
        case panaLa = "pana_la"
    }
}

/// Preț final lei/kWh, pe rețelele de distribuție unde se aplică.
struct OfertaGaz: Codable, Hashable {
    let furnizor: String
    let oferta: String
    let arii: [String]
    let pret: Double
    let panaLa: String?
    let nota: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case furnizor, oferta, arii, pret, nota, link
        case panaLa = "pana_la"
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
