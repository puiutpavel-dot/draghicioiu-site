package ro.draghicioiu.rentz

import android.graphics.Color as AndroidColor
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import kotlinx.coroutines.CoroutineScope
import ro.draghicioiu.rentz.model.GameKind
import ro.draghicioiu.rentz.model.Phase
import ro.draghicioiu.rentz.model.RentzGame
import ro.draghicioiu.rentz.model.SaveStore
import ro.draghicioiu.rentz.model.Settings
import ro.draghicioiu.rentz.ui.GameScreen
import ro.draghicioiu.rentz.ui.SetupScreen
import ro.draghicioiu.rentz.ui.T

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(AndroidColor.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(AndroidColor.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        val store = SaveStore(applicationContext)
        // Capturile Google Play pornesc aplicația cu: --ez demo true --es scena <joc|rentz|alege|scor|final|start>
        val demoScene = if (intent?.getBooleanExtra("demo", false) == true) intent.getStringExtra("scena") ?: "joc" else null
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(primary = T.red, background = T.bg, surface = T.panel)) {
                Box(Modifier.fillMaxSize().background(T.bg).safeDrawingPadding()) {
                    RentzRoot(store, demoScene)
                }
            }
        }
    }
}

@Composable
private fun RentzRoot(store: SaveStore, demoScene: String?) {
    val scope = rememberCoroutineScope()
    var game by remember { mutableStateOf(demoScene?.let { Demo.make(it, scope) }) }
    var initialSheet by remember { mutableStateOf(demoScene) }
    Crossfade(game, label = "ecran") { g ->
        if (g != null) {
            GameScreen(g, initialSheet) {
                initialSheet = null
                game = null
            }
        } else {
            SetupScreen(store) { settings, saved ->
                val ng = RentzGame(settings, scope, store, saved)
                ng.start()
                game = ng
            }
        }
    }
}

/** Partide demonstrative, jucate automat până la scena cerută (pentru capturi). */
object Demo {
    fun make(scene: String, scope: CoroutineScope): RentzGame? {
        if (scene == "start") return null
        val g = RentzGame(Settings(players = 4, preset = "clasic", eighth = "whist", fast = false, name = "Daniel"), scope, null)
        when (scene) {
            "alege" -> {
                g.runSync { it.round >= 4 && it.chooser == 0 && it.phase == Phase.AI_CHOOSING }
                g.blind = false
                g.phase = Phase.CHOOSE
                g.log = "E rândul tău să alegi jocul."
            }
            "rentz" -> g.runSync {
                it.game == GameKind.RENTZ && it.phase == Phase.RENTZ && it.turn == 0 &&
                    it.placedCount >= 9 && it.hand(0).size >= 3 && it.validRentz(0).isNotEmpty()
            }
            "scor" -> g.runSync { it.round >= 13 && it.phase == Phase.ROUND_END }
            "final" -> g.runSync { it.phase == Phase.GAME_OVER }
            else -> g.runSync {
                it.round >= 5 && it.phase == Phase.TRICK && it.turn == 0 && it.trick.size >= 2 &&
                    it.game != GameKind.RENTZ && it.hand(0).size >= 5
            }
        }
        return g
    }
}
