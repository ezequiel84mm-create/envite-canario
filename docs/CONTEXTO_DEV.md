# Contexto de desarrollo (handoff)

Juego: Envite Canario (Flutter). Repo privado: github.com/ezequiel84mm-create/envite-canario, rama main. Version actual: 1.6.0+15.

## Como ponerse al dia
Leer tambien docs/ESTADO_PROYECTO.md (historial y novedades por version).

## Plataformas y rarezas
- Windows: el audio (audioplayers) y Firebase CRASHEAN (error "non-platform thread"). Por eso el audio se silencia solo en Windows y Firebase NO se usa ahi. Desarrollo/pruebas reales en Mac / iPhone / iPad.
- iOS: minimo 15.0 (lo exige firebase_core).
- macOS: necesita el entitlement com.apple.security.network.client.

## Dispositivos y firma
- iPhone: 00008130-000654A22E9A001C
- iPad:   00008027-000879020287002E
- Apple team (cuenta gratuita): 4BADJNW5CA

## Comandos habituales
- Ejecutar: flutter run -d <device_id> --release
- APK: flutter build apk --release  ->  build/app/outputs/flutter-apk/app-release.apk
- Convencion de nombre del APK al Escritorio: ENVITEv<version>.apk  (ej. ENVITEv1.5.apk)

## Firebase (online)
- Realtime Database, proyecto envite-canario, region europe-west1. Fase 4 hecha (v1.6.0): reglas de seguridad activas (`.read`/`.write` = `auth != null`), ya NO en modo prueba abierto.
- IMPORTANTE: hay que pasar la URL de la RTDB explicitamente:
  FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL:
  'https://envite-canario-default-rtdb.europe-west1.firebasedatabase.app')
- firebase_auth (^6.5.6): login ANONIMO al arrancar (main.dart, signInAnonymously), omitido en Windows por el bug de hilos. Hay que tener habilitado el proveedor "Anonimo" en la consola (Authentication). El uid del dato sigue siendo un id aleatorio por dispositivo; el login solo sirve para pasar las reglas (auth != null).

## Arquitectura del multijugador (aditiva, no rompe lo anterior)
- Interfaz comun TransporteSala. La implementan ConexionSala (WiFi por sockets) y ConexionSalaOnline (Firebase).
- La pantalla SalaScreen se reutiliza para online con el parametro online: true.
- Pantallas de juego: game_2v2 / game_3v3 / game_4v4 segun cuantos entren (se rellena con IA).

## Forma de trabajar (preferencias del autor)
- No modificar lo que ya funciona sin consultar antes.
- Respuestas breves.
- Editar en la Mac: si el puente llega, directo; si no, con scripts python heredoc y anclajes precisos.

## Pendiente
- Probar reconexiones en partida online.
