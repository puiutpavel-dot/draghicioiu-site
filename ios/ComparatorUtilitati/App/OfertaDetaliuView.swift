import Charts
import SwiftUI

/// Detaliul unei oferte: din ce e format prețul, costul pe fiecare lună, comparația cu contractul tău
/// și pașii pentru schimbarea furnizorului.
struct OfertaDetaliuView: View {
    let rand: Rand
    let kwh: Double
    let costActual: Double?
    let celMaiIeftin: Rand?

    private var luni: [Double] {
        Comparator.costPeLuni(pretKwh: rand.pretKwh ?? 0, fixLuna: rand.fixLuna, kwhMediu: kwh, categorie: rand.categorie)
    }

    /// Componentele cu TVA, plus TVA-ul ca felie separată.
    private var felii: [Componenta] {
        guard !rand.componente.isEmpty else { return [] }
        let tva = rand.componente.map(\.valoare).reduce(0, +) * rand.tva / 100
        return rand.componente + [Componenta(nume: "TVA \(Int(rand.tva))%", valoare: tva)]
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        IconCategorie(categorie: rand.categorie)
                        Text(rand.furnizor).font(.title3.bold())
                    }
                    Text(rand.oferta).font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Format.lei(rand.lunar, zecimale: 0)) lei").font(.system(size: 32, weight: .heavy, design: .rounded))
                        Text("pe lună în medie").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    Text("\(Format.lei(rand.anual, zecimale: 0)) lei pe an pentru \(Int(kwh)) kWh/lună · \(Format.lei(rand.pretKwh ?? 0, zecimale: 4)) lei/kWh")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let costActual {
                        let dif = (costActual - rand.lunar) * 12
                        Label(dif >= 1 ? "Economisești \(Format.lei(dif, zecimale: 0)) lei pe an față de contractul tău"
                                       : dif <= -1 ? "Cu \(Format.lei(-dif, zecimale: 0)) lei pe an mai scump decât contractul tău"
                                                   : "Cam cât plătești acum",
                              systemImage: dif >= 1 ? "arrow.down.circle.fill" : "equal.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(dif >= 1 ? Color.castig : Color.secondary)
                            .padding(.top, 4)
                    } else if let best = celMaiIeftin, best.id != rand.id {
                        Text("Cu \(Format.lei((rand.lunar - best.lunar) * 12, zecimale: 0)) lei pe an mai scump decât cea mai ieftină ofertă (\(best.furnizor)).")
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }

            if !felii.isEmpty {
                Section {
                    Chart(felii) { f in
                        SectorMark(angle: .value("lei/kWh", f.valoare), innerRadius: .ratio(0.62), angularInset: 1.5)
                            .foregroundStyle(by: .value("Componentă", f.nume))
                            .cornerRadius(3)
                    }
                    .chartLegend(.hidden)
                    .chartForegroundStyleScale(domain: felii.map(\.nume), range: felii.indices.map { culoare($0) })
                    .frame(height: 190)
                    .padding(.vertical, 6)
                    .accessibilityLabel("Structura prețului")

                    let total = felii.map(\.valoare).reduce(0, +)
                    ForEach(Array(felii.enumerated()), id: \.element.id) { i, f in
                        HStack {
                            Circle().fill(culoare(i)).frame(width: 10, height: 10)
                            Text(f.nume).font(.subheadline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(Format.lei(f.valoare, zecimale: 4)) lei/kWh").font(.subheadline.monospacedDigit())
                                Text("\(Int((f.valoare / max(total, 0.0001) * 100).rounded()))%").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Din ce e format prețul")
                } footer: {
                    Text(rand.categorie == .gaz
                         ? "Doar prețul gazului diferă între furnizori. Transportul și distribuția sunt tarife reglementate de ANRE, aceleași la orice furnizor din localitatea ta."
                         : "Doar prețul energiei diferă între furnizori. Distribuția, transportul și taxele sunt reglementate de ANRE și le plătești la fel, oricare ar fi furnizorul.")
                }
            }

            Section {
                Chart(Array(luni.enumerated()), id: \.offset) { i, v in
                    BarMark(x: .value("Luna", Comparator.luni[i]), y: .value("lei", v))
                        .foregroundStyle(rand.categorie.culoare.gradient)
                        .cornerRadius(3)
                }
                .chartXScale(domain: Comparator.luni)
                .frame(height: 170)
                .padding(.vertical, 6)
                LabeledContent("Cea mai scumpă lună", value: "\(Format.lei(luni.max() ?? 0, zecimale: 0)) lei")
                LabeledContent("Cea mai ieftină lună", value: "\(Format.lei(luni.min() ?? 0, zecimale: 0)) lei")
            } header: {
                Text("Factura estimată, lună de lună")
            } footer: {
                Text(rand.categorie == .gaz
                     ? "Consumul de gaz e repartizat pe luni după profilul obișnuit al unei locuințe cu centrală: aproape jumătate din consumul anual cade în decembrie–februarie."
                     : "Consumul de curent variază puțin de la o lună la alta; iarna e ceva mai mare.")
            }

            Section("Condiții") {
                if let t = rand.tip, !t.isEmpty { LabeledContent("Tip preț", value: t) }
                if let d = rand.durata, !d.isEmpty { LabeledContent("Durata contractului", value: d) }
                if let e = rand.expira { LabeledContent("Oferta e valabilă până pe", value: Format.data(e, cuAn: true)) }
                if let g = rand.garantii, !g.isEmpty { LabeledContent("Garanții", value: g) }
                LabeledContent("Componentă fixă", value: rand.fixLuna > 0 ? "\(Format.lei(rand.fixLuna)) lei/lună" : "nu are")
                if rand.serviciuUniversal { LabeledContent("Tip ofertă", value: "Serviciu universal") }
                if let pdf = rand.pdf {
                    Link(destination: pdf) { Label("Oferta-tip oficială (PDF)", systemImage: "doc.richtext") }
                }
                if let link = rand.link {
                    Link(destination: link) { Label("Pagina ofertei la furnizor", systemImage: "safari") }
                }
            }

            Section {
                Pas(numar: 1, text: "Pregătește ultima factură: de acolo îți trebuie codul locului de consum (POD) și indexul contorului.")
                Pas(numar: 2, text: "Cere contractul de la noul furnizor, online sau la un punct de lucru. Ai nevoie de actul de identitate și de dovada că locuiești la adresă (act de proprietate sau contract de închiriere).")
                Pas(numar: 3, text: "Noul furnizor se ocupă de schimbare, inclusiv de notificarea furnizorului vechi. Schimbarea furnizorului e gratuită, iar curentul sau gazul nu se întrerup.")
                Pas(numar: 4, text: "Achită ultima factură de la furnizorul vechi. Dacă ai un contract cu preț fix și perioadă minimă, verifică dacă rezilierea anticipată are penalități.")
            } header: {
                Text("Cum schimbi furnizorul")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(rand.categorie.scurt)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func culoare(_ i: Int) -> Color {
        let paleta: [Color] = [rand.categorie.culoare, .blue, .teal, .purple, .gray, .pink]
        return paleta[i % paleta.count]
    }

    private struct Pas: View {
        let numar: Int
        let text: String
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Text("\(numar)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor, in: Circle())
                Text(text).font(.subheadline)
            }
            .padding(.vertical, 2)
        }
    }
}
