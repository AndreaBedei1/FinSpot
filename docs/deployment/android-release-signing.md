# Android release signing

Per evitare la debug key in release:

1. Crea `android/key.properties` a partire da `android/key.properties.example`.
2. Imposta percorso keystore e credenziali reali.
3. Esegui la build release.

Comando esempio:

```powershell
flutter build apk --release
```

Nota:
- Se `android/key.properties` non esiste, la build release non usera la debug key.
