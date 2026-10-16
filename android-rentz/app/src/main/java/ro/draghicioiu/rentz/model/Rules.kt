package ro.draghicioiu.rentz.model

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

enum class GameKind(val title: String, val short: String, val positive: Boolean) {
    POPA("Popa de roșu", "Popa ♥", false),
    DAME("Dame", "Dame", false),
    CAROURI("Carouri", "Carouri", false),
    LEVATE("Levate", "Levate", false),
    TOTALE("Totale", "Totale", false),
    WHIST("Whist", "Whist", true),
    TOTPLUS("Totale Plus", "Tot. +", true),
    ZECE("Zece de treflă", "10 ♣", true),
    RENTZ("Renț", "Renț", true);

    fun desc(p: Preset): String = when (this) {
        POPA -> "${p.popa} cine ia K♥"
        DAME -> "${p.dama} / damă"
        CAROURI -> "${p.caro} / caro"
        LEVATE -> "${p.levata} / levată"
        TOTALE -> "popa + dame + carouri + levate"
        WHIST -> "+${p.whist} / levată"
        TOTPLUS -> "totale, cu semn plus"
        ZECE -> "+${p.zece} cine ia 10♣"
        RENTZ -> "locuri: " + p.rentz.take(4).joinToString(" / ")
    }
}

data class Preset(
    val key: String,
    val label: String,
    val popa: Int,
    val zece: Int,
    val dama: Int,
    val caro: Int,
    val levata: Int,
    val whist: Int,
    val rentz: List<Int>,
) {
    companion object {
        /** Wikipedia (ro): Popa −300, levata −20, Whist +20. */
        val CLASIC = Preset("clasic", "Clasic", -300, 100, -25, -20, -20, 20, listOf(300, 200, 100, 0, 0, 0))
        /** Regulamentul PokerStars / casino.com.ro: Popa −100, levata −10. */
        val CASINO = Preset("casino", "Casino", -100, 100, -25, -20, -10, 10, listOf(300, 200, 150, 100, 50, 0))

        fun named(key: String) = if (key == "casino") CASINO else CLASIC
    }
}

data class Settings(
    val players: Int = 4,
    val preset: String = "clasic",
    val eighth: String = "whist",
    val fast: Boolean = false,
    val name: String = "Tu",
) {
    fun toJson(): JSONObject = JSONObject()
        .put("players", players).put("preset", preset).put("eighth", eighth)
        .put("fast", fast).put("name", name)

    companion object {
        fun fromJson(o: JSONObject) = Settings(
            o.optInt("players", 4), o.optString("preset", "clasic"), o.optString("eighth", "whist"),
            o.optBoolean("fast", false), o.optString("name", "Tu"),
        )
    }
}

data class RoundRecord(
    val round: Int,
    val chooser: Int,
    val game: GameKind,
    val blind: Boolean,
    val pts: List<Int>,
    val det: List<String>,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("round", round).put("chooser", chooser).put("game", game.name).put("blind", blind)
        .put("pts", JSONArray(pts)).put("det", JSONArray(det))

    companion object {
        fun fromJson(o: JSONObject) = RoundRecord(
            o.getInt("round"), o.getInt("chooser"), GameKind.valueOf(o.getString("game")), o.getBoolean("blind"),
            o.getJSONArray("pts").let { a -> List(a.length()) { a.getInt(it) } },
            o.getJSONArray("det").let { a -> List(a.length()) { a.getString(it) } },
        )
    }
}

/** Partida salvată după fiecare rundă terminată, ca să poată fi continuată. */
data class SavedGame(
    val settings: Settings,
    val names: List<String>,
    val scores: List<Int>,
    val used: List<Map<GameKind, Int>>,
    val round: Int,
    val history: List<RoundRecord>,
    val refusals: List<Int>,
) {
    fun toJson(): String = JSONObject()
        .put("settings", settings.toJson())
        .put("names", JSONArray(names))
        .put("scores", JSONArray(scores))
        .put("used", JSONArray(used.map { m -> JSONObject().apply { m.forEach { (k, v) -> put(k.name, v) } } }))
        .put("round", round)
        .put("history", JSONArray(history.map { it.toJson() }))
        .put("refusals", JSONArray(refusals))
        .toString()

    companion object {
        fun fromJson(s: String): SavedGame? = try {
            val o = JSONObject(s)
            val usedArr = o.getJSONArray("used")
            SavedGame(
                Settings.fromJson(o.getJSONObject("settings")),
                o.getJSONArray("names").let { a -> List(a.length()) { a.getString(it) } },
                o.getJSONArray("scores").let { a -> List(a.length()) { a.getInt(it) } },
                List(usedArr.length()) { i ->
                    val m = usedArr.getJSONObject(i)
                    m.keys().asSequence().mapNotNull { k ->
                        runCatching { GameKind.valueOf(k) to m.getInt(k) }.getOrNull()
                    }.toMap()
                },
                o.getInt("round"),
                o.getJSONArray("history").let { a -> List(a.length()) { RoundRecord.fromJson(a.getJSONObject(it)) } },
                o.getJSONArray("refusals").let { a -> List(a.length()) { a.getInt(it) } },
            )
        } catch (e: Exception) {
            null
        }
    }
}

/** Setările și partida în curs, în SharedPreferences (rămân doar pe telefon). */
class SaveStore(context: Context) {
    private val prefs = context.getSharedPreferences("rentz", Context.MODE_PRIVATE)

    fun loadSettings(): Settings =
        prefs.getString("settings", null)?.let { runCatching { Settings.fromJson(JSONObject(it)) }.getOrNull() }
            ?: Settings()

    fun saveSettings(s: Settings) = prefs.edit().putString("settings", s.toJson().toString()).apply()

    fun loadGame(): SavedGame? = prefs.getString("partida", null)?.let { SavedGame.fromJson(it) }

    fun saveGame(g: SavedGame) = prefs.edit().putString("partida", g.toJson()).apply()

    fun clearGame() = prefs.edit().remove("partida").apply()
}
