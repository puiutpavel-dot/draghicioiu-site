import SwiftUI

/// Ecranul principal: contractele tale, cât economisești și ofertele ANRE din zona locuinței active.
struct EconomiiView: View {
    @Environment(Store.self) private var store
    @Environment(Locuinte.self) private var locuinte
    let locatie: Locatie?

    @State private var path: [Rand] = []
    @State private var editeaza: Categorie?
    @State private var locuintaNoua = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if locuinte.lista.isEmpty {
                        PrimaLocuinta()
                    } else if let l = locuinte.activa {
                        if let loc = locatie, loc.codPostal == l.codPostal {
                            let e = energie(l, loc)
                            LocatieCard(locatie: loc) { siruta in
                                var c = l
                                c.sirutaAleasa = siruta
                                locuinte.actualizeaza(c)
                            }
                            ContracteCard(locuinta: l, energie: e) { editeaza = $0 }
                            SectiuneView(categorie: .curent,
                                         subtitlu: "\(e.curent.count) oferte ANRE pentru casnici în zona \(loc.zonaCurent). Estimare pentru \(Int(l.kwhCurent)) kWh pe lună. Atinge o ofertă pentru detalii.",
                                         randuri: e.curent, detaliu: true,
                                         costActual: Comparator.costContract(l.contractCurent, in: e.curent, kwh: l.kwhCurent))
                            SectiuneView(categorie: .gaz, subtitlu: subtitluGaz(l, loc, e),
                                         randuri: e.gaz, detaliu: true,
                                         costActual: Comparator.costContract(l.contractGaz, in: e.gaz, kwh: l.kwhGaz))
                            NotaSurse(actualizatAnre: store.anre?.zi ?? store.anre?.actualizat)
                        } else if store.anre == nil {
                            ContentUnavailableView {
                                Label("Nu am putut încărca ofertele", systemImage: "wifi.exclamationmark")
                            } description: {
                                Text("Verifică conexiunea la internet și trage în jos ca să reîncerci.")
                            }
                        } else {
                            ProgressView("Caut rețelele și ofertele din zona ta…")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await store.reincarca() }
            .navigationTitle(locuinte.activa?.nume ?? "Utilități")
            .toolbar {
                if locuinte.lista.count > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(locuinte.lista) { l in
                                Button {
                                    locuinte.selecteaza(l.id)
                                } label: {
                                    if l.id == locuinte.activa?.id {
                                        Label(l.nume, systemImage: "checkmark")
                                    } else {
                                        Text(l.nume)
                                    }
                                }
                            }
                            Divider()
                            Button { locuintaNoua = true } label: { Label("Adaugă locuință", systemImage: "plus") }
                        } label: {
                            Label("Locuința", systemImage: "house")
                        }
                    }
                }
            }
            .navigationDestination(for: Rand.self) { r in
                if let l = locuinte.activa, let loc = locatie {
                    let e = energie(l, loc)
                    OfertaDetaliuView(rand: r, kwh: l.kwh(r.categorie),
                                      costActual: Comparator.costContract(l.contract(r.categorie), in: e.randuri(r.categorie), kwh: l.kwh(r.categorie)),
                                      celMaiIeftin: e.randuri(r.categorie).first)
                }
            }
            .sheet(item: $editeaza) { cat in
                if let l = locuinte.activa, let loc = locatie {
                    ContractView(categorie: cat, oferte: energie(l, loc).randuri(cat), kwh: l.kwh(cat), initial: l.contract(cat)) { nou in
                        var c = l
                        if cat == .gaz { c.contractGaz = nou } else { c.contractCurent = nou }
                        locuinte.actualizeaza(c)
                    }
                }
            }
            .sheet(isPresented: $locuintaNoua) {
                LocuintaEditView(initial: nil)
            }
            .task(id: locatie?.codPostal) {
                // Doar pentru capturile App Store: -detaliu YES deschide cea mai ieftină ofertă la curent
                guard UserDefaults.standard.bool(forKey: "detaliu"), path.isEmpty,
                      let l = locuinte.activa, let loc = locatie, let r = energie(l, loc).curent.first else { return }
                path.append(r)
            }
        }
    }

    private func energie(_ l: Locuinta, _ loc: Locatie) -> Energie {
        Comparator.energie(anre: store.anre, zona: loc.zonaCurent, judetAnre: loc.judetAnre, t0: loc.t0,
                           kwhCurent: l.kwhCurent, kwhGaz: l.kwhGaz)
    }

    private func subtitluGaz(_ l: Locuinta, _ loc: Locatie, _ e: Energie) -> String {
        if loc.t0 == nil {
            return "Localitatea ta nu apare cu rețea de gaz în lista ANRE. Mai jos, prețurile pentru reședința de județ. Estimare pentru \(Int(l.kwhGaz)) kWh pe lună (media anului)."
        }
        let unde = (loc.localitateGaz ?? loc.localitate).map { " în \(Geografie.titlu($0))" } ?? ""
        return "\(e.gaz.count) oferte ANRE\(unde), cu tariful de distribuție al localității. Estimare pentru \(Int(l.kwhGaz)) kWh pe lună (media anului)."
    }
}

