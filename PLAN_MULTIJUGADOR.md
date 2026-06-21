# PLAN MAESTRO — MODO MULTIJUGADOR (Envite Canario)

Documento de referencia. Recoge todas las decisiones de diseño y las reglas
por modo de juego. Sirve de guía para la construcción por fases.

---

## 1. ESTRUCTURA GENERAL

Multijugador se divide en dos submodos:
- **Local** (se construye primero): cada jugador con su teléfono en la MISMA red wifi.
- **En línea** (etapa futura): por internet, con servidores. Es prácticamente un proyecto aparte ("fase 2").

**Modos de equipo a incluir:** 2vs2 y 3vs3. (El 4vs4 queda fuera por ahora.)

---

## 2. SALA / MESA / JUGADORES

- **Conexión local:** mesas con CÓDIGO. El anfitrión crea una mesa, recibe un código, lo comparte; los demás se unen escribiendo el código.
- **Identidad:** cada jugador escribe un APODO al entrar. Se le identifica por apodo + asiento. Anónimo (sin perfil guardado por ahora).
- **Asientos:** cada jugador ELIGE su asiento al entrar. Los asientos enfrentados forman pareja (equipo).
- **IA completa:** si faltan jugadores, la IA ocupa los puestos vacíos.
- **Mínimo:** se permite 1 humano + IA (para practicar el formato).
- **Inicio de partida:** el ANFITRIÓN pulsa empezar, pero los demás deben marcar "listo" antes.

---

## 3. DURANTE LA PARTIDA

- **Perspectiva:** cada jugador se ve a SÍ MISMO abajo, y los demás alrededor de la mesa. La pareja queda enfrente.
- **Marcador:** por EQUIPOS (mi equipo vs equipo rival), con garbanzos. No por jugador individual.
- **Tiempo por turno:** SIN límite.
- **Al terminar:** opción de REVANCHA (misma mesa y jugadores, nueva partida).

---

## 4. SEÑAS ENTRE COMPAÑEROS (función estrella)

Inspirado en las señas reales del Envite (gestos y guiños entre la pareja).

- Conjunto LIMITADO de gestos/emoticonos. Cada gesto equivale a una CARTA/triunfo concreto. (La lista exacta gesto-carta la definirá el usuario.)
- **Privadas:** SOLO los miembros del mismo equipo ven las señas de su equipo.
- **Libres:** se pueden enviar en CUALQUIER momento.
- **Aviso sonoro:** al enviar una seña suena un aviso NEUTRO e IDÉNTICO para todas (un silbido o una tos). Lo oyen todos, pero NO revela qué seña es: solo hace que el compañero mire la pantalla, donde ve el gesto exacto.
- El sonido es PARTE del juego (tensión/picardía) y NO se puede silenciar.

---

## 5. DESCONEXIONES Y SALIDAS

- **Un jugador se desconecta o se va:** la partida se PAUSA y se pregunta a los demás si cubren el puesto con IA o terminan. Si vuelve rápido, se reincorpora.
- **El anfitrión se desconecta:** la partida TERMINA para todos.

---

## 6. GESTOS DE SEÑAS (lista tradicional)

Estos son los gestos reales del Envite que se traducirán a emoticonos/animaciones
limitadas. Cada uno equivale a una carta o situación.

### Gestos de cartas principales (triunfos)
- **La Perica (Sota de Oros):** guiñar un ojo.
- **La Malilla (Dos del palo de la vira):** sacar la punta de la lengua.
- **El Rey (del palo de la vira):** arrugar el entrecejo o levantar las cejas.
- **El Caballo (del palo de la vira):** mover o torcer la boca hacia un lado.
- **El Tres de Bastos / Cinco de Oros (según modalidad):** arrugar levemente la nariz.

### Gestos de juego y situaciones
- **Ir "Ciego" (sin ningún triunfo):** cerrar los ojos.
- **Ir "Flus" (tres cartas del mismo palo):** inflar un poco los carrillos.
- **Envido (desafío de puntos):** dar una cabezadita leve.
- **Triunfos menores:** chasquear los dedos índice y pulgar.

> Nota de implementación: cada gesto será un emoticono/icono. Solo visible para el
> compañero de equipo. Al enviarse, suena el aviso neutro común (silbido/tos).

---

## 7. REGLAS DE JUEGO POR MODO (lógica a implementar)

### Jerarquía de cartas (triunfos), de MAYOR a menor

**1vs1 (ya implementado, modo simplificado):**
- Rey de lo virado > Caballo > Sota > As > 7,6,5,4,3,2 del virado.

**2vs2:**
1. Mala / malilla = DOS de lo virado
2. Rey de lo virado
3. Caballo de lo virado
4. Sota de lo virado
5. As de lo virado
6. Siete, seis, cinco, cuatro, tres… (del virado)

**3vs3:**
1. Tres de bastos  (TRIUNFO FIJO, manda siempre)
2. Caballo de bastos  (TRIUNFO FIJO, manda siempre)
3. Perica = Sota de oros  (TRIUNFO FIJO, manda siempre)
4. Mala / malilla = Dos de lo virado
5. Rey, caballo, sota, as… (del virado)

> IMPORTANTE 3vs3: Tres de bastos, Caballo de bastos y Perica son TRIUNFOS FIJOS:
> mandan SIEMPRE, sin importar el palo virado. El motor 1vs1 NO tiene este
> concepto; hay que añadirlo.

### Arrastre
- Si el mano sale con triunfo/carta de lo virado, "arrastra": los demás deben
  servir con triunfo/chilasco.
- La ÚNICA carta que NO arrastra es la de más valor del modo:
  - 2vs2: la malilla (2 de lo virado)
  - 3vs3: el tres de bastos

### Puntuación
- Igual que ahora pero por EQUIPOS. Piedras, chicos, tumbo, envite: mismas
  mecánicas. (El 1vs1 de la app es una versión SIMPLIFICADA: 2 chicos, menos
  triunfos. Los modos por equipos siguen las reglas tradicionales completas.)

### Turnos
- 2vs2: rotación entre 4. 3vs3: rotación entre 6.
- Reparto en sentido contrario a las agujas del reloj; empieza el de la derecha
  del que repartió.

---

## 8. ORDEN DE CONSTRUCCIÓN (por fases)

1. **Lógica por equipos** (2vs2, 3vs3): jerarquías, triunfos fijos, arrastre,
   turnos, puntuación por equipos. Probable en 1 teléfono contra IA.
2. **IA en equipos:** coopera con su pareja, completa puestos.
3. **Pantallas nuevas:** menú Multijugador (Local/Online), crear mesa, unirse por
   código, sala de espera (apodos, asientos, listos), interfaz de señas.
4. **Red local (wifi):** conexión, sincronización, desconexiones. (Lo más difícil.)
5. **En línea (futuro):** servidores, salas, emparejamiento. Fase 2.

**Primer lanzamiento recomendado:** fases 1+2 (2vs2 y 3vs3 contra IA en un
teléfono) antes de la red.

---

## 9. POSPUESTO / A DEFINIR

- Estadísticas / ranking.
- Diseño visual de la mesa para 4 y 6 jugadores (con bocetos en su momento).
- Todo el modo EN LÍNEA.
