import SwiftUI

extension Categorie {
    var culoare: Color {
        switch self {
        case .curent: Color(red: 0.88, green: 0.63, blue: 0.0)
        case .gaz: Color(red: 0.84, green: 0.27, blue: 0.12)
        case .internet: Color(red: 0.0, green: 0.44, blue: 0.89)
        case .tv: Color(red: 0.48, green: 0.24, blue: 0.84)
        case .mobil: Color(red: 0.11, green: 0.54, blue: 0.31)
        }
    }
}

extension Color {
    static let castig = Color(red: 0.11, green: 0.54, blue: 0.31)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct Eticheta: View {
    let text: String
    var culoare: Color = .castig
    var plin = true

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(plin ? .white : culoare)
            .background(plin ? culoare : culoare.opacity(0.14), in: Capsule())
    }
}
