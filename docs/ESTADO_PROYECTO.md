# ENVITE CANARIO — Estado del proyecto

_(Documento de contexto para retomar el trabajo en una conversación nueva.)_

## Qué es
App de cartas del **envite canario** hecha en **Flutter**, para Mac/iPhone/Android.
La desarrolla Zeky en solitario, sin ser programador: trabaja copiando y pegando
comandos en Terminal (scripts Python con heredoc, git). Claude escribe el código.

## Datos técnicos
- **Ruta local:** `~/dev/envite_canario`
- **GitHub:** `ezequiel84mm-create/envite-canario`, rama `main`
- **Versión actual:** 1.6.5+20
- **iPhone (device fijo):** `flutter run -d 00008130-000654A22E9A001C --release`
- **Mac:** `flutter run -d macos`
  - A veces da "Failed to foreground"; se abre con:
    `open ~/dev/envite_canario/build/macos/Build/Products/Debug/envite_canario.app`
- **APKs:** se copian al Escritorio como `ENVITEv[versión].apk` para compartir por WhatsApp
- **Apple dev team:** `4BADJNW5CA` (cuenta gratis, el certificado caduca cada 7 días)

## Modos de juego
1v1, 2v2, 3v3, 4v4 (contra IA, multijugador por WiFi local y online por internet).
Baraja española de 40 cartas.

## Cambios v1.3.4+10
Dos bugs corregidos en los modos por equipos (2v2/3v3/4v4):
1. **Bug de recogida:** al tocar una carta justo cuando se completaba la baza y se
   recogía, te quedabas sin carta. Solución: candado `_recogiendo` que bloquea jugar
   durante la recogida. Aplicado también al 1v1.
2. **Bug de obligación de montar:** el juego te obligaba a "montar" (ganar la baza)
   aunque tu compañero aún no hubiera tirado y pudiera ganarla él. Solución: nueva
   función `_quedaCompaneroPorTirar` que permite tiro libre si queda un compañero por
   jugar detrás. El 1v1 se revisó y NO lo necesitaba (no tiene equipos).

## Cambios v1.3.5 — sala, orientación y arreglos de juego
Sala y orientación (formalizado en esta versión):
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

Arreglos de juego (modos por equipos / IA):
- **Voz del rival según Opciones** en los modos por equipos (se respeta la voz elegida).
- **La IA no canta ni sube de farol en posición perdida** (deja de tirarse faroles
  absurdos cuando va a perder la baza).
- **El "no quiero" termina la mano** a favor del que apostó, con el valor aceptado.
- **Arrastre:** una fija que sale de primera obliga a arrastrar en 3v3 y 4v4
  (`trick_engine_3v3.dart` / `trick_engine_4v4.dart`).
- **En el tumbo, los compañeros IA envían sus señas antes de decidir.**

Nueva seña:
- **"Mordido" (🫦, morderse el labio inferior):** señal para *dos triunfos menores*.
  Ya son 11 señas (5 de carta + 6 de situación) en `senas.dart` / `rueda_senas.dart`.

## Cambios v1.3.6 — tablet y guía rápida
- **Ajustes de tablet:** en tablet (lado corto ≥ 600 px) los botones del inicio no se
  estiran y quedan más compactos, las cartas se dibujan un **25% más grandes** y la
  tipografía se agranda un **20%** (vía `MediaQuery.textScaler` en `main.dart`).
- **Guía rápida:** ahora permite navegar adelante y atrás desde que se abre, sin tener
  que escucharla entera (`quick_guide_screen.dart`).
- **Voces nuevas de Manolo** para la guía rápida (`assets/guia/manologuiapag0..6.mp3`).

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
- **Multijugador online (Firebase): HECHO** (desde v1.5.0). Salas por código,
  anfitrión + invitados por internet rellenando con IA, en 2v2/3v3/4v4. Reglas de
  seguridad y login anónimo desde v1.6.0. Modo/lobby robustos desde v1.6.3.


## Ideas pendientes (online)
- El QR no sirve en online: RESUELTO (en online se comparte por CODIGO, no por QR).
- Codigo de sala pulsable (copiar / compartir por WhatsApp): RESUELTO.
- Sonido del envite en el invitado: RESUELTO.


