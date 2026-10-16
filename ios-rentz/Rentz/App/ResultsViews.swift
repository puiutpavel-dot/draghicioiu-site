import SwiftUI

struct Dimmed<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.66).ignoresSafeArea()
            ScrollView {
                content
                    .padding(18)
                    .frame(maxWidth: 560, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(T.panel))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.line, lineWidth: 1))
                    .padding(16)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
    }
}

func signed(_ x: Int) -> String { x > 0 ? "+\(x)" : "\(x)" }
func pointsColor(_ x: Int) -> Color { x < 0 ? T.bad : (x > 0 ? T.ok : T.fg) }

struct RoundEndView: View {
    let g: RentzGame
    let openScore: () -> Void

    var body: some View {
        if let r = g.history.last {
            Dimmed {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Runda \(r.round): \(r.game.title)\(r.blind ? " ×2" : "")")
                            .font(T.display(26))
                            .textCase(.uppercase)
                            .foregroundStyle(T.fg)
                        Text("Ales de \(g.names[r.chooser]).").font(.system(size: 13)).foregroundStyle(T.muted)
                    }
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Text("Jucător"); Text("Ce a luat"); Text("Puncte").gridColumnAlignment(.trailing); Text("Total").gridColumnAlignment(.trailing)
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(T.muted)
                        Divider().overlay(T.line)
                        ForEach(0..<g.n, id: \.self) { p in
                            GridRow {
                                Text(g.names[p]).fontWeight(p == 0 ? .heavy : .semibold).lineLimit(1)
                                Text(r.det[p]).foregroundStyle(T.muted).lineLimit(2).minimumScaleFactor(0.8)
                                Text(signed(r.pts[p])).fontWeight(.bold).foregroundStyle(pointsColor(r.pts[p]))
                                Text("\(g.scores[p])").fontWeight(.heavy)
                            }
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(T.fg)
                        }
                    }
                    HStack(spacing: 10) {
                        Button(g.round + 1 >= g.total ? "Vezi clasamentul" : "Runda următoare") { g.nextRound() }
                            .buttonStyle(PillButton())
                        Button("Foaia de scor", action: openScore).buttonStyle(PillButton(kind: .ghost))
                    }
                }
            }
        }
    }
}

struct FinalView: View {
    let g: RentzGame
    let openScore: () -> Void
    let newGame: () -> Void

    var body: some View {
        let rows = g.finalTable()
        Dimmed {
            VStack(alignment: .leading, spacing: 14) {
                Text("Clasament final").font(T.display(30)).textCase(.uppercase).foregroundStyle(T.fg)
                Text("Punctajul final se calculează ca la Whist: locul 1 +\(10 * g.n), ultimul −\(10 * g.n), ceilalți proporțional.")
                    .font(.system(size: 13))
                    .foregroundStyle(T.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        HStack {
                            Text("\(i + 1)").font(T.display(24)).foregroundStyle(T.gold).frame(width: 30, alignment: .leading)
                            Text(g.names[row.p]).font(.system(size: 16, weight: .heavy)).foregroundStyle(T.fg)
                            Spacer()
                            Text("\(row.raw) pct").font(.system(size: 13).monospacedDigit()).foregroundStyle(T.muted)
                            Text(signed(row.fin)).font(.system(size: 18, weight: .heavy).monospacedDigit()).foregroundStyle(pointsColor(row.fin))
                                .frame(minWidth: 52, alignment: .trailing)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(T.panel2))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(i == 0 ? T.gold : T.line, lineWidth: 1))
                    }
                }
                HStack(spacing: 10) {
                    Button("Joc nou", action: newGame).buttonStyle(PillButton())
                    Button("Foaia de scor", action: openScore).buttonStyle(PillButton(kind: .ghost))
                }
            }
        }
    }
}

struct ScoreSheetView: View {
    let g: RentzGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle("Jocuri alese")
                    Text("Fiecare jucător hașurează jocul ales, cu numărul rundei. Când toate căsuțele sunt hașurate, partida se încheie.")
                        .font(.system(size: 13)).foregroundStyle(T.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                            GridRow {
                                Text("").frame(width: 70)
                                ForEach(g.games) { k in
                                    Text(k.short).font(.system(size: 10, weight: .heavy)).foregroundStyle(T.muted).frame(width: 52)
                                }
                                Text("TOTAL").font(.system(size: 10, weight: .heavy)).foregroundStyle(T.muted).frame(width: 56, alignment: .trailing)
                            }
                            ForEach(0..<g.n, id: \.self) { p in
                                GridRow {
                                    Text(g.names[p]).font(.system(size: 13, weight: p == 0 ? .heavy : .semibold)).lineLimit(1)
                                        .frame(width: 70, alignment: .leading)
                                    ForEach(g.games) { k in
                                        SheetCell(round: g.used[p][k])
                                    }
                                    Text("\(g.scores[p])").font(.system(size: 14, weight: .heavy).monospacedDigit())
                                        .frame(width: 56, alignment: .trailing)
                                }
                                .foregroundStyle(T.fg)
                            }
                        }
                    }
                    SectionTitle("Istoric runde")
                    if g.history.isEmpty {
                        Text("Încă nu s-a terminat nicio rundă.").font(.system(size: 14)).foregroundStyle(T.muted)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 7) {
                                GridRow {
                                    Text("Runda").gridColumnAlignment(.leading)
                                    ForEach(0..<g.n, id: \.self) { p in Text(g.names[p]).lineLimit(1) }
                                }
                                .font(.system(size: 10, weight: .heavy)).textCase(.uppercase).foregroundStyle(T.muted)
                                ForEach(Array(g.history.reversed())) { r in
                                    GridRow {
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("\(r.round). \(r.game.title)\(r.blind ? " ×2" : "")").font(.system(size: 13, weight: .semibold))
                                            Text(g.names[r.chooser]).font(.system(size: 11)).foregroundStyle(T.muted)
                                        }
                                        ForEach(0..<g.n, id: \.self) { p in
                                            Text(signed(r.pts[p])).font(.system(size: 13, weight: .semibold).monospacedDigit())
                                                .foregroundStyle(pointsColor(r.pts[p]))
                                        }
                                    }
                                    .foregroundStyle(T.fg)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(T.bg)
            .navigationTitle("Foaia de scor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Gata") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SheetCell: View {
    let round: Int?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(T.panel2)
            if let round {
                Canvas { ctx, size in
                    var path = Path()
                    var x: CGFloat = -size.height
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        x += 7
                    }
                    ctx.stroke(path, with: .color(T.red.opacity(0.45)), lineWidth: 2.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("R\(round)").font(.system(size: 12, weight: .heavy).monospacedDigit()).foregroundStyle(T.fg)
            }
        }
        .frame(width: 52, height: 30)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(T.display(20)).textCase(.uppercase).tracking(0.6).foregroundStyle(T.gold).padding(.top, 4)
    }
}
