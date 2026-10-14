import Foundation
import Observation

/// Ce plătește utilizatorul acum la curent sau la gaz.
struct ContractActual: Codable, Hashable {
    var furnizor: String
    var oferta: String?
    /// Codul ofertei ANRE, dacă a fost aleasă din listă.
    var cod: String?
    /// Preț final lei/kWh cu TVA.
    var pretKwh: Double
    /// Abonament / componentă fixă, lei/lună cu TVA.
    var fixLuna: Double = 0
}

/// O locuință salvată: adresa (codul poștal), consumul și contractele actuale.
struct Locuinta: Codable, Identifiable, Hashable {
    var id = UUID()
    var nume: String
    var codPostal: String
    /// Localitatea cu rețea de gaz aleasă manual (cod SIRUTA ANRE).
    var sirutaAleasa: Int?
    var kwhCurent: Double = 175
    var kwhGaz: Double = 600
    var contractCurent: ContractActual?
    var contractGaz: ContractActual?

    // Ultimele date despre zonă, păstrate pentru verificarea din fundal (alerte).
    var zonaCurent: String?
    var judetAnre: String?
    var t0: Double?
    var localitate: String?

    func contract(_ c: Categorie) -> ContractActual? { c == .gaz ? contractGaz : contractCurent }
    func kwh(_ c: Categorie) -> Double { c == .gaz ? kwhGaz : kwhCurent }
}

/// Locuințele salvate pe telefon (UserDefaults). Nimic nu pleacă de pe telefon.
@MainActor
@Observable
final class Locuinte {
    nonisolated private static let cheie = "locuinte.v1"
    nonisolated private static let cheieActiva = "locuintaActiva"

    private(set) var lista: [Locuinta]
    private(set) var activaId: UUID?

    var activa: Locuinta? { lista.first { $0.id == activaId } ?? lista.first }

    init() {
        let d = UserDefaults.standard
        lista = Self.incarcaSalvate()
        activaId = d.string(forKey: Self.cheieActiva).flatMap(UUID.init(uuidString:))

        if d.bool(forKey: "demo") {
            // Doar pentru capturile App Store (argument de lansare -demo YES)
            let cod = d.string(forKey: "codPostal") ?? "060042"
            lista = [
                Locuinta(nume: "Acasă", codPostal: cod,
                         contractCurent: ContractActual(furnizor: "Furnizorul actual", oferta: "de pe factură", pretKwh: 1.39),
                         contractGaz: ContractActual(furnizor: "Furnizorul actual", oferta: "de pe factură", pretKwh: 0.33)),
                Locuinta(nume: "La părinți", codPostal: "700259", kwhCurent: 140, kwhGaz: 750),
            ]
            activaId = lista.first?.id
            salveaza()
        } else if lista.isEmpty, let cod = d.string(forKey: "codPostal"), cod.count == 6 {
            // Migrare din versiunea 1.0: codul poștal și consumul salvate devin locuința „Acasă”.
            let kc = d.object(forKey: "kwhCurent") as? Double ?? 175
            let kg = d.object(forKey: "kwhGaz") as? Double ?? 600
            lista = [Locuinta(nume: "Acasă", codPostal: cod, kwhCurent: kc, kwhGaz: kg)]
            activaId = lista.first?.id
            salveaza()
        }
    }

    func selecteaza(_ id: UUID) {
        activaId = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.cheieActiva)
    }

    func actualizeaza(_ l: Locuinta) {
        guard let i = lista.firstIndex(where: { $0.id == l.id }), lista[i] != l else { return }
        lista[i] = l
        salveaza()
    }

    func adauga(_ l: Locuinta) {
        lista.append(l)
        salveaza()
        selecteaza(l.id)
    }

    func sterge(_ id: UUID) {
        lista.removeAll { $0.id == id }
        salveaza()
        if activaId == id, let p = lista.first { selecteaza(p.id) }
    }

    private func salveaza() {
        if let d = try? JSONEncoder().encode(lista) { UserDefaults.standard.set(d, forKey: Self.cheie) }
    }

    nonisolated static func incarcaSalvate() -> [Locuinta] {
        guard let d = UserDefaults.standard.data(forKey: cheie),
              let l = try? JSONDecoder().decode([Locuinta].self, from: d) else { return [] }
        return l
    }
}
