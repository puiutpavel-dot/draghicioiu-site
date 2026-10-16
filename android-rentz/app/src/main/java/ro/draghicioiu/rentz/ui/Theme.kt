package ro.draghicioiu.rentz.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Paleta mesei: postav verde, ramă de lemn închis, butoane roșii și auriu pentru rândul tău. */
object T {
    val bg = Color(0xFF111315)
    val panel = Color(0xFF1B1D20)
    val panel2 = Color(0xFF25282C)
    val line = Color(0xFF363A40)
    val fg = Color(0xFFF3F2EE)
    val muted = Color(0xFFA4A8AD)
    val red = Color(0xFFD3172B)
    val redHi = Color(0xFFEC3045)
    val redLo = Color(0xFF8F0D1B)
    val gold = Color(0xFFF1BE50)
    val goldInk = Color(0xFF2A1B00)
    val ok = Color(0xFF4FC58C)
    val bad = Color(0xFFFF8D9B)
    val felt = Color(0xFF11603F)
    val feltMid = Color(0xFF0C4A31)
    val feltLo = Color(0xFF073523)
    val rim = Color(0xFF2B1B12)
    val card = Color(0xFFFBFAF5)
    val cardRed = Color(0xFFC4122D)
    val cardBlack = Color(0xFF1A1B1D)

    val redGradient = Brush.verticalGradient(listOf(redHi, red, redLo))
    val goldGradient = Brush.verticalGradient(listOf(Color(0xFFFFD77D), gold, Color(0xFFB98620)))

    /** Titluri: sans condensat, foarte gros, cu majuscule. */
    fun display(size: Int) = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Black,
        fontSize = size.sp,
        letterSpacing = 0.5.sp,
    )
}

enum class PillKind { RED, GHOST, GOLD }

@Composable
fun PillButton(
    text: String,
    modifier: Modifier = Modifier,
    kind: PillKind = PillKind.RED,
    small: Boolean = false,
    onClick: () -> Unit,
) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val shape = CircleShape
    val bgMod = when (kind) {
        PillKind.RED -> Modifier.background(T.redGradient, shape)
        PillKind.GOLD -> Modifier.background(T.goldGradient, shape)
        PillKind.GHOST -> Modifier.background(T.panel2, shape).border(BorderStroke(1.dp, T.line), shape)
    }
    val ink = when (kind) {
        PillKind.RED -> Color.White
        PillKind.GHOST -> T.fg
        PillKind.GOLD -> T.goldInk
    }
    Box(
        modifier
            .offset(y = if (pressed) 2.dp else 0.dp)
            .shadow(if (pressed) 1.dp else 3.dp, shape)
            .then(bgMod)
            .clickable(interactionSource = source, indication = null, role = Role.Button, onClick = onClick)
            .padding(horizontal = if (small) 14.dp else 20.dp, vertical = if (small) 9.dp else 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text.uppercase(),
            color = ink,
            fontSize = if (small) 12.sp else 14.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = 0.6.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
fun Chip(label: String, value: String, hot: Boolean = false) {
    Row(
        Modifier
            .background(T.panel, CircleShape)
            .border(1.dp, if (hot) T.gold else T.line, CircleShape)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(label, color = if (hot) T.gold else T.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        Text(value, color = if (hot) T.gold else T.fg, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold)
    }
}

enum class BadgeKind { RED, GOLD, DARK }

@Composable
fun Badge(text: String, kind: BadgeKind = BadgeKind.RED) {
    Text(
        text.uppercase(),
        color = when (kind) {
            BadgeKind.GOLD -> T.goldInk
            BadgeKind.DARK -> T.fg
            BadgeKind.RED -> Color.White
        },
        fontSize = 9.sp,
        fontWeight = FontWeight.ExtraBold,
        letterSpacing = 0.6.sp,
        modifier = Modifier
            .background(
                when (kind) {
                    BadgeKind.GOLD -> T.gold
                    BadgeKind.DARK -> T.panel2
                    BadgeKind.RED -> T.red
                },
                RoundedCornerShape(4.dp),
            )
            .padding(horizontal = 5.dp, vertical = 2.dp),
    )
}

fun signed(x: Int) = if (x > 0) "+$x" else "$x"
fun pointsColor(x: Int) = if (x < 0) T.bad else if (x > 0) T.ok else T.fg
