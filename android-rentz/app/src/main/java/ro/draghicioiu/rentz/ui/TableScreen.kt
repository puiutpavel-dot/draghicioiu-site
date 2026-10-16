package ro.draghicioiu.rentz.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.ParentDataModifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import ro.draghicioiu.rentz.model.Card
import ro.draghicioiu.rentz.model.GameKind
import ro.draghicioiu.rentz.model.Phase
import ro.draghicioiu.rentz.model.RentzGame
import ro.draghicioiu.rentz.model.Suit
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

// ---------- așezare liberă: fiecare copil e centrat într-un punct (fracțiuni din masă) ----------

private class At(val fx: Float, val fy: Float) : ParentDataModifier {
    override fun Density.modifyParentData(parentData: Any?): Any = this@At
}

private fun Modifier.at(fx: Float, fy: Float): Modifier = this.then(At(fx, fy))

@Composable
private fun FreeLayout(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Layout(content, modifier) { measurables, constraints ->
        val w = constraints.maxWidth
        val h = constraints.maxHeight
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val placed = measurables.map { it.measure(loose) to (it.parentData as? At) }
        layout(w, h) {
            placed.forEach { (pl, at) ->
                if (at == null) pl.place(0, 0)
                else pl.place((w * at.fx - pl.width / 2f).roundToInt(), (h * at.fy - pl.height / 2f).roundToInt())
            }
        }
    }
}

/** Poziția fiecărui jucător în jurul mesei (0…1). Omul stă jos, adversarii pe un arc deasupra. */
fun seatPos(p: Int, n: Int): Pair<Float, Float> {
    if (p == 0) return 0.5f to 0.9f
    val m = (n - 1).toDouble()
    val deg = 180.0 - (p - 1) * 180.0 / (m - 1)
    val a = deg * PI / 180
    return (0.5 + 0.39 * cos(a)).toFloat() to (0.5 - 0.4 * sin(a)).toFloat()
}

@Composable
fun TableView(g: RentzGame, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier) {
        val w = maxWidth
        val h = maxHeight
        val cardW = (w.value * 0.13f).coerceIn(38f, 58f).dp
        val corner = min(w, h) * 0.3f
        FreeLayout(Modifier.fillMaxSize()) {
            Felt(corner, Modifier.fillMaxSize())
            Text(
                "RENȚ",
                style = T.display((min(w, h).value * 0.2f).toInt()),
                letterSpacing = 8.sp,
                color = Color.White.copy(alpha = 0.045f),
                modifier = Modifier.at(0.5f, 0.5f),
            )
            if (g.game == GameKind.RENTZ && (g.phase == Phase.RENTZ || g.phase == Phase.ROUND_END)) {
                RentzBoard(g, (w.value * 0.075f).coerceIn(24f, 36f).dp, Modifier.at(0.5f, 0.5f))
            }
            g.trick.forEach { t ->
                val (sx, sy) = seatPos(t.p, g.n)
                Box(Modifier.at(0.5f + (sx - 0.5f) * 0.42f, 0.5f + (sy - 0.5f) * 0.46f)) {
                    EnterPop(t.c.id) { PlayingCard(t.c, cardW, glow = g.winningCardId == t.c.id) }
                }
            }
            for (p in 0 until g.n) {
                val (sx, sy) = seatPos(p, g.n)
                Seat(g, p, Modifier.at(sx, sy))
            }
            Box(Modifier.at(0.5f, 0.5f).widthIn(max = min(w * 0.92f, 440.dp)).heightIn(max = h * 0.88f)) {
                DecisionPanel(g)
            }
        }
    }
}

@Composable
private fun Felt(corner: Dp, modifier: Modifier) {
    val shape = RoundedCornerShape(corner)
    Box(
        modifier
            .shadow(14.dp, shape)
            .background(Brush.radialGradient(listOf(T.felt, T.feltMid, T.feltLo), radius = 900f), shape)
            .border(9.dp, T.rim, shape)
            .padding(9.dp)
            .border(1.5.dp, T.gold.copy(alpha = 0.25f), RoundedCornerShape(corner - 9.dp))
    )
}

@Composable
private fun Seat(g: RentzGame, p: Int, modifier: Modifier) {
    val isTurn = (g.phase == Phase.TRICK || g.phase == Phase.RENTZ) && g.turn == p
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (p != 0) BacksRow(g.hand(p).size)
        Box {
            Column(
                Modifier
                    .shadow(if (isTurn) 8.dp else 0.dp, RoundedCornerShape(10.dp), ambientColor = T.gold, spotColor = T.gold)
                    .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(10.dp))
                    .border(if (isTurn) 2.dp else 1.dp, if (isTurn) T.gold else T.line, RoundedCornerShape(10.dp))
                    .widthIn(min = 64.dp)
                    .padding(horizontal = 8.dp, vertical = 5.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    g.names[p], color = T.fg, fontSize = 13.sp, fontWeight = FontWeight.ExtraBold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 84.dp),
                )
                Text("${g.scores[p]} pct", color = T.muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            }
            g.bubble[p]?.let { b ->
                Text(
                    b, color = T.bg, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = 12.dp, y = (-10).dp)
                        .background(T.fg, CircleShape)
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
        }
        val chooser = p == g.chooser && g.phase != Phase.GAME_OVER
        val lev = if (g.game != null && g.game != GameKind.RENTZ) g.tricks.getOrElse(p) { 0 } else 0
        val place = if (g.game == GameKind.RENTZ) g.finished.indexOf(p).takeIf { it >= 0 } else null
        if (chooser || lev > 0 || place != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                if (chooser) Badge("alege")
                if (lev > 0) Badge("$lev lev.", BadgeKind.DARK)
                if (place != null) Badge("locul ${place + 1}", BadgeKind.GOLD)
            }
        }
    }
}

