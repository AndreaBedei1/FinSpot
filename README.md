<h1 align="center">SeaWatch</h1>

<p align="center">
  App Flutter per gestione avvistamenti marini con supporto offline, sincronizzazione e mappa interattiva.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-0ea5e9?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.5+-1d4ed8?logo=dart&logoColor=white">
  <img alt="Android" src="https://img.shields.io/badge/Android-ready-22c55e?logo=android&logoColor=white">
  <img alt="iOS" src="https://img.shields.io/badge/iOS-supported-64748b?logo=apple&logoColor=white">
  <img alt="Offline first" src="https://img.shields.io/badge/Offline-first-f59e0b">
</p>

## Perche SeaWatch
SeaWatch e pensata per funzionare bene in due situazioni reali:

- online: invio dati in tempo reale al backend
- offline: salvataggio locale con coda di sincronizzazione automatica

L'obiettivo e avere un'app fluida anche in barca o in zone con rete instabile.

## Funzionalita principali
- autenticazione e sessione persistente
- profilo utente con avatar
- creazione, modifica ed eliminazione avvistamenti
- upload immagini e annotazioni
- mappa con marker per specie/tipologia
- statistiche visuali (grafici)
- tema chiaro/scuro (con default dal sistema)
- gestione offline con sincronizzazione in background

## Stack tecnico
- Flutter + Dart
- `flutter_map` + `latlong2` per la mappa
- `geolocator` per geolocalizzazione
- `image_picker` per camera/galleria
- `shared_preferences` + `flutter_secure_storage` per stato locale e sessione
- backend REST configurabile via `--dart-define`

## Avvio rapido
Prerequisiti:
- Flutter SDK installato
- Android SDK (per build Android)
- JDK 17

Comandi base:

```powershell
flutter pub get
flutter analyze
flutter run
```

## Build Android (APK)
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

APK generato:
`build/app/outputs/flutter-apk/app-release.apk`

Nota firma:
- se `android/key.properties` e presente, usa il keystore release
- se non e presente, usa fallback debug signing (utile per test interni)

## Configurazione backend
Valori supportati:
- `API_BASE` (o legacy `API_BASE_URL`)
- `FILES_BASE` (o legacy `FILES_BASE_URL`)

Default nel codice:
- API: `https://isi-seawatch.csr.unibo.it/api`
- Files: `https://isi-seawatch.csr.unibo.it`

Esempio:

```powershell
flutter run --dart-define=API_BASE=https://tuo-dominio.tld/api --dart-define=FILES_BASE=https://tuo-dominio.tld
```

## Struttura progetto
```text
lib/
  config/                  # AppConfig e URL backend/files
  models/                  # modelli dominio (avvistamenti, pending ops, ...)
  screens/                 # UI principale
  services/                # auth, sync offline, api client, tema
  widgets/                 # componenti riusabili
docs/deployment/           # note deploy e firma Android
```

## Troubleshooting veloce
- errore upload immagine: verifica connessione e formato file
- riconoscimento disabilitato: disponibile solo online
- specie non selezionabile offline: apri una volta la schermata con rete attiva per aggiornare cache
- build Android fallita: ricontrolla JDK/SDK, poi `flutter clean && flutter pub get`

## Documentazione deploy
- HTTPS reverse proxy: `docs/deployment/reverse-proxy-https.md`
- Android release signing: `docs/deployment/android-release-signing.md`