/// Ce plătești acum, cât ai plăti la cea mai ieftină ofertă și diferența pe an.
private struct ContracteCard: View {
    let locuinta: Locuinta
    let energie: Energie
    let editeaza: (Categorie) -> Void

    private var economii: [(Categorie, Double)] {
        [Categorie.curent, .gaz].compactMap { c in
            guard let best = energie.randuri(c).first,
                  let actual = Comparator.costContract(locuinta.contract(c), in: energie.randuri(c), kwh: locuinta.kwh(c)) else { return nil }
            return (c, (actual - best.lunar) * 12)
        }
    }

    var body: some View {
        let total = economii.map { $0.1 }.filter { $0 > 0 }.reduce(0, +)
        Card {
            VStack(alignment: .leading, spacing: 14) {
                if economii.isEmpty {
                    Text("Cât economisești?").font(.title3.bold())
                    Text("Spune-ne ce plătești acum la curent și la gaz și îți arătăm, pe ani, cât câștigi dacă schimbi furnizorul.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if total >= 1 {
                    Text("Poți economisi").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(Format.lei(total, zecimale: 0)) lei pe an")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.castig)
                        .contentTransition(.numericText())
                } else {
                    Label("Ai deja cele mai bune oferte din zona ta", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Color.castig)
                }
                ForEach([Categorie.curent, .gaz]) { c in
                    RandContract(categorie: c, contract: locuinta.contract(c), oferte: energie.randuri(c), kwh: locuinta.kwh(c)) {
                        editeaza(c)
                    }
                }
            }
        }
    }

    private struct RandContract: View {
        let categorie: Categorie
        let contract: ContractActual?
        let oferte: [Rand]
        let kwh: Double
        let editeaza: () -> Void

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                IconCategorie(categorie: categorie)
                VStack(alignment: .leading, spacing: 3) {
                    if let contract, let actual = Comparator.costContract(contract, in: oferte, kwh: kwh) {
                        Text("\(categorie.scurt): \(contract.furnizor)").font(.subheadline.weight(.semibold))
                        Text("acum ≈ \(Format.lei(actual, zecimale: 0)) lei/lună · \(Format.lei(contract.pretKwh, zecimale: 4)) lei/kWh")
                            .font(.caption).foregroundStyle(.secondary)
                        if let best = oferte.first {
                            let dif = (actual - best.lunar) * 12
                            if dif >= 1 {
                                Text("Cu \(best.furnizor): \(Format.lei(best.lunar, zecimale: 0)) lei/lună, −\(Format.lei(dif, zecimale: 0)) lei/an")
                                    .font(.caption.weight(.semibold)).foregroundStyle(Color.castig)
                            } else {
                                Text("Contractul tău e printre cele mai ieftine.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(categorie.titlu).font(.subheadline.weight(.semibold))
                        Text("Adaugă contractul actual ca să vezi economia.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                Button(contract == nil ? "Adaugă" : "Schimbă", action: editeaza)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
            }
        }
    }
}

/// Prima pornire: codul poștal al primei locuințe.
private struct PrimaLocuinta: View {
    @Environment(Locuinte.self) private var locuinte
    @State private var cod = ""
    @State private var eroare: String?
    @FocusState private var tastatura: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Cât plătești prea mult la curent și la gaz?")
                .font(.title2.bold())
            Text("Scrie codul poștal al locuinței. Îți arătăm rețelele de distribuție de la adresa ta, toate ofertele ANRE pentru casnici și, după ce adaugi contractul actual, cât economisești pe an.")
                .font(.subheadline).foregroundStyle(.secondary)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Cod poștal din România, ex. 060042", text: $cod)
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                        .font(.title3.monospacedDigit())
                        .focused($tastatura)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onChange(of: cod) { _, nou in
                            let curat = String(nou.filter(\.isNumber).prefix(6))
                            if curat != nou { cod = curat }
                        }
                    if let eroare { Text(eroare).font(.footnote).foregroundStyle(.red) }
                    Button {
                        switch Geografie.localizeaza(cod) {
                        case .success:
                            tastatura = false
                            locuinte.adauga(Locuinta(nume: "Acasă", codPostal: cod))
                        case .failure(.lungime):
                            eroare = "Codul poștal are 6 cifre."
                        case .failure(.necunoscut):
                            eroare = "Nu recunoaștem acest cod poștal. Verifică-l pe posta-romana.ro."
                        }
                    } label: {
                        Text("Continuă").bold().frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Label("Economia pe an față de contractul tău", systemImage: "banknote")
                Label("Din ce e format prețul fiecărei oferte", systemImage: "chart.pie")
                Label("Istoricul celui mai mic preț din zona ta", systemImage: "chart.xyaxis.line")
                Label("Alertă când apare o ofertă mai ieftină", systemImage: "bell.badge")
                Label("Mai multe locuințe: acasă, la părinți, casa de vacanță", systemImage: "house")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}
