# Comandos útiles — Envite Canario

## Lanzar en el iPhone físico de Zeky (device fijo)

```bash
cd ~/dev/envite_canario && \
flutter run -d 00008130-000654A22E9A001C --release
```

- Es el comando "oficial" para actualizar/probar en el teléfono real.
- `--release`: build optimizada (sin la sobrecarga de debug).
- Device id del iPhone: `00008130-000654A22E9A001C`.

## Lanzar en el iPad físico de Zeky

```bash
flutter run -d 00008027-000879020287002E --release
```

- Device id del iPad: `00008027-000879020287002E`.

## Generar el APK (para compartir por WhatsApp)

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ~/Desktop/ENVITEv<version>.apk
```

## Lanzar en el escritorio del Mac (iteración rápida)

```bash
flutter run -d macos
```

## Otros

```bash
flutter devices        # lista dispositivos conectados y sus ids
flutter analyze        # análisis estático (dejar en verde antes de dar por bueno un cambio)
flutter test           # tests automáticos (dejar en verde igual que el analyze)
```

Teclas mientras corre `flutter run`: `r` hot reload · `R` hot restart · `q` salir.

## Pendientes

- **APK más ligero para WhatsApp** (el universal pesa ~124 MB). Probar:

  ```bash
  flutter build apk --release --split-per-abi
  cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk ~/Desktop/ENVITEv<version>.apk
  ```

  El `arm64-v8a` vale para cualquier Android moderno (64 bits) y suele pesar
  menos de la mitad. Sin probar todavía.
