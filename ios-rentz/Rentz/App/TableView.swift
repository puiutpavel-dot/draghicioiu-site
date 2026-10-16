import SwiftUI

/// Masa de postav: locurile jucătorilor pe margine, levata sau coloanele Renț-ului în mijloc,
/// iar deasupra, când e cazul, panoul de decizie.
struct TableView: View {
    let g: RentzGame

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let cardW = min(58, max(38, W * 0.13))
            ZStack {
                Felt(cornerRadius: min(W, H) * 0.3)
                    .frame(width: W, height: H)
                    .position(x: W / 2, y: H / 2)

                Text("RENȚ")
                    .font(T.display(min(W, H) * 0.22))
                    .tracking(8)
                    .foregroundStyle(Color.white.opacity(0.045))
                    .position(x: W / 2, y: H / 2)
                    .accessibilityHidden(true)

                if showsBoard {
                    RentzBoardView(g: g, cardW: min(36, max(24, W * 0.075)))
                        .position(x: W / 2, y: H * 0.5)
                }

                ForEach(g.trick) { t in
                    let s = seatPos(t.p)
                    CardView(card: t.c, width: cardW, glow: g.winningCardId == t.c.id)
                        .position(x: W * (0.5 + (s.x - 0.5) * 0.42), y: H * (0.5 + (s.y - 0.5) * 0.46))
                        .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
                }

                ForEach(0..<g.n, id: \.self) { p in
                    let s = seatPos(p)
                    SeatView(g: g, p: p)
                        .position(x: W * s.x, y: H * s.y)
                }

                DecisionPanel(g: g)
                    .frame(maxWidth: min(W * 0.92, 440))
                    .frame(maxHeight: H * 0.86)
                    .position(x: W / 2, y: H / 2)
            }
            .animation(.easeOut(duration: 0.22), value: g.trick)
            .animation(.easeOut(duration: 0.22), value: g.board)
        }
    }

    private var showsBoard: Bool {
        g.game == .rentz && (g.phase == .rentz || g.phase == .roundEnd)
    }

    /// Poziția fiecărui jucător în jurul mesei (0…1). Omul stă jos, adversarii pe un arc deasupra.
    func seatPos(_ p: Int) -> CGPoint {
        if p == 0 { return CGPoint(x: 0.5, y: 0.9) }
        let m = Double(g.n - 1)
        let deg = 180.0 - Double(p - 1) * 180.0 / (m - 1)
        let a = deg * .pi / 180
        return CGPoint(x: 0.5 + 0.39 * cos(a), y: 0.5 - 0.4 * sin(a))
    }
}

struct Felt: View {
    var cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(RadialGradient(colors: [T.felt, T.feltMid, T.feltLo], center: UnitPoint(x: 0.5, y: 0.45),
                                 startRadius: 10, endRadius: 360))
            .overlay(shape.inset(by: 4).strokeBorder(T.gold.opacity(0.25), lineWidth: 1.5))
            .overlay(shape.strokeBorder(T.rim, lineWidth: 9))
            .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 8)
    }
}

struct SeatView: View {
    let g: RentzGame
    let p: Int

    private var isTurn: Bool { (g.phase == .trick || g.phase == .rentz) && g.turn == p }

    var body: some View {
        VStack(spacing: 4) {
            if p != 0 { BacksRow(count: g.hand(p).count) }
            VStack(spacing: 1) {
                Text(g.names[p])
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                    .frame(maxWidth: 84)
                Text("\(g.scores[p]) pct")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(T.muted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minWidth: 64)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isTurn ? T.gold : T.line, lineWidth: isTurn ? 2 : 1))
            .shadow(color: isTurn ? T.gold.opacity(0.55) : .clear, radius: 8)
            .overlay(alignment: .topTrailing) {
                if let b = g.bubble[p] {
                    Text(b)
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .foregroundStyle(T.bg)
                        .background(Capsule().fill(T.fg))
                        .offset(x: 12, y: -10)
                }
            }
            badges
        }
        .animation(.easeInOut(duration: 0.2), value: isTurn)
    }

    @ViewBuilder
    private var badges: some View {
        let chooser = p == g.chooser && g.phase != .gameOver
        let lev = (g.game != nil && g.game != .rentz && g.tricks.indices.contains(p)) ? g.tricks[p] : 0
        let place = g.game == .rentz ? g.finished.firstIndex(of: p) : nil
        if chooser || lev > 0 || place != nil {
            HStack(spacing: 3) {
                if chooser { Badge(text: "alege") }
                if lev > 0 { Badge(text: "\(lev) lev.", kind: .dark) }
                if let place { Badge(text: "locul \(place + 1)", kind: .gold) }
            }
        }
    }
}