## Novedades v1.5.0 (julio 2026)

Multijugador ONLINE (por internet, Firebase Realtime Database):
- Funciona de punta a punta: anfitrion + invitados por internet, rellenando con IA. Modos 2v2 / 3v3 / 4v4 segun cuanta gente entre.
- Menu principal: "Multijugador" abre panel "ELIGE MODO" con WiFi y Online.
- En Online se comparte por CODIGO (no por QR): se muestra grande, se toca para copiar y hay boton Compartir (WhatsApp u otra app).
- Sonido del envite: ahora tambien suena en el invitado (antes solo en el anfitrion).

Ajustes:
- Nuevo control de VOLUMEN global en Opciones (debajo de Musica): afecta a musica del menu, efectos y voces. Se guarda entre sesiones.

Mesa de juego:
- Nombres largos: hasta 6 letras enteros; con mas, 4 primeras + "..." (ej. "Samuel1" -> "Samu..."). Ya no se parten en dos lineas.

Tecnico:
- Dependencia share_plus ^13.2.1. iOS minimo 15.0.

Pendiente:
- Probar reconexiones en partida online.


## Novedades v1.6.5 (julio 2026)

Robustez de red (bloque 2 de la revision general; solo se rechazan mensajes
ilegales, el juego normal no cambia):
- El ANFITRION valida ahora todo lo que llega por red antes de aplicarlo:
  - Jugadas: turno correcto, baza abierta (ni cerrada ni recogiendose),
    carta en la mano Y legal segun cartasValidas (arrastre, obligacion de
    montar). El invitado ya lo miraba en su UI, pero su copia del estado
    puede ir atrasada; ahora manda el anfitrion.
  - Envite: solo puede cantar quien tiene el turno de apuesta y solo puede
    responder el equipo contrario al que canto. El tumbo solo lo decide el
    equipo que esta en el tumbo.
  - Senas y jugadas se atribuyen al asiento REAL del emisor (por su id de
    conexion), no al asiento que diga el mensaje.
  (game_2v2/3v3/4v4_screen.dart con helper _asientoDeInvitado;
   juego_red_1v1_screen.dart con los mismos candados que _jugarCarta.)
- Dialogo de fin de mano duplicado en el invitado: si el anfitrion reenviaba
  el estado (p.ej. por un pedirEstado de otro invitado) despues de que el
  invitado cerrara el dialogo, se le volvia a abrir. Candado
  _dialogoFinYaMostrado que se rearma al llegar la mano nueva (las 4
  pantallas de red).
- Probado en iPhone y iPad por WiFi: mano completa con envite, sin cambios
  en el juego normal.


## Novedades v1.6.4 (julio 2026)

Arreglos de estabilidad (salidos de una revision general del codigo):
- Boton "Nueva ronda": en partidas en red ya solo lo ve el anfitrion. Un
  invitado podia pulsarlo tras el fin de mano y repartirse cartas locales
  falsas quedando desincronizado de la partida real. Guardia doble: el boton
  se oculta y _repartirNuevaRonda ignora al invitado
  (game_2v2/3v3/4v4_screen.dart).
- Envite 1v1: el "subir" queda capado al nivel maximo Chico Fuera en
  envite_tumbo_1v1_logic.dart. Antes un mensaje de red desincronizado podia
  llevar el nivel a 5+ y romper los accesos a valores[nivel] con crash.
- 1v1 contra la IA (main.dart): comprobaciones mounted en las jugadas
  retardadas de la IA (_iaSacaPrimera / _jugarCartaIA / _iaDecideTumbo /
  _lanzarEnvite). Evita el error de setState tras cerrar la pantalla si
  salias de la partida justo en ese momento.
- Tests: estado_sala_test.dart actualizado a la regla actual de la sala
  (empezar con mesa completa de 4/6/8) y test nuevo de que con 2 jugadores
  no se puede empezar. flutter analyze y flutter test en verde con 12 tests.
- Probado en iPhone y iPad: partida en red con fin de mano correcto en el
  invitado.


## Novedades v1.6.3 (julio 2026)

