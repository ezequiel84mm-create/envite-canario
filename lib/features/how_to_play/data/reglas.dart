class SeccionRegla {
  final String titulo;
  final String cuerpo;
  const SeccionRegla(this.titulo, this.cuerpo);
}

const List<SeccionRegla> reglasEnvite = [
  SeccionRegla(
    '',
    'El Envite Canario es el juego canario de cartas por excelencia.',
  ),
  SeccionRegla(
    'Objetivo',
    'El objetivo principal del juego es hacer cuatro chicos para ganar la partida. Esto se consigue llegando a tumbo cuatro veces (11 piedras) y ganando el tumbo. El equipo que llegue a 11 piedras puede decidir si juega o no; en caso de que diga que no, el equipo contrario sumará una piedra más, dado que desde que un equipo llegue a 11 se sumará de una en una. Si el equipo que llega a tumbo decide jugar y gana, consigue un chico. Sin embargo, si decide jugar y pierde, el equipo contrario se llevará tres piedras. Cuando ambos equipos lleven 11 piedras se verán obligados ambos a tumbar (a jugar).',
  ),
  SeccionRegla(
    'Inicio del juego',
    'Se baraja, se corta y se reparten 3 cartas a la vez en sentido contrario a las agujas del reloj. Cuando el repartidor se dé sus tres cartas a sí mismo, la siguiente del mazo será «La Vira», colocándose boca arriba. Las cartas del palo que salga se denominan «de lo virado». Empieza a jugar el jugador situado a la derecha del que repartió. Se juegan tres manos, ganando la ronda y dos piedras el equipo que gane dos de las tres manos. Las cartas del palo que salga se denominan «chilasco» o «de lo virado».',
  ),
];

const List<SeccionRegla> reglasEnvite2 = [
  SeccionRegla(
    'El envido',
    'Al cantar envido, se reta al equipo contrario a disputarse cuatro piedras en lugar de dos. Al cantar un envido puede ocurrir una de tres cosas:\n\n• Que el contrario no acepte, ganando dos piedras el equipo que envidó.\n• Que el contrario acepte el envido y se jueguen las cuatro piedras.\n• Que el contrario acepte y además suba la apuesta a siete.\n\nSi se canta el siete, usted podrá a su vez aceptar, subir a nueve, o achicarse. La siguiente apuesta es el «chico fuera», llevándose un chico el que lo gane.',
  ),
  SeccionRegla(
    'El valor de las cartas',
    'El valor de las cartas depende del número de jugadores por equipo. Se comentan de mayor a menor.\n\nSi es un solo jugador:\n• Rey de lo virado\n• Caballo de lo virado\n• Sota de lo virado\n• As de lo virado\n• Siete, seis, cinco, cuatro y tres…\n\nSi el equipo es de dos jugadores:\n• Mala o malilla, que es el Dos de lo virado\n• Rey de lo virado\n• Caballo de lo virado\n• Sota de lo virado\n• As de lo virado\n• Siete, seis, cinco, cuatro y tres…\n\nSi el equipo es de tres jugadores:\n• Tres de bastos\n• Caballo de bastos\n• Perica, que es la Sota de oros\n• Mala o malilla, o Dos de lo virado\n• Rey, caballo, sota, uno…\n\nSi los equipos son de cuatro jugadores:\n• Cinco de oros\n• Tres de bastos\n• Caballo de bastos\n• Sota de oros\n• Dos de lo virado…',
  ),
];

const List<SeccionRegla> reglasEnvite3 = [
  SeccionRegla(
    'El arrastre',
    'Si el jugador mano sale con una carta de lo virado o un triunfo, se dice que está «arrastrando». Los demás jugadores tendrán que servir al arrastre y echar un chilasco o un triunfo. La única carta que no arrastra es la que más valor tiene en la partida (tres de bastos si es 3×3, o la malilla si es 2×2).',
  ),
  SeccionRegla(
    'El tumbo',
    'Se dice que se está en tumbo cuando se tienen once piedras. Si un equipo tiene diez piedras y gana dos más, no se llega a doce sino a once, pues se resta una al pasar por las once piedras. Lo mismo pasaría si se tuvieran ocho piedras y se ganara un envido: se quedaría en once piedras y no en doce.\n\nMientras uno de los equipos se encuentre en tumbo, no se puede envidar. Si se canta un envido, se canta un renuncio y ganará el chico si el equipo que cantó el renuncio es el que estaba en tumbo, o arrayará cuatro piedras si el que lo cantó fuera el otro equipo. El que decide si se tumba o no es el equipo que está en tumbo. Si se achican y no tumban, el contrario se arraya una piedra; si se tumba y se pierde, el contrario gana tres puntos; y si se gana el tumbo, se gana el chico.\n\nTumbo forzoso: si los dos equipos llegan a tener once piedras, se llega al tumbo forzoso, siendo obligatorio tumbar para terminar el chico.',
  ),
  SeccionRegla(
    '¿Cómo arrayar?',
    'Arrayar es apuntarse un punto. Para ello son necesarias piedras, garbanzos, judías…\n\n• 1 punto: una piedra\n• 2 puntos: dos piedras, y así sucesivamente hasta seis\n• 7 puntos: una sola piedra\n• 8 puntos: dos piedras separadas\n• 9 puntos: tres piedras separadas\n• 10 puntos: una piedra\n• 11 puntos: tumbo, ninguna piedra',
  ),
  SeccionRegla(
    '',
    '\n\nSi alguna de estas normas no encaja con lo que sabes o recuerdas, no te preocupes: siempre puedes decir «en mi casa se juega así…». ¡SUERTE!',
  ),
];

const List<SeccionRegla> todasLasReglas = [
  ...reglasEnvite,
  ...reglasEnvite2,
  ...reglasEnvite3,
];
