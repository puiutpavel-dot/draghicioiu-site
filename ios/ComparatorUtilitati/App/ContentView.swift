import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store

    @AppStorage("codPostal") private var codSalvat = ""
    @AppStorage("kwhCurent") private var kwhCurent = 175.0
    @AppStorage("kwhGaz") private var kwhGaz = 600.0

    @State private var cod = ""
    @State private var locatie: Locatie?
    @State private var sirutaAleasa: Int?
    @State private var eroare: String?
    @State private var setari = false
    @FocusState private var tastatura: Bool

    private var rezultat: Rezultat? {
        guard let locatie, let d = store.oferte else { return nil }
        return Comparator.calculeaza(telecom: d, anre: store.anre, locatie, kwhCurent: kwhCurent, kwhGaz: kwhGaz)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        cautare
                        if let rezultat {
                            LocatieCard(locatie: rezultat.locatie) { siruta in
                                sirutaAleasa = siruta
                                compara(ascundeTastatura: false)
                            }
                            Sumar(rezultat: rezultat) { c in
                                withAnimation { proxy.scrollTo(c.id, anchor: .top) }
                            }
                            ForEach(Categorie.allCases) { c in
                                SectiuneView(categorie: c, rezultat: rezultat, kwhCurent: kwhCurent, kwhGaz: kwhGaz)
                                    .id(c.id)
                            }
                            NotaSurse(actualizatAnre: store.anre?.zi ?? store.anre?.actualizat, actualizatTelecom: store.oferte?.actualizat)
                        } else if store.oferte == nil {
                            ContentUnavailableView {
                                Label("Nu am putut încărca ofertele", systemImage: "wifi.exclamationmark")
                            } description: {
                                Text("Verifică conexiunea la internet și trage în jos ca să reîncerci.")
                            }
                        } else {
                            Introducere()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: locatie) { _, nou in
                    // Doar pentru capturile App Store: -captura gaz|curent|internet|tv|mobil
                    guard nou != nil, let c = UserDefaults.standard.string(forKey: "captura"),
                          let cat = Categorie(rawValue: c) else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        proxy.scrollTo(cat.id, anchor: .top)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .refreshable { await store.reincarca() }
            }
            .navigationTitle("Utilități")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { setari = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Consum și informații")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Compară") { compara() }.bold()
                }
            }
            .sheet(isPresented: $setari) {
                SetariView(kwhCurent: $kwhCurent, kwhGaz: $kwhGaz, actualizat: store.anre?.zi ?? store.oferte?.actualizat)
            }
        }
        .task {
            if UserDefaults.standard.bool(forKey: "capturaSetari") { setari = true }
            if !codSalvat.isEmpty, locatie == nil {
                cod = codSalvat
                compara(ascundeTastatura: false)
            }
            await store.reincarca()
            if locatie != nil { compara(ascundeTastatura: false) } // cu datele proaspete
        }
    }

    private var cautare: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Operatorul de rețea și cel mai ieftin furnizor de curent și gaz din zona ta, după comparatorul ANRE, plus internet, TV și mobil.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
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
                            if curat.count == 6, curat != locatie?.codPostal { sirutaAleasa = nil; compara() }
                        }
                    Button(action: { sirutaAleasa = nil; compara() }) {
                        Text("Compară").bold().padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.oferte == nil)
                }
                if let eroare {
                    Text(eroare).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .padding(.top, 4)
    }

    private func compara(ascundeTastatura: Bool = true) {
        switch Geografie.localizeaza(cod) {
        case .success(let baza):
            if ascundeTastatura { tastatura = false }
            let aleasa = sirutaAleasa
            Task {
                switch await store.completeaza(baza, sirutaAleasa: aleasa) {
                case .success(let loc):
                    eroare = nil
                    withAnimation(.snappy) { locatie = loc }
                    codSalvat = loc.codPostal
                case .failure:
                    eroare = "Codul poștal nu există în nomenclator. Verifică-l pe posta-romana.ro."
                }
            }
        case .failure(.lungime):
            eroare = "Codul poștal are 6 cifre (ex. 060042)."
        case .failure(.necunoscut):
            eroare = "Nu recunoaștem acest cod poștal. Verifică-l pe posta-romana.ro."
        }
    }
}

// MARK: - Bucăți de ecran

