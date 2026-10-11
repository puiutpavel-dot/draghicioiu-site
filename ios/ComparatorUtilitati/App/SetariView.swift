import SwiftUI

struct SetariView: View {
    @Binding var kwhCurent: Double
    @Binding var kwhGaz: Double
    let actualizat: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $kwhCurent, in: 0...2000, step: 10) {
                        LabeledContent("Curent", value: "\(Int(kwhCurent)) kWh")
                    }
                    Stepper(value: $kwhGaz, in: 0...5000, step: 50) {
                        LabeledContent("Gaz", value: "\(Int(kwhGaz)) kWh")
                    }
                    Button("Valori tipice (175 / 600 kWh)") {
                        kwhCurent = 175
                        kwhGaz = 600
                    }
                } header: {
                    Text("Consum lunar")
                } footer: {
                    Text("Găsești consumul pe factură. O familie consumă în medie 150–200 kWh de curent pe lună și 600 kWh de gaz (mai mult iarna, cu centrală).")
                }

                Section("Despre date") {
                    if let actualizat {
                        LabeledContent("Prețuri verificate", value: Format.data(actualizat, cuAn: true))
                    }
                    Link(destination: URL(string: "https://posf.ro/comparator")!) {
                        Label("Comparatorul oficial ANRE", systemImage: "building.columns")
                    }
                    Link(destination: Store.site) {
                        Label("Varianta web pe draghicioiu.ro", systemImage: "safari")
                    }
                }

                Section {
                    Text("Aplicația nu colectează date personale. Codul poștal și consumul rămân doar pe telefonul tău.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Consum și informații")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gata") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
