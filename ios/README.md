# Utilități — aplicație iOS nativă

Varianta pentru iPhone a [comparatorului de utilități](https://draghicioiu.ro/comparator-utilitati/). Introduci codul poștal și vezi cel mai ieftin furnizor de curent, gaz, internet, cablu TV și telefonie mobilă din zona ta.

- **SwiftUI**, iOS 17+, fără biblioteci externe. Merge pe iPhone (portret) și pe iPad.
- **Datele** vin din același fișier ca site-ul: `comparator-utilitati/oferte.json`. Aplicația îl descarcă de pe draghicioiu.ro la pornire și la tragere în jos, îl păstrează în cache pentru folosire offline și are o copie inclusă (`ComparatorUtilitati/Resources/oferte.json`, actualizată automat la fiecare build din Codemagic). Când schimbi prețurile pe site, se schimbă și în aplicație, fără update în App Store.
- Codul poștal și consumul rămân doar pe telefon. Aplicația nu colectează date (vezi `PrivacyInfo.xcprivacy`).
- Bundle ID: `ro.draghicioiu.utilitati`.

## Structura
```
ComparatorUtilitati/
  App/     ComparatorUtilitatiApp, ContentView (căutare, sumar, clasamente), SetariView (consum), Theme
  Model/   Oferte (formatul JSON), Geografie (cod poștal → județ → zonă curent / rețea gaz),
           Comparator (clasamente și estimări), Store (descărcare + cache)
  Resources/oferte.json   copia inclusă
```

## Build fără Mac (Codemagic)
`codemagic.yaml` e în rădăcina repo-ului:
1. **Utilități — Configurare** o singură dată (bundle ID + profil).
2. Creezi fișa în App Store Connect (bundle `ro.draghicioiu.utilitati`).
3. **Utilități — TestFlight**.

**Utilități — Verificare** pornește singur la orice schimbare în `ios/`: compilează și face capturi în simulator pentru București, Iași și Mehedinți. Pentru capturi pornește aplicația cu `-codPostal 060042`.

Cu Mac: deschide `ComparatorUtilitati.xcodeproj` în Xcode 16+, alege echipa la *Signing* și rulează.

Iconița se regenerează cu `python3 ci/icon.py ComparatorUtilitati/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