Arreglo: el invitado entraba en el MODO equivocado (p.ej. 4v4 en anfitrion pero
2v2 en invitado) y con asientos/identidades mal. Causa: al pulsar EMPEZAR el
invitado arrancaba con SU copia de la sala, que podia estar vieja/incompleta si
se perdio algun estadoSala (buzon aInvitado con fugas). Solucion: el anfitrion
manda la sala COMPLETA dentro del mensaje EMPEZAR y el invitado arranca con esa
(sala_screen.dart: _empezarPartida + handler de empezar).
Ademas el LOBBY va ahora por CANAL FIABLE: el anfitrion escribe el estado de la
sala en salas/<cod>/estado (set, JSON) y el invitado lo observa con onValue + un
get de backup al unirse (conexion_sala_online.dart: escribirEstadoSala /
alRecibirEstadoSala / pedirEstadoSala; sala_screen.dart). El invitado ya ve
siempre los asientos llenos, sin depender del buzon aInvitado.


## Novedades v1.6.2 (julio 2026)

Arreglo de voces en el 1v1 online:
- Sintoma: en 1v1 online solo sonaba la voz propia (Zeky) y nunca la del rival
  (Manolo); se "arreglaba" al cambiar un valor de voz.
- Causa: el 1v1 usaba las voces sincronizadas por red (la vozPropia del otro), que
  por defecto coincidian (zeky). El ajuste vozRival ni se usaba.
- Solucion: alinearlo con los modos por equipos: cada dispositivo usa su vozPropia
  para lo suyo y su vozRival para el rival (juego_red_1v1_screen.dart, _sonidoApuesta).


## Novedades v1.6.1 (julio 2026)

Arreglo importante del online (el invitado se quedaba sin cartas al empezar):
- Causa raiz: la mano del invitado viajaba por el "buzon" aInvitado (push + borrar
  al leer). En rafaga al arranque ese buzon PIERDE mensajes; y como la mano no
  cambia (es el turno del invitado, nadie tira), no se reenviaba -> invitado sin
  cartas. Dependia de milisegundos (siempre fallaba en release, nunca en debug).
- Solucion: canal FIABLE para la mano. El anfitrion la ESCRIBE en
  salas/<cod>/manos/<idInvitado> con set; el invitado la OBSERVA con onValue y
  ademas la LEE con un get puntual en cada reintento (cierra el hueco de que
  onValue solo entrega en el momento de cambiar). En game_2v2/3v3/4v4_screen.dart
  y conexion_sala_online.dart (escribirMano / alRecibirMiManoFija / pedirMiManoFija).
- Cimiento de reconexion (R1): el online usa ahora el uid ESTABLE del login
  anonimo (persiste entre reinicios) en vez de un id aleatorio por sesion.

Pendiente:
- Reconexion online R2 (silla reservada + reconexion por wifi) y R3 (volver a la
  partida al reabrir).
- Bug 1v1 online: solo suena Zeky, nunca Manolo.


## Novedades v1.6.0 (julio 2026)

Seguridad (Fase 4 — cerrada):
- **Login anonimo** con firebase_auth (^6.5.6): al arrancar la app se hace
  `signInAnonymously()` (en `main.dart`), omitido en Windows por su bug de hilos.
  Requiere tener habilitado el proveedor "Anonimo" en Authentication (consola).
- **Reglas de seguridad** en la Realtime Database: `.read`/`.write` = `auth != null`.
  Se acabo el modo prueba abierto: solo entra quien pasa por la app (logueado).
- El login no cambia la logica del online: el uid del dato sigue siendo un id
  aleatorio por dispositivo; el login solo sirve para cumplir las reglas.

Arreglo online:
- **El invitado a veces se quedaba sin cartas al empezar** (cualquier modo/aparato).
  Su peticion "dame mi mano" (`pedirEstado`) podia cruzarse con el cambio de pantalla
  del anfitrion y perderse, sin reintento. Solucion: el invitado reintenta la peticion
  hasta 6 veces (cada 700 ms) y para en cuanto llega la mano. Aplicado en
  `game_2v2/3v3/4v4_screen.dart` (metodo `_pedirEstadoConReintentos`).
