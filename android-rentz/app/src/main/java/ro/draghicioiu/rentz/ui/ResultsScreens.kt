package ro.draghicioiu.rentz.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import ro.draghicioiu.rentz.model.RentzGame

/** Fundal întunecat peste tot ecranul, cu un card centrat care se poate derula. */
@Composable
private fun Dimmed(content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.66f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .safeDrawingPadding()
            .padding(16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .widthIn(max = 560.dp)
                .fillMaxWidth()
                .background(T.panel, RoundedCornerShape(16.dp))
                .border(1.dp, T.line, RoundedCornerShape(16.dp))
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) { content() }
    }
}

@Composable
fun RoundEndView(g: RentzGame, openScore: () -> Unit) {
    val r = g.history.lastOrNull() ?: return
    Dimmed {
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text("RUNDA ${r.round}: ${r.game.title.uppercase()}${if (r.blind) " ×2" else ""}", style = T.display(24), color = T.fg)
            Text("Ales de ${g.names[r.chooser]}.", color = T.muted, fontSize = 13.sp)
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row {
                HeaderCell("Jucător", Modifier.weight(1.1f))
                HeaderCell("Ce a luat", Modifier.weight(1.5f))
                HeaderCell("Puncte", Modifier.weight(0.8f), TextAlign.End)
                HeaderCell("Total", Modifier.weight(0.8f), TextAlign.End)
            }
            Box(Modifier.fillMaxWidth().height(1.dp).background(T.line))
            for (p in 0 until g.n) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(g.names[p], color = T.fg, fontSize = 14.sp, fontWeight = if (p == 0) FontWeight.ExtraBold else FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1.1f))
                    Text(r.det[p], color = T.muted, fontSize = 13.sp, maxLines = 2, modifier = Modifier.weight(1.5f))
                    Text(signed(r.pts[p]), color = pointsColor(r.pts[p]), fontSize = 14.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.End, modifier = Modifier.weight(0.8f))
                    Text("${g.scores[p]}", color = T.fg, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.End, modifier = Modifier.weight(0.8f))
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PillButton(if (g.round + 1 >= g.total) "Vezi clasamentul" else "Runda următoare") { g.nextRound() }
            PillButton("Foaia de scor", kind = PillKind.GHOST, onClick = openScore)
        }
    }
}

@Composable
private fun HeaderCell(text: String, modifier: Modifier, align: TextAlign = TextAlign.Start) {
    Text(text.uppercase(), color = T.muted, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 0.8.sp, textAlign = align, modifier = modifier)
}

@Composable
fun FinalView(g: RentzGame, openScore: () -> Unit, newGame: () -> Unit) {
    val rows = g.finalTable()
    Dimmed {
        Text("CLASAMENT FINAL", style = T.display(28), color = T.fg)
        Text(
            "Punctajul final se calculează ca la Whist: locul 1 +${10 * g.n}, ultimul −${10 * g.n}, ceilalți proporțional.",
            color = T.muted, fontSize = 13.sp, lineHeight = 18.sp,
        )
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            rows.forEachIndexed { i, row ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .background(T.panel2, RoundedCornerShape(10.dp))
                        .border(1.dp, if (i == 0) T.gold else T.line, RoundedCornerShape(10.dp))
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("${i + 1}", style = T.display(22), color = T.gold, modifier = Modifier.width(30.dp))
                    Text(g.names[row.p], color = T.fg, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.weight(1f))
                    Text("${row.raw} pct", color = T.muted, fontSize = 13.sp)
                    Text(signed(row.fin), color = pointsColor(row.fin), fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.End, modifier = Modifier.width(60.dp))
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PillButton("Joc nou", onClick = newGame)
            PillButton("Foaia de scor", kind = PillKind.GHOST, onClick = openScore)
        }
    }
}

/** Ecran plin pentru foaia de scor și regulament. */
@Composable
fun FullDialog(title: String, onClose: () -> Unit, content: @Composable () -> Unit) {
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxSize().background(T.bg).safeDrawingPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(title, color = T.fg, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                TextButton(onClick = onClose) { Text("Gata", color = T.redHi, fontWeight = FontWeight.Bold) }
            }
            Box(Modifier.fillMaxWidth().height(1.dp).background(T.line))
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) { content() }
        }
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(text.uppercase(), style = T.display(19), color = T.gold, modifier = Modifier.padding(top = 4.dp))
}

@Composable
fun ScoreSheet(g: RentzGame) {
    SectionTitle("Jocuri alese")
    Text(
        "Fiecare jucător hașurează jocul ales, cu numărul rundei. Când toate căsuțele sunt hașurate, partida se încheie.",
        color = T.muted, fontSize = 13.sp, lineHeight = 18.sp,
    )
    Column(Modifier.horizontalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Box(Modifier.width(70.dp))
            g.games.forEach { k -> Text(k.short, color = T.muted, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.Center, modifier = Modifier.width(52.dp)) }
            Text("TOTAL", color = T.muted, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.End, modifier = Modifier.width(56.dp))
        }
        for (p in 0 until g.n) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(g.names[p], color = T.fg, fontSize = 13.sp, fontWeight = if (p == 0) FontWeight.ExtraBold else FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.width(70.dp))
                g.games.forEach { k -> SheetCell(g.used[p][k]) }
                Text("${g.scores[p]}", color = T.fg, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.End, modifier = Modifier.width(56.dp))
            }
        }
    }
    SectionTitle("Istoric runde")
    if (g.history.isEmpty()) {
        Text("Încă nu s-a terminat nicio rundă.", color = T.muted, fontSize = 14.sp)
    } else {
        Column(Modifier.horizontalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                HeaderCell("Runda", Modifier.width(150.dp))
                g.names.forEach { HeaderCell(it, Modifier.width(56.dp), TextAlign.End) }
            }
            g.history.asReversed().forEach { r ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.width(150.dp)) {
                        Text("${r.round}. ${r.game.title}${if (r.blind) " ×2" else ""}", color = T.fg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        Text(g.names[r.chooser], color = T.muted, fontSize = 11.sp)
                    }
                    r.pts.forEach { x ->
                        Text(signed(x), color = pointsColor(x), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.End, modifier = Modifier.width(56.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun SheetCell(round: Int?) {
    val shape = RoundedCornerShape(6.dp)
    Box(
        Modifier
            .size(52.dp, 30.dp)
            .clip(shape)
            .background(T.panel2)
            .then(
                if (round != null) Modifier.drawBehind {
                    var x = -size.height
                    while (x < size.width) {
                        drawLine(T.red.copy(alpha = 0.45f), Offset(x, size.height), Offset(x + size.height, 0f), strokeWidth = 2.5.dp.toPx())
                        x += 7.dp.toPx()
                    }
                } else Modifier
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (round != null) Text("R$round", color = T.fg, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold)
    }
}
