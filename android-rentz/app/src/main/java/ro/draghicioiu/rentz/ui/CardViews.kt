package ro.draghicioiu.rentz.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import ro.draghicioiu.rentz.model.Card

/** O carte de joc desenată nativ. `compact` arată doar indicele (pentru coloanele de la Renț). */
@Composable
fun PlayingCard(
    card: Card?,
    width: Dp,
    modifier: Modifier = Modifier,
    faceDown: Boolean = false,
    glow: Boolean = false,
    dim: Boolean = false,
    compact: Boolean = false,
    ring: Boolean = false,
) {
    val shape = RoundedCornerShape(width * 0.1f)
    val ink = if (card?.s?.isRed == true) T.cardRed else T.cardBlack
    val density = LocalDensity.current
    fun sp(f: Float) = with(density) { (width * f).toSp() }
    Box(
        modifier
            .size(width, width * 1.42f)
            .alpha(if (dim) 0.42f else 1f)
            .shadow(if (glow) 8.dp else 3.dp, shape, ambientColor = if (glow) T.gold else Color.Black, spotColor = if (glow) T.gold else Color.Black)
            .clip(shape)
            .background(T.card)
            .then(
                if (glow || ring) Modifier.border(if (glow) 2.5.dp else 2.dp, T.gold, shape)
                else Modifier
            )
            .semantics { contentDescription = card?.let { "${it.label} ${it.s.label}" } ?: "carte cu fața în jos" },
    ) {
        if (faceDown || card == null) {
            CardBack(Modifier.fillMaxSize())
        } else {
            Column(
                Modifier.padding(start = width * 0.07f, top = width * 0.04f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(card.label, color = ink, fontSize = sp(if (compact) 0.36f else 0.31f), fontWeight = FontWeight.ExtraBold, lineHeight = sp(if (compact) 0.38f else 0.33f))
                Text(card.s.symbol, color = ink, fontSize = sp(if (compact) 0.30f else 0.25f), lineHeight = sp(if (compact) 0.32f else 0.27f))
            }
            if (!compact) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .padding(start = width * 0.2f, top = width * 0.3f),
                    contentAlignment = Alignment.Center,
                ) {
                    if (card.isFace) {
                        Box(
                            Modifier
                                .size(width * 0.5f, width * 0.62f)
                                .border(1.5.dp, ink, RoundedCornerShape(width * 0.07f)),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(card.label, color = ink, style = T.display(0).copy(fontSize = sp(0.46f)))
                        }
                    } else {
                        Text(card.s.symbol, color = ink, fontSize = sp(0.56f))
                    }
                }
            }
        }
    }
}

@Composable
fun CardBack(modifier: Modifier = Modifier) {
    Canvas(modifier.background(Brush.linearGradient(listOf(T.redHi, T.red, T.redLo)))) {
        val step = 6.dp.toPx()
        var x = -size.height
        while (x < size.width) {
            drawLine(Color.Black.copy(alpha = 0.18f), Offset(x, size.height), Offset(x + size.height, 0f), strokeWidth = 2.dp.toPx())
            x += step
        }
        val w = 2.5.dp.toPx()
        drawRoundRect(
            Color.White,
            topLeft = Offset(w / 2, w / 2),
            size = androidx.compose.ui.geometry.Size(size.width - w, size.height - w),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(size.width * 0.1f),
            style = androidx.compose.ui.graphics.drawscope.Stroke(w),
        )
    }
}

/** Spatele cărților din mâna unui adversar, ca evantai mic. */
@Composable
fun BacksRow(count: Int) {
    Box(Modifier.size(width = (15 + (count - 1).coerceAtLeast(0) * 6).dp, height = 22.dp)) {
        repeat(count) { i ->
            Box(
                Modifier
                    .padding(start = (i * 6).dp)
                    .size(15.dp, 22.dp)
                    .clip(RoundedCornerShape(3.dp))
            ) { CardBack(Modifier.fillMaxSize()) }
        }
    }
}

/** Intră cu o mică animație de scalare, o singură dată, când apare pe masă. */
@Composable
fun EnterPop(key: Any, content: @Composable () -> Unit) {
    val anim = remember(key) { Animatable(0.82f) }
    LaunchedEffect(key) { anim.animateTo(1f, tween(220)) }
    Box(Modifier.graphicsLayer {
        scaleX = anim.value
        scaleY = anim.value
        alpha = ((anim.value - 0.82f) / 0.18f).coerceIn(0.3f, 1f)
    }) { content() }
}
