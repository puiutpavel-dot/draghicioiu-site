import SwiftUI

/// Regulamentul cristalizat din Wikipedia, regulamentul PokerStars și casino.com.ro.
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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
                .padding(16)
            }
            .background(T.bg)
            .navigationTitle("Regulament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Gata") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct Para: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 15)).foregroundStyle(T.fg.opacity(0.88)).lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(T.red).fontWeight(.heavy)
            Text(text).font(.system(size: 15)).foregroundStyle(T.fg.opacity(0.88)).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PointsTable: View {
    var body: some View {
        let a = Preset.clasic, b = Preset.casino
        let rows: [(String, String, String)] = [
            ("Popa de roșu (K♥)", "\(a.popa)", "\(b.popa)"),
            ("Dame (fiecare)", "\(a.dama)", "\(b.dama)"),
            ("Carouri (fiecare)", "\(a.caro)", "\(b.caro)"),
            ("Levate (fiecare)", "\(a.levata)", "\(b.levata)"),
            ("Totale", "suma", "suma"),
            ("Whist (pe levată)", "+\(a.whist)", "+\(b.whist)"),
            ("Zece de treflă", "+\(a.zece)", "+\(b.zece)"),
            ("Renț (locurile)", a.rentz.prefix(4).map(String.init).joined(separator: "/"), b.rentz.prefix(5).map(String.init).joined(separator: "/"))
        ]
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Joc"); Text("Clasic"); Text("Casino")
            }
            .font(.system(size: 10, weight: .heavy)).textCase(.uppercase).foregroundStyle(T.muted)
            ForEach(rows.indices, id: \.self) { i in
                GridRow {
                    Text(rows[i].0).foregroundStyle(T.fg)
                    Text(rows[i].1).foregroundStyle(T.fg).fontWeight(.bold)
                    Text(rows[i].2).foregroundStyle(T.fg).fontWeight(.bold)
                }
                .font(.system(size: 13).monospacedDigit())
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(T.panel))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.line, lineWidth: 1))
    }
}
