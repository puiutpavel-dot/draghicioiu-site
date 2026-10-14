import BackgroundTasks
import Foundation
import UserNotifications

/// Alerte locale: aplicația verifică în fundal ofertele ANRE și anunță când apare o ofertă
/// mai ieftină decât contractul tău. Totul se calculează pe telefon.
enum Alerte {
    static let id = "ro.draghicioiu.utilitati.refresh"
    private static let cheieActive = "alerteActive"
    private static let cheieTrimise = "alerteTrimise"
    /// Sub această economie anuală nu deranjăm utilizatorul.
    static let pragLeiPeAn = 60.0

    static var active: Bool {
        get { UserDefaults.standard.bool(forKey: cheieActive) }
        set { UserDefaults.standard.set(newValue, forKey: cheieActive) }
    }

    static func cerePermisiune() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func programeaza() {
        guard active else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: id)
            return
        }
        let r = BGAppRefreshTaskRequest(identifier: id)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(r)
    }

    /// Descarcă ofertele de azi și trimite câte o notificare pentru fiecare locuință și categorie
    /// unde există o ofertă nouă mai ieftină decât contractul salvat.
    static func verifica() async {
        guard active else { return }
        var req = URLRequest(url: Store.baza.appendingPathComponent("anre.json"))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 25
        guard let raspuns = try? await URLSession.shared.data(for: req),
              let anre = try? JSONDecoder().decode(Anre.self, from: raspuns.0) else { return }

        var trimise = UserDefaults.standard.dictionary(forKey: cheieTrimise) as? [String: String] ?? [:]
        for l in Locuinte.incarcaSalvate() {
            guard let zona = l.zonaCurent else { continue }
            let e = Comparator.energie(anre: anre, zona: zona, judetAnre: l.judetAnre, t0: l.t0,
                                       kwhCurent: l.kwhCurent, kwhGaz: l.kwhGaz)
            for cat in [Categorie.curent, .gaz] {
                let oferte = e.randuri(cat)
                guard let best = oferte.first,
                      let actual = Comparator.costContract(l.contract(cat), in: oferte, kwh: l.kwh(cat)) else { continue }
                let economie = (actual - best.lunar) * 12
                let cheie = "\(l.id.uuidString)-\(cat.rawValue)"
                guard economie >= pragLeiPeAn, trimise[cheie] != best.id else { continue }
                trimise[cheie] = best.id

                let c = UNMutableNotificationContent()
                c.title = cat == .gaz ? "Gaz mai ieftin la \(l.nume)" : "Curent mai ieftin la \(l.nume)"
                c.body = "\(best.furnizor): cu aproximativ \(Format.lei(economie, zecimale: 0)) lei pe an mai puțin decât contractul tău."
                c.sound = .default
                try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: cheie, content: c, trigger: nil))
            }
        }
        UserDefaults.standard.set(trimise, forKey: cheieTrimise)
    }
}
