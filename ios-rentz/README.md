# Masa de Renț — aplicație iOS nativă

Varianta pentru iPhone a [jocului Renț de pe site](https://draghicioiu.ro/rentz/). Joci Renț contra 2–5 adversari conduși de calculator, fără internet.

- **SwiftUI + Observation**, iOS 17+, fără biblioteci externe. iPhone, portret, temă închisă.
- **Regulile** sunt aceleași ca pe site (Wikipedia + PokerStars + casino.com.ro): 8 jocuri, refuzul Renț-ului cu 3/4 capete, pe nevăzute ×2, clasament final ca la Whist. Două variante de punctaj (Clasic / Casino) și Whist sau Totale Plus ca al optulea joc.
- **Partida** se salvează după fiecare rundă (UserDefaults) și se continuă din ecranul de start.
- Nu colectează date (vezi `PrivacyInfo.xcprivacy`). Bundle ID: `ro.draghicioiu.rentz`.

## Structura
```
Rentz/
  Model/  Cards (cărți, culori), Rules (jocuri, punctaje, setări, salvare),
          Engine (RentzGame: runde, levate, Renț, refuz, punctaj, calculatorul)
  App/    RentzApp (+ scene demo), SetupView, GameView, TableView, CardView,
          ResultsViews (rundă, clasament, foaia de scor), RulesView, Theme
```
Motorul e un port direct al celui din `rentz/index.html`, verificat acolo cu partide simulate complete pentru 3–6 jucători.

## Build fără Mac (Codemagic)
`codemagic.yaml` e în rădăcina repo-ului:
1. **Renț — Configurare** o singură dată (bundle ID + profil).
2. Creezi fișa în App Store Connect (bundle `ro.draghicioiu.rentz`, nume „Masa de Renț – Rentz”).
3. **Renț — TestFlight**.
4. **Renț — Fișa App Store** completează textele, categoriile (Jocuri › Cărți, Board) și capturile.
5. **Renț — Trimite la App Review** cu `TRIMITE=1`.

**Renț — Verificare** pornește singur la orice schimbare în `ios-rentz/`: compilează și face capturi în simulator. Capturile folosesc partide jucate automat: aplicația pornește cu `-demo YES -scena joc|rentz|alege|scor|final|start`.

Cu Mac: deschide `Rentz.xcodeproj` în Xcode 16+, alege echipa la *Signing* și rulează.

Iconița se regenerează cu `python3 ci/icon.py Rentz/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
