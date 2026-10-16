import Foundation

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case popa, dame, carouri, levate, totale, whist, totplus, zece, rentz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popa: return "Popa de roșu"
        case .dame: return "Dame"
        case .carouri: return "Carouri"
        case .levate: return "Levate"
        case .totale: return "Totale"
        case .whist: return "Whist"
        case .totplus: return "Totale Plus"
        case .zece: return "Zece de treflă"
        case .rentz: return "Renț"
        }
    }

    var short: String {
        switch self {
        case .popa: return "Popa ♥"
        case .totplus: return "Tot. +"
        case .zece: return "10 ♣"
        default: return title
        }
    }

    var positive: Bool { [.whist, .totplus, .zece, .rentz].contains(self) }

    func desc(_ p: Preset) -> String {
        switch self {
        case .popa: return "\(p.popa) cine ia K♥"
        case .dame: return "\(p.dama) / damă"
        case .carouri: return "\(p.caro) / caro"
        case .levate: return "\(p.levata) / levată"
        case .totale: return "popa + dame + carouri + levate"
        case .whist: return "+\(p.whist) / levată"
        case .totplus: return "totale, cu semn plus"
        case .zece: return "+\(p.zece) cine ia 10♣"
        case .rentz: return "locuri: " + p.rentz.prefix(4).map(String.init).joined(separator: " / ")
        }
    }
}

struct Preset: Codable, Equatable {
    let key: String
    let label: String
    let popa: Int
    let zece: Int
    let dama: Int
    let caro: Int
    let levata: Int
    let whist: Int
    let rentz: [Int]

    /// Wikipedia (ro): Popa −300, levata −20, Whist +20.
    static let clasic = Preset(key: "clasic", label: "Clasic", popa: -300, zece: 100, dama: -25, caro: -20,
                               levata: -20, whist: 20, rentz: [300, 200, 100, 0, 0, 0])
    /// Regulamentul PokerStars / casino.com.ro: Popa −100, levata −10.
    static let casino = Preset(key: "casino", label: "Casino", popa: -100, zece: 100, dama: -25, caro: -20,
                               levata: -10, whist: 10, rentz: [300, 200, 150, 100, 50, 0])

    static func named(_ key: String) -> Preset { key == "casino" ? .casino : .clasic }
}

struct Settings: Codable, Equatable {
    var players: Int = 4
    var preset: String = "clasic"
    var eighth: String = "whist"
    var fast: Bool = false
    var name: String = "Tu"
}

struct RoundRecord: Codable, Identifiable {
    let round: Int
    let chooser: Int
    let game: GameKind
    let blind: Bool
    let pts: [Int]
    let det: [String]
    var id: Int { round }
}

/// Partida salvată după fiecare rundă terminată, ca să poată fi continuată.
struct SavedGame: Codable {
    let settings: Settings
    let names: [String]
    let scores: [Int]
    let used: [[String: Int]]
    let round: Int
    let history: [RoundRecord]
    let refusals: [Int]
}

enum SaveStore {
    private static let key = "rentz.partida"

    static func save(_ s: SavedGame) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }

    static func load() -> SavedGame? {
        guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedGame.self, from: d)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
