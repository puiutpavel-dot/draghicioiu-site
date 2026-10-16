import SwiftUI

/// Ecranul de start: setările mesei și, dacă există, partida salvată.
struct SetupView: View {
    @AppStorage("players") private var players = 4
    @AppStorage("preset") private var preset = "clasic"
    @AppStorage("eighth") private var eighth = "whist"
    @AppStorage("fast") private var fast = false
    @AppStorage("name") private var name = "Tu"

    @State private var saved: SavedGame? = SaveStore.load()
    @State private var showRules = false
    @FocusState private var nameFocused: Bool

    let onStart: (RentzGame) -> Void

    private var settings: Settings {
        Settings(players: players, preset: preset, eighth: eighth, fast: fast, name: name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Brand(subtitle: "joc de cărți românesc")
                    Spacer()
                    Button("Reguli") { showRules = true }.buttonStyle(PillButton(kind: .ghost, small: true))
                }

                Hero()

                if let s = saved {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Partidă începută").font(T.display(20)).textCase(.uppercase).foregroundStyle(T.gold)
                        Text("Runda \(s.round + 1) din \(s.settings.players * 8) · \(s.settings.players) jucători · scorul tău \(s.scores.first ?? 0)")
                            .font(.system(size: 14)).foregroundStyle(T.fg)
                        HStack(spacing: 10) {
                            Button("Continuă") {
                                let g = RentzGame(settings: s.settings, saved: s)
                                g.start()
                                onStart(g)
                            }
                            .buttonStyle(PillButton(kind: .gold))
                            Button("Renunță") { SaveStore.clear(); saved = nil }
                                .buttonStyle(PillButton(kind: .ghost, small: true))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(T.panel))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.gold.opacity(0.6), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text(saved == nil ? "Masă nouă" : "Sau o masă nouă").font(T.display(24)).textCase(.uppercase).foregroundStyle(T.fg)

                    Field("Numele tău") {
                        TextField("Tu", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 9).fill(T.panel2))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(T.line, lineWidth: 1))
                            .onChange(of: name) { _, v in if v.count > 14 { name = String(v.prefix(14)) } }
                    }
                    Field("Jucători la masă") {
                        Picker("Jucători", selection: $players) {
                            ForEach(3...6, id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.segmented)
                    }
                    Field("Punctaj") {
                        Picker("Punctaj", selection: $preset) {
                            Text("Clasic −300").tag("clasic")
                            Text("Casino −100").tag("casino")
                        }.pickerStyle(.segmented)
                    }
                    Field("Al optulea joc") {
                        Picker("Al optulea joc", selection: $eighth) {
                            Text("Whist").tag("whist")
                            Text("Totale Plus").tag("totplus")
                        }.pickerStyle(.segmented)
                    }
                    Field("Viteza adversarilor") {
                        Picker("Viteza", selection: $fast) {
                            Text("Normal").tag(false)
                            Text("Rapid").tag(true)
                        }.pickerStyle(.segmented)
                    }
                    Text("\(players) jucători: pachet de \(8 * players) cărți (\(Card.rankLabel(15 - 2 * players))–A), mijlocul la Renț este \(Card.rankLabel(15 - players)), \(8 * players) runde.")
                        .font(.system(size: 13)).foregroundStyle(T.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Începe jocul") {
                        nameFocused = false
                        if saved != nil { SaveStore.clear() }
                        let g = RentzGame(settings: settings)
                        g.start()
                        onStart(g)
                    }
                    .buttonStyle(PillButton())
                    if saved != nil {
                        Text("O masă nouă înlocuiește partida începută.").font(.system(size: 12)).foregroundStyle(T.muted)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(T.panel))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.line, lineWidth: 1))
            }
            .padding(16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showRules) { RulesView() }
        .onAppear { saved = SaveStore.load() }
    }
}

private struct Field<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 11, weight: .heavy)).tracking(1).textCase(.uppercase).foregroundStyle(T.muted)
            content
        }
    }
}

/// O bucată de postav cu un evantai de cărți: ce face aplicația, dintr-o privire.
private struct Hero: View {
    private let fan: [Card] = [Card(r: 11, s: .H), Card(r: 12, s: .S), Card(r: 13, s: .H), Card(r: 14, s: .C), Card(r: 10, s: .D)]

    var body: some View {
        ZStack {
            Felt(cornerRadius: 70)
            HStack(spacing: -26) {
                ForEach(Array(fan.enumerated()), id: \.offset) { i, c in
                    CardView(card: c, width: 62)
                        .rotationEffect(.degrees(Double(i - 2) * 9), anchor: .bottom)
                        .offset(y: abs(Double(i - 2)) * 6)
                }
            }
            .offset(y: 4)
        }
        .frame(height: 170)
        .accessibilityHidden(true)
    }
}
