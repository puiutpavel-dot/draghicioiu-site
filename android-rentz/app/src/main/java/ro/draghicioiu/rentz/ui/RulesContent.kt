package ro.draghicioiu.rentz.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ro.draghicioiu.rentz.model.Preset

/** Regulamentul cristalizat din Wikipedia, regulamentul PokerStars și casino.com.ro. */
@Composable
fun RulesContent() {
    Para("Regulile combină trei surse: Wikipedia, regulamentul publicat de PokerStars și cel de la casino.com.ro. Unde se contrazic, am ales o variantă, iar cealaltă e disponibilă în setări.")

    SectionTitle("Masa și pachetul")
    Bullet("3–6 jucători, fiecare primește 8 cărți. Pachetul se ia de la As în jos: 3 jucători 9–A (24 de cărți), 4 jucători 7–A (32), 5 jucători 5–A (40), 6 jucători 3–A (48).")
    Bullet("Pe rând, fiecare jucător alege un joc din cele 8, iar fiecare joc se alege o singură dată. O partidă are 8 × numărul de jucători runde (32 la 4 jucători).")
    Bullet("Cine alege jocul deschide prima levată. La Renț, tot el pune primul.")

    SectionTitle("Cum se joacă levatele")
    Bullet("Nu există atu. Ești obligat să răspunzi la culoarea cerută; dacă nu ai, pui orice carte.")
    Bullet("Levata o ia cea mai mare carte din culoarea cerută, iar cine o ia deschide următoarea.")
    Bullet("La Popa de roșu, Dame, Carouri și Zece de treflă, runda se oprește când au ieșit toate cărțile care contează.")

    SectionTitle("Cele 8 jocuri")
    PointsTable()
    Bullet("La Totale se adună doar jocurile negative. Dama de caro contează și ca damă, și ca caro (−45).")
    Bullet("Variantă: în locul Whist-ului se poate juca Totale Plus, adică Totale cu toate punctele pozitive.")

    SectionTitle("Renț")
    Bullet("Nu se joacă pe levate. Cărțile se etalează pe masă, câte o coloană pentru fiecare culoare, pornind de la cartea de mijloc: Q la 3 jucători, J la 4, 10 la 5, 9 la 6.")
    Bullet("Poți pune cartea de mijloc a unei culori neîncepute sau o carte imediat mai mică ori mai mare decât capetele unei coloane. Dacă nu poți pune nimic, spui pas. Dacă poți, ești obligat să pui.")
    Bullet("Cine pune un As mai pune o carte. Dacă înaintea ta s-a pus capătul mic (cea mai mică carte din pachet), stai o tură.")
    Bullet("Locul 1 îl ia cine termină primul cărțile, apoi locul 2 și așa mai departe.")

    SectionTitle("Refuzul Renț-ului")
    Bullet("Capetele sunt așii și cărțile cele mai mici din pachet. Când un adversar alege Renț, îl poți refuza dacă ai 3 capete; de la al doilea refuz încolo îți trebuie 4.")
    Bullet("Cine a ales Renț-ul nu îl poate refuza. La refuz se amestecă și se reîmpart cărțile, iar alegătorul poate alege orice joc rămas.")
    Bullet("Se poate refuza de cel mult (jucători − 1) ori la rând; după aceea Renț-ul se joacă obligatoriu.")

    SectionTitle("Pe nevăzute")
    Bullet("Alegătorul poate alege jocul fără să se uite la cărți. Punctajul rundei se dublează pentru toți.")
    Bullet("Un Renț ales pe nevăzute se poate refuza doar cu cel puțin 4 capete, dintre care 3 identice.")
    Bullet("Când îți mai rămâne un singur joc, nu mai poți juca pe nevăzute, fiindcă se știe deja ce urmează.")

    SectionTitle("Scorul final")
    Bullet("Se face clasamentul după totalul de puncte. Ca la Whist, locul 1 primește +10 × jucători, ultimul −10 × jucători, iar ceilalți proporțional cu distanța față de primul și ultimul.")
}

@Composable
private fun Para(text: String) {
    Text(text, color = T.fg.copy(alpha = 0.88f), fontSize = 15.sp, lineHeight = 21.sp)
}

@Composable
private fun Bullet(text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("•", color = T.red, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold)
        Text(text, color = T.fg.copy(alpha = 0.88f), fontSize = 15.sp, lineHeight = 21.sp)
    }
}

@Composable
private fun PointsTable() {
    val a = Preset.CLASIC
    val b = Preset.CASINO
    val rows = listOf(
        Triple("Popa de roșu (K♥)", "${a.popa}", "${b.popa}"),
        Triple("Dame (fiecare)", "${a.dama}", "${b.dama}"),
        Triple("Carouri (fiecare)", "${a.caro}", "${b.caro}"),
        Triple("Levate (fiecare)", "${a.levata}", "${b.levata}"),
        Triple("Totale", "suma", "suma"),
        Triple("Whist (pe levată)", "+${a.whist}", "+${b.whist}"),
        Triple("Zece de treflă", "+${a.zece}", "+${b.zece}"),
        Triple("Renț (locurile)", a.rentz.take(4).joinToString("/"), b.rentz.take(5).joinToString("/")),
    )
    Column(
        Modifier
            .fillMaxWidth()
            .background(T.panel, RoundedCornerShape(12.dp))
            .border(1.dp, T.line, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row {
            listOf("Joc" to 1.6f, "Clasic" to 1f, "Casino" to 1.2f).forEach { (t, w) ->
                Text(t.uppercase(), color = T.muted, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.weight(w))
            }
        }
        rows.forEach { (l, x, y) ->
            Row {
                Text(l, color = T.fg, fontSize = 13.sp, modifier = Modifier.weight(1.6f))
                Text(x, color = T.fg, fontSize = 13.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text(y, color = T.fg, fontSize = 13.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1.2f))
            }
        }
    }
}
