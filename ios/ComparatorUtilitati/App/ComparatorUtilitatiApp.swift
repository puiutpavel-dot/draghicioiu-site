import SwiftUI

@main
struct ComparatorUtilitatiApp: App {
    @State private var store = Store()
    @State private var locuinte = Locuinte()
    @Environment(\.scenePhase) private var faza

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(locuinte)
                .onChange(of: faza) { _, f in
                    if f == .background { Alerte.programeaza() }
                }
        }
        .backgroundTask(.appRefresh(Alerte.id)) {
            await Alerte.verifica()
            Alerte.programeaza()
        }
    }
}

enum Fila: String {
    case economii, istoric, telecom, locuinte
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Locuinte.self) private var locuinte
    @State private var tab: Fila = Fila(rawValue: UserDefaults.standard.string(forKey: "tab") ?? "") ?? .economii
    @State private var locatie: Locatie?

    var body: some View {
        TabView(selection: $tab) {
            EconomiiView(locatie: locatie)
                .tabItem { Label("Economii", systemImage: "bolt.house.fill") }
                .tag(Fila.economii)
            IstoricView(locatie: locatie)
                .tabItem { Label("Istoric", systemImage: "chart.xyaxis.line") }
                .tag(Fila.istoric)
            TelecomView()
                .tabItem { Label("Telecom", systemImage: "wifi") }
                .tag(Fila.telecom)
            LocuinteView()
                .tabItem { Label("Locuințe", systemImage: "house.fill") }
                .tag(Fila.locuinte)
        }
        .task(id: cheie) { await rezolva() }
        .task { await store.reincarca() }
    }

    /// Se schimbă când se schimbă locuința activă, adresa ei sau datele descărcate.
    private var cheie: String {
        let l = locuinte.activa
        return "\(l?.id.uuidString ?? "-")|\(l?.codPostal ?? "")|\(l?.sirutaAleasa ?? 0)|\(store.anre?.actualizat ?? "")|\(store.localitati?.actualizat ?? "")"
    }

    private func rezolva() async {
        guard let l = locuinte.activa else { locatie = nil; return }
        guard let loc = await store.locatie(pentru: l) else { return }
        locatie = loc
        // păstrăm zona pentru alertele din fundal
        var c = l
        c.zonaCurent = loc.zonaCurent
        c.judetAnre = loc.judetAnre
        c.t0 = loc.t0
        c.localitate = loc.localitate
        locuinte.actualizeaza(c)
    }
}
