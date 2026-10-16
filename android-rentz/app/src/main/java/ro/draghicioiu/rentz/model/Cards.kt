package ro.draghicioiu.rentz.model

enum class Suit(val symbol: String, val isRed: Boolean, val label: String) {
    H("♥", true, "inimă roșie"),
    D("♦", true, "caro"),
    C("♣", false, "treflă"),
    S("♠", false, "pică");

    companion object {
        /** Ordinea în mână: culorile alternează roșu / negru. */
        val handOrder = listOf(H, S, D, C)
        /** Ordinea rândurilor pe masă la Renț. */
        val boardOrder = listOf(H, S, D, C)
    }
}

data class Card(val r: Int, val s: Suit) {
    val id: String get() = "$r${s.name}"
    val label: String get() = rankLabel(r)
    val name: String get() = label + s.symbol
    val isFace: Boolean get() = r > 10

    companion object {
        fun rankLabel(r: Int): String = when (r) {
            11 -> "J"
            12 -> "Q"
            13 -> "K"
            14 -> "A"
            else -> r.toString()
        }

        val handComparator: Comparator<Card> =
            compareBy<Card>({ Suit.handOrder.indexOf(it.s) }, { it.r })
    }
}

/** Coloana unei culori la Renț: de la cea mai mică la cea mai mare carte pusă. */
data class Span(val lo: Int, val hi: Int)

/** Alege elementul cu scorul cel mai mare (scorul se calculează o singură dată pe element). */
fun <T> bestOf(items: List<T>, score: (T) -> Double): T =
    items.map { it to score(it) }.maxBy { it.second }.first

fun <T> worstOf(items: List<T>, score: (T) -> Double): T =
    items.map { it to score(it) }.minBy { it.second }.first
