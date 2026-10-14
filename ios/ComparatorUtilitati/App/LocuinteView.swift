import SwiftUI

/// Locuințele salvate, alertele de preț și informațiile despre date.
struct LocuinteView: View {
    @Environment(Store.self) private var store
    @Environment(Locuinte.self) private var locuinte
    @State private var adauga = false
    @State private var editata: Locuinta?
    @State private var alerte = Alerte.active
    @State private var refuzat = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(locuinte.lista) { l in
                        Button {
                            locuinte.selecteaza(l.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: l.id == locuinte.activa?.id ? "house.fill" : "house")
                                    .foregroundStyle(.tint)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.nume).font(.headline).foregroundStyle(.primary)
                                    Text([l.codPostal, l.localitate.map(Geografie.titlu)].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("\(Int(l.kwhCurent)) kWh curent · \(Int(l.kwhGaz)) kWh gaz pe lună")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if l.id == locuinte.activa?.id {
                                    Text("activă").font(.caption.weight(.semibold)).foregroundStyle(.tint)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Șterge", role: .destructive) { locuinte.sterge(l.id) }
                            Button("Editează") { editata = l }.tint(.accentColor)
                        }
                        .contextMenu {
                            Button { editata = l } label: { Label("Editează", systemImage: "pencil") }
                            Button(role: .destructive) { locuinte.sterge(l.id) } label: { Label("Șterge", systemImage: "trash") }
                        }
                    }
                    Button { adauga = true } label: { Label("Adaugă locuință", systemImage: "plus.circle.fill") }
                } header: {
                    Text("Locuințele tale")
                } footer: {
                    Text("Fiecare locuință are adresa, consumul și contractele ei. Atinge una ca s-o vezi în Economii și Istoric; glisează pentru editare.")
                }

                Section {
                    Toggle(isOn: $alerte) {
                        Label("Alertă la ofertă mai ieftină", systemImage: "bell.badge")
                    }
                    .onChange(of: alerte) { _, pornit in
                        Task {
                            if pornit, !(await Alerte.cerePermisiune()) {
                                alerte = false
                                refuzat = true
                                return
                            }
                            Alerte.active = alerte
                            Alerte.programeaza()
                        }
                    }
                } header: {
                    Text("Alerte de preț")
                } footer: {
                    Text("Aplicația verifică ofertele ANRE în fundal, cam o dată pe zi, și te anunță când o ofertă nouă te costă cu cel puțin \(Int(Alerte.pragLeiPeAn)) lei pe an mai puțin decât contractul salvat la o locuință. Calculul se face pe telefon.")
                }

                Section("Despre date") {
                    if let zi = store.anre?.zi {
                        LabeledContent("Prețuri ANRE", value: Format.data(zi, cuAn: true))
                    }
                    if let t = store.oferte?.actualizat {
                        LabeledContent("Prețuri telecom", value: Format.data(t, cuAn: true))
                    }
                    Link(destination: URL(string: "https://posf.ro/comparator")!) {
                        Label("Comparatorul oficial ANRE", systemImage: "building.columns")
                    }
                    Link(destination: Store.site) {
                        Label("Varianta web pe draghicioiu.ro", systemImage: "safari")
                    }
                    Link(destination: URL(string: "https://draghicioiu.ro/aplicatii/utilitati/")!) {
                        Label("Suport și întrebări", systemImage: "questionmark.circle")
                    }
                }

                Section {
                    Text("Aplicația nu are cont, reclame sau urmărire. Locuințele, consumul și contractele rămân doar pe telefonul tău.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Locuințe")
            .sheet(isPresented: $adauga) { LocuintaEditView(initial: nil) }
            .sheet(item: $editata) { l in LocuintaEditView(initial: l) }
            .alert("Notificările sunt oprite", isPresented: $refuzat) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Pornește notificările pentru Utilități din Configurări ca să primești alertele de preț.")
            }
        }
    }
}

/// Adaugă sau editează o locuință: nume, cod poștal, consum lunar.
struct LocuintaEditView: View {
    let initial: Locuinta?
    @Environment(Locuinte.self) private var locuinte
    @Environment(\.dismiss) private var dismiss
    @State private var nume = ""
    @State private var cod = ""
    @State private var kwhCurent = 175.0
    @State private var kwhGaz = 600.0
    @State private var eroare: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Locuința") {
                    TextField("Nume (ex. Acasă, La părinți)", text: $nume)
                    TextField("Cod poștal din România", text: $cod)
                        .keyboardType(.numberPad)
                        .onChange(of: cod) { _, nou in
                            let curat = String(nou.filter(\.isNumber).prefix(6))
                            if curat != nou { cod = curat }
                        }
                    if let eroare { Text(eroare).font(.footnote).foregroundStyle(.red) }
                }
                Section {
                    Stepper(value: $kwhCurent, in: 0...2000, step: 10) {
                        LabeledContent("Curent", value: "\(Int(kwhCurent)) kWh")
                    }
                    Stepper(value: $kwhGaz, in: 0...5000, step: 50) {
                        LabeledContent("Gaz", value: "\(Int(kwhGaz)) kWh")
                    }
                } header: {
                    Text("Consum mediu pe lună")
                } footer: {
                    Text("Îl găsești pe factură. O familie consumă în medie 150–200 kWh de curent pe lună. La gaz, cu centrală, media anului e în jur de 600 kWh pe lună, iarna mult mai mult: folosește media pe tot anul, nu o factură de iarnă.")
                }
            }
            .navigationTitle(initial == nil ? "Locuință nouă" : "Editează locuința")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Renunță") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvează", action: salveaza).bold() }
            }
            .onAppear {
                if let l = initial {
                    nume = l.nume
                    cod = l.codPostal
                    kwhCurent = l.kwhCurent
                    kwhGaz = l.kwhGaz
                } else {
                    nume = locuinte.lista.isEmpty ? "Acasă" : ""
                }
            }
        }
        .presentationDetents([.large])
    }

    private func salveaza() {
        switch Geografie.localizeaza(cod) {
        case .failure(.lungime):
            eroare = "Codul poștal are 6 cifre."
            return
        case .failure(.necunoscut):
            eroare = "Nu recunoaștem acest cod poștal."
            return
        case .success:
            break
        }
        let n = nume.trimmingCharacters(in: .whitespaces)
        if var l = initial {
            if l.codPostal != cod {
                // altă adresă: localitatea aleasă manual și datele zonei nu mai sunt valabile
                l.sirutaAleasa = nil
                l.zonaCurent = nil
                l.judetAnre = nil
                l.t0 = nil
                l.localitate = nil
            }
            l.nume = n.isEmpty ? l.nume : n
            l.codPostal = cod
            l.kwhCurent = kwhCurent
            l.kwhGaz = kwhGaz
            locuinte.actualizeaza(l)
        } else {
            locuinte.adauga(Locuinta(nume: n.isEmpty ? "Locuința \(locuinte.lista.count + 1)" : n,
                                     codPostal: cod, kwhCurent: kwhCurent, kwhGaz: kwhGaz))
        }
        dismiss()
    }
}
