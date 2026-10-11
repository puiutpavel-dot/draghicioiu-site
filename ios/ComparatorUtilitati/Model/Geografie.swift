import Foundation

/// Unde se află un cod poștal: județ, zonă de distribuție curent, localitate și rețea de gaz.
struct Locatie: Equatable {
    let codPostal: String
    let judet: String
    let codJudet: String
    let zonaCurent: String
    let operatorCurent: String
    /// Localitatea din nomenclatorul de coduri poștale.
    var localitate: String?
    /// Numele județului în comparatorul ANRE (ex. „CLUJ”).
    var judetAnre: String?
    /// Localitatea cu rețea de gaz (din cod sau aleasă de utilizator); nil = nu apare în lista ANRE.
    var siruta: Int?
    /// Numele localității cu rețea de gaz folosite la calcul (poate fi aleasă manual).
    var localitateGaz: String?
    /// Tariful de distribuție gaz al localității, lei/MWh.
    var t0: Double?
    var operatorGaz: String?
    /// Localitățile din județ cu rețea de gaz, pentru alegere manuală.
    var localitatiGaz: [LocalitateGaz] = []

    var esteBucuresti: Bool { codJudet == "B" }
}

enum Geografie {
    static let distrigaz = "Distrigaz Sud Rețele"
    static let delgaz = "Delgaz Grid"

    /// Primele 2 cifre ale codului poștal → (județ, indicativ)
    static let judete: [String: (String, String)] = [
        "01": ("București (Sector 1)", "B"), "02": ("București (Sector 2)", "B"), "03": ("București (Sector 3)", "B"),
        "04": ("București (Sector 4)", "B"), "05": ("București (Sector 5)", "B"), "06": ("București (Sector 6)", "B"),
        "07": ("Ilfov", "IF"), "08": ("Giurgiu", "GR"),
        "10": ("Prahova", "PH"), "11": ("Argeș", "AG"), "12": ("Buzău", "BZ"), "13": ("Dâmbovița", "DB"), "14": ("Teleorman", "TR"),
        "20": ("Dolj", "DJ"), "21": ("Gorj", "GJ"), "22": ("Mehedinți", "MH"), "23": ("Olt", "OT"), "24": ("Vâlcea", "VL"),
        "30": ("Timiș", "TM"), "31": ("Arad", "AR"), "32": ("Caraș-Severin", "CS"), "33": ("Hunedoara", "HD"),
        "40": ("Cluj", "CJ"), "41": ("Bihor", "BH"), "42": ("Bistrița-Năsăud", "BN"), "43": ("Maramureș", "MM"),
        "44": ("Satu Mare", "SM"), "45": ("Sălaj", "SJ"),
        "50": ("Brașov", "BV"), "51": ("Alba", "AB"), "52": ("Covasna", "CV"), "53": ("Harghita", "HR"),
        "54": ("Mureș", "MS"), "55": ("Sibiu", "SB"),
        "60": ("Bacău", "BC"), "61": ("Neamț", "NT"), "62": ("Vrancea", "VN"),
        "70": ("Iași", "IS"), "71": ("Botoșani", "BT"), "72": ("Suceava", "SV"), "73": ("Vaslui", "VS"),
        "80": ("Galați", "GL"), "81": ("Brăila", "BR"), "82": ("Tulcea", "TL"),
        "90": ("Constanța", "CT"), "91": ("Călărași", "CL"), "92": ("Ialomița", "IL"),
    ]

    /// Zonele de distribuție a energiei electrice → județe
    static let zoneCurent: [(zona: String, distribuitor: String, judete: Set<String>)] = [
        ("Muntenia Sud", "Rețele Electrice Muntenia", ["B", "IF", "GR"]),
        ("Muntenia Nord", "Distribuție Energie Electrică România", ["PH", "BZ", "DB", "GL", "BR", "VN"]),
        ("Transilvania Nord", "Distribuție Energie Electrică România", ["CJ", "BH", "BN", "MM", "SM", "SJ"]),
        ("Transilvania Sud", "Distribuție Energie Electrică România", ["BV", "AB", "CV", "HR", "MS", "SB"]),
        ("Banat", "Rețele Electrice Banat", ["TM", "AR", "CS", "HD"]),
        ("Dobrogea", "Rețele Electrice Dobrogea", ["CT", "TL", "CL", "IL"]),
        ("Oltenia", "Distribuție Energie Oltenia", ["DJ", "GJ", "MH", "OT", "VL", "AG", "TR"]),
        ("Moldova", "Delgaz Grid", ["IS", "BC", "NT", "SV", "BT", "VS"]),
    ]

    static let judeteDistrigaz: Set<String> = [
        "AG", "BR", "BV", "BZ", "CL", "CT", "CV", "DB", "DJ", "GL", "GR", "GJ", "IL", "IF", "OT", "PH", "TL", "VL", "VN", "TR", "B",
    ]

    enum Eroare: Error, Equatable {
        case lungime
        case necunoscut
    }

    /// Partea care nu depinde de date descărcate: județul și zona de curent.
    static func localizeaza(_ text: String) -> Result<Locatie, Eroare> {
        let cp = text.filter(\.isNumber)
        guard cp.count == 6 else { return .failure(.lungime) }
        guard let jud = judete[String(cp.prefix(2))] else { return .failure(.necunoscut) }
        let (judet, cod) = jud
        guard let zona = zoneCurent.first(where: { $0.judete.contains(cod) }) else { return .failure(.necunoscut) }
        var loc = Locatie(codPostal: cp, judet: judet, codJudet: cod, zonaCurent: zona.zona, operatorCurent: zona.distribuitor)
        if cod == "B" {
            loc.localitate = "București"
            loc.judetAnre = "BUCURESTI"
            loc.siruta = 999_999
        }
        return .success(loc)
    }

    /// Operatorul de distribuție gaz, recunoscut după tariful de distribuție al localității.
    static func operatorGaz(codJudet: String, t0: Double?, anre: Anre?) -> String? {
        guard let t0 else { return nil }
        let ref = { (j: String) in anre?.gaz?.judete[j]?.t0 }
        if judeteDistrigaz.contains(codJudet), let r = ref("BUCURESTI"), abs(t0 - r) < 0.01 { return distrigaz }
        if !judeteDistrigaz.contains(codJudet), let r = ref("CLUJ"), abs(t0 - r) < 0.01 { return delgaz }
        return "operator local de distribuție"
    }

    /// „DROBETA-TURNU SEVERIN” → „Drobeta-Turnu Severin”
    static func titlu(_ s: String) -> String {
        var rez = ""
        var mare = true
        for ch in s.lowercased() {
            rez += mare ? String(ch).uppercased() : String(ch)
            mare = ch == " " || ch == "-" || ch == "("
        }
        return rez
    }
}
