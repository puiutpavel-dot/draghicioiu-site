import Foundation

enum Suit: String, CaseIterable, Codable {
    case H, D, C, S

    var symbol: String {
        switch self {
        case .H: return "♥"
        case .D: return "♦"
        case .C: return "♣"
        case .S: return "♠"
        }
    }

    var isRed: Bool { self == .H || self == .D }

    var name: String {
        switch self {
        case .H: return "inimă roșie"
        case .D: return "caro"
        case .C: return "treflă"
        case .S: return "pică"
        }
    }

    /// Ordinea în mână: culorile alternează roșu / negru.
    static let handOrder: [Suit] = [.H, .S, .D, .C]
    /// Ordinea rândurilor pe masă la Renț.
    static let boardOrder: [Suit] = [.H, .S, .D, .C]
}

struct Card: Hashable, Codable, Identifiable {
    let r: Int
    let s: Suit

    var id: String { "\(r)\(s.rawValue)" }
    var label: String { Card.rankLabel(r) }
    var name: String { label + s.symbol }
    var isFace: Bool { r > 10 }

    static func rankLabel(_ r: Int) -> String {
        switch r {
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return String(r)
        }
    }

    static func handSort(_ a: Card, _ b: Card) -> Bool {
        let ia = Suit.handOrder.firstIndex(of: a.s) ?? 0
        let ib = Suit.handOrder.firstIndex(of: b.s) ?? 0
        return ia != ib ? ia < ib : a.r < b.r
    }
}

/// Coloana unei culori la Renț: de la cea mai mică la cea mai mare carte pusă.
struct Span: Codable, Equatable {
    var lo: Int
    var hi: Int
}

/// Alege elementul cu scorul cel mai mare (scorul se calculează o singură dată pe element).
func bestOf<T>(_ items: [T], _ score: (T) -> Double) -> T {
    items.map { ($0, score($0)) }.max { $0.1 < $1.1 }!.0
}

func worstOf<T>(_ items: [T], _ score: (T) -> Double) -> T {
    items.map { ($0, score($0)) }.min { $0.1 < $1.1 }!.0
}
