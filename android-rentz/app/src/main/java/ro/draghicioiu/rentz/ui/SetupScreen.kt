package ro.draghicioiu.rentz.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ro.draghicioiu.rentz.model.Card
import ro.draghicioiu.rentz.model.SaveStore
import ro.draghicioiu.rentz.model.SavedGame
import ro.draghicioiu.rentz.model.Settings
import ro.draghicioiu.rentz.model.Suit
import kotlin.math.abs

/** Ecranul de start: setările mesei și, dacă există, partida salvată. */
@Composable
fun SetupScreen(
    store: SaveStore,
    onStart: (Settings, SavedGame?) -> Unit,
) {
    var s by remember { mutableStateOf(store.loadSettings()) }
    var saved by remember { mutableStateOf(store.loadGame()) }
    var showRules by remember { mutableStateOf(false) }
    fun update(n: Settings) {
        s = n
        store.saveSettings(n)
    }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier
                .widthIn(max = 620.dp)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Brand("joc de cărți românesc", Modifier.weight(1f))
                PillButton("Reguli", kind = PillKind.GHOST, small = true) { showRules = true }
            }

            Hero()

            saved?.let { sv ->
                val shape = RoundedCornerShape(14.dp)
                Column(
                    Modifier
                        .fillMaxWidth()
                        .background(T.panel, shape)
                        .border(1.dp, T.gold.copy(alpha = 0.6f), shape)
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text("PARTIDĂ ÎNCEPUTĂ", style = T.display(19), color = T.gold)
                    Text(
                        "Runda ${sv.round + 1} din ${sv.settings.players * 8} · ${sv.settings.players} jucători · scorul tău ${sv.scores.firstOrNull() ?: 0}",
                        color = T.fg, fontSize = 14.sp,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        PillButton("Continuă", kind = PillKind.GOLD) { onStart(sv.settings, sv) }
                        PillButton("Renunță", kind = PillKind.GHOST, small = true) {
                            store.clearGame()
                            saved = null
                        }
                    }
                }
            }

            val shape = RoundedCornerShape(16.dp)
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(T.panel, shape)
                    .border(1.dp, T.line, shape)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(if (saved == null) "MASĂ NOUĂ" else "SAU O MASĂ NOUĂ", style = T.display(22), color = T.fg)
                Field("Numele tău") {
                    BasicTextField(
                        value = s.name,
                        onValueChange = { update(s.copy(name = it.take(14))) },
                        singleLine = true,
                        textStyle = TextStyle(color = T.fg, fontSize = 16.sp),
                        cursorBrush = SolidColor(T.gold),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(T.panel2, RoundedCornerShape(9.dp))
                            .border(1.dp, T.line, RoundedCornerShape(9.dp))
                            .padding(horizontal = 12.dp, vertical = 11.dp),
                    )
                }
                Field("Jucători la masă") {
                    Segmented(listOf(3, 4, 5, 6).map { it to "$it" }, s.players) { update(s.copy(players = it)) }
                }
                Field("Punctaj") {
                    Segmented(listOf("clasic" to "Clasic −300", "casino" to "Casino −100"), s.preset) { update(s.copy(preset = it)) }
                }
                Field("Al optulea joc") {
                    Segmented(listOf("whist" to "Whist", "totplus" to "Totale Plus"), s.eighth) { update(s.copy(eighth = it)) }
                }
                Field("Viteza adversarilor") {
                    Segmented(listOf(false to "Normal", true to "Rapid"), s.fast) { update(s.copy(fast = it)) }
                }
                val p = s.players
                Text(
                    "$p jucători: pachet de ${8 * p} cărți (${Card.rankLabel(15 - 2 * p)}–A), mijlocul la Renț este ${Card.rankLabel(15 - p)}, ${8 * p} runde.",
                    color = T.muted, fontSize = 13.sp, lineHeight = 18.sp,
                )
                PillButton("Începe jocul") {
                    if (saved != null) store.clearGame()
                    onStart(s, null)
                }
                if (saved != null) Text("O masă nouă înlocuiește partida începută.", color = T.muted, fontSize = 12.sp)
            }
        }
    }
    if (showRules) FullDialog("Regulament", onClose = { showRules = false }) { RulesContent() }
}

@Composable
private fun Field(label: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(label.uppercase(), color = T.muted, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 1.sp)
        content()
    }
}

@Composable
private fun <V> Segmented(options: List<Pair<V, String>>, selected: V, onSelect: (V) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(T.panel2, CircleShape)
            .border(1.dp, T.line, CircleShape)
            .padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        options.forEach { (v, label) ->
            val on = v == selected
            Box(
                Modifier
                    .weight(1f)
                    .background(if (on) T.red else T.panel2, CircleShape)
                    .clickable(role = Role.RadioButton) { onSelect(v) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(label, color = if (on) androidx.compose.ui.graphics.Color.White else T.muted, fontSize = 13.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            }
        }
    }
}

/** O bucată de postav cu un evantai de cărți: ce face aplicația, dintr-o privire. */
@Composable
private fun Hero() {
    val fan = listOf(Card(11, Suit.H), Card(12, Suit.S), Card(13, Suit.H), Card(14, Suit.C), Card(10, Suit.D))
    val shape = RoundedCornerShape(70.dp)
    Box(
        Modifier
            .fillMaxWidth()
            .height(170.dp)
            .background(androidx.compose.ui.graphics.Brush.radialGradient(listOf(T.felt, T.feltMid, T.feltLo)), shape)
            .border(8.dp, T.rim, shape),
        contentAlignment = Alignment.Center,
    ) {
        Box {
            fan.forEachIndexed { i, c ->
                PlayingCard(
                    c, 62.dp,
                    modifier = Modifier
                        .offset(x = ((i - 2) * 36).dp, y = (abs(i - 2) * 6).dp)
                        .rotate((i - 2) * 9f),
                )
            }
        }
    }
}
