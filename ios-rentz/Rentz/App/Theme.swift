import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

/// Paleta mesei: postav verde, ramă de lemn închis, butoane roșii și auriu pentru rândul tău.
enum T {
    static let bg = Color(hex: 0x111315)
    static let panel = Color(hex: 0x1b1d20)
    static let panel2 = Color(hex: 0x25282c)
    static let line = Color(hex: 0x363a40)
    static let fg = Color(hex: 0xf3f2ee)
    static let muted = Color(hex: 0xa4a8ad)
    static let red = Color(hex: 0xd3172b)
    static let redHi = Color(hex: 0xec3045)
    static let redLo = Color(hex: 0x8f0d1b)
    static let gold = Color(hex: 0xf1be50)
    static let goldInk = Color(hex: 0x2a1b00)
    static let ok = Color(hex: 0x4fc58c)
    static let bad = Color(hex: 0xff8d9b)
    static let felt = Color(hex: 0x11603f)
    static let feltMid = Color(hex: 0x0c4a31)
    static let feltLo = Color(hex: 0x073523)
    static let rim = Color(hex: 0x2b1b12)
    static let card = Color(hex: 0xfbfaf5)
    static let cardRed = Color(hex: 0xc4122d)
    static let cardBlack = Color(hex: 0x1a1b1d)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }
}

struct PillButton: ButtonStyle {
    enum Kind { case red, ghost, gold }
    var kind: Kind = .red
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 12 : 14, weight: .heavy))
            .textCase(.uppercase)
            .tracking(0.6)
            .lineLimit(1)
            .padding(.horizontal, small ? 13 : 20)
            .padding(.vertical, small ? 8 : 12)
            .foregroundStyle(foreground)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(kind == .ghost ? T.line : Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: shadow, radius: 0, x: 0, y: configuration.isPressed ? 1 : 3)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .red: return .white
        case .ghost: return T.fg
        case .gold: return T.goldInk
        }
    }

    private var fill: LinearGradient {
        switch kind {
        case .red: return LinearGradient(colors: [T.redHi, T.red, T.redLo], startPoint: .top, endPoint: .bottom)
        case .ghost: return LinearGradient(colors: [T.panel2, T.panel2], startPoint: .top, endPoint: .bottom)
        case .gold: return LinearGradient(colors: [Color(hex: 0xffd77d), T.gold, Color(hex: 0xb98620)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var shadow: Color {
        switch kind {
        case .red: return Color(hex: 0x5e0811)
        case .ghost: return Color.black
        case .gold: return Color(hex: 0x6f4f0f)
        }
    }
}

struct Chip: View {
    let label: String
    let value: String
    var hot = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(hot ? T.gold : T.muted)
            Text(value).fontWeight(.heavy).foregroundStyle(hot ? T.gold : T.fg)
        }
        .font(.system(size: 12, weight: .semibold).monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(T.panel))
        .overlay(Capsule().strokeBorder(hot ? T.gold : T.line, lineWidth: 1))
    }
}

struct Badge: View {
    enum Kind { case red, gold, dark }
    let text: String
    var kind: Kind = .red

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundStyle(kind == .gold ? T.goldInk : (kind == .dark ? T.fg : .white))
            .background(RoundedRectangle(cornerRadius: 4).fill(kind == .gold ? T.gold : (kind == .dark ? T.panel2 : T.red)))
    }
}
