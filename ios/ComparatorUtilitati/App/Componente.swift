import SwiftUI

/// Rețelele de curent și gaz de la adresa locuinței active.
struct LocatieCard: View {
    let locatie: Locatie
    let alegeLocalitate: (Int) -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(titluLoc).font(.headline)
                } icon: {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.tint)
                }
                Retea(categorie: .curent, eticheta: "Rețeaua de curent", numeOperator: locatie.operatorCurent,
                      detaliu: "zona de distribuție \(locatie.zonaCurent)")
                if let op = locatie.operatorGaz, let t0 = locatie.t0 {
                    Retea(categorie: .gaz, eticheta: "Rețeaua de gaz", numeOperator: op,
                          detaliu: "tarif de distribuție \(Format.lei(t0 / 1000 * 1.21, zecimale: 4)) lei/kWh cu TVA")
                } else {
                    Retea(categorie: .gaz, eticheta: "Rețeaua de gaz", numeOperator: "Nu apare în lista ANRE",
                          detaliu: "\(locatie.localitate.map(Geografie.titlu) ?? "Localitatea") nu figurează cu rețea de gaz. Dacă ai gaz, alege localitatea.")
                }
                if !locatie.esteBucuresti, !locatie.localitatiGaz.isEmpty {
                    Menu {
                        ForEach(locatie.localitatiGaz) { l in
                            Button(numeLoc(l)) { alegeLocalitate(l.siruta) }
                        }
                    } label: {
                        Label(locatie.t0 == nil ? "Alege localitatea pentru gaz" : "Altă localitate pentru gaz", systemImage: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
        }
    }

    private var titluLoc: String {
        let l = locatie.localitate.map(Geografie.titlu)
        return "\(locatie.codPostal) · " + (l.map { $0 == "București" ? locatie.judet : "\($0), \(locatie.judet)" } ?? locatie.judet)
    }

    private func numeLoc(_ l: LocalitateGaz) -> String {
        let n = Geografie.titlu(l.nume)
        return l.principala != l.nume && !l.principala.isEmpty ? "\(n) (\(Geografie.titlu(l.principala)))" : n
    }

    private struct Retea: View {
        let categorie: Categorie
        let eticheta: String
        let numeOperator: String
        let detaliu: String
        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                IconCategorie(categorie: categorie, marime: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(eticheta).font(.caption).foregroundStyle(.secondary)
                    Text(numeOperator).font(.subheadline.weight(.semibold))
                    Text(detaliu).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct IconCategorie: View {
    let categorie: Categorie
    var marime: CGFloat = 30
    var body: some View {
        Image(systemName: categorie.simbol)
            .font(marime > 28 ? .body : .footnote)
            .foregroundStyle(.white)
            .frame(width: marime, height: marime)
            .background(categorie.culoare, in: RoundedRectangle(cornerRadius: marime * 0.27, style: .continuous))
    }
}

/// Lista de oferte a unei categorii, cu primele 8 și butonul „Arată toate”.
struct SectiuneView: View {
    let categorie: Categorie
    let subtitlu: String
    let randuri: [Rand]
    /// Energie: fiecare rând deschide detaliul ofertei. Telecom: deschide site-ul operatorului.
    var detaliu = false
    /// Costul lunar al contractului actual, pentru comparația de pe fiecare rând.
    var costActual: Double? = nil
    @State private var toate = false
    private let pas = 8

    var body: some View {
        let vizibile = toate ? randuri : Array(randuri.prefix(pas))
        VStack(alignment: .leading, spacing: 10) {
            Label(categorie.titlu, systemImage: categorie.simbol)
                .font(.title3.bold())
                .labelStyle(TitluSectiune(culoare: categorie.culoare))
                .padding(.top, 14)
            Text(subtitlu).font(.footnote).foregroundStyle(.secondary)

            if vizibile.isEmpty {
                Card {
                    Text("Nu avem oferte active pentru zona ta acum. Verifică în comparatorul ANRE (posf.ro).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vizibile.enumerated()), id: \.element.id) { i, r in
                        if detaliu {
                            NavigationLink(value: r) {
                                RandView(pozitie: i + 1, rand: r, costActual: costActual, cuSageata: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            LinkRand(pozitie: i + 1, rand: r)
                        }
                        if i < vizibile.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if randuri.count > pas {
                    Button(toate ? "Arată mai puține" : "Arată toate cele \(randuri.count) oferte") {
                        withAnimation { toate.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private struct LinkRand: View {
        let pozitie: Int
        let rand: Rand
        @Environment(\.openURL) private var openURL
        var body: some View {
            Button {
                if let link = rand.link { openURL(link) }
            } label: {
                RandView(pozitie: pozitie, rand: rand, costActual: nil, cuSageata: false)
            }
            .buttonStyle(.plain)
            .accessibilityHint(rand.link == nil ? "" : "Deschide site-ul operatorului")
        }
    }
}

struct RandView: View {
    let pozitie: Int
    let rand: Rand
    let costActual: Double?
    let cuSageata: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(pozitie)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(pozitie == 1 ? Color.white : Color.secondary)
                .frame(width: 28, height: 28)
                .background(pozitie == 1 ? Color.castig : Color(.tertiarySystemFill), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rand.furnizor).font(.headline)
                        Text(rand.oferta).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Format.lei(rand.lunar, zecimale: rand.pretKwh == nil ? 2 : 0)) lei")
                            .font(.headline.monospacedDigit())
                        Text(rand.pretKwh == nil ? "pe lună" : "estimat / lună").font(.caption2).foregroundStyle(.secondary)
                    }
                    if cuSageata {
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                if pozitie == 1 || rand.expira != nil || rand.serviciuUniversal {
                    HStack(spacing: 6) {
                        if pozitie == 1 { Eticheta(text: "Cel mai ieftin") }
                        if rand.serviciuUniversal { Eticheta(text: "Serviciu universal", culoare: .accentColor, plin: false) }
                        if let e = rand.expira { Eticheta(text: "până pe \(Format.data(e))", culoare: .orange, plin: false) }
                    }
                }
                if let p = rand.pretUnitar {
                    Text(p).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if let costActual {
                    let dif = (costActual - rand.lunar) * 12
                    if abs(dif) >= 1 {
                        Text(dif > 0 ? "−\(Format.lei(dif, zecimale: 0)) lei/an față de contractul tău"
                                     : "+\(Format.lei(-dif, zecimale: 0)) lei/an față de contractul tău")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dif > 0 ? Color.castig : Color.secondary)
                    }
                }
                if let d = rand.dupaPromo {
                    Text(d).font(.caption).foregroundStyle(.orange)
                }
                if let d = rand.detalii, !d.isEmpty {
                    Text(d).font(.caption).foregroundStyle(.secondary)
                }
                if let c = rand.contract {
                    Label(c, systemImage: "doc.text").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

struct NotaSurse: View {
    let actualizatAnre: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let actualizatAnre {
                Text("Prețuri ANRE la zi: \(Format.data(String(actualizatAnre.prefix(10)), cuAn: true)).").bold()
            }
            Text("Toate ofertele pentru clienți casnici din comparatorul oficial ANRE (posf.ro), preluate în fiecare dimineață. Prețuri finale pe kWh, cu energie, distribuție, transport, taxe și TVA; estimarea include și componenta fixă. La gaze se folosește tariful de distribuție al localității tale; până la 31 martie 2027 se facturează cel mai mic dintre prețul din contract și cel stabilit prin OUG 12/2026.")
            Text("Coduri poștale: GeoNames (CC BY 4.0). Aplicația nu este afiliată ANRE sau vreunui furnizor; verifică oferta la furnizor înainte de a semna.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 20)
    }
}

struct TitluSectiune: LabelStyle {
    let culoare: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(culoare)
            configuration.title
        }
    }
}
