# ENVITE CANARIO — Estado del proyecto

_(Documento de contexto para retomar el trabajo en una conversación nueva.)_

## Qué es
App de cartas del **envite canario** hecha en **Flutter**, para Mac/iPhone/Android.
La desarrolla Zeky en solitario, sin ser programador: trabaja copiando y pegando
comandos en Terminal (scripts Python con heredoc, git). Claude escribe el código.

## Datos técnicos
- **Ruta local:** `~/dev/envite_canario`
- **GitHub:** `ezequiel84mm-create/envite-canario`, rama `main`
- **Versión actual:** 1.3.4+10
- **iPhone (device fijo):** `flutter run -d 00008130-000654A22E9A001C --release`
- **Mac:** `flutter run -d macos`
  - A veces da "Failed to foreground"; se abre con:
    `open ~/dev/envite_canario/build/macos/Build/Products/Debug/envite_canario.app`
- **APKs:** se copian al Escritorio como `ENVITEv[versión].apk` para compartir por WhatsApp
- **Apple dev team:** `4BADJNW5CA` (cuenta gratis, el certificado caduca cada 7 días)

## Modos de juego
1v1, 2v2, 3v3, 4v4 (contra IA y multijugador por WiFi local).
Baraja española de 40 cartas.

## Últimos cambios (v1.3.4+10)
Dos bugs corregidos en los modos por equipos (2v2/3v3/4v4):
1. **Bug de recogida:** al tocar una carta justo cuando se completaba la baza y se
   recogía, te quedabas sin carta. Solución: candado `_recogiendo` que bloquea jugar
   durante la recogida. Aplicado también al 1v1.
2. **Bug de obligación de montar:** el juego te obligaba a "montar" (ganar la baza)
   aunque tu compañero aún no hubiera tirado y pudiera ganarla él. Solución: nueva
   función `_quedaCompaneroPorTirar` que permite tiro libre si queda un compañero por
   jugar detrás. El 1v1 se revisó y NO lo necesitaba (no tiene equipos).

## Cambios de esta sesión (posteriores a lo de arriba, sala/orientación)
- **Orden obligatorio de asientos en la sala** (`sala_screen.dart`): relleno contiguo
  en zigzag (0→1→2…), IA siempre al primer hueco, compactado automático al quitar
  IA/desconexión, ids de IA únicos. Evita que la mesa se rompa.
- **Intercambio de jugadores por el anfitrión:** toca a dos jugadores (menos a sí
  mismo, asiento 0) para intercambiarlos y armar los equipos. Con resaltado dorado.
- **Fallback de equipos blindado** en `game_2v2/3v3/4v4_screen.dart`: el fallback de
  `_equipoDeAsiento` ahora usa el mapa zigzag correcto (A={0,3,4,7}, B={1,2,5,6}).
- **Bloqueo de orientación vertical** (iPhone y Android): `SystemChrome` en
  `main.dart` + `Info.plist` (solo portrait) + `AndroidManifest.xml`
  (`screenOrientation="portrait"`). El layout se deformaba al girar el teléfono.
- Limpieza de lints: `flutter analyze` en verde (de 50 avisos a 0).

## Otras funciones que ya tiene la app
Selector de baraja Española/Canaria en Opciones · botón "Primeros Pasos" con pergamino
en Cómo Jugar · botón de donación "Invítame a un café" con QR de PayPal en Créditos ·
selector de dificultad de IA · sistema de señas.

## Convenciones de trabajo
- Ediciones de Dart con scripts Python heredoc (`cat > /tmp/x.py << 'PYEOF'`).
- Revisar SIEMPRE la zona exacta con `sed -n` / `cat -n` ANTES de reemplazar, para no
  sobrescribir código que funciona.
- En zsh: evitar `!` en strings Python, escapar `$` como `\$` en heredocs, mensajes de
  commit sin paréntesis ni comas.
- Verificar cada cambio con grep antes de compilar.

## Flujo de cierre tras cada cambio
1. Subir versión en `pubspec.yaml` (línea `version:`).
2. Commit y push a `main`.
3. `flutter build apk --release` → copiar a Escritorio como `ENVITEv[versión].apk`.
4. Actualizar iPhone: `flutter run -d 00008130-000654A22E9A001C --release`.

## Pendiente / hoja de ruta
- **Difusión (fase actual):** publicar en historias y pasar a amigos/familia. Vídeo
  promocional para TikTok ya hecho.
- **Distribución — siguiente paso grande:** publicar en **Google Play** (25 $ pago
  único) para tener enlace, estadísticas y actualizaciones automáticas. Apple/App Store
  (99 €/año) aparcado hasta ver tracción.
- **Multijugador online (Firebase):** el salto grande. Empezar por Firebase + login
  anónimo + salas por código; probar en 1v1 antes que en los modos por equipos.
