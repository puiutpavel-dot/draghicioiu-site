import Foundation
import Observation

enum Phase: String, Codable {
    case blindAsk, choose, refuseAsk, aiChoosing, refused, trick, trickShow, rentz, roundEnd, gameOver
}

struct PlayedCard: Identifiable, Equatable {
    let p: Int
    let c: Card
    var id: String { c.id }
}

struct FinalRow: Identifiable {
    let p: Int
    let raw: Int
    let fin: Int
    var id: Int { p }
}

/// Starea unei partide de Renț. Jucătorul 0 e omul, ceilalți sunt conduși de calculator.
@MainActor
@Observable
final class RentzGame {
    let settings: Settings
    let n: Int
    let preset: Preset
    let games: [GameKind]
    let lowR: Int
    let midR: Int

    var names: [String]
    var scores: [Int]
    var used: [[GameKind: Int]]
    var round = 0
    var history: [RoundRecord] = []
    var refusals: [Int]

    var log = ""
    var phase: Phase = .aiChoosing
    var hands: [[Card]] = []
    var game: GameKind?
    var blind = false
    var consec = 0
    var refK = 0

    var trick: [PlayedCard] = []
    var taken: [[Card]] = []
    var tricks: [Int] = []
    var played: Set<String> = []
    var turn = 0
    var winP: Int?
    var lastId: String?

    var board: [Suit: Span] = [:]
    var finished: [Int] = []
    var bubble: [Int: String] = [:]

    var bots = false
    var persist = true

    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var syncQueue: [@MainActor () -> Void]?

    static let botNames = ["Ana", "Mihai", "Ioana", "Radu", "Elena"]

    init(settings s: Settings, saved: SavedGame? = nil) {
        let count = min(6, max(3, s.players))
        settings = s
        n = count
        preset = Preset.named(s.preset)
        games = [.popa, .dame, .carouri, .levate, .totale, s.eighth == "totplus" ? .totplus : .whist, .zece, .rentz]
        lowR = 15 - 2 * count
        midR = 15 - count
        let trimmed = s.name.trimmingCharacters(in: .whitespacesAndNewlines)
        names = [trimmed.isEmpty ? "Tu" : String(trimmed.prefix(14))] + Array(RentzGame.botNames.prefix(count - 1))
        scores = Array(repeating: 0, count: count)
        used = Array(repeating: [:], count: count)
        refusals = Array(repeating: 0, count: count)
        if let sv = saved, sv.scores.count == count {
            names = sv.names
            scores = sv.scores
            used = sv.used.map { d in
                var out: [GameKind: Int] = [:]
                for (k, v) in d { if let g = GameKind(rawValue: k) { out[g] = v } }
                return out
            }
            round = sv.round
            history = sv.history
            refusals = sv.refusals
        }
    }

    // MARK: - Ajutoare

    var total: Int { games.count * n }
    var chooser: Int { round % n }
    func hand(_ p: Int) -> [Card] { hands.indices.contains(p) ? hands[p] : [] }
    func remaining(_ p: Int) -> [GameKind] { games.filter { used[p][$0] == nil } }
    var placedCount: Int { board.values.reduce(0) { $0 + $1.hi - $1.lo + 1 } }
    var tricksPlayed: Int { tricks.reduce(0, +) }

    func start() {
        if round >= total { phase = .gameOver; return }
        startRound()
    }

    func stop() {
        pending?.cancel()
        pending = nil
    }