@Composable
private fun RentzBoard(g: RentzGame, cardW: Dp, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Suit.boardOrder.forEach { s ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    s.symbol, fontSize = 17.sp,
                    color = if (s.isRed) T.bad else Color.White.copy(alpha = 0.7f),
                    modifier = Modifier.widthIn(min = 18.dp),
                )
                val span = g.board[s]
                if (span != null) {
                    val count = span.hi - span.lo + 1
                    Box(Modifier.size(cardW + cardW * 0.58f * (count - 1), cardW * 1.42f)) {
                        for ((i, r) in (span.lo..span.hi).withIndex()) {
                            Box(Modifier.padding(start = cardW * 0.58f * i)) {
                                PlayingCard(Card(r, s), cardW, compact = true, ring = r == g.midR)
                            }
                        }
                    }
                } else {
                    Box(
                        Modifier
                            .size(cardW, cardW * 1.42f)
                            .drawBehind {
                                drawRoundRect(
                                    Color.White.copy(alpha = 0.35f),
                                    cornerRadius = CornerRadius(4.dp.toPx()),
                                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 7f))),
                                )
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(Card.rankLabel(g.midR) + s.symbol, color = Color.White.copy(alpha = 0.55f), fontSize = 11.sp, fontWeight = FontWeight.ExtraBold)
                    }
                }
            }
        }
    }
}

// ---------- deciziile omului pe postav ----------

@Composable
private fun DecisionPanel(g: RentzGame) {
    val show = g.phase in setOf(Phase.BLIND_ASK, Phase.CHOOSE, Phase.REFUSE_ASK, Phase.AI_CHOOSING, Phase.REFUSED)
    AnimatedVisibility(show, enter = fadeIn() + scaleIn(initialScale = 0.95f), exit = fadeOut()) {
        when (g.phase) {
            Phase.BLIND_ASK -> Panel(
                "Tu alegi jocul",
                "Te uiți la cărți sau alegi pe nevăzute? Pe nevăzute, punctajul rundei se dublează pentru toți jucătorii.",
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PillButton("Văd cărțile", small = true) { g.humanBlind(false) }
                    PillButton("Pe nevăzute ×2", kind = PillKind.GOLD, small = true) { g.humanBlind(true) }
                }
            }
            Phase.CHOOSE -> Panel(
                if (g.blind) "Alege jocul · ×2" else "Alege jocul",
                "Îți mai rămân ${g.remaining(0).size} din 8. Fiecare joc se alege o singură dată.",
            ) { GameChoiceGrid(g) }
            Phase.REFUSE_ASK -> {
                val k = g.caps(0)
                val who = g.names[g.chooser]
                Panel(
                    "Refuzi Renț-ul?",
                    "$who a ales Renț${if (g.blind) " pe nevăzute" else ""}. Ai ${k.total} capete (${k.aces} ași, ${k.lows} de ${Card.rankLabel(g.lowR)}), deci poți refuza. La refuz se reîmpart cărțile și $who alege din nou.",
                ) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        PillButton("Refuz", small = true) { g.humanRefuse(true) }
                        PillButton("Joc Renț", kind = PillKind.GHOST, small = true) { g.humanRefuse(false) }
                    }
                }
            }
            Phase.AI_CHOOSING -> Panel(
                "${g.names[g.chooser]} alege…",
                "Se uită la cărți și alege unul dintre jocurile rămase (${g.remaining(g.chooser).size}).",
            ) {}
            Phase.REFUSED -> Panel("Refuzat", g.log) {}
            else -> Box {}
        }
    }
}

@Composable
private fun Panel(title: String, text: String, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(16.dp, shape)
            .background(Color(0xF20E1012), shape)
            .border(1.dp, T.line, shape)
            .padding(15.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(title.uppercase(), style = T.display(22), color = T.fg)
        Text(text, color = T.muted, fontSize = 14.sp, lineHeight = 19.sp)
        content()
    }
}

@Composable
private fun GameChoiceGrid(g: RentzGame) {
    Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        g.remaining(0).chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { k ->
                    Column(
                        Modifier
                            .weight(1f)
                            .heightIn(min = 54.dp)
                            .background(T.panel2, RoundedCornerShape(10.dp))
                            .border(1.dp, T.line, RoundedCornerShape(10.dp))
                            .clickable { g.humanChoose(k) }
                            .padding(9.dp),
                    ) {
                        Row {
                            Text(k.title, color = T.fg, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (k.positive) Text(" +", color = T.ok, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold)
                        }
                        Text(k.desc(g.preset), color = T.muted, fontSize = 11.sp, maxLines = 2, lineHeight = 14.sp)
                    }
                }
                if (row.size == 1) Box(Modifier.weight(1f))
            }
        }
    }
}
