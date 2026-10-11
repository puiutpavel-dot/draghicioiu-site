import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store

    @AppStorage("codPostal") private var codSalvat = ""
    @AppStorage("kwhCurent") private var kwhCurent = 175.0
    @AppStorage("kwhGaz") private var kwhGaz = 600.0

    @State private var cod = ""
    @State private var locatie: Locatie?
    @State private var eroare: String?
    @State private var setari = false
    @FocusState private var tastatura: Bool

    private var rezultat: Rezultat? {
        guard let locatie, let d = store.oferte else { return nil }
        return Comparator.calculeaza(d, locatie, kwhCurent: kwhCurent, kwhGaz: kwhGaz)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        cautare
                        if let rezultat {
                            LocatieCard(locatie: rezultat.locatie)
                            Sumar(rezultat: rezultat) { c in
                                withAnimation { proxy.scrollTo(c.id, anchor: .top) }
                            }
                            ForEach(Categorie.allCases) { c in
                                SectiuneView(categorie: c, rezultat: rezultat, kwhCurent: kwhCurent, kwhGaz: kwhGaz)
                                    .id(c.id)
                            }
                            NotaSurse(actualizat: store.oferte?.actualizat)
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
                SetariView(kwhCurent: $kwhCurent, kwhGaz: $kwhGaz, actualizat: store.oferte?.actualizat)
            }
        }
        .task {
            if !codSalvat.isEmpty, locatie == nil {
                cod = codSalvat
                compara(ascundeTastatura: false)
            }
            await store.reincarca()
        }
    }

    private var cautare: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cel mai ieftin furnizor de curent, gaz, internet, TV și mobil din zona ta.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    TextField("Cod poștal, ex. 060042", text: $cod)
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
                            if curat.count == 6, curat != locatie?.codPostal { compara() }
                        }
                    Button(action: { compara() }) {
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
        case .success(let loc):
            eroare = nil
            withAnimation(.snappy) { locatie = loc }
            codSalvat = loc.codPostal
            if ascundeTastatura { tastatura = false }
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
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("\(locatie.codPostal) · \(locatie.judet)").font(.headline)
                } icon: {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.tint)
                }
                Text("Zonă curent: **\(locatie.zonaCurent)** (\(locatie.operatorCurent))")
                Text("Distribuție gaz: **\(locatie.operatorGaz ?? "operatori locali")**")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
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

    private var subtitlu: String {
        let loc = rezultat.locatie
        switch categorie {
        case .curent:
            return "Zona \(loc.zonaCurent). Estimare pentru \(Int(kwhCurent)) kWh pe lună, toate taxele incluse."
        case .gaz:
            let retea = loc.operatorGaz.map { "Rețeaua \($0)." } ?? "Județul tău are operatori locali de distribuție."
            return "\(retea) Estimare pentru \(Int(kwhGaz)) kWh pe lună."
        case .internet:
            return "Disponibilitatea depinde de adresa exactă. Verifică pe site-ul operatorului înainte de a comanda."
        case .tv:
            return "Satelitul merge oriunde în țară; pentru cablu, verifică acoperirea la adresa ta."
        case .mobil:
            return "Aceleași prețuri în toată țara. Ordonate după prețul din primul an."
        }
    }

    var body: some View {
        let randuri = rezultat.randuri(categorie)
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
            }

            if categorie == .gaz, rezultat.locatie.gazPartial {
                Text("În \(rezultat.locatie.judet) unele localități au alt operator de distribuție. Prețul final poate diferi puțin.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    if pozitie == 1 || rand.expira != nil {
                        HStack(spacing: 6) {
                            if pozitie == 1 { Eticheta(text: "Cel mai ieftin") }
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
    let actualizat: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let actualizat {
                Text("Prețuri verificate pe \(Format.data(actualizat, cuAn: true)).").bold()
            }
            Text("Curent și gaz: prețuri finale pe kWh (energie, distribuție, transport, taxe, TVA), după comparatorul ANRE și site-urile furnizorilor. La gaze, până la 31 martie 2027 se facturează cel mai mic dintre prețul din contract și cel stabilit prin OUG 12/2026.")
            Text("Telecom: prețurile în euro sunt convertite la cursul BNR; suma de pe factură poate varia puțin. Multe oferte sunt promoții online sau la portare, cu contract de 24 de luni.")
            Text("Informațiile au rol orientativ. Verifică prețul final la furnizor înainte de a semna.")
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