    private func wait(_ m: Double, _ f: @escaping @MainActor () -> Void) {
        pending?.cancel()
        if syncQueue != nil {
            syncQueue?.append(f)
            return
        }
        let ms = Int((settings.fast ? 300.0 : 640.0) * m)
        pending = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(ms))
            if Task.isCancelled { return }
            f()
        }
    }

    // MARK: - Runda

    private func deal() {
        var d: [Card] = []
        for s in [Suit.H, .D, .C, .S] {
            for r in lowR...14 { d.append(Card(r: r, s: s)) }
        }
        d.shuffle()
        hands = (0..<n).map { i in Array(d[(i * 8)..<(i * 8 + 8)]).sorted(by: Card.handSort) }
    }

    private func startRound() {
        consec = 0
        deal()
        blind = false
        game = nil
        trick = []
        board = [:]
        finished = []
        bubble = [:]
        winP = nil
        lastId = nil
        taken = []
        tricks = []
        askChoice()
    }

    private func askChoice() {
        let c = chooser
        if c == 0 && !bots {
            phase = remaining(0).count > 1 ? .blindAsk : .choose
            return
        }
        phase = .aiChoosing
        wait(1.5) { [self] in
            let g = aiChoose(c)
            log = "\(names[c]) a ales \(g.title)."
            afterChoose(g)
        }
    }

    func humanBlind(_ b: Bool) {
        guard phase == .blindAsk else { return }
        blind = b
        phase = .choose
    }

    func humanChoose(_ g: GameKind) {
        guard phase == .choose, remaining(0).contains(g) else { return }
        log = "Ai ales \(g.title)" + (blind ? " pe nevăzute (punctaj ×2)." : ".")
        afterChoose(g)
    }

    private func afterChoose(_ g: GameKind) {
        game = g
        if g == .rentz { refusalCheck(from: 1) } else { beginPlay() }
    }

    // MARK: - Refuzul Renț-ului

    func caps(_ p: Int) -> (aces: Int, lows: Int, total: Int) {
        let h = hand(p)
        let a = h.filter { $0.r == 14 }.count
        let l = h.filter { $0.r == lowR }.count
        return (a, l, a + l)
    }

    func canRefuse(_ p: Int) -> Bool {
        if p == chooser { return false }
        let k = caps(p)
        if blind { return k.total >= 4 && (k.aces >= 3 || k.lows >= 3) }
        return k.total >= (refusals[p] > 0 ? 4 : 3)
    }

    private func refusalCheck(from k: Int) {
        if consec >= n - 1 {
            if consec > 0 { log += " Limita de refuzuri e atinsă: Renț-ul se joacă." }
            beginPlay()
            return
        }
        let c = chooser
        var i = k
        while i < n {
            let p = (c + i) % n
            if canRefuse(p) {
                if p == 0 && !bots {
                    phase = .refuseAsk
                    refK = i
                    return
                }
                doRefuse(p)
                return
            }
            i += 1
        }
        beginPlay()
    }

    func humanRefuse(_ yes: Bool) {
        guard phase == .refuseAsk else { return }
        if yes { doRefuse(0) } else { refusalCheck(from: refK + 1) }
    }

    private func doRefuse(_ p: Int) {
        let k = caps(p)
        refusals[p] += 1
        consec += 1
        log = "\(names[p]) refuză Renț-ul (\(k.total) capete). Se reîmpart cărțile; \(names[chooser]) alege din nou."
        deal()
        blind = false
        game = nil
        phase = .refused
        wait(2) { [self] in askChoice() }
    }

    // MARK: - Jocul propriu-zis

    private func beginPlay() {
        taken = Array(repeating: [], count: n)
        tricks = Array(repeating: 0, count: n)
        played = []
        trick = []
        turn = chooser
        lastId = nil
        bubble = [:]
        if game == .rentz {
            board = [:]
            finished = []
            phase = .rentz
        } else {
            phase = .trick
        }
        schedule()
    }

    private func schedule() {
        guard phase == .trick || phase == .rentz else { return }
        if turn == 0 && !bots { return }
        wait(1) { [self] in aiMove(turn) }
    }

    var isHumanTurn: Bool { (phase == .trick || phase == .rentz) && turn == 0 && !bots }

    func humanPlayable() -> Set<String> {
        guard isHumanTurn else { return [] }
        return Set((phase == .trick ? validTrick(0) : validRentz(0)).map(\.id))
    }

    func humanPlay(_ c: Card) {
        guard humanPlayable().contains(c.id) else { return }
        if phase == .trick {
            bubble = [:]
            playTrick(0, c)
        } else {
            playRentz(0, c)
        }
    }

    func humanPass() {
        guard isHumanTurn, phase == .rentz, validRentz(0).isEmpty else { return }
        passRentz(0)
    }

    // Levate

    func validTrick(_ p: Int) -> [Card] {
        let h = hand(p)
        guard let first = trick.first else { return h }
        let f = h.filter { $0.s == first.c.s }
        return f.isEmpty ? h : f
    }

    private func trickWinner() -> Int {
        let led = trick[0].c.s
        var b = trick[0]
        for t in trick where t.c.s == led && t.c.r > b.c.r { b = t }
        return b.p
    }

    /// Cartea care câștigă levata curentă (pentru evidențiere).
    var winningCardId: String? {
        guard phase == .trickShow, let first = trick.first else { return nil }
        return trick.filter { $0.c.s == first.c.s }.max { $0.c.r < $1.c.r }?.c.id
    }

    private func removeCard(_ p: Int, _ c: Card) {
        hands[p].removeAll { $0 == c }
    }

    private func playTrick(_ p: Int, _ c: Card) {
        removeCard(p, c)
        trick.append(PlayedCard(p: p, c: c))
        played.insert(c.id)
        lastId = c.id
        if trick.count == n {
            let w = trickWinner()
            winP = w
            phase = .trickShow
            log = "\(names[w]) ia levata."
            wait(1.6) { [self] in collect(w) }
        } else {
            turn = (p + 1) % n
            schedule()
        }
    }

    private func collect(_ w: Int) {
        taken[w].append(contentsOf: trick.map(\.c))
        tricks[w] += 1
        trick = []
        winP = nil
        lastId = nil
        if hands.allSatisfy({ $0.isEmpty }) || earlyEnd() {
            if hands.contains(where: { !$0.isEmpty }) { log += " Toate cărțile cu punctaj au ieșit, runda se oprește." }
            endRound()
            return
        }
        turn = w
        phase = .trick
        schedule()
    }

    private func earlyEnd() -> Bool {
        let all = taken.flatMap { $0 }
        switch game {
        case .popa: return all.contains { $0.id == "13H" }
        case .dame: return all.filter { $0.r == 12 }.count == 4
        case .carouri: return all.filter { $0.s == .D }.count == 15 - lowR
        case .zece: return all.contains { $0.id == "10C" }
        default: return false
        }
    }

    // Renț

    func validRentz(_ p: Int) -> [Card] {
        hand(p).filter { c in
            if let b = board[c.s] { return c.r == b.lo - 1 || c.r == b.hi + 1 }
            return c.r == midR
        }
    }

    static func place(_ board: inout [Suit: Span], _ c: Card) {
        if var b = board[c.s] {
            if c.r < b.lo { b.lo = c.r } else { b.hi = c.r }
            board[c.s] = b
        } else {
            board[c.s] = Span(lo: c.r, hi: c.r)
        }
    }

    private var active: [Int] { (0..<n).filter { !finished.contains($0) } }

    private func nextActive(_ p: Int) -> Int {
        for i in 1...n {
            let q = (p + i) % n
            if !finished.contains(q) { return q }
        }
        return p
    }

    private func playRentz(_ p: Int, _ c: Card) {
        removeCard(p, c)
        RentzGame.place(&board, c)
        lastId = c.id
        bubble = [:]
        var msg = "\(names[p]) pune \(c.name)"
        if hands[p].isEmpty {
            finished.append(p)
            msg += " și termină pe locul \(finished.count)"
        }
        if active.count <= 1 {
            log = msg + "."
            wait(1.4) { [self] in finishRentz() }
            return
        }
        if c.r == 14 && !hands[p].isEmpty && !validRentz(p).isEmpty {
            log = msg + " — As: mai pune o carte."
            schedule()
            return
        }
        advanceRentz(skip: c.r == lowR, msg)
    }

    private func advanceRentz(skip: Bool, _ message: String) {
        var msg = message
        var nx = nextActive(turn)
        if skip {
            msg += " — capăt mic: \(names[nx]) stă o tură"
            bubble = [nx: "stă"]
            nx = nextActive(nx)
        }
        turn = nx
        log = msg + "."
        schedule()
    }

    private func passRentz(_ p: Int) {
        bubble = [p: "pas"]
        advanceRentz(skip: false, "\(names[p]): pas")
    }

    private func finishRentz() {
        for p in active { finished.append(p) }
        endRound()
    }

    // MARK: - Punctaj

    private func roundPoints() -> [Int] {
        let P = preset
        var a = Array(repeating: 0, count: n)
        guard let g = game else { return a }
        if g == .rentz {
            for (i, p) in finished.enumerated() { a[p] = i < P.rentz.count ? P.rentz[i] : 0 }
            return a
        }
        for p in 0..<n {
            let T = taken[p]
            let K = T.contains { $0.id == "13H" } ? 1 : 0
            let Q = T.filter { $0.r == 12 }.count
            let D = T.filter { $0.s == .D }.count
            let L = tricks[p]
            let X = T.contains { $0.id == "10C" } ? 1 : 0
            let tot = K * P.popa + Q * P.dama + D * P.caro + L * P.levata
            switch g {
            case .popa: a[p] = K * P.popa
            case .dame: a[p] = Q * P.dama
            case .carouri: a[p] = D * P.caro
            case .levate: a[p] = L * P.levata
            case .totale: a[p] = tot
            case .totplus: a[p] = -tot
            case .whist: a[p] = L * P.whist
            case .zece: a[p] = X * P.zece
            case .rentz: break
            }
        }
        return a
    }

    private func detail(_ p: Int) -> String {
        guard let g = game else { return "—" }
        if g == .rentz { return "locul \((finished.firstIndex(of: p) ?? 0) + 1)" }
        let T = taken[p]
        var bits: [String] = []
        if T.contains(where: { $0.id == "13H" }) && [.popa, .totale, .totplus].contains(g) { bits.append("K♥") }
        let Q = T.filter { $0.r == 12 }.count
        if Q > 0 && [.dame, .totale, .totplus].contains(g) { bits.append("\(Q) \(Q > 1 ? "dame" : "damă")") }
        let D = T.filter { $0.s == .D }.count
        if D > 0 && [.carouri, .totale, .totplus].contains(g) { bits.append("\(D) \(D > 1 ? "carouri" : "caro")") }
        if [.levate, .totale, .totplus, .whist].contains(g) { bits.append("\(tricks[p]) \(tricks[p] == 1 ? "levată" : "levate")") }
        if g == .zece && T.contains(where: { $0.id == "10C" }) { bits.append("10♣") }
        return bits.isEmpty ? "—" : bits.joined(separator: ", ")
    }

    private func endRound() {
        guard let g = game else { return }
        var pts = roundPoints()
        if blind { pts = pts.map { $0 * 2 } }
        let det = (0..<n).map { detail($0) }
        for i in 0..<n { scores[i] += pts[i] }
        let c = chooser
        history.append(RoundRecord(round: round + 1, chooser: c, game: g, blind: blind, pts: pts, det: det))
        used[c][g] = round + 1
        phase = .roundEnd
        save(nextRound: round + 1)
        if bots { wait(0) { [self] in nextRound() } }
    }

    func nextRound() {
        round += 1
        if round >= total {
            phase = .gameOver
            if persist { SaveStore.clear() }
            return
        }
        startRound()
    }

    private func save(nextRound r: Int) {
        guard persist else { return }
        if r >= total { SaveStore.clear(); return }
        SaveStore.save(SavedGame(settings: settings, names: names, scores: scores,
                                 used: used.map { d in Dictionary(uniqueKeysWithValues: d.map { ($0.key.rawValue, $0.value) }) },
                                 round: r, history: history, refusals: refusals))
    }

    /// Clasamentul final; punctajul se calculează ca la Whist: primul +10×n, ultimul −10×n, ceilalți proporțional.
    func finalTable() -> [FinalRow] {
        let mx = scores.max() ?? 0
        let mn = scores.min() ?? 0
        return (0..<n).map { p in
            let fin: Int
            if mx == mn {
                fin = 0
            } else {
                let t = Double(scores[p] - mn) / Double(mx - mn)
                fin = Int((Double(-10 * n) + t * Double(20 * n)).rounded())
            }
            return FinalRow(p: p, raw: scores[p], fin: fin)
        }.sorted { $0.raw > $1.raw }
    }

    // MARK: - Calculatorul

    private func aiMove(_ p: Int) {
        if phase == .trick {
            playTrick(p, aiTrick(p))
        } else if phase == .rentz {
            let v = validRentz(p)
            if v.isEmpty { passRentz(p) } else { playRentz(p, aiRentz(p, v)) }
        }
    }

    private func aiChoose(_ p: Int) -> GameKind {
        let h = hand(p), P = preset
        let span = Double(14 - lowR)
        let hearts = h.filter { $0.s == .H }
        let hasK = h.contains { $0.id == "13H" }
        let hasA = h.contains { $0.id == "14H" }
        var pK: Double
        if hasK {
            pK = hasA ? 0.8 : max(0.15, 1 - 0.2 * Double(hearts.filter { $0.r < 13 }.count))
        } else {
            pK = 0.1 * max(0, 1 - Double(hearts.count) / 4) + 0.04
        }
        let vPopa = pK * Double(P.popa)
        let q = Double(h.filter { $0.r == 12 }.count)
        let hi = Double(h.filter { $0.r >= 13 }.count)
        let vDame = (q * 0.6 + hi * 0.22 + 0.35) * Double(P.dama)
        let dW = h.filter { $0.s == .D }.reduce(0.0) { $0 + Double($1.r - lowR) / span }
        let vCar = (dW * 1.1 + 0.6) * Double(P.caro)
        let str = h.reduce(0.0) { $0 + Double(max(0, $1.r - midR)) / Double(14 - midR) }
        let vLev = (str * 0.9 + 0.6) * Double(P.levata)
        let vTot = vPopa + vDame + vCar + vLev
        let W = Double(h.filter { $0.r == 14 }.count) + 0.55 * Double(h.filter { $0.r == 13 }.count) + 0.2 * q
        let has10 = h.contains { $0.id == "10C" }
        let cHi = Double(h.filter { $0.s == .C && $0.r > 10 }.count)
        let pZ = has10 ? min(0.9, 0.3 + 0.2 * cHi) : min(0.55, 0.1 * cHi + 0.05)
        let k = caps(p)
        let near = Double(h.filter { abs($0.r - midR) <= 1 }.count)
        let placeIdx = max(0, min(n - 1, Int((Double(n - 1) / 2 - (near * 0.6 - Double(k.total) * 0.7) * 0.6).rounded())))
        func value(_ g: GameKind) -> Double {
            switch g {
            case .popa: return vPopa
            case .dame: return vDame
            case .carouri: return vCar
            case .levate: return vLev
            case .totale: return vTot
            case .totplus: return -vTot * 0.85
            case .whist: return W * Double(P.whist)
            case .zece: return pZ * Double(P.zece)
            case .rentz: return Double(placeIdx < P.rentz.count ? P.rentz[placeIdx] : 0)
            }
        }
        return bestOf(remaining(p)) { value($0) + Double.random(in: 0..<4) }
    }

    private func pen(_ c: Card, _ g: GameKind) -> Double {
        var v = 0.0
        if c.id == "13H" && [.popa, .totale, .totplus].contains(g) { v += 100 }
        if c.r == 12 && [.dame, .totale, .totplus].contains(g) { v += 25 }
        if c.s == .D && [.carouri, .totale, .totplus].contains(g) { v += 12 + Double(c.r) / 2 }
        return v
    }

    private func aiTrick(_ p: Int) -> Card {
        let v = validTrick(p)
        let g = game ?? .levate
        let t = trick
        let last = t.count == n - 1
        let R: (Card) -> Double = { Double($0.r) }

        if t.isEmpty {
            if g == .zece {
                let ten = v.first { $0.id == "10C" }
                let topOut = [11, 12, 13, 14].allSatisfy { r in
                    played.contains("\(r)C") || hand(p).contains { $0.id == "\(r)C" }
                }
                if let ten, topOut { return ten }
                if ten == nil && !played.contains("10C") {
                    let cl = v.filter { $0.s == .C && $0.r > 10 }
                    if !cl.isEmpty { return bestOf(cl, R) }
                }
                let nt = v.filter { $0.id != "10C" }
                return worstOf(nt.isEmpty ? v : nt, R)
            }
            if g.positive { return bestOf(v) { Double($0.r) - (g == .totplus ? pen($0, g) / 10 : 0) } }
            if g == .popa && !hand(p).contains(where: { $0.id == "13H" }) && !played.contains("13H") {
                let lh = v.filter { $0.s == .H && $0.r < 13 }
                if !lh.isEmpty { return worstOf(lh, R) }
            }
            return worstOf(v) { pen($0, g) * 10 + Double($0.r) }
        }

        let led = t[0].c.s
        let best = t.filter { $0.c.s == led }.map(\.c.r).max() ?? 0
        let follow = v[0].s == led

        if g.positive {
            if g == .zece {
                let tenIn = t.contains { $0.c.id == "10C" }
                let my10 = v.first { $0.id == "10C" }
                let win = v.filter { $0.r > best }
                let nt = v.filter { $0.id != "10C" }
                if follow {
                    if tenIn && !win.isEmpty { return last ? worstOf(win, R) : bestOf(win, R) }
                    if let my10, my10.r > best, last { return my10 }
                    if nt.isEmpty, let my10 { return my10 }
                    if led == .C && my10 == nil && !played.contains("10C") && !last {
                        let w2 = nt.filter { $0.r > best }
                        if !w2.isEmpty { return bestOf(w2, R) }
                    }
                    return worstOf(nt.isEmpty ? v : nt, R)
                }
                return worstOf(nt.isEmpty ? v : nt, R)
            }
            if follow {
                let win = v.filter { $0.r > best }
                if !win.isEmpty { return last ? worstOf(win, R) : bestOf(win, R) }
                return worstOf(v, R)
            }
            return worstOf(v) { pen($0, g) * 10 + Double($0.r) }
        }

        if follow {
            let under = v.filter { $0.r < best }
            if !under.isEmpty { return bestOf(under, R) }
            if last { return bestOf(v) { Double($0.r) - pen($0, g) * 10 } }
            return worstOf(v) { Double($0.r) + pen($0, g) * 10 }
        }
        return bestOf(v) { pen($0, g) * 10 + Double($0.r) }
    }

    private func aiRentz(_ p: Int, _ v: [Card]) -> Card {
        bestOf(v) { c in
            var b = board
            RentzGame.place(&b, c)
            let rest = hand(p).filter { $0 != c }
            let ok = rest.filter { x in
                if let s = b[x.s] { return x.r == s.lo - 1 || x.r == s.hi + 1 }
                return x.r == midR
            }.count
            return Double(ok) + (c.r == 14 ? 2.5 : 0) + (c.r == lowR ? 2 : 0) + Double.random(in: 0..<0.3)
        }
    }

    // MARK: - Rulare sincronă (scene demonstrative pentru capturile App Store)

    /// Joacă singur, fără pauze, până când `until` e adevărat; apoi predă controlul omului.
    func runSync(until: (RentzGame) -> Bool, maxSteps: Int = 200_000) {
        persist = false
        bots = true
        syncQueue = []
        startRound()
        var steps = 0
        while !until(self), steps < maxSteps, let f = syncQueue?.first {
            syncQueue?.removeFirst()
            f()
            steps += 1
        }
        syncQueue = nil
        bots = false
    }
}
