import SwiftUI
import UIKit

@main
struct RentzApp: App {
    init() {
        let seg = UISegmentedControl.appearance()
        seg.selectedSegmentTintColor = UIColor(red: 0.827, green: 0.09, blue: 0.169, alpha: 1)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .selected)
        seg.setTitleTextAttributes([.foregroundColor: UIColor(white: 0.75, alpha: 1), .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var game: RentzGame?
    @State private var initialSheet: String?
    @State private var demoDone = false

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            if let game {
                GameView(g: game, initialSheet: initialSheet, onExit: {
                    initialSheet = nil
                    self.game = nil
                })
                .transition(.opacity)
            } else {
                SetupView(onStart: { g in self.game = g })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: game == nil)
        .preferredColorScheme(.dark)
        .tint(T.red)
        .onAppear(perform: startDemoIfAsked)
    }

    /// Capturile App Store pornesc aplicația cu `-demo YES -scena <nume>`.
    private func startDemoIfAsked() {
        guard !demoDone, UserDefaults.standard.bool(forKey: "demo") else { return }
        demoDone = true
        let scene = UserDefaults.standard.string(forKey: "scena") ?? "joc"
        if let g = Demo.make(scene) {
            initialSheet = scene
            game = g
        }
    }
}

@MainActor
enum Demo {
    static func make(_ scene: String) -> RentzGame? {
        let g = RentzGame(settings: Settings(players: 4, preset: "clasic", eighth: "whist", fast: false, name: "Daniel"))
        switch scene {
        case "start":
            return nil
        case "alege":
            g.runSync { $0.round >= 4 && $0.chooser == 0 && $0.phase == .aiChoosing }
            g.blind = false
            g.phase = .choose
            g.log = "E rândul tău să alegi jocul."
        case "rentz":
            g.runSync { $0.game == .rentz && $0.phase == .rentz && $0.turn == 0 && $0.placedCount >= 9 && $0.hand(0).count >= 3 && !$0.validRentz(0).isEmpty }
        case "scor":
            g.runSync { $0.round >= 13 && $0.phase == .roundEnd }
        case "final":
            g.runSync { $0.phase == .gameOver }
        default:
            g.runSync { $0.round >= 5 && $0.phase == .trick && $0.turn == 0 && $0.trick.count >= 2 && $0.game != .rentz && $0.hand(0).count >= 5 }
        }
        return g
    }
}
