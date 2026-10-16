package ro.draghicioiu.rentz.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.random.Random

enum class Phase { BLIND_ASK, CHOOSE, REFUSE_ASK, AI_CHOOSING, REFUSED, TRICK, TRICK_SHOW, RENTZ, ROUND_END, GAME_OVER }

data class PlayedCard(val p: Int, val c: Card)

data class FinalRow(val p: Int, val raw: Int, val fin: Int)

data class Caps(val aces: Int, val lows: Int) {
    val total get() = aces + lows
}

/**
 * Starea unei partide de Renț. Jucătorul 0 e omul, ceilalți sunt conduși de calculator.
 * Proprietățile sunt stare Compose, deci ecranele se redesenează singure la fiecare mutare.
 * Port direct al motorului din rentz/index.html și din aplicația iOS (Engine.swift).
 */
class RentzGame(
    val settings: Settings,
    private val scope: CoroutineScope,
    private val store: SaveStore?,
    saved: SavedGame? = null,
) {
    val n: Int = settings.players.coerceIn(3, 6)
    val preset: Preset = Preset.named(settings.preset)
    val games: List<GameKind> = listOf(
        GameKind.POPA, GameKind.DAME, GameKind.CAROURI, GameKind.LEVATE, GameKind.TOTALE,
        if (settings.eighth == "totplus") GameKind.TOTPLUS else GameKind.WHIST,
        GameKind.ZECE, GameKind.RENTZ,
    )
    val lowR: Int = 15 - 2 * n
    val midR: Int = 15 - n
    val total: Int get() = games.size * n

    var names by mutableStateOf(
        listOf(settings.name.trim().ifEmpty { "Tu" }.take(14)) + BOT_NAMES.take(n - 1)
    )
    var scores by mutableStateOf(List(n) { 0 })
    var used by mutableStateOf(List(n) { emptyMap<GameKind, Int>() })
    var round by mutableStateOf(0)
    var history by mutableStateOf(emptyList<RoundRecord>())
    var refusals by mutableStateOf(List(n) { 0 })

    var log by mutableStateOf("")
    var phase by mutableStateOf(Phase.AI_CHOOSING)
    var hands by mutableStateOf(List(n) { emptyList<Card>() })
    var game by mutableStateOf<GameKind?>(null)
    var blind by mutableStateOf(false)
    private var consec = 0
    private var refK = 0

    var trick by mutableStateOf(emptyList<PlayedCard>())
    var taken by mutableStateOf(List(n) { emptyList<Card>() })
    var tricks by mutableStateOf(List(n) { 0 })
    private var played = setOf<String>()
    var turn by mutableStateOf(0)
    var winP by mutableStateOf<Int?>(null)
    var lastId by mutableStateOf<String?>(null)

    var board by mutableStateOf(emptyMap<Suit, Span>())
    var finished by mutableStateOf(emptyList<Int>())
    var bubble by mutableStateOf(emptyMap<Int, String>())

    var bots = false
    var persist = true

    private var pending: Job? = null
    private var syncQueue: ArrayDeque<() -> Unit>? = null

    init {
        if (saved != null && saved.scores.size == n) {
            names = saved.names
            scores = saved.scores
            used = saved.used
            round = saved.round
            history = saved.history
            refusals = saved.refusals
        }
    }

    // ---------- ajutoare ----------

    val chooser: Int get() = round % n
    fun hand(p: Int): List<Card> = hands.getOrElse(p) { emptyList() }
    fun remaining(p: Int): List<GameKind> = games.filter { used[p][it] == null }
    val placedCount: Int get() = board.values.sumOf { it.hi - it.lo + 1 }
    val tricksPlayed: Int get() = tricks.sum()

    private fun <T> List<T>.with(i: Int, v: T): List<T> = mapIndexed { j, x -> if (j == i) v else x }

    fun start() {
        if (round >= total) {
            phase = Phase.GAME_OVER
            return
        }
        startRound()
    }

    fun stop() {
        pending?.cancel()
        pending = null
    }

    private fun wait(m: Double, f: () -> Unit) {
        pending?.cancel()
        val q = syncQueue
        if (q != null) {
            q.addLast(f)
            return
        }
        val ms = ((if (settings.fast) 300.0 else 640.0) * m).toLong()
        pending = scope.launch {
            delay(ms)
            f()
        }
    }

    // ---------- runda ----------

    private fun deal() {
        val d = mutableListOf<Card>()
        for (s in listOf(Suit.H, Suit.D, Suit.C, Suit.S)) for (r in lowR..14) d.add(Card(r, s))
        d.shuffle()
        hands = List(n) { i -> d.subList(i * 8, i * 8 + 8).sortedWith(Card.handComparator) }
    }

    private fun startRound() {
        consec = 0
        deal()
        blind = false
        game = null
        trick = emptyList()
        board = emptyMap()
        finished = emptyList()
        bubble = emptyMap()
        winP = null
        lastId = null
        taken = List(n) { emptyList() }
        tricks = List(n) { 0 }
        askChoice()
    }

    private fun askChoice() {
        val c = chooser
        if (c == 0 && !bots) {
            phase = if (remaining(0).size > 1) Phase.BLIND_ASK else Phase.CHOOSE
            return
        }
        phase = Phase.AI_CHOOSING
        wait(1.5) {
            val g = aiChoose(c)
            log = "${names[c]} a ales ${g.title}."
            afterChoose(g)
        }
    }

    fun humanBlind(b: Boolean) {
        if (phase != Phase.BLIND_ASK) return
        blind = b
        phase = Phase.CHOOSE
    }

    fun humanChoose(g: GameKind) {
        if (phase != Phase.CHOOSE || g !in remaining(0)) return
        log = "Ai ales ${g.title}" + if (blind) " pe nevăzute (punctaj ×2)." else "."
        afterChoose(g)
    }

    private fun afterChoose(g: GameKind) {
        game = g
        if (g == GameKind.RENTZ) refusalCheck(1) else beginPlay()
    }

    // ---------- refuzul Renț-ului ----------

    fun caps(p: Int): Caps {
        val h = hand(p)
        return Caps(h.count { it.r == 14 }, h.count { it.r == lowR })
    }

    fun canRefuse(p: Int): Boolean {
        if (p == chooser) return false
        val k = caps(p)
        if (blind) return k.total >= 4 && (k.aces >= 3 || k.lows >= 3)
        return k.total >= (if (refusals[p] > 0) 4 else 3)
    }

    private fun refusalCheck(from: Int) {
        if (consec >= n - 1) {
            if (consec > 0) log += " Limita de refuzuri e atinsă: Renț-ul se joacă."
            beginPlay()
            return
        }
        val c = chooser
        for (i in from until n) {
            val p = (c + i) % n
            if (canRefuse(p)) {
                if (p == 0 && !bots) {
                    phase = Phase.REFUSE_ASK
                    refK = i
                    return
                }
                doRefuse(p)
                return
            }
        }
        beginPlay()
    }

    fun humanRefuse(yes: Boolean) {
        if (phase != Phase.REFUSE_ASK) return
        if (yes) doRefuse(0) else refusalCheck(refK + 1)
    }

    private fun doRefuse(p: Int) {
        val k = caps(p)
        refusals = refusals.with(p, refusals[p] + 1)
        consec += 1
        log = "${names[p]} refuză Renț-ul (${k.total} capete). Se reîmpart cărțile; ${names[chooser]} alege din nou."
        deal()
        blind = false
        game = null
        phase = Phase.REFUSED
        wait(2.0) { askChoice() }
    }

    // ---------- jocul propriu-zis ----------

    private fun beginPlay() {
        taken = List(n) { emptyList() }
        tricks = List(n) { 0 }
        played = emptySet()
        trick = emptyList()
        turn = chooser
        lastId = null
        bubble = emptyMap()
        if (game == GameKind.RENTZ) {
            board = emptyMap()
            finished = emptyList()
            phase = Phase.RENTZ
        } else {
            phase = Phase.TRICK
        }
        schedule()
    }

    private fun schedule() {
        if (phase != Phase.TRICK && phase != Phase.RENTZ) return
        if (turn == 0 && !bots) return
        wait(1.0) { aiMove(turn) }
    }

    val isHumanTurn: Boolean get() = (phase == Phase.TRICK || phase == Phase.RENTZ) && turn == 0 && !bots

    fun humanPlayable(): Set<String> {
        if (!isHumanTurn) return emptySet()
        return (if (phase == Phase.TRICK) validTrick(0) else validRentz(0)).map { it.id }.toSet()
    }

    fun humanPlay(c: Card) {
        if (c.id !in humanPlayable()) return
        if (phase == Phase.TRICK) {
            bubble = emptyMap()
            playTrick(0, c)
        } else {
            playRentz(0, c)
        }
    }

    fun humanPass() {
        if (!isHumanTurn || phase != Phase.RENTZ || validRentz(0).isNotEmpty()) return
        passRentz(0)
    }

    // levate

    fun validTrick(p: Int): List<Card> {
        val h = hand(p)
        val first = trick.firstOrNull() ?: return h
        val f = h.filter { it.s == first.c.s }
        return f.ifEmpty { h }
    }

    private fun trickWinner(): Int {
        val led = trick[0].c.s
        var b = trick[0]
        for (t in trick) if (t.c.s == led && t.c.r > b.c.r) b = t
        return b.p
    }

    /** Cartea care câștigă levata curentă (pentru evidențiere). */
    val winningCardId: String?
        get() {
            if (phase != Phase.TRICK_SHOW) return null
            val first = trick.firstOrNull() ?: return null
            return trick.filter { it.c.s == first.c.s }.maxByOrNull { it.c.r }?.c?.id
        }

    private fun removeCard(p: Int, c: Card) {
        hands = hands.with(p, hands[p].filter { it != c })
    }

    private fun playTrick(p: Int, c: Card) {
        removeCard(p, c)
        trick = trick + PlayedCard(p, c)
        played = played + c.id
        lastId = c.id
        if (trick.size == n) {
            val w = trickWinner()
            winP = w
            phase = Phase.TRICK_SHOW
            log = "${names[w]} ia levata."
            wait(1.6) { collect(w) }
        } else {
            turn = (p + 1) % n
            schedule()
        }
    }

    private fun collect(w: Int) {
        taken = taken.with(w, taken[w] + trick.map { it.c })
        tricks = tricks.with(w, tricks[w] + 1)
        trick = emptyList()
        winP = null
        lastId = null
        if (hands.all { it.isEmpty() } || earlyEnd()) {
            if (hands.any { it.isNotEmpty() }) log += " Toate cărțile cu punctaj au ieșit, runda se oprește."
            endRound()
            return
        }
        turn = w
        phase = Phase.TRICK
        schedule()
    }

    private fun earlyEnd(): Boolean {
        val all = taken.flatten()
        return when (game) {
            GameKind.POPA -> all.any { it.id == "13H" }
            GameKind.DAME -> all.count { it.r == 12 } == 4
            GameKind.CAROURI -> all.count { it.s == Suit.D } == 15 - lowR
            GameKind.ZECE -> all.any { it.id == "10C" }
            else -> false
        }
    }

    // Renț

    fun validRentz(p: Int): List<Card> = hand(p).filter { c ->
        val b = board[c.s]
        if (b != null) c.r == b.lo - 1 || c.r == b.hi + 1 else c.r == midR
    }

    private fun placed(b: Map<Suit, Span>, c: Card): Map<Suit, Span> {
        val s = b[c.s]
        val ns = when {
            s == null -> Span(c.r, c.r)
            c.r < s.lo -> s.copy(lo = c.r)
            else -> s.copy(hi = c.r)
        }
        return b + (c.s to ns)
    }

    private val active: List<Int> get() = (0 until n).filter { it !in finished }

    private fun nextActive(p: Int): Int {
        for (i in 1..n) {
            val q = (p + i) % n
            if (q !in finished) return q
        }
        return p
    }

    private fun playRentz(p: Int, c: Card) {
        removeCard(p, c)
        board = placed(board, c)
        lastId = c.id
        bubble = emptyMap()
        var msg = "${names[p]} pune ${c.name}"
        if (hands[p].isEmpty()) {
            finished = finished + p
            msg += " și termină pe locul ${finished.size}"
        }
        if (active.size <= 1) {
            log = "$msg."
            wait(1.4) { finishRentz() }
            return
        }
        if (c.r == 14 && hands[p].isNotEmpty() && validRentz(p).isNotEmpty()) {
            log = "$msg — As: mai pune o carte."
            schedule()
            return
        }
        advanceRentz(c.r == lowR, msg)
    }

    private fun advanceRentz(skip: Boolean, message: String) {
        var msg = message
        var nx = nextActive(turn)
        if (skip) {
            msg += " — capăt mic: ${names[nx]} stă o tură"
            bubble = mapOf(nx to "stă")
            nx = nextActive(nx)
        }
        turn = nx
        log = "$msg."
        schedule()
    }

    private fun passRentz(p: Int) {
        bubble = mapOf(p to "pas")
        advanceRentz(false, "${names[p]}: pas")
    }

    private fun finishRentz() {
        finished = finished + active
        endRound()
    }

    // ---------- punctaj ----------

    private fun roundPoints(): List<Int> {
        val P = preset
        val g = game ?: return List(n) { 0 }
        if (g == GameKind.RENTZ) {
            val a = MutableList(n) { 0 }
            finished.forEachIndexed { i, p -> a[p] = P.rentz.getOrElse(i) { 0 } }
            return a
        }
        return List(n) { p ->
            val t = taken[p]
            val k = if (t.any { it.id == "13H" }) 1 else 0
            val q = t.count { it.r == 12 }
            val d = t.count { it.s == Suit.D }
            val l = tricks[p]
            val x = if (t.any { it.id == "10C" }) 1 else 0
            val tot = k * P.popa + q * P.dama + d * P.caro + l * P.levata
            when (g) {
                GameKind.POPA -> k * P.popa
                GameKind.DAME -> q * P.dama
                GameKind.CAROURI -> d * P.caro
                GameKind.LEVATE -> l * P.levata
                GameKind.TOTALE -> tot
                GameKind.TOTPLUS -> -tot
                GameKind.WHIST -> l * P.whist
                GameKind.ZECE -> x * P.zece
                GameKind.RENTZ -> 0
            }
        }
    }

    private fun detail(p: Int): String {
        val g = game ?: return "—"
        if (g == GameKind.RENTZ) return "locul ${finished.indexOf(p) + 1}"
        val t = taken[p]
        val bits = mutableListOf<String>()
        if (t.any { it.id == "13H" } && g in listOf(GameKind.POPA, GameKind.TOTALE, GameKind.TOTPLUS)) bits.add("K♥")
        val q = t.count { it.r == 12 }
        if (q > 0 && g in listOf(GameKind.DAME, GameKind.TOTALE, GameKind.TOTPLUS)) bits.add("$q ${if (q > 1) "dame" else "damă"}")
        val d = t.count { it.s == Suit.D }
        if (d > 0 && g in listOf(GameKind.CAROURI, GameKind.TOTALE, GameKind.TOTPLUS)) bits.add("$d ${if (d > 1) "carouri" else "caro"}")
        if (g in listOf(GameKind.LEVATE, GameKind.TOTALE, GameKind.TOTPLUS, GameKind.WHIST)) {
            bits.add("${tricks[p]} ${if (tricks[p] == 1) "levată" else "levate"}")
        }
        if (g == GameKind.ZECE && t.any { it.id == "10C" }) bits.add("10♣")
        return if (bits.isEmpty()) "—" else bits.joinToString(", ")
    }

    private fun endRound() {
        val g = game ?: return
        var pts = roundPoints()
        if (blind) pts = pts.map { it * 2 }
        val det = List(n) { detail(it) }
        scores = scores.mapIndexed { i, s -> s + pts[i] }
        val c = chooser
        history = history + RoundRecord(round + 1, c, g, blind, pts, det)
        used = used.with(c, used[c] + (g to round + 1))
        phase = Phase.ROUND_END
        save(round + 1)
        if (bots) wait(0.0) { nextRound() }
    }

    fun nextRound() {
        round += 1
        if (round >= total) {
            phase = Phase.GAME_OVER
            if (persist) store?.clearGame()
            return
        }
        startRound()
    }

    private fun save(next: Int) {
        if (!persist || store == null) return
        if (next >= total) {
            store.clearGame()
            return
        }
        store.saveGame(SavedGame(settings, names, scores, used, next, history, refusals))
    }

    /** Clasamentul final, ca la Whist: primul +10×n, ultimul −10×n, ceilalți proporțional. */
    fun finalTable(): List<FinalRow> {
        val mx = scores.max()
        val mn = scores.min()
        return (0 until n).map { p ->
            val fin = if (mx == mn) 0 else {
                val t = (scores[p] - mn).toDouble() / (mx - mn)
                (-10.0 * n + t * 20.0 * n).roundToInt()
            }
            FinalRow(p, scores[p], fin)
        }.sortedByDescending { it.raw }
    }

    // ---------- calculatorul ----------

    private fun aiMove(p: Int) {
        if (phase == Phase.TRICK) {
            playTrick(p, aiTrick(p))
        } else if (phase == Phase.RENTZ) {
            val v = validRentz(p)
            if (v.isEmpty()) passRentz(p) else playRentz(p, aiRentz(p, v))
        }
    }

    private fun aiChoose(p: Int): GameKind {
        val h = hand(p)
        val P = preset
        val span = (14 - lowR).toDouble()
        val hearts = h.filter { it.s == Suit.H }
        val hasK = h.any { it.id == "13H" }
        val hasA = h.any { it.id == "14H" }
        val pK = if (hasK) {
            if (hasA) 0.8 else max(0.15, 1 - 0.2 * hearts.count { it.r < 13 })
        } else {
            0.1 * max(0.0, 1 - hearts.size / 4.0) + 0.04
        }
        val vPopa = pK * P.popa
        val q = h.count { it.r == 12 }.toDouble()
        val hi = h.count { it.r >= 13 }.toDouble()
        val vDame = (q * 0.6 + hi * 0.22 + 0.35) * P.dama
        val dW = h.filter { it.s == Suit.D }.sumOf { (it.r - lowR) / span }
        val vCar = (dW * 1.1 + 0.6) * P.caro
        val str = h.sumOf { max(0, it.r - midR).toDouble() / (14 - midR) }
        val vLev = (str * 0.9 + 0.6) * P.levata
        val vTot = vPopa + vDame + vCar + vLev
        val w = h.count { it.r == 14 } + 0.55 * h.count { it.r == 13 } + 0.2 * q
        val has10 = h.any { it.id == "10C" }
        val cHi = h.count { it.s == Suit.C && it.r > 10 }.toDouble()
        val pZ = if (has10) min(0.9, 0.3 + 0.2 * cHi) else min(0.55, 0.1 * cHi + 0.05)
        val k = caps(p)
        val near = h.count { abs(it.r - midR) <= 1 }.toDouble()
        val placeIdx = ((n - 1) / 2.0 - (near * 0.6 - k.total * 0.7) * 0.6).roundToInt().coerceIn(0, n - 1)
        fun value(g: GameKind): Double = when (g) {
            GameKind.POPA -> vPopa
            GameKind.DAME -> vDame
            GameKind.CAROURI -> vCar
            GameKind.LEVATE -> vLev
            GameKind.TOTALE -> vTot
            GameKind.TOTPLUS -> -vTot * 0.85
            GameKind.WHIST -> w * P.whist
            GameKind.ZECE -> pZ * P.zece
            GameKind.RENTZ -> P.rentz.getOrElse(placeIdx) { 0 }.toDouble()
        }
        return bestOf(remaining(p)) { value(it) + Random.nextDouble(0.0, 4.0) }
    }

    private fun pen(c: Card, g: GameKind): Double {
        var v = 0.0
        if (c.id == "13H" && g in listOf(GameKind.POPA, GameKind.TOTALE, GameKind.TOTPLUS)) v += 100
        if (c.r == 12 && g in listOf(GameKind.DAME, GameKind.TOTALE, GameKind.TOTPLUS)) v += 25
        if (c.s == Suit.D && g in listOf(GameKind.CAROURI, GameKind.TOTALE, GameKind.TOTPLUS)) v += 12 + c.r / 2.0
        return v
    }

    private fun aiTrick(p: Int): Card {
        val v = validTrick(p)
        val g = game ?: GameKind.LEVATE
        val t = trick
        val last = t.size == n - 1
        val rank: (Card) -> Double = { it.r.toDouble() }

        if (t.isEmpty()) {
            if (g == GameKind.ZECE) {
                val ten = v.firstOrNull { it.id == "10C" }
                val topOut = listOf(11, 12, 13, 14).all { r -> "${r}C" in played || hand(p).any { it.id == "${r}C" } }
                if (ten != null && topOut) return ten
                if (ten == null && "10C" !in played) {
                    val cl = v.filter { it.s == Suit.C && it.r > 10 }
                    if (cl.isNotEmpty()) return bestOf(cl, rank)
                }
                val nt = v.filter { it.id != "10C" }
                return worstOf(nt.ifEmpty { v }, rank)
            }
            if (g.positive) return bestOf(v) { it.r - (if (g == GameKind.TOTPLUS) pen(it, g) / 10 else 0.0) }
            if (g == GameKind.POPA && hand(p).none { it.id == "13H" } && "13H" !in played) {
                val lh = v.filter { it.s == Suit.H && it.r < 13 }
                if (lh.isNotEmpty()) return worstOf(lh, rank)
            }
            return worstOf(v) { pen(it, g) * 10 + it.r }
        }

        val led = t[0].c.s
        val best = t.filter { it.c.s == led }.maxOf { it.c.r }
        val follow = v[0].s == led

        if (g.positive) {
            if (g == GameKind.ZECE) {
                val tenIn = t.any { it.c.id == "10C" }
                val my10 = v.firstOrNull { it.id == "10C" }
                val win = v.filter { it.r > best }
                val nt = v.filter { it.id != "10C" }
                if (follow) {
                    if (tenIn && win.isNotEmpty()) return if (last) worstOf(win, rank) else bestOf(win, rank)
                    if (my10 != null && my10.r > best && last) return my10
                    if (nt.isEmpty() && my10 != null) return my10
                    if (led == Suit.C && my10 == null && "10C" !in played && !last) {
                        val w2 = nt.filter { it.r > best }
                        if (w2.isNotEmpty()) return bestOf(w2, rank)
                    }
                    return worstOf(nt.ifEmpty { v }, rank)
                }
                return worstOf(nt.ifEmpty { v }, rank)
            }
            if (follow) {
                val win = v.filter { it.r > best }
                if (win.isNotEmpty()) return if (last) worstOf(win, rank) else bestOf(win, rank)
                return worstOf(v, rank)
            }
            return worstOf(v) { pen(it, g) * 10 + it.r }
        }

        if (follow) {
            val under = v.filter { it.r < best }
            if (under.isNotEmpty()) return bestOf(under, rank)
            if (last) return bestOf(v) { it.r - pen(it, g) * 10 }
            return worstOf(v) { it.r + pen(it, g) * 10 }
        }
        return bestOf(v) { pen(it, g) * 10 + it.r }
    }

    private fun aiRentz(p: Int, v: List<Card>): Card = bestOf(v) { c ->
        val b = placed(board, c)
        val rest = hand(p).filter { it != c }
        val ok = rest.count { x ->
            val s = b[x.s]
            if (s != null) x.r == s.lo - 1 || x.r == s.hi + 1 else x.r == midR
        }
        ok + (if (c.r == 14) 2.5 else 0.0) + (if (c.r == lowR) 2.0 else 0.0) + Random.nextDouble(0.0, 0.3)
    }

    // ---------- rulare sincronă (scene demonstrative pentru capturile Google Play) ----------

    /** Joacă singur, fără pauze, până când [until] e adevărat; apoi predă controlul omului. */
    fun runSync(maxSteps: Int = 200_000, until: (RentzGame) -> Boolean) {
        persist = false
        bots = true
        val q = ArrayDeque<() -> Unit>()
        syncQueue = q
        startRound()
        var steps = 0
        while (!until(this) && steps < maxSteps) {
            val f = q.removeFirstOrNull() ?: break
            f()
            steps++
        }
        syncQueue = null
        bots = false
    }

    companion object {
        val BOT_NAMES = listOf("Ana", "Mihai", "Ioana", "Radu", "Elena")
    }
}
