# Comandos útiles — Envite Canario

## Lanzar en el iPhone físico de Zeky (device fijo)

```bash
cd ~/dev/envite_canario && \
flutter run -d 00008130-000654A22E9A001C --release
```

- Es el comando "oficial" para actualizar/probar en el teléfono real.
- `--release`: build optimizada (sin la sobrecarga de debug).
- Device id del iPhone: `00008130-000654A22E9A001C`.

## Lanzar en el escritorio del Mac (iteración rápida)

```bash
flutter run -d macos
```

## Otros

```bash
flutter devices        # lista dispositivos conectados y sus ids
flutter analyze        # análisis estático (dejar en verde antes de dar por bueno un cambio)
```

Teclas mientras corre `flutter run`: `r` hot reload · `R` hot restart · `q` salir.
