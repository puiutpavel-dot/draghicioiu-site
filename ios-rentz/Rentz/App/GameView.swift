import SwiftUI

struct GameView: View {
    let g: RentzGame
    var initialSheet: String?
    let onExit: () -> Void

    @State private var showRules = false
    @State private var showScore = false
    @State private var confirmExit = false

    var body: some View {
        VStack(spacing: 8) {
            topBar
            InfoChips(g: g)
            Text(g.log.isEmpty ? " " : g.log)
                .font(.system(size: 13))
                .foregroundStyle(T.fg.opacity(0.9))
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
                .animation(nil, value: g.log)
            TableView(g: g)
                .frame(maxHeight: .infinity)
            HandView(g: g)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .overlay {
            if g.phase == .roundEnd {
                RoundEndView(g: g, openScore: { showScore = true })
                    .transition(.opacity)
            } else if g.phase == .gameOver {
                FinalView(g: g, openScore: { showScore = true }, newGame: { g.stop(); onExit() })
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: g.phase)
        .sheet(isPresented: $showRules) { RulesView() }
        .sheet(isPresented: $showScore) { ScoreSheetView(g: g) }
        .confirmationDialog("Părăsești masa?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("Ieși la meniu", role: .destructive) { g.stop(); onExit() }
            Button("Rămân la masă", role: .cancel) {}
        } message: {
            Text("Partida se salvează după fiecare rundă terminată și o poți continua din meniu.")
        }
        .sensoryFeedback(.selection, trigger: g.lastId)
        .sensoryFeedback(.success, trigger: g.history.count)
        .onAppear {
            if initialSheet == "scor" { showScore = true }
            if initialSheet == "reguli" { showRules = true }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Brand(subtitle: "\(g.n) jucători · punctaj \(g.preset.label.lowercased())")
            Spacer(minLength: 4)
            Menu {
                Button { showScore = true } label: { Label("Foaia de scor", systemImage: "list.number") }
                Button { showRules = true } label: { Label("Reguli", systemImage: "book") }
                Divider()
                Button(role: .destructive) { confirmExit = true } label: { Label("Ieși la meniu", systemImage: "rectangle.portrait.and.arrow.right") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(T.fg)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(T.panel2))
                    .overlay(Circle().strokeBorder(T.line, lineWidth: 1))
            }
            .accessibilityLabel("Meniu")
            Button { showScore = true } label: {
                Image(systemName: "list.number")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(LinearGradient(colors: [T.redHi, T.red, T.redLo], startPoint: .top, endPoint: .bottom)))
            }
            .accessibilityLabel("Foaia de scor")
        }
    }
}

struct Brand: View {
    var subtitle: String

    var body: some View {
        HStack(spacing: 9) {
            Text("♠")
                .font(.system(size: 19))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(RadialGradient(colors: [T.redHi, T.red, T.redLo], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 22)))
            VStack(alignment: .leading, spacing: 0) {
                Text("MASA DE RENȚ").font(T.display(23)).foregroundStyle(T.fg).lineLimit(1)
                Text(subtitle.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(T.muted)
                    .lineLimit(1)
            }
        }
    }
}

struct InfoChips: View {
    let g: RentzGame

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Chip(label: "Runda", value: "\(min(g.round + 1, g.total)) / \(g.total)")
                Chip(label: "Alege", value: g.names[g.chooser])
                if let game = g.game { Chip(label: "Joc", value: game.title, hot: true) }
                if g.blind { Chip(label: "×2", value: "pe nevăzute", hot: true) }
                if let game = g.game, game != .rentz, !g.tricks.isEmpty {
                    Chip(label: "Levata", value: "\(min(g.tricksPlayed + 1, 8)) / 8")
                }
                if g.game == .rentz {
                    Chip(label: "Mijloc", value: Card.rankLabel(g.midR) + " · capăt " + Card.rankLabel(g.lowR))
                }
            }
        }
    }
}

struct HandView: View {
    let g: RentzGame

    var body: some View {
        let hide = g.phase == .blindAsk || (g.phase == .choose && g.blind)
        let playable = g.humanPlayable()
        let mine = g.isHumanTurn
        let cards = g.hand(0)
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = min(76, geo.size.width / (1 + 7 * 0.74))
                HStack(spacing: -w * 0.26) {
                    ForEach(cards) { c in
                        let ok = playable.contains(c.id)
                        CardView(card: c, width: w, faceDown: hide, glow: ok, dim: mine && !ok)
                            .offset(y: ok ? -12 : 0)
                            .onTapGesture { if ok { g.humanPlay(c) } }
                            .accessibilityAddTraits(ok ? .isButton : [])
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(.easeOut(duration: 0.2), value: cards)
                .animation(.easeOut(duration: 0.15), value: playable)
            }
            .frame(height: 122)
            hint
                .frame(height: 38)
        }
    }

    @ViewBuilder
    private var hint: some View {
        if g.isHumanTurn && g.phase == .rentz && g.validRentz(0).isEmpty {
            HStack(spacing: 10) {
                Button("Pas") { g.humanPass() }.buttonStyle(PillButton(small: true))
                Text("Nu ai nicio carte care se leagă.").font(.system(size: 13, weight: .bold)).foregroundStyle(T.gold)
            }
        } else if g.isHumanTurn {
            Text(g.phase == .rentz ? "Rândul tău: pune o carte lângă coloană" : "Rândul tău: alege o carte")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(T.gold)
        } else if g.game == .rentz, let place = g.finished.firstIndex(of: 0) {
            Text("Ai terminat pe locul \(place + 1).").font(.system(size: 13, weight: .bold)).foregroundStyle(T.gold)
        } else if g.hand(0).isEmpty && g.phase != .roundEnd {
            Text("Nu mai ai cărți în mână.").font(.system(size: 13)).foregroundStyle(T.muted)
        } else {
            Color.clear
        }
    }
}