struct RentzBoardView: View {
    let g: RentzGame
    let cardW: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Suit.boardOrder, id: \.self) { s in
                HStack(spacing: 8) {
                    Text(s.symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(s.isRed ? T.bad : Color.white.opacity(0.7))
                        .frame(width: 18)
                    if let span = g.board[s] {
                        HStack(spacing: -cardW * 0.42) {
                            ForEach(span.lo...span.hi, id: \.self) { r in
                                CardView(card: Card(r: r, s: s), width: cardW, compact: true, ring: r == g.midR)
                            }
                        }
                    } else {
                        Text(Card.rankLabel(g.midR) + s.symbol)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: cardW, height: cardW * 1.42)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    }
                }
                .frame(height: cardW * 1.42)
            }
        }
    }
}

/// Deciziile omului pe postav: pe nevăzute, alegerea jocului, refuzul Renț-ului.
struct DecisionPanel: View {
    let g: RentzGame

    var body: some View {
        switch g.phase {
        case .blindAsk:
            Panel(title: "Tu alegi jocul",
                  text: "Te uiți la cărți sau alegi pe nevăzute? Pe nevăzute, punctajul rundei se dublează pentru toți jucătorii.") {
                HStack(spacing: 10) {
                    Button("Văd cărțile") { g.humanBlind(false) }.buttonStyle(PillButton(small: true))
                    Button("Pe nevăzute ×2") { g.humanBlind(true) }.buttonStyle(PillButton(kind: .gold, small: true))
                }
            }
        case .choose:
            Panel(title: g.blind ? "Alege jocul · ×2" : "Alege jocul",
                  text: "Îți mai rămân \(g.remaining(0).count) din 8. Fiecare joc se alege o singură dată.") {
                GameChoiceGrid(g: g)
            }
        case .refuseAsk:
            let k = g.caps(0)
            Panel(title: "Refuzi Renț-ul?",
                  text: "\(g.names[g.chooser]) a ales Renț\(g.blind ? " pe nevăzute" : ""). Ai \(k.total) capete (\(k.aces) ași, \(k.lows) de \(Card.rankLabel(g.lowR))), deci poți refuza. La refuz se reîmpart cărțile și \(g.names[g.chooser]) alege din nou.") {
                HStack(spacing: 10) {
                    Button("Refuz") { g.humanRefuse(true) }.buttonStyle(PillButton(small: true))
                    Button("Joc Renț") { g.humanRefuse(false) }.buttonStyle(PillButton(kind: .ghost, small: true))
                }
            }
        case .aiChoosing:
            Panel(title: "\(g.names[g.chooser]) alege…",
                  text: "Se uită la cărți și alege unul dintre jocurile rămase (\(g.remaining(g.chooser).count)).") { EmptyView() }
        case .refused:
            Panel(title: "Refuzat", text: g.log) { EmptyView() }
        default:
            EmptyView()
        }
    }
}

struct Panel<Content: View>: View {
    let title: String
    let text: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(T.display(23))
                .textCase(.uppercase)
                .foregroundStyle(T.fg)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(T.muted)
                .fixedSize(horizontal: false, vertical: true)
            content
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x0e1012, alpha: 0.95)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 16, y: 8)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}

struct GameChoiceGrid: View {
    let g: RentzGame

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(g.remaining(0)) { k in
                    Button { g.humanChoose(k) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 3) {
                                Text(k.title).font(.system(size: 14, weight: .bold)).foregroundStyle(T.fg)
                                if k.positive { Text("+").font(.system(size: 14, weight: .heavy)).foregroundStyle(T.ok) }
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            Text(k.desc(g.preset))
                                .font(.system(size: 11))
                                .foregroundStyle(T.muted)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(T.panel2))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
