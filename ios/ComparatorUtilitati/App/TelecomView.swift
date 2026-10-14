import SwiftUI

/// Abonamente de internet, TV și mobil (aceleași în toată țara).
struct TelecomView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let t = Comparator.telecom(store.oferte)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectiuneView(categorie: .internet,
                                 subtitlu: "Disponibilitatea depinde de adresa exactă. Verifică pe site-ul operatorului înainte de a comanda.",
                                 randuri: t.internet)
                    SectiuneView(categorie: .tv,
                                 subtitlu: "Satelitul merge oriunde în țară; pentru cablu, verifică acoperirea la adresa ta.",
                                 randuri: t.tv)
                    SectiuneView(categorie: .mobil,
                                 subtitlu: "Aceleași prețuri în toată țara. Ordonate după prețul din primul an.",
                                 randuri: t.mobil)
                    Text("Operatorii au prețurile în euro; le convertim la cursul BNR, iar suma de pe factură poate varia puțin. Multe oferte sunt promoții online sau la portare, cu contract de 24 de luni.\(store.oferte.map { " Prețuri verificate pe \(Format.data($0.actualizat, cuAn: true))." } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await store.reincarca() }
            .navigationTitle("Telecom")
        }
    }
}
