import Charts
import SwiftUI

/// Cel mai mic preț din zona locuinței active, zi de zi, comparat cu contractul tău.
struct IstoricView: View {
    @Environment(Store.self) private var store
    @Environment(Locuinte.self) private var locuinte
    let locatie: Locatie?
    @State private var categorie: Categorie = .curent

    private struct Punct: Identifiable {
        let zi: Date
        let pret: Double
        var id: Date { zi }
    }

    private var puncte: [Punct] {
        guard let ist = store.istoric, let loc = locatie else { return [] }
        return ist.zile.keys.sorted().compactMap { k -> Punct? in
            guard let p = ist.zile[k], let d = Format.dinIso(k) else { return nil }
            if categorie == .curent {
                return p.curent[loc.zonaCurent].map { Punct(zi: d, pret: $0) }
            }
            guard let j = loc.judetAnre, let v = p.gaz[j] else { return nil }
            let t0 = loc.t0 ?? store.anre?.gaz?.judete[j]?.t0 ?? 0
            return Punct(zi: d, pret: (v + t0) * 1.21 / 1000)
        }
    }

    private var pretContract: Double? {
        guard let l = locuinte.activa, let c = l.contract(categorie) else { return nil }
        return c.pretKwh
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Categoria", selection: $categorie) {
                        Text("Curent").tag(Categorie.curent)
                        Text("Gaz").tag(Categorie.gaz)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if puncte.isEmpty {
                    ContentUnavailableView("Încă nu avem istoric pentru zona ta",
                                           systemImage: "chart.xyaxis.line",
                                           description: Text("Adaugă o locuință din fila Economii. Istoricul se completează în fiecare dimineață."))
                } else {
                    Section {
                        Chart {
                            ForEach(puncte) { p in
                                LineMark(x: .value("Ziua", p.zi, unit: .day), y: .value("lei/kWh", p.pret))
                                    .foregroundStyle(categorie.culoare)
                                    .interpolationMethod(.stepEnd)
                                PointMark(x: .value("Ziua", p.zi, unit: .day), y: .value("lei/kWh", p.pret))
                                    .foregroundStyle(categorie.culoare)
                                    .symbolSize(30)
                            }
                            if let c = pretContract {
                                RuleMark(y: .value("Contractul tău", c))
                                    .foregroundStyle(.secondary)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("Contractul tău: \(Format.lei(c, zecimale: 3))").font(.caption2).foregroundStyle(.secondary)
                                    }
                            }
                        }
                        .chartYScale(domain: domeniu)
                        .chartYAxis {
                            AxisMarks(position: .leading) { v in
                                AxisGridLine()
                                AxisValueLabel { Text(Format.lei(v.as(Double.self) ?? 0, zecimale: 2)) }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            }
                        }
                        .frame(height: 240)
                        .padding(.vertical, 8)
                    } header: {
                        Text("Cel mai mic preț final, lei/kWh")
                    } footer: {
                        Text(subsol)
                    }

                    Section("Rezumat") {
                        if let azi = puncte.last {
                            LabeledContent("Azi", value: "\(Format.lei(azi.pret, zecimale: 4)) lei/kWh")
                        }
                        if let min = puncte.min(by: { $0.pret < $1.pret }) {
                            LabeledContent("Cel mai mic din perioadă", value: "\(Format.lei(min.pret, zecimale: 4)) · \(min.zi.formatted(.dateTime.day().month(.abbreviated)))")
                        }
                        if let max = puncte.max(by: { $0.pret < $1.pret }) {
                            LabeledContent("Cel mai mare din perioadă", value: "\(Format.lei(max.pret, zecimale: 4)) · \(max.zi.formatted(.dateTime.day().month(.abbreviated)))")
                        }
                        if let c = pretContract, let azi = puncte.last, let l = locuinte.activa {
                            let dif = (c - azi.pret) * l.kwh(categorie) * 12
                            LabeledContent("Diferența față de contract", value: dif >= 0 ? "−\(Format.lei(dif, zecimale: 0)) lei/an posibil" : "contractul tău e mai ieftin")
                        }
                    }
                }
            }
            .navigationTitle("Istoric prețuri")
        }
    }

    private var domeniu: ClosedRange<Double> {
        let v = puncte.map(\.pret) + [pretContract].compactMap { $0 }
        let lo = (v.min() ?? 0) * 0.92, hi = (v.max() ?? 1) * 1.06
        return lo...max(hi, lo + 0.01)
    }

    private var subsol: String {
        let unde = categorie == .curent ? "zona \(locatie?.zonaCurent ?? "")" : "localitatea \(locatie.flatMap { $0.localitateGaz ?? $0.localitate }.map(Geografie.titlu) ?? "ta")"
        let start = puncte.first.map { $0.zi.formatted(.dateTime.day().month(.wide).year()) } ?? ""
        return "Cea mai ieftină ofertă ANRE activă în fiecare zi, pentru \(unde). Istoricul începe pe \(start) și se completează în fiecare dimineață."
    }
}
