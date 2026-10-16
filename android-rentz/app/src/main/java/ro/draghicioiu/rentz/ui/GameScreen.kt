package ro.draghicioiu.rentz.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FormatListNumbered
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ro.draghicioiu.rentz.model.Card
import ro.draghicioiu.rentz.model.GameKind
import ro.draghicioiu.rentz.model.Phase
import ro.draghicioiu.rentz.model.RentzGame

@Composable
fun GameScreen(g: RentzGame, initialSheet: String?, onExit: () -> Unit) {
    var showRules by rememberSaveable { mutableStateOf(initialSheet == "reguli") }
    var showScore by rememberSaveable { mutableStateOf(initialSheet == "scor") }
    var confirmExit by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current

    LaunchedEffect(g.lastId) { if (g.lastId != null) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
    BackHandler { confirmExit = true }

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().padding(horizontal = 12.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Brand("${g.n} jucători · punctaj ${g.preset.label.lowercase()}", Modifier.weight(1f))
                Box {
                    RoundIcon(Icons.Filled.MoreVert, "Meniu", T.panel2) { menu = true }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(text = { Text("Foaia de scor") }, onClick = { menu = false; showScore = true })
                        DropdownMenuItem(text = { Text("Reguli") }, onClick = { menu = false; showRules = true })
                        DropdownMenuItem(text = { Text("Ieși la meniu") }, onClick = { menu = false; confirmExit = true })
                    }
                }
                RoundIcon(Icons.Filled.FormatListNumbered, "Foaia de scor", null) { showScore = true }
            }
            InfoChips(g)
            Text(
                g.log.ifEmpty { " " }, color = T.fg.copy(alpha = 0.9f), fontSize = 13.sp, lineHeight = 17.sp,
                maxLines = 2, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.fillMaxWidth().heightIn(min = 34.dp),
            )
            TableView(g, Modifier.fillMaxWidth().weight(1f))
            HandView(g)
        }

        if (g.phase == Phase.ROUND_END) RoundEndView(g) { showScore = true }
        if (g.phase == Phase.GAME_OVER) FinalView(g, openScore = { showScore = true }, newGame = { g.stop(); onExit() })
    }

    if (showRules) FullDialog("Regulament", onClose = { showRules = false }) { RulesContent() }
    if (showScore) FullDialog("Foaia de scor", onClose = { showScore = false }) { ScoreSheet(g) }
    if (confirmExit) {
        AlertDialog(
            onDismissRequest = { confirmExit = false },
            title = { Text("Părăsești masa?") },
            text = { Text("Partida se salvează după fiecare rundă terminată și o poți continua din meniu.") },
            confirmButton = { TextButton(onClick = { confirmExit = false; g.stop(); onExit() }) { Text("Ieși la meniu") } },
            dismissButton = { TextButton(onClick = { confirmExit = false }) { Text("Rămân la masă") } },
            containerColor = T.panel, titleContentColor = T.fg, textContentColor = T.muted,
        )
    }
}

@Composable
private fun RoundIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, bg: Color?, onClick: () -> Unit) {
    Box(
        Modifier
            .size(40.dp)
            .then(if (bg != null) Modifier.background(bg, CircleShape).border(1.dp, T.line, CircleShape) else Modifier.background(T.redGradient, CircleShape))
            .clickable(role = Role.Button, onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = if (bg != null) T.fg else Color.White, modifier = Modifier.size(20.dp))
    }
}

@Composable
fun Brand(subtitle: String, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
        Box(
            Modifier.size(34.dp).background(Brush.radialGradient(listOf(T.redHi, T.red, T.redLo)), CircleShape),
            contentAlignment = Alignment.Center,
        ) { Text("♠", color = Color.White, fontSize = 18.sp) }
        Column {
            Text("MASA DE RENȚ", style = T.display(21), color = T.fg, maxLines = 1)
            Text(
                subtitle.uppercase(), color = T.muted, fontSize = 9.sp, fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun InfoChips(g: RentzGame) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Chip("Runda", "${minOf(g.round + 1, g.total)} / ${g.total}")
        Chip("Alege", g.names[g.chooser])
        g.game?.let { Chip("Joc", it.title, hot = true) }
        if (g.blind) Chip("×2", "pe nevăzute", hot = true)
        val gm = g.game
        if (gm != null && gm != GameKind.RENTZ) Chip("Levata", "${minOf(g.tricksPlayed + 1, 8)} / 8")
        if (gm == GameKind.RENTZ) Chip("Mijloc", Card.rankLabel(g.midR) + " · capăt " + Card.rankLabel(g.lowR))
    }
}

@Composable
private fun HandView(g: RentzGame) {
    val hide = g.phase == Phase.BLIND_ASK || (g.phase == Phase.CHOOSE && g.blind)
    val playable = g.humanPlayable()
    val mine = g.isHumanTurn
    val cards = g.hand(0)
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        BoxWithConstraints(Modifier.fillMaxWidth().height(124.dp)) {
            val w = minOf(76f, maxWidth.value / (1 + 7 * 0.74f)).dp
            val step = w * 0.74f
            val total = w + step * (cards.size - 1).coerceAtLeast(0)
            Box(Modifier.align(Alignment.BottomCenter).width(total).height(w * 1.42f + 14.dp)) {
                cards.forEachIndexed { i, c ->
                    val ok = c.id in playable
                    PlayingCard(
                        c, w, faceDown = hide, glow = ok, dim = mine && !ok,
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .offset(x = step * i, y = if (ok) (-12).dp else 0.dp)
                            .then(if (ok) Modifier.clickable(role = Role.Button) { g.humanPlay(c) } else Modifier),
                    )
                }
            }
        }
        Box(Modifier.height(40.dp), contentAlignment = Alignment.Center) {
            val place = if (g.game == GameKind.RENTZ) g.finished.indexOf(0).takeIf { it >= 0 } else null
            when {
                mine && g.phase == Phase.RENTZ && g.validRentz(0).isEmpty() ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        PillButton("Pas", small = true) { g.humanPass() }
                        Text("Nu ai nicio carte care se leagă.", color = T.gold, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                mine -> Text(
                    if (g.phase == Phase.RENTZ) "Rândul tău: pune o carte lângă coloană" else "Rândul tău: alege o carte",
                    color = T.gold, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                )
                place != null -> Text("Ai terminat pe locul ${place + 1}.", color = T.gold, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                cards.isEmpty() && g.phase != Phase.ROUND_END -> Text("Nu mai ai cărți în mână.", color = T.muted, fontSize = 13.sp)
                else -> Spacer(Modifier.width(1.dp))
            }
        }
    }
}