private struct Introducere: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Categorie.allCases) { c in
                Label {
                    Text(c.titlu).font(.body.weight(.medium))
                } icon: {
                    Image(systemName: c.simbol)
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(c.culoare, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            Text("Prețurile la curent și gaz depind de zona de distribuție, de aceea pornim de la codul poștal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }
}

private struct LocatieCard: View {
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
                Image(systemName: categorie.simbol)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(categorie.culoare, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(eticheta).font(.caption).foregroundStyle(.secondary)
                    Text(numeOperator).font(.subheadline.weight(.semibold))
                    Text(detaliu).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct Sumar: View {
    let rezultat: Rezultat
    let mergiLa: (Categorie) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Categorie.allCases) { c in
                if let r = rezultat.randuri(c).first {
                    Button { mergiLa(c) } label: { Tile(categorie: c, rand: r) }
                        .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Total estimat").font(.caption.weight(.semibold)).opacity(0.75)
                Text("\(Format.lei(rezultat.total, zecimale: 0)) lei")
                    .font(.title2.weight(.heavy))
                Text("pe lună, cu cele mai ieftine oferte").font(.caption2).opacity(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(14)
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private struct Tile: View {
        let categorie: Categorie
        let rand: Rand
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Label(categorie.scurt, systemImage: categorie.simbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(categorie.culoare)
                Text("\(Format.lei(rand.lunar, zecimale: 0)) lei")
                    .font(.title2.weight(.heavy))
                Text(rand.furnizor).font(.caption.weight(.semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(alignment: .top) {
                Rectangle().fill(categorie.culoare).frame(height: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct SectiuneView: View {
    let categorie: Categorie
    let rezultat: Rezultat
    let kwhCurent: Double
    let kwhGaz: Double
    @State private var toate = false
    private let pas = 8

    private var subtitlu: String {
        let loc = rezultat.locatie
        switch categorie {
        case .curent:
            return "\(rezultat.curent.count) oferte ANRE pentru casnici în zona \(loc.zonaCurent). Estimare pentru \(Int(kwhCurent)) kWh pe lună, toate taxele incluse."
        case .gaz:
            if loc.t0 == nil {
                return "Localitatea ta nu apare cu rețea de gaz în lista ANRE. Mai jos, prețurile pentru reședința de județ. Estimare pentru \(Int(kwhGaz)) kWh pe lună."
            }
            let unde = (loc.localitateGaz ?? loc.localitate).map { " în \(Geografie.titlu($0))" } ?? ""
            return "\(rezultat.gaz.count) oferte ANRE\(unde), cu tariful de distribuție al localității. Estimare pentru \(Int(kwhGaz)) kWh pe lună."
        case .internet:
            return "Disponibilitatea depinde de adresa exactă. Verifică pe site-ul operatorului înainte de a comanda."
        case .tv:
            return "Satelitul merge oriunde în țară; pentru cablu, verifică acoperirea la adresa ta."
        case .mobil:
            return "Aceleași prețuri în toată țara. Ordonate după prețul din primul an."
        }
    }

    var body: some View {
        let toateRandurile = rezultat.randuri(categorie)
        let randuri = toate ? toateRandurile : Array(toateRandurile.prefix(pas))
        VStack(alignment: .leading, spacing: 10) {
            Label(categorie.titlu, systemImage: categorie.simbol)
                .font(.title3.bold())
                .labelStyle(TitluSectiune(culoare: categorie.culoare))
                .padding(.top, 14)
            Text(subtitlu).font(.footnote).foregroundStyle(.secondary)

            if randuri.isEmpty {
                Card {
                    Text("Nu avem oferte active pentru zona ta acum. Verifică în comparatorul ANRE (posf.ro).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(randuri.enumerated()), id: \.element.id) { i, r in
                        RandView(pozitie: i + 1, rand: r, unitate: categorie == .curent || categorie == .gaz ? "estimat / lună" : "pe lună")
                        if i < randuri.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if toateRandurile.count > pas {
                    Button(toate ? "Arată mai puține" : "Arată toate cele \(toateRandurile.count) oferte") {
                        withAnimation { toate.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct RandView: View {
    let pozitie: Int
    let rand: Rand
    let unitate: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let link = rand.link { openURL(link) }
        } label: {
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
                            Text(rand.oferta).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Format.lei(rand.lunar, zecimale: rand.pretUnitar?.hasSuffix("kWh") == true ? 0 : 2)) lei")
                                .font(.headline.monospacedDigit())
                            Text(unitate).font(.caption2).foregroundStyle(.secondary)
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
                    if let d = rand.dupaPromo {
                        Text(d).font(.caption).foregroundStyle(.orange)
                    }
                    if let d = rand.detalii, !d.isEmpty {
                        Text(d).font(.caption).foregroundStyle(.secondary)
                    }
                    if let c = rand.contract {
                        Label(c, systemImage: "doc.text").font(.caption).foregroundStyle(.secondary)
                    }
                    if let pdf = rand.pdf {
                        Link(destination: pdf) {
                            Label("Oferta-tip (PDF)", systemImage: "doc.richtext").font(.caption.weight(.semibold))
                        }
                    }
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(rand.link == nil ? "" : "Deschide site-ul furnizorului")
    }
}

private struct NotaSurse: View {
    let actualizatAnre: String?
    let actualizatTelecom: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let actualizatAnre {
                Text("Prețuri ANRE la zi: \(Format.data(String(actualizatAnre.prefix(10)), cuAn: true)).").bold()
            }
            Text("Curent și gaz: toate ofertele pentru clienți casnici din comparatorul oficial ANRE (posf.ro), preluate în fiecare dimineață. Prețuri finale pe kWh, cu energie, distribuție, transport, taxe și TVA; estimarea lunară include și componenta fixă. La gaze se folosește tariful de distribuție al localității tale; până la 31 martie 2027 se facturează cel mai mic dintre prețul din contract și cel stabilit prin OUG 12/2026.")
            Text("Telecom\(actualizatTelecom.map { " (verificat pe \(Format.data($0, cuAn: true)))" } ?? ""): prețurile în euro sunt convertite la cursul BNR; suma de pe factură poate varia puțin. Multe oferte sunt promoții online sau la portare, cu contract de 24 de luni.")
            Text("Coduri poștale: GeoNames (CC BY 4.0). Informațiile au rol orientativ; verifică oferta la furnizor înainte de a semna.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 20)
    }
}

private struct TitluSectiune: LabelStyle {
    let culoare: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(culoare)
            configuration.title
        }
    }
}
