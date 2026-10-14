import SwiftUI

/// Contractul actual la curent sau gaz: ales din lista ANRE sau scris de pe factură.
struct ContractView: View {
    let categorie: Categorie
    let oferte: [Rand]
    let kwh: Double
    let initial: ContractActual?
    let salveaza: (ContractActual?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var furnizor = ""
    @State private var pretText = ""
    @State private var fixText = ""
    @State private var cautare = ""

    private var pret: Double? {
        guard let p = Format.numar(pretText), p >= 0.05, p <= 5 else { return nil }
        return p
    }

    private var filtrate: [Rand] {
        let q = cautare.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return oferte }
        return oferte.filter { "\($0.furnizor) \($0.oferta)".lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Furnizorul tău (ex. Enel, E.ON)", text: $furnizor)
                        .textInputAutocapitalization(.words)
                    TextField("Preț final pe kWh, ex. 1,45", text: $pretText)
                        .keyboardType(.decimalPad)
                    TextField("Abonament fix pe lună, dacă ai (lei)", text: $fixText)
                        .keyboardType(.decimalPad)
                    if let pret {
                        LabeledContent("Cost estimat", value: "\(Format.lei(pret * kwh + (Format.numar(fixText) ?? 0), zecimale: 0)) lei/lună")
                    }
                    Button("Salvează") {
                        guard let pret else { return }
                        salveaza(ContractActual(furnizor: furnizor.isEmpty ? "Furnizorul actual" : furnizor,
                                                oferta: "preț de pe factură", cod: nil,
                                                pretKwh: pret, fixLuna: max(0, Format.numar(fixText) ?? 0)))
                        dismiss()
                    }
                    .disabled(pret == nil)
                } header: {
                    Text("Prețul de pe factură")
                } footer: {
                    Text("Prețul final pe kWh: împarte totalul de plată pentru \(categorie == .gaz ? "gaz" : "energie") (cu TVA, fără restanțe) la numărul de kWh facturați. \(categorie == .gaz ? "La gaz, factura arată consumul în kWh, convertit din metri cubi." : "")")
                }

                Section {
                    ForEach(filtrate) { r in
                        Button {
                            salveaza(ContractActual(furnizor: r.furnizor, oferta: r.oferta, cod: r.cod,
                                                    pretKwh: r.pretKwh ?? 0, fixLuna: r.fixLuna))
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.furnizor).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(r.oferta).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                Text("\(Format.lei(r.pretKwh ?? 0, zecimale: 4))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                if initial?.cod != nil, initial?.cod == r.cod {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Sau alege oferta ta din lista ANRE")
                } footer: {
                    Text("Lista conține ofertele active acum în zona ta. Dacă ai un contract mai vechi, scrie prețul de pe factură.")
                }

                if initial != nil {
                    Section {
                        Button("Șterge contractul", role: .destructive) {
                            salveaza(nil)
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $cautare, prompt: "Caută furnizorul")
            .navigationTitle(categorie == .gaz ? "Contractul la gaz" : "Contractul la curent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Renunță") { dismiss() }
                }
            }
            .onAppear {
                if let c = initial, c.cod == nil {
                    furnizor = c.furnizor == "Furnizorul actual" ? "" : c.furnizor
                    pretText = Format.lei(c.pretKwh, zecimale: 4)
                    if c.fixLuna > 0 { fixText = Format.lei(c.fixLuna) }
                }
            }
        }
    }
}
