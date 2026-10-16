import SwiftUI

/// O carte de joc desenată nativ. `compact` arată doar indicele (pentru coloanele de la Renț).
struct CardView: View {
    let card: Card?
    var width: CGFloat
    var faceDown = false
    var glow = false
    var dim = false
    var compact = false
    var ring = false

    private var radius: CGFloat { width * 0.1 }
    private var ink: Color { (card?.s.isRed ?? false) ? T.cardRed : T.cardBlack }

    var body: some View {
        ZStack {
            if faceDown {
                CardBack(radius: radius)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(T.card)
                if let c = card { face(c) }
            }
        }
        .frame(width: width, height: width * 1.42)
        .overlay {
            if glow || ring {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(T.gold, lineWidth: glow ? 2.5 : 2)
            }
        }
        .overlay {
            // Cărțile care nu se pot juca se întunecă opac (nu transparent), ca să nu se vadă prin ele.
            if dim { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(T.bg.opacity(0.55)) }
        }
        .shadow(color: glow ? T.gold.opacity(0.6) : .black.opacity(0.45), radius: glow ? 8 : 3, x: 0, y: 2)
        .accessibilityElement()
        .accessibilityLabel(card.map { "\($0.label) \($0.s.name)" } ?? "carte cu fața în jos")
    }

    @ViewBuilder
    private func face(_ c: Card) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(spacing: -width * 0.03) {
                Text(c.label).font(.system(size: width * (compact ? 0.36 : 0.31), weight: .heavy))
                Text(c.s.symbol).font(.system(size: width * (compact ? 0.3 : 0.25)))
            }
            .padding(.leading, width * 0.07)
            .padding(.top, width * 0.05)
            if !compact {
                Group {
                    if c.isFace {
                        Text(c.label)
                            .font(T.display(width * 0.5))
                            .frame(width: width * 0.5, height: width * 0.62)
                            .overlay(RoundedRectangle(cornerRadius: width * 0.07).strokeBorder(ink, lineWidth: 1.5))
                    } else {
                        Text(c.s.symbol).font(.system(size: width * 0.56))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, width * 0.2)
                .padding(.top, width * 0.28)
            }
        }
        .foregroundStyle(ink)
    }
}

struct CardBack: View {
    var radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: [T.redHi, T.red, T.redLo], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Canvas { ctx, size in
                    var path = Path()
                    let step: CGFloat = 6
                    var x: CGFloat = -size.height
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        x += step
                    }
                    ctx.stroke(path, with: .color(.black.opacity(0.18)), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white, lineWidth: 2.5))
    }
}

/// Spatele cărților din mâna unui adversar, ca evantai mic.
struct BacksRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: -9) {
            ForEach(0..<count, id: \.self) { _ in
                CardBack(radius: 3).frame(width: 15, height: 22)
            }
        }
        .frame(height: 22)
    }
}
