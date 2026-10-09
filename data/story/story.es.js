/* DEADLINE 15 — Guion de la historia (traducción al español)
 * Formato: docs/story-schema.md
 * Ambientación narrativa: docs/STORY.md
 * {commander} se sustituye por el nombre del comandante del jugador. No se usan pronombres de género para el comandante.
 */
window.STORY_ES = {
  cast: {
    commander: { name: 'Lian', portrait: 'commander', role: 'Protagonista · Comandante del clan' },
    narrator:  { name: '', portrait: null },
    bram:  { name: 'Bram',   portrait: 'story/bram',  fallback: 'knight_01',   role: 'Viejo caballero · Instructor de la milicia, mentor de quien comanda' },
    sera:  { name: 'Sera',   portrait: 'story/sera',  fallback: 'priest_02',   role: 'Sanadora del clan · Amiga de la infancia de quien comanda' },
    bark:  { name: 'Bark',   portrait: 'story/bark',  fallback: 'brawler_01',  role: 'Exbandido · Líder de asalto del clan' },
    kasha: { name: 'Kasha',   portrait: 'story/kasha', fallback: 'assassin_02', role: 'Líder de los mercenarios de la Pluma Negra · Rival' },
    ordin: { name: 'Ordin', portrait: 'story/ordin', fallback: 'summoner_01', role: 'Archimago Real · Patrocinador del clan' },
    fake_bram: { name: '¿Bram?', portrait: 'story/bram', fallback: 'knight_01', ghost: true, role: 'Ilusión que imita la apariencia de Bram (s70)' },
  },

  episodes: {
    1: { title: 'El Comienzo del Héroe',
      prologue: [
        { who: 'narrator', text: 'Hace 15 años, hubo una noche en que se partió el cielo.' },
        { who: 'narrator', text: 'Una grieta violeta se abrió y volvió a cerrarse antes del alba.' },
        { who: 'narrator', text: 'Entre los escombros de aquella noche encontraron a un bebé.' },
        { who: 'narrator', text: 'En la palma llevaba una cicatriz con forma de estrella partida.' },
        { who: 'narrator', text: 'Y ahora, en la frontera: la aldea de Solbit.' },
        { who: 'bram', text: 'El capitán de la milicia cayó por una flecha bandida. Alguien debe tomar el mando.' },
        { who: 'commander', text: '¿Por qué yo? Hay muchos con más años en la milicia.' },
        { who: 'bram', text: 'Tú miras alrededor antes de pelear. Ese es el ojo de quien comanda.' },
        { who: 'sera', text: '{commander}, voy contigo. Si te hieren, yo te curo.' },
        { who: 'commander', text: '……Entendido. No perderé a nadie.' },
        { who: 'bram', text: 'Buena determinación, peque. Cumple esa palabra hasta el final.' },
        { who: 'bram', text: 'Toma esto. Es el bastón de mando de plata que usé en las guerras del reino.' },
        { who: 'commander', text: '¿Un bastón de mando? ¿No una espada?' },
        { who: 'bram', text: 'Quien comanda no se planta al frente con una espada.' },
        { who: 'bram', text: 'Lee el campo desde atrás y da las señales con esto.' },
        { who: 'bram', text: 'Las armas de quien comanda son los miembros del clan. Tú solo da órdenes precisas.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'La banda de bandidos cayó, y las campanas sonaron en la aldea de Solbit.' },
        { who: 'narrator', text: 'Tres días después, un carruaje con el estandarte de la capital real entró en la aldea.' },
        { who: 'ordin', text: 'Soy Ordin, Archimago Real. Así que usted es quien comanda.' },
        { who: 'ordin', text: 'El norte se está congelando. La corona necesita a su clan.' },
        { who: 'commander', text: 'Solo somos la milicia de una aldea.' },
        { who: 'ordin', text: 'Una milicia que venció a cien bandidos basta y sobra.' },
        { who: 'ordin', text: '……Esa cicatriz de la mano, ¿desde cuándo la tiene?' },
        { who: 'commander', text: 'Desde que tengo memoria. ¿Por qué?' },
        { who: 'ordin', text: 'Por nada. Simplemente me resulta interesante.' },
        { who: 'bram', text: '(Esa mirada… ya la vi hace 15 años.)' },
        { who: 'narrator', text: 'El clan recibió el mandato real y partió hacia el norte.' },
      ] },

    2: { title: 'La Conspiración Helada',
      prologue: [
        { who: 'narrator', text: 'Los Montes Velo de Nieve, en el norte. Tierra donde la nieve nunca se derrite.' },
        { who: 'narrator', text: 'Este año, hasta las aldeas al pie del monte se congelaron en una sola noche.' },
        { who: 'bark', text: 'Capi, aquí hasta respirar te congela los pelos de la nariz.' },
        { who: 'sera', text: 'Los que murieron congelados… todos tienen cara de haber visto algo horrible.' },
        { who: 'bram', text: 'Este frío no es natural. Alguien lo ha invocado.' },
        { who: 'commander', text: '(La cicatriz de la palma… late con un dolor helado.)' },
        { who: 'commander', text: 'Primero protegemos la aldea del valle. La causa, después.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'Cuando cayó el Caballero de escarcha, la brisa de primavera bajó a las montañas.' },
        { who: 'bram', text: 'Halvar… era mi viejo compañero de armas. Hace 15 años, estuvo en esa misma noche.' },
        { who: 'commander', text: 'Sus últimas palabras… ¿qué quería decirnos sobre el archimago?' },
        { who: 'bram', text: 'No lo sé. No lo digas en voz alta hasta estar seguros.' },
        { who: 'kasha', text: 'Otra vez llegaste antes, comandante de pueblo.' },
        { who: 'kasha', text: 'Pero recuérdalo: la Pluma Negra no pierde dos veces.' },
        { who: 'narrator', text: 'En ese momento, llegó un mensajero urgente de la capital real.' },
        { who: 'ordin', text: 'Una plaga se extiende por los pantanos del sur. Dense prisa.' },
        { who: 'commander', text: '……Es como si supiera dónde va a estallar lo siguiente.' },
      ] },

    3: { title: 'La Maldición de la Ciénaga',
      prologue: [
        { who: 'narrator', text: 'El Pantano de Aguanegra, en el sur. Entre la bruma no cesaban las toses.' },
        { who: 'narrator', text: 'Las bestias, deformadas y retorcidas, atacaban a la gente.' },
        { who: 'sera', text: 'Si es una plaga, es cosa mía. Esta vez voy al frente.' },
        { who: 'commander', text: 'Sera, no intentes cargar con todo tú sola.' },
        { who: 'bark', text: '¡Si es pelea en el barro, soy todo un experto!' },
        { who: 'bram', text: 'En el agua poco profunda se traban los pies. Y ahí los golpes duelen más.' },
        { who: 'commander', text: 'Nada de pararse en los vados a la ligera. Recuérdenlo.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'Cuando el Señor del pantano se hundió, el agua empezó a aclararse.' },
        { who: 'commander', text: 'Este mapa… el norte, el pantano y el volcán del Imperio.' },
        { who: 'bram', text: 'Si unes los tres, sale un triángulo. Es una formación mágica enorme.' },
        { who: 'sera', text: 'Alguien ha estado provocando las catástrofes una por una, a propósito.' },
        { who: 'ordin', text: 'Recibí el informe. Detrás de todo está el Imperio Volkar, sin duda.' },
        { who: 'commander', text: 'En el templo también encontramos un objeto ritual con el escudo real.' },
        { who: 'ordin', text: 'El Imperio querrá incriminarnos. Avancen.' },
        { who: 'bram', text: '(Responde demasiado rápido.)' },
        { who: 'narrator', text: 'Con la duda a cuestas, el clan cruzó la frontera.' },
      ] },

    4: { title: 'El Imperio en Llamas',
      prologue: [
        { who: 'narrator', text: 'El Imperio Volkar. Una nación de acero que forja el hierro con fuego volcánico.' },
        { who: 'narrator', text: 'Ahora ardía, partida entre los leales al emperador y los rebeldes.' },
        { who: 'bark', text: 'Si los del Imperio son los culpables, basta con cortarle la cabeza al emperador.' },
        { who: 'bram', text: 'Ojalá fuera tan simple.' },
        { who: 'sera', text: 'Hay niños llorando en las aldeas quemadas. Ellos van primero.' },
        { who: 'commander', text: 'Nos aliamos con los rebeldes. Nuestro enemigo no es el pueblo de este país.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'El Emperador de las llamas cayó, y el cielo rojo del volcán empezó a enfriarse.' },
        { who: 'commander', text: 'Las últimas palabras del emperador y la carta del altar. Todo apunta a Ordin.' },
        { who: 'bram', text: '"Aviva las llamas, según lo acordado." Ahora está claro.' },
        { who: 'kasha', text: 'O sea que tu patrocinador montó todo este tablero.' },
        { who: 'commander', text: 'Iré a la capital real a preguntárselo en persona. Por qué hizo esto.' },
        { who: 'narrator', text: 'Pero esa noche, la tierra se partió como si gritara.' },
        { who: 'narrator', text: 'En los páramos del oeste se abrió un agujero sin fondo: el Abismo.' },
        { who: 'sera', text: 'De ahí salen monstruos sin parar. ¡Las aldeas están en peligro!' },
        { who: 'bram', text: 'La verdad no se va a escapar. Las vidas de la gente no esperan.' },
        { who: 'commander', text: '……Vamos al Abismo. Ordin, después.' },
      ] },

    5: { title: 'El Fin del Abismo',
      prologue: [
        { who: 'narrator', text: 'El Abismo. Las ruinas de una civilización antigua dormida bajo tierra.' },
        { who: 'narrator', text: 'Allí, donde no llega la luz, algo estaba despertando.' },
        { who: 'bark', text: 'No se ve el fondo. Si caes, se acabó para siempre.' },
        { who: 'sera', text: 'El aire pesa. Siento que mis plegarias no llegan.' },
        { who: 'bram', text: 'Comandante. Esta vez puede que alguien no regrese.' },
        { who: 'commander', text: 'No diga eso. Volvemos con todos.' },
        { who: 'bram', text: 'Sí. Esa terquedad es tu virtud.' },
        { who: 'commander', text: '(La cicatriz quema. Alguien me llama desde allá abajo.)' },
      ],
      epilogue: [
        { who: 'narrator', text: 'El Guerrero del abismo cayó, y el eco de las profundidades se apagó.' },
        { who: 'narrator', text: 'El clan volvió a la superficie. Dejando atrás a uno de los suyos.' },
        { who: 'narrator', text: 'En la colina de la aldea de Solbit enterraron un ataúd vacío.' },
        { who: 'sera', text: 'El tío Bram… sonrió hasta el final.' },
        { who: 'commander', text: 'Dije que volveríamos todos. Lo dije yo.' },
        { who: 'bark', text: 'No es culpa tuya, capi. El viejo eligió ese puesto.' },
        { who: 'kasha', text: 'No hay tiempo para llorar. Ordin desapareció de la capital real.' },
        { who: 'kasha', text: 'Y en el cielo al norte de la capital… se está formando una puerta.' },
        { who: 'commander', text: '……Vamos. A proteger lo que Bram quería proteger.' },
      ] },

    6: { title: 'Puerta del Infierno',
      prologue: [
        { who: 'narrator', text: 'Las grietas se extendieron por todo el cielo. Como aquella noche hace 15 años.' },
        { who: 'narrator', text: 'Pero esta vez, ni con el alba se cerraron.' },
        { who: 'narrator', text: 'Al norte de la capital real, una puerta gigantesca se abría lentamente.' },
        { who: 'sera', text: '{commander}, últimamente no duermes. ¿Estás bien?' },
        { who: 'commander', text: 'No, no lo estoy. Pero si me detengo, perderemos más.' },
        { who: 'commander', text: 'Bram lo dijo: quien comanda no puede salvar a todos.' },
        { who: 'commander', text: 'Pero sí puede no abandonar a nadie.' },
        { who: 'narrator', text: 'Con la espada rota guardada junto al pecho, el bastón de plata se alzó de nuevo.' },
        { who: 'bark', text: 'Esperaba oír eso, capi. Vamos otra vez.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'En cuanto cayó el Guardián de la puerta infernal, la Puerta del Infierno se abrió de par en par.' },
        { who: 'ordin', text: 'Buen trabajo, joven comandante. Mejor dicho… Llave.' },
        { who: 'commander', text: '¡Ordin! ¿Esto era lo que buscabas desde el principio?' },
        { who: 'ordin', text: 'Solo su sangre podía derribar al guardián.' },
        { who: 'ordin', text: 'Hace 15 años, sus padres cerraron la puerta. Dando la vida por ello.' },
        { who: 'ordin', text: 'Yo debo abrirla. Para invocar a un dios.' },
        { who: 'narrator', text: 'Ordin desapareció en la oscuridad roja al otro lado de la puerta.' },
        { who: 'kasha', text: 'Vas a perseguirlo, ¿no? Por tu cara, ya lo decidiste.' },
        { who: 'commander', text: 'Cruzamos la puerta. Esta vez, lo terminamos nosotros.' },
      ] },

    7: { title: 'Reino Demoníaco',
      prologue: [
        { who: 'narrator', text: 'El Reino Demoníaco. El cielo, rojo como la sangre; la tierra, respirando.' },
        { who: 'narrator', text: 'Aquí los caminos cambiaban cada día y los recuerdos cobraban forma.' },
        { who: 'bark', text: 'Esa roca me acaba de mirar. En serio.' },
        { who: 'sera', text: 'Creo que aquí no hay que creer todo lo que vemos.' },
        { who: 'kasha', text: 'Te seguí. Las deudas se pagan. El grueso de mi tropa llegará pronto.' },
        { who: 'commander', text: 'Sigan llamándose por su nombre. Para no perderse a sí mismos.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'Cuando el Hechicero demoníaco se disipó, la niebla de ilusiones se levantó.' },
        { who: 'commander', text: 'La voz que oí en las ruinas… ¿de verdad eran mis padres?' },
        { who: 'sera', text: '"La Llave no se gira en soledad." Eso dijeron, ¿no?' },
        { who: 'commander', text: 'Sí. Quiero creer que esas palabras no eran una ilusión.' },
        { who: 'kasha', text: 'El hechicero confesó. Ordin fue a la cima del Reino Demoníaco.' },
        { who: 'kasha', text: 'Donde se filtra la luz celestial. Allí piensa invocar a su dios.' },
        { who: 'bark', text: '¿Un dios? ¿Ahora también hay que pelear contra dioses?' },
        { who: 'commander', text: 'Dios o lo que sea: si usa a la gente como material, lo detendremos.' },
      ] },

    8: { title: 'Juicio Divino',
      prologue: [
        { who: 'narrator', text: 'En lo más alto del cielo del Reino Demoníaco se abrió una grieta blanca.' },
        { who: 'narrator', text: 'La luz que brotaba de ella no distinguía entre demonios y personas.' },
        { who: 'sera', text: 'Esto es… la luz a la que he rezado toda mi vida.' },
        { who: 'sera', text: 'Entonces, ¿por qué es tan fría?' },
        { who: 'ordin', text: 'Observen. El dios reducirá a cenizas todo lo impuro.' },
        { who: 'ordin', text: 'El Reino Demoníaco, las tierras que lo han tocado y a quienes viven en ellas.' },
        { who: 'commander', text: '¡En esas tierras también está nuestro hogar!' },
        { who: 'ordin', text: 'Para salvar el mundo, hay que perder una parte. Así es el cálculo.' },
        { who: 'commander', text: 'A quién perder no lo decides tú.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'La grieta blanca se cerró, y el cielo del Reino Demoníaco volvió a teñirse de rojo.' },
        { who: 'ordin', text: 'El dios… ya había sido derrotado una vez por el Señor Demoníaco.' },
        { who: 'ordin', text: 'He pasado 15 años rezando a un dios vencido, al parecer.' },
        { who: 'bark', text: 'Capi, ¿qué hacemos con este viejo? ¿Lo dejamos aquí?' },
        { who: 'commander', text: 'Viene con nosotros. Pagar con la muerte sería demasiado fácil.' },
        { who: 'sera', text: '{commander}… has cambiado mucho. Para bien.' },
        { who: 'narrator', text: 'Entonces, desde lo profundo del Reino Demoníaco, retumbó un tambor de guerra colosal.' },
        { who: 'kasha', text: 'El ejército del Señor se mueve. Su objetivo… ¡es nuestro mundo!' },
        { who: 'commander', text: 'Regresamos. Si no lo detenemos ahora, no habrá adónde volver.' },
      ] },

    9: { title: 'Crisis Absoluta',
      prologue: [
        { who: 'narrator', text: 'El ejército del Señor Demoníaco brotó de todas las grietas del mundo.' },
        { who: 'narrator', text: 'El reino, el Imperio, el norte, el pantano: todo era ya un solo campo de batalla.' },
        { who: 'narrator', text: 'Los supervivientes dispersos se reunieron bajo una sola bandera.' },
        { who: 'kasha', text: 'Todos quieren que asumas el mando supremo. Qué gracia, viniendo de una aldea.' },
        { who: 'commander', text: 'Sigo al mando de la milicia de una aldea.' },
        { who: 'commander', text: 'Solo que la aldea que debo proteger se ha hecho un poco más grande.' },
        { who: 'bark', text: '¡Jajaja! Hay que bordar eso en la bandera.' },
        { who: 'sera', text: 'Esta vez terminemos con todos vivos. Prométemelo.' },
        { who: 'commander', text: 'Lo prometo. Y esta vez lo cumpliré hasta el final.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'Cuando cayó el Guerrero de la guerra, el avance demoníaco se detuvo.' },
        { who: 'narrator', text: 'El mundo resistió a duras penas. A muy duras penas.' },
        { who: 'ordin', text: 'Conozco el camino al trono del Señor. Los guiaré.' },
        { who: 'kasha', text: '¿Podemos fiarnos? Todo esto pasó por culpa de este viejo.' },
        { who: 'commander', text: 'No es confianza. Es darle una oportunidad.' },
        { who: 'ordin', text: '……Sus padres dijeron exactamente lo mismo.' },
        { who: 'bark', text: '¿Mañana se acaba todo? ¿De verdad?' },
        { who: 'commander', text: 'Vamos a acabarlo. Todos juntos.' },
        { who: 'narrator', text: 'La víspera de la partida, las hogueras del campamento ardieron toda la noche.' },
      ] },

    10: { title: 'Reino de la Imposibilidad',
      prologue: [
        { who: 'narrator', text: 'Lo más profundo del Reino Demoníaco. Un fondo al que no llegan ni la luz ni el sonido.' },
        { who: 'narrator', text: 'Allí se alzaba el trono del Señor Demoníaco.' },
        { who: 'ordin', text: 'Ante el trono, los cinco vasallos del Señor bloquean el paso.' },
        { who: 'kasha', text: 'Cinco, ¿eh? Pues los tumbamos uno por uno.' },
        { who: 'sera', text: '{commander}, dame la mano. …La cicatriz está brillando.' },
        { who: 'commander', text: 'Es la Llave que me dejaron mis padres. Esta vez la giramos juntos.' },
        { who: 'bark', text: 'Mi mano sobre la tuya, capi. ¡Vamos, todos encima!' },
        { who: 'commander', text: 'Última operación. ¡Clan de Solbit, en marcha!' },
      ],
      epilogue: [
        { who: 'narrator', text: 'La Llave giró, y todas las grietas del cielo se cerraron a la vez.' },
        { who: 'narrator', text: 'El Reino Demoníaco volvió a un sueño profundo. Esta vez, para siempre.' },
        { who: 'narrator', text: 'Y unos meses después, primavera en la aldea de Solbit.' },
        { who: 'bark', text: '¡Capi! Faltan manos para arar. ¡Los héroes también trabajan!' },
        { who: 'kasha', text: 'La Pluma Negra se disolvió. Ahora solo soy Kasha. Cuento contigo.' },
        { who: 'sera', text: 'Llevé flores a la tumba del tío Bram. ¿Vienes conmigo?' },
        { who: 'commander', text: 'Sí. Tengo mucho que contarle. Debo decirle que todo terminó.' },
        { who: 'commander', text: 'Bram, solo cumplí la mitad de la promesa. Pero aquí estamos todos.' },
        { who: 'narrator', text: 'El viento sopló sobre la colina. Sonaba como alguien riendo.' },
        { who: 'commander', text: 'Éramos gente común. Pero juntos, lo logramos.' },
        { who: 'narrator', text: '— DEADLINE 15, fin —' },
      ] },
  },

  stages: {
    // ═══ Episode 1: El Comienzo del Héroe ═══
    1: {
      pre: [
        { who: 'narrator', text: 'Empalizada este de la aldea de Solbit. Más allá del campo, se agitaban antorchas.' },
        { who: 'bram', text: 'Son secuaces bandidos. Si aguanta la empalizada, la aldea está a salvo.' },
        { who: 'commander', text: 'Primera orden: defiendan la empalizada. Yo leeré el campo desde atrás.' },
        { who: 'sera', text: 'Si te hieren, retrocede enseguida. Para eso estoy yo.' },
      ],
      post: [
        { who: 'bram', text: 'Nada mal. Nadie ha caído.' },
        { who: 'commander', text: 'La punta del bastón todavía me tiembla.' },
        { who: 'bram', text: 'Con la mano temblando también se dan órdenes. Con eso basta.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Si cae la empalizada, se acabó. ¡Mantengan sus puestos!' } ],
        last: [ { who: 'sera', text: '¡Queda uno! ¡Un poco más!' } ],
      },
    },
    2: {
      pre: [
        { who: 'narrator', text: 'Al alba del día siguiente, los bandidos volvieron en tropel.' },
        { who: 'bram', text: 'Esta vez traen gente con hachas. Son guerreros.' },
        { who: 'bram', text: 'Los guerreros se enfurecen cuanto más los golpeas. No alargues la pelea.' },
        { who: 'commander', text: 'Dos contra uno. Uno a uno, sin fallar.' },
      ],
      post: [
        { who: 'sera', text: '{commander}, esa orden de antes sonó a comandante de verdad.' },
        { who: 'commander', text: 'Solo repetí lo que dice Bram.' },
        { who: 'bram', text: 'De tanto repetirlo, se vuelve tuyo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero los de las hachas! ¡Acábenlos entre dos!' } ],
        wave: [ { who: 'bram', text: 'Segundo grupo. Sin prisa: la empalizada aguanta.' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡estás muy mal! ¡Retrocede, yo te curo!' } ],
      },
    },
    3: {
      pre: [
        { who: 'narrator', text: 'Un cañón rocoso que llevaba a la aldea. El atajo de los bandidos.' },
        { who: 'bram', text: 'Tomen la colina sobre el cañón. Desde arriba se golpea más fuerte.' },
        { who: 'commander', text: 'Ojalá tuviéramos más gente para disparar desde arriba.' },
        { who: 'bram', text: 'No lamentes lo que no tienes. Gana con lo que tienes.' },
      ],
      post: [
        { who: 'narrator', text: 'En el fondo del cañón encontraron una nota de suministros de los bandidos.' },
        { who: 'commander', text: '"Reunión en el aserradero del bosque." Ese es el siguiente.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'El paso es estrecho. No pueden venir todos a la vez. ¡Aquí los frenamos!' } ],
        wave: [ { who: 'sera', text: '¡Vienen más por detrás del cañón! ¡Esta vez son más!' } ],
        last: [ { who: 'commander', text: 'El último. Que no escape.' } ],
      },
    },
    4: {
      pre: [
        { who: 'bram', text: 'La otra entrada del cañón. Hoy vienen con todo.' },
        { who: 'sera', text: 'Hay alguien escondido en esas sombras.' },
        { who: 'bram', text: 'Un asesino. Se cuela detrás de los escudos. Cuidado.' },
        { who: 'commander', text: 'Sera, a mi lado. No te separes.' },
      ],
      post: [
        { who: 'commander', text: 'Ese asesino llevaba un extraño fragmento de cristal.' },
        { who: 'sera', text: 'Es violeta. Al tocarlo, se me entumece la mano.' },
        { who: 'commander', text: '(¿La cicatriz… reacciona?)' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Bloqueen la entrada. Primero busquemos al que se coló.' } ],
        wave: [ { who: 'bram', text: 'Las sombras se movieron. ¡Vigilen la retaguardia!' } ],
        danger: [ { who: 'bram', text: 'El lado de {ally} se derrumba. ¡Los heridos, tras los escudos!' } ],
      },
    },
    5: {
      pre: [
        { who: 'narrator', text: 'El aserradero del bosque. Allí se apilaba la leña de invierno de la aldea.' },
        { who: 'bram', text: 'Si queman esto, la aldea no pasará el invierno. Hay que defenderlo.' },
        { who: 'commander', text: 'Entre los árboles reciben menos flechas. Usen el bosque.' },
        { who: 'sera', text: 'Allí hay un grandullón… parece que pelea solo con los puños.' },
      ],
      post: [
        { who: 'bark', text: 'Perdí, perdí. Si vas a matarme, hazlo rápido.' },
        { who: 'commander', text: '¿Por qué fallabas los golpes a propósito? Lo vi todo.' },
        { who: 'bark', text: '…Soy Bark. Me hice bandido por hambre; matar gente no me va.' },
        { who: 'commander', text: 'Entonces guíanos. Hasta la base de los bandidos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Peleen de espaldas a la leña. ¡Ni un paso atrás!' } ],
        wave: [ { who: 'bram', text: 'Refuerzos desde el fondo del bosque. ¡Cierren filas!' } ],
        last: [ { who: 'sera', text: '¡Queda uno! Ese grandullón no ha atacado en todo el rato…' } ],
      },
    },
    6: {
      pre: [
        { who: 'bark', text: 'Ja, qué agallas tienes, capi. Bueno, te sigo.' },
        { who: 'bark', text: 'Pasando este bosque está el puesto avanzado bandido. Les enseño un atajo.' },
        { who: 'bram', text: 'Es la primera vez que somos nosotros quienes atacamos.' },
        { who: 'bram', text: 'No es lo mismo que defender. Hace falta valor para avanzar.' },
        { who: 'commander', text: 'Rodeamos y atacamos por el flanco. Bark, el frente es tuyo.' },
        { who: 'bark', text: 'Ya de entrada el puesto más duro. ¡Me encanta!' },
      ],
      post: [
        { who: 'bark', text: '¿Qué tal? Sirvo para algo, ¿eh?' },
        { who: 'sera', text: '¿No estás herido? …De verdad te has puesto de nuestro lado.' },
        { who: 'commander', text: 'Desde hoy, Bark es parte del clan.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Adelante! Esta vez vamos nosotros a por ellos.' } ],
        last: [ { who: 'bark', text: '¡Tumbamos a ese y la base es nuestra!' } ],
      },
    },
    7: {
      pre: [
        { who: 'narrator', text: 'Al salir del bosque, se extendían dunas sin fin.' },
        { who: 'bark', text: 'La ruta de suministros bandida. Agua y comida, todo pasa por aquí.' },
        { who: 'bram', text: 'En la arena no hay dónde esconderse. Cuidado con los arqueros.' },
        { who: 'commander', text: 'Si cortamos los suministros, la banda pasará hambre. Vamos.' },
      ],
      post: [
        { who: 'sera', text: 'Las cajas de suministros llevan letras del Imperio.' },
        { who: 'bram', text: '¿Bandidos con armas imperiales? ¿De dónde las sacaron?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡No se queden mucho al alcance de los arqueros!' } ],
        wave: [ { who: 'bark', text: '¡Emboscada tras las dunas! Sabía que pasaría.' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡sangras demasiado! ¡Te curo ahora!' } ],
      },
    },
    8: {
      pre: [
        { who: 'narrator', text: 'Un oasis en mitad del desierto. Allí estaba el almacén de los bandidos.' },
        { who: 'bark', text: 'El jefe recogía armas aquí. De un mago encapuchado.' },
        { who: 'commander', text: '¿Un mago? ¿Un mago que trata con bandidos?' },
        { who: 'bram', text: 'Si asaltamos el almacén, lo sabremos.' },
      ],
      post: [
        { who: 'commander', text: 'Este libro de cuentas… pagan monedas de oro por cristales violetas.' },
        { who: 'bram', text: 'Mover bandidos con simples cristales. Hay alguien detrás.' },
        { who: 'bark', text: 'El jefe está en el Paso de Roca Roja. Zona volcánica.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Barran primero a los guardias. ¡Protegemos los suministros!' } ],
        last: [ { who: 'bark', text: '¡El último! Seguro que lleva la llave del almacén.' } ],
      },
    },
    9: {
      pre: [
        { who: 'narrator', text: 'El Paso de Roca Roja. La lava corría por las grietas del suelo.' },
        { who: 'bram', text: 'Si te quedas mucho junto a la lava, te quemarás.' },
        { who: 'sera', text: 'Al terminar tu turno, quédate a una casilla de la lava.' },
        { who: 'commander', text: 'La guarida del jefe está a un paso. No podemos agotarnos aquí.' },
      ],
      post: [
        { who: 'bark', text: 'Allá arriba está la fortaleza del jefe. Acabemos esta noche.' },
        { who: 'commander', text: 'Descansen todos. Atacamos al amanecer.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Cuidado con que no los empujen hacia la lava!' } ],
        wave: [ { who: 'bram', text: 'Bajan refuerzos de la fortaleza. ¡Defiendan el paso!' } ],
        danger: [ { who: 'bram', text: '¡Retrocede, {ally}! ¡Si te excedes, no protegerás nada!' } ],
        last: [ { who: 'sera', text: '¡Ya solo queda uno! ¡Concentración hasta el final!' } ],
      },
    },
    10: {
      pre: [
        { who: 'narrator', text: 'La fortaleza bandida al pie del volcán. Las banderas ondeaban en el viento ardiente.' },
        { who: 'boss', text: '¿Una criatura con un palito está al mando? ¡Qué chiste!' },
        { who: 'commander', text: 'Hoy se acaba tu acoso a la aldea.' },
        { who: 'boss', text: '¡Bark, maldito traidor! ¡A ti te echo a la lava primero!' },
        { who: 'bark', text: 'Jefe, ahora tengo a otra persona al mando.' },
        { who: 'bram', text: 'Primero limpien a los secuaces del jefe. Sin prisas.' },
      ],
      post: [
        { who: 'boss', text: 'Ugh… Me lo prometió… que el fuego se abriría….' },
        { who: 'commander', text: '¿Quién te lo prometió? ¿Qué significa que el fuego se abrirá?' },
        { who: 'narrator', text: 'El cabecilla expiró sin llegar a responder.' },
        { who: 'bram', text: 'Esto no ha terminado. Puede que solo sea el comienzo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Si cae el jefe, la banda se dispersa!' } ],
        boss: [ { who: 'boss', text: '¡Una miserable milicia! ¡Prueben mi hacha!' } ],
        wave: [ { who: 'bark', text: '¡La élite del fondo de la fortaleza! ¡La guardia del jefe!' } ],
        danger: [ { who: 'sera', text: '¡El jefe va a por {ally}! ¡Abran distancia!' } ],
        last: [ { who: 'bark', text: '¡Solo queda uno! ¡Hoy se acaba la banda!' } ],
      },
    },
    // ═══ Episode 2: La Conspiración Helada ═══
    11: {
      pre: [
        { who: 'narrator', text: 'Fuenteblanca, aldea al pie del monte. Hasta el pozo se había congelado.' },
        { who: 'sera', text: 'Esos soldados que vienen hacia la aldea… llevan armadura del reino.' },
        { who: 'bram', text: 'Tienen los ojos vacíos. No están vivos. Son cadáveres atados por el hielo.' },
        { who: 'commander', text: '¡Dentro de las murallas! ¡Defendemos la puerta!' },
      ],
      post: [
        { who: 'bark', text: 'Los tumbas y no sangran. Qué escalofrío.' },
        { who: 'bram', text: 'Ese emblema… es la guarnición del norte, disuelta hace 15 años.' },
        { who: 'commander', text: '¿Por qué una guarnición muerta camina ahora?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Corten primero a los que se pegan a la muralla!' } ],
        wave: [ { who: 'sera', text: '¡Salen más de la ventisca! ¡No se acaban!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Rompámoslo como hielo!' } ],
      },
    },
    12: {
      pre: [
        { who: 'narrator', text: 'Los habitantes de Fuenteblanca empezaron a evacuar montaña abajo.' },
        { who: 'sera', text: 'Entre esos no muertos hay algunos con hábito de sacerdote.' },
        { who: 'sera', text: 'Esos sacerdotes vuelven a levantar a los otros cadáveres.' },
        { who: 'commander', text: 'Vayan a por los sacerdotes. Así terminará la pelea.' },
        { who: 'bram', text: 'Aguanten hasta que todos los refugiados salgan por la puerta.' },
      ],
      post: [
        { who: 'sera', text: 'Sacerdotes muertos que pelean invocando el nombre de un dios… Qué horror.' },
        { who: 'commander', text: 'Alguien les hizo esto. Lo encontraré, sea como sea.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defendemos la muralla hasta que salgan todos los refugiados!' } ],
        wave: [ { who: 'bram', text: 'Los caballeros van delante. No pierdan de vista al sacerdote tras el escudo.' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡tienes las manos congeladas! ¡Aguanta un momento!' } ],
      },
    },
    13: {
      pre: [
        { who: 'narrator', text: 'Fortaleza Puertahelada, el paso del norte. La puerta estaba cubierta de hielo.' },
        { who: 'kasha', text: 'Vaya, ¿la milicia de pueblo llegó hasta aquí?' },
        { who: 'kasha', text: 'Soy Kasha, de los mercenarios de la Pluma Negra. Esta fortaleza es nuestra.' },
        { who: 'commander', text: 'Me da igual de quién sea. Juntos acabamos antes.' },
        { who: 'kasha', text: '¿Juntos? Mejor apostemos quién llega antes a la sala del señor.' },
        { who: 'bark', text: 'Capi, esa mujer sonríe de un modo que da mala espina.' },
      ],
      post: [
        { who: 'kasha', text: 'Tsk, llegué un paso tarde. Tuviste suerte.' },
        { who: 'commander', text: 'No fue suerte. Los miembros del clan lo hicieron bien.' },
        { who: 'kasha', text: 'Hmph, la próxima llego yo primero. Recuérdalo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Cuidado con los zapadores. ¡Si cruzan la puerta, usarán bombas!' } ],
        wave: [ { who: 'kasha', text: 'Refuerzos en la muralla. Te los mando a ti.' } ],
        last: [ { who: 'bark', text: '¡Estamos ante la sala del señor! ¡Tumbamos a ese y ganamos!' } ],
      },
    },
    14: {
      pre: [
        { who: 'narrator', text: 'Campamento bajo la fortaleza. En plena noche, la hoguera titilaba.' },
        { who: 'kasha', text: 'No es momento de dormir. Hay asesinos que van a por ti.' },
        { who: 'commander', text: '¿A por mí? ¿Por qué, si solo comando una milicia de pueblo?' },
        { who: 'kasha', text: 'Lo ponía en el encargo: "Quien tenga una cicatriz en la mano."' },
        { who: 'bram', text: 'Todos en pie. Defendemos el campamento.' },
      ],
      post: [
        { who: 'commander', text: '¿Por qué me avisaste? Somos rivales.' },
        { who: 'kasha', text: 'Si mi rival muere en sueños, no tiene gracia.' },
        { who: 'bram', text: 'Alguien va tras esa cicatriz. Desde ahora, nunca vayas sin compañía.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Junto al fuego! ¡No se dispersen en la oscuridad!' } ],
        wave: [ { who: 'kasha', text: 'Un invocador sacó bestias. ¡Primero ese lado!' } ],
        danger: [ { who: 'commander', text: '¡Los asesinos van a por los heridos! ¡Protejan a {ally}!' } ],
        last: [ { who: 'bark', text: '¡El último asesino! ¡Dejémoslo vivo para saber quién lo envía!' } ],
      },
    },
    15: {
      pre: [
        { who: 'narrator', text: 'Bajo el glaciar asomaron unas ruinas antiguas.' },
        { who: 'bram', text: 'El frío sale de aquí dentro.' },
        { who: 'sera', text: 'El grabado de la pared… tiene forma de estrella partida.' },
        { who: 'commander', text: '(Es idéntica a mi cicatriz.)' },
        { who: 'commander', text: 'Dentro hay magos atrincherados. Abrimos paso.' },
      ],
      post: [
        { who: 'narrator', text: 'Cuando el grabado tocó la mano de {commander}, brilló débilmente.' },
        { who: 'sera', text: '{commander}, esa luz… ¿reaccionó contigo?' },
        { who: 'commander', text: 'No lo sé. Pero no creo que sea casualidad.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Los magos aguantan poco los golpes. ¡Péguense a ellos y acaben!' } ],
        wave: [ { who: 'bram', text: 'Chamanes desde el fondo de las ruinas. Cuidado con las maldiciones.' } ],
        last: [ { who: 'sera', text: '¡Solo uno más! ¡El grabado sigue brillando!' } ],
      },
    },
    16: {
      pre: [
        { who: 'narrator', text: 'La cresta helada. El origen del frío estaba en la cumbre.' },
        { who: 'kasha', text: 'Carrera hasta la cumbre. Esta vez gano yo.' },
        { who: 'bram', text: 'Sus caballeros van juntos. Es una formación de cobertura.' },
        { who: 'bram', text: 'Al que está junto a un caballero no le aciertas desde lejos.' },
        { who: 'commander', text: 'Primero los caballeros, para romper la formación. Luego la retaguardia.' },
      ],
      post: [
        { who: 'kasha', text: '…Perdí otra vez. Eres mejor de lo que creía.' },
        { who: 'commander', text: '¿Es un cumplido? Creo que es la primera vez que te lo oigo.' },
        { who: 'kasha', text: 'No te equivoques. Es una observación.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Rompan la formación de caballeros! ¡Sin cobertura será fácil!' } ],
        wave: [ { who: 'bark', text: '¡Una tropa de lanceros baja por la cresta!' } ],
        danger: [ { who: 'bram', text: '{ally}, ¡ponte en defensa y aguanta un turno!' } ],
      },
    },
    17: {
      pre: [
        { who: 'narrator', text: 'Otras ruinas tras la cresta. Resonaban gritos.' },
        { who: 'bark', text: '¿Esos no son los de la Pluma Negra? Los tienen rodeados.' },
        { who: 'sera', text: '¡Kasha está herida! ¿Qué hacemos, {commander}?' },
        { who: 'commander', text: 'La salvamos. Para competir, hay que seguir con vida.' },
      ],
      post: [
        { who: 'kasha', text: '…Gracias. No pienso repetirlo.' },
        { who: 'kasha', text: 'Era una trampa. Quien nos contrató filtró nuestra posición.' },
        { who: 'commander', text: '¿Y quién los contrató?' },
        { who: 'kasha', text: 'Un agente de la capital real. No le vi la cara.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Rompemos el cerco! ¡Abran paso hasta la Pluma Negra!' } ],
        wave: [ { who: 'kasha', text: '¡Los zapadores quieren volar los pilares de las ruinas! ¡Deténganlos!' } ],
        last: [ { who: 'kasha', text: 'El último me lo cobro yo. ¡Aparta!' } ],
      },
    },
    18: {
      pre: [
        { who: 'narrator', text: 'Campamento bajo la cumbre. La ventisca no cesaba desde hacía tres días.' },
        { who: 'bram', text: 'Tengo algo que decir. Quien invoca el frío… creo que sé quién es.' },
        { who: 'bram', text: 'Halvar. Un caballero real que luchó a mi lado hace 15 años.' },
        { who: 'bram', text: 'Después de aquella noche, entró en la guardia del archimago.' },
        { who: 'commander', text: 'El archimago… ¿se refiere al señor Ordin?' },
        { who: 'bram', text: '……Primero sobrevivamos a esta noche. Ya vienen.' },
      ],
      post: [
        { who: 'commander', text: 'Bram, termine lo que estaba contando.' },
        { who: 'bram', text: 'Una sospecha sin certeza es más peligrosa que una espada.' },
        { who: 'bram', text: 'Cuando veamos a Halvar, lo oiremos de su propia boca.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'La ventisca no deja ver. ¡Peleen juntos!' } ],
        wave: [ { who: 'bram', text: '¡Es un ataque masivo! ¡Estrechen la defensa en una sola línea!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡tienes el cuerpo helado! ¡Retírate!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡Quitamos a este y a dormir un rato!' } ],
      },
    },
    19: {
      pre: [
        { who: 'narrator', text: 'Una grieta en el glaciar. Por debajo se filtraba una luz violeta.' },
        { who: 'sera', text: 'Esto… es igual que la historia de la noche en que se partió el cielo.' },
        { who: 'bram', text: 'Es la grieta de hace 15 años. Pequeña, pero no hay duda.' },
        { who: 'commander', text: 'Hay que frenar lo que sale de ahí. Bajamos.' },
      ],
      post: [
        { who: 'narrator', text: 'La grieta se encogió, pero no llegó a cerrarse.' },
        { who: 'commander', text: 'De esta grieta salía el frío que cubrió las montañas.' },
        { who: 'bram', text: 'Alguien la abrió a propósito. El de la cumbre.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Córtenlos según salgan! ¡Que no se extiendan!' } ],
        wave: [ { who: 'sera', text: '¡La grieta creció como un latido! ¡Salen más!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡A empujar la grieta hasta cerrarla!' } ],
      },
    },
    20: {
      pre: [
        { who: 'narrator', text: 'La cumbre de los Montes Velo de Nieve: una ciudadela hecha de hielo.' },
        { who: 'bram', text: '¡Halvar! ¡Soy yo, Bram! ¿Por qué haces esto?' },
        { who: 'boss', text: 'Bram… cuánto tiempo. Yo solo sigo órdenes.' },
        { who: 'boss', text: 'Encontrar la Llave. Esa es la orden que me dieron.' },
        { who: 'boss', text: 'Esa cicatriz en la mano… sí, la criatura de la noche partida.' },
        { who: 'commander', text: '¿Me conoces? ¿¡Qué demonios es esa Llave!?' },
      ],
      post: [
        { who: 'boss', text: 'Bram… gracias… por fin se derrite el hielo….' },
        { who: 'boss', text: 'No confíes… en el archimago….' },
        { who: 'narrator', text: 'Antes de terminar, el cuerpo del caballero se deshizo en polvo de nieve.' },
        { who: 'bram', text: '……Descansa en paz, amigo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Si lo detenemos, las montañas se salvan. ¡Vamos!' } ],
        boss: [ { who: 'boss', text: 'Congélense. La duda, los recuerdos, todo.' } ],
        wave: [ { who: 'kasha', text: '¡La Pluma Negra frena los refuerzos de atrás! ¡Mira al frente!' } ],
        danger: [ { who: 'bram', text: '¡{ally}! ¡Que no te arrastre el frío, retrocede!' } ],
        last: [ { who: 'sera', text: 'Ya solo queda uno. ¡Acabemos con este frío!' } ],
      },
    },
    // ═══ Episode 3: La Maldición de la Ciénaga ═══
    21: {
      pre: [
        { who: 'narrator', text: 'La aldea de Vado de Cañas, en el pantano. Las casas sobre pilotes estaban torcidas.' },
        { who: 'sera', text: 'La mitad de la aldea está enferma. No pueden moverse.' },
        { who: 'bark', text: 'Entonces toca aguantar aquí. Ahí vienen en manada.' },
        { who: 'commander', text: 'Si se traban en un vado, los acribillan. Pisen tierra firme.' },
      ],
      post: [
        { who: 'sera', text: 'Dicen que esas bestias eran ciervos y lobos del pantano.' },
        { who: 'commander', text: 'No enfermaron: los transformaron. ¿Quién?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defendemos la barrera de la aldea! ¡Que no los arrastren al agua!' } ],
        wave: [ { who: 'bark', text: '¡Algo sale reptando del agua! ¡Segundo grupo!' } ],
        last: [ { who: 'sera', text: 'Queda uno. ¡La gente de la aldea nos está mirando!' } ],
      },
    },
    22: {
      pre: [
        { who: 'narrator', text: 'Sera convirtió la casa comunal en una enfermería.' },
        { who: 'sera', text: 'No puedo dejar de curar. Protejan este lugar, por favor.' },
        { who: 'bram', text: 'Hay invocadores y chamanes. Van a llover maldiciones.' },
        { who: 'commander', text: 'Las invocaciones desaparecen si cae quien las invoca. A por ellos.' },
      ],
      post: [
        { who: 'sera', text: 'Todos sobrevivieron. Hoy… no ha muerto nadie.' },
        { who: 'commander', text: 'Sera, llevas tres días sin dormir. Descansa ya.' },
        { who: 'sera', text: 'Me da miedo que alguien muera si descanso.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan los muros de la enfermería! ¡Sera está curando!' } ],
        wave: [ { who: 'bram', text: 'Hasta traen sacerdotes. Ataquen antes de que se curen.' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Voy para allá, aguanta!' } ],
      },
    },
    23: {
      pre: [
        { who: 'narrator', text: 'El manglar al borde del pantano. Las raíces cerraban el camino.' },
        { who: 'bark', text: 'Dicen que la plaga empezó en lo profundo de este bosque.' },
        { who: 'bram', text: 'Entre los árboles es fácil esconderse. Para ellos y para nosotros.' },
        { who: 'commander', text: 'Peleen pegados al bosque. Los asesinos saltan desde las sombras.' },
      ],
      post: [
        { who: 'narrator', text: 'En el corazón del bosque se alzaba un tótem moldeado con barro negro.' },
        { who: 'sera', text: 'La enfermedad sale de este tótem. ¡Lo pusieron a propósito!' },
        { who: 'commander', text: 'No era un desastre natural. Alguien enfermó el pantano.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Revisen detrás de los árboles! ¡Hay asesinos ocultos!' } ],
        wave: [ { who: 'bark', text: '¡Los zapadores enterraron bombas entre las raíces!' } ],
        last: [ { who: 'commander', text: 'El último. ¡Se abre el camino al tótem!' } ],
      },
    },
    24: {
      pre: [
        { who: 'narrator', text: 'No había un solo tótem. Estaban por todo el pantano.' },
        { who: 'commander', text: 'Primero rompemos el más grande. Esta vez atacamos nosotros.' },
        { who: 'bark', text: 'Esas montañas de músculo son todos luchadores. De mi gremio.' },
        { who: 'bark', text: 'Lo peligroso de un luchador es el contragolpe. No vayan a por ellos sin apoyo.' },
      ],
      post: [
        { who: 'narrator', text: 'Al caer el tótem, un humo negro escapó del agua estancada.' },
        { who: 'bark', text: 'Uf, me hormiguean los puños. Pero qué a gusto me he quedado.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Avanzamos hasta el tótem! ¡Que el barro no los atrape!' } ],
        wave: [ { who: 'bram', text: 'La élite que guarda el tótem. Enfréntenlos de dos en dos.' } ],
        danger: [ { who: 'bark', text: '¡Hirieron a {ally}! ¡Yo cubro el frente, retírate!' } ],
      },
    },
    25: {
      pre: [
        { who: 'narrator', text: 'En pleno pantano apareció un templo antiguo medio hundido.' },
        { who: 'bram', text: 'Este es el corazón de la maldición. Hasta el olor es distinto.' },
        { who: 'sera', text: 'Se oyen conjuros dentro del templo. Están en pleno ritual.' },
        { who: 'commander', text: 'Lo cortamos antes de que acaben. ¡Adentro!' },
      ],
      post: [
        { who: 'commander', text: 'Este objeto ritual… lleva grabado el escudo de la familia real de Arden.' },
        { who: 'bark', text: '¿La familia real? ¿La misma que nos envió?' },
        { who: 'bram', text: '……Guárdalo de momento. Servirá de prueba.' },
        { who: 'sera', text: 'Tío Bram, usted sabe algo, ¿verdad?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero los que conjuran! ¡Detengan el ritual!' } ],
        wave: [ { who: 'bram', text: 'Salen caballeros del fondo del templo. No los reciban de frente.' } ],
        last: [ { who: 'sera', text: '¡El último! ¡El conjuro se está rompiendo!' } ],
      },
    },
    26: {
      pre: [
        { who: 'narrator', text: 'Por fin, los habitantes de Vado de Cañas decidieron abandonar el pantano.' },
        { who: 'commander', text: 'Avanzamos escoltando la columna. Sin parar.' },
        { who: 'sera', text: '¡No! ¡Los enfermos no pueden seguir ese ritmo!' },
        { who: 'commander', text: 'Si nos quedamos aquí, morimos todos. Yo tampoco quiero elegir.' },
        { who: 'bram', text: 'Los dos tienen razón. Así que busquen cómo proteger a ambos.' },
        { who: 'commander', text: '……Montamos una defensa tras la columna. Iremos al paso de los enfermos.' },
      ],
      post: [
        { who: 'sera', text: 'Perdona por gritarte antes.' },
        { who: 'commander', text: 'No. Si no lo hubieras dicho, habría elegido mal.' },
        { who: 'bram', text: 'No decidir sin escuchar a nadie. Eso también es comandar.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Cubrimos la retaguardia de los refugiados! ¡Que no se pierda nadie!' } ],
        wave: [ { who: 'bark', text: '¡Salen más del pantano! ¡Por el flanco de la columna!' } ],
        danger: [ { who: 'sera', text: '¡Si cae el lado de {ally}, la columna se derrumba! ¡Apóyenlo!' } ],
        last: [ { who: 'bram', text: 'Queda uno. La columna está a salvo.' } ],
      },
    },
    27: {
      pre: [
        { who: 'narrator', text: 'Ruinas al otro lado del templo. Caballeros de capa roja habían acampado allí.' },
        { who: 'bram', text: 'La orden de caballería del Imperio Volkar. ¿Qué hacen en un pantano ajeno?' },
        { who: 'kasha', text: 'Cuánto tiempo. Olí a los del Imperio y los seguí.' },
        { who: 'commander', text: '¿Kasha? …Vamos juntos. Esta vez sin carreras.' },
        { who: 'kasha', text: 'Hmph, solo por esta vez.' },
      ],
      post: [
        { who: 'kasha', text: 'Un caballero imperial llevaba esto encima. Las siguientes órdenes.' },
        { who: 'commander', text: '"Terminado el pantano, al volcán." ¿El Imperio también está metido?' },
        { who: 'bram', text: 'O el Imperio también recibe órdenes de alguien.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Junto a los caballeros hay cobertura. ¡Que los asesinos se cuelen!' } ],
        wave: [ { who: 'kasha', text: '¡Arqueros tras las ruinas! ¡Tomaron el terreno alto!' } ],
        last: [ { who: 'kasha', text: 'El último es mío. El que lleva las órdenes.' } ],
      },
    },
    28: {
      pre: [
        { who: 'narrator', text: 'Bajo el templo. En el suelo, ya sin agua, se abría una grieta.' },
        { who: 'sera', text: 'Es igual a la del norte. Una grieta violeta.' },
        { who: 'commander', text: 'La cicatriz me punza. Aquí abajo está la raíz de la maldición.' },
        { who: 'bram', text: 'Hay magos custodiando la grieta. Corten el ritual.' },
      ],
      post: [
        { who: 'narrator', text: 'La segunda grieta se calmó. Pero no se cerró.' },
        { who: 'commander', text: 'En el norte y aquí. Alguien está abriendo grietas una a una.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Presionen hacia la grieta! ¡Rompan el ritual!' } ],
        wave: [ { who: 'bark', text: '¡Salen zapadores de la grieta! ¡Huele a bomba!' } ],
        danger: [ { who: 'bram', text: '¡{ally}! ¡Que no te consuma la energía de la grieta!' } ],
      },
    },
    29: {
      pre: [
        { who: 'narrator', text: 'Lo más hondo del pantano, cubierto de miasma. No se veía nada.' },
        { who: 'sera', text: 'Esta niebla es la enfermedad. No podemos quedarnos mucho.' },
        { who: 'bram', text: 'Más allá está el templo donde despertó el Señor del pantano.' },
        { who: 'commander', text: 'Abrimos camino. En la niebla, no se separen.' },
      ],
      post: [
        { who: 'narrator', text: 'La niebla se abrió y apareció la sombra de un templo enorme.' },
        { who: 'bark', text: 'El que está ahí dentro es el verdadero rey.' },
        { who: 'commander', text: 'Mañana lo terminamos. Esta noche, todos a entrar en calor.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡En la niebla, vayan juntos! ¡Busquen ataques combinados!' } ],
        wave: [ { who: 'sera', text: '¡Las invocaciones no dejan de aumentar en la niebla!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Se abre el camino!' } ],
      },
    },
    30: {
      pre: [
        { who: 'narrator', text: 'Lo más profundo del templo. El agua del pantano se alzó con forma colosal.' },
        { who: 'boss', text: 'Seres diminutos. Huelen a quien me invocó.' },
        { who: 'commander', text: '¿Quien te invocó? ¿¡Quién es!?' },
        { who: 'boss', text: 'Criatura de la mano violeta. Pronto tú también irás con él.' },
        { who: 'sera', text: 'Si cae esa cosa, el pantano quedará limpio. ¡Vamos!' },
      ],
      post: [
        { who: 'boss', text: 'El pantano… no se seca… el fuego… es el siguiente….' },
        { who: 'narrator', text: 'Donde se derritió el Señor, encontraron un mapa viejo.' },
        { who: 'commander', text: 'Hay tres lugares marcados. El norte, el pantano y el Imperio.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero quitamos a los hechiceros que protegen al Señor!' } ],
        boss: [ { who: 'boss', text: 'El pantano los tragará. Su aliento y su nombre.' } ],
        wave: [ { who: 'bram', text: 'Las invocaciones no paran. ¡Vayan a por el cuerpo principal!' } ],
        danger: [ { who: 'sera', text: '¡El veneno se extiende! ¡Ven conmigo, {ally}!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡Terminemos la limpieza del pantano!' } ],
      },
    },
    // ═══ Episode 4: El Imperio en Llamas ═══
    31: {
      pre: [
        { who: 'narrator', text: 'El fuerte de piedra fronterizo. El último paso que defendían los rebeldes.' },
        { who: 'narrator', text: 'Más allá del horizonte brillaban las puntas de lanza del ejército imperial.' },
        { who: 'bram', text: 'Son muchos. Pero las murallas son gruesas. Podemos aguantar.' },
        { who: 'commander', text: 'Córtenlos según se peguen a la muralla. Sin prisas con el orden de ataque.' },
      ],
      post: [
        { who: 'narrator', text: 'Los soldados rebeldes vitorearon al clan.' },
        { who: 'bark', text: 'Nunca pensé que la gente de este país nos aplaudiría.' },
        { who: 'commander', text: 'Esta gente solo quiere proteger su hogar. Como nosotros.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡De espaldas a la muralla! ¡Si cae este paso, se acabó!' } ],
        wave: [ { who: 'bram', text: 'Lanceros imperiales. La fila es larga: golpeen el flanco.' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡retrocede tras la muralla!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡El paso es nuestro!' } ],
      },
    },
    32: {
      pre: [
        { who: 'narrator', text: 'El cañón carmesí que lleva al interior del Imperio.' },
        { who: 'kasha', text: 'Alto, {commander}. No vengas por este camino.' },
        { who: 'kasha', text: 'El grueso de la Pluma Negra firmó con el Imperio. Y yo soy la líder.' },
        { who: 'commander', text: '¿Entonces somos enemigos?' },
        { who: 'kasha', text: '…Yo no desenvainaré. Pero el cañón está lleno de tropas imperiales.' },
      ],
      post: [
        { who: 'commander', text: 'Kasha no apareció en ningún momento.' },
        { who: 'sera', text: 'Ella también lo está pasando mal. Viste su cara.' },
        { who: 'bram', text: 'Una espada atada por un contrato acaba cortando sus propias ataduras.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero el terreno alto! ¡Si fallamos el primer movimiento, quedamos atrapados!' } ],
        wave: [ { who: 'bark', text: '¡Llueven asesinos por ambos lados del cañón!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Salimos del cañón!' } ],
      },
    },
    33: {
      pre: [
        { who: 'narrator', text: 'Pozo Ceniza, aldea rebelde al pie del volcán.' },
        { who: 'narrator', text: 'Los canales de lava que la rodeaban hervían en rojo.' },
        { who: 'bram', text: 'Vienen zapadores con bombas. Irán a por la muralla.' },
        { who: 'sera', text: 'Si se quedan junto a la lava, se queman. Elijan bien su posición.' },
        { who: 'commander', text: 'Primero los zapadores. ¡Antes de que estallen las bombas!' },
      ],
      post: [
        { who: 'narrator', text: 'Los niños de la aldea ofrecieron pan chamuscado a los miembros del clan.' },
        { who: 'bark', text: 'Quién diría que el pan quemado estaba tan rico.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Que los zapadores no lleguen a la muralla! ¡Córtenlos antes!' } ],
        wave: [ { who: 'bram', text: 'Una unidad de magos dispara fuego desde atrás. ¡Dispérsense!' } ],
        danger: [ { who: 'sera', text: '¡Tienes quemaduras graves! ¡Aléjate de la lava, {ally}!' } ],
        last: [ { who: 'sera', text: '¡El último! ¡La aldea está a salvo!' } ],
      },
    },
    34: {
      pre: [
        { who: 'narrator', text: 'El borde del cráter. El lugar de ritual de los magos imperiales.' },
        { who: 'bram', text: 'Es un ritual para despertar el volcán. Si sale bien, esta tierra será un mar de fuego.' },
        { who: 'commander', text: 'El frío del norte, la plaga del pantano… y ahora el fuego.' },
        { who: 'commander', text: 'Cortamos el ritual. Si la lava bloquea el camino, la rodeamos.' },
      ],
      post: [
        { who: 'narrator', text: 'Roto el ritual, el rugido del cráter se apagó.' },
        { who: 'commander', text: 'Aquí también hay un grabado de estrella partida en el suelo.' },
        { who: 'bram', text: 'Significa que los tres lugares los diseñó la misma persona.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Los hechiceros están en pleno ritual. ¡No hay tiempo, a la carga!' } ],
        wave: [ { who: 'bark', text: '¡Suben invocaciones trepando del cráter!' } ],
        last: [ { who: 'commander', text: 'El último hechicero. ¡Corten el ritual del todo!' } ],
      },
    },
    35: {
      pre: [
        { who: 'narrator', text: 'Una ciudadela de obsidiana: la Puerta de Obsidiana. Clave de la defensa occidental del Imperio.' },
        { who: 'narrator', text: 'La aldea al pie de la ciudadela ardía a manos del ejército imperial.' },
        { who: 'kasha', text: '……Esto no estaba en el contrato. Quemar a su propio pueblo.' },
        { who: 'kasha', text: 'La Pluma Negra rompe el contrato. Desde ahora, estoy de tu lado.' },
        { who: 'commander', text: 'Gracias por volver, Kasha.' },
        { who: 'kasha', text: 'No te equivoques. No quiero que se ensucie mi nombre.' },
      ],
      post: [
        { who: 'kasha', text: 'Encontré esto en el cuarto del comandante imperial. Una carta del reino.' },
        { who: 'commander', text: 'La firma está borrada. Pero esta letra…' },
        { who: 'bram', text: 'Vamos al castillo imperial. El original lo tendrá el emperador.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defendemos la ciudadela y abrimos la puerta! ¡Las dos cosas!' } ],
        wave: [ { who: 'kasha', text: '¡La Pluma Negra se encarga de los arqueros de la muralla!' } ],
        danger: [ { who: 'kasha', text: '¡El lado de {ally} quedó expuesto! ¡Te cubro!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Abramos la puerta de par en par!' } ],
      },
    },
    36: {
      pre: [
        { who: 'narrator', text: 'El canal de lava que abastece al castillo imperial.' },
        { who: 'bark', text: 'Sobre ese puente van y vienen carros de suministros sin parar.' },
        { who: 'bram', text: 'En el puente, usen los empujones. Si empujas contra algo bloqueado, chocan.' },
        { who: 'commander', text: 'Si cortamos el suministro, el castillo se tambalea. ¡Vamos!' },
      ],
      post: [
        { who: 'narrator', text: 'El puente de suministros cayó, y el castillo imperial quedó aislado tras el canal.' },
        { who: 'kasha', text: 'Ahora el emperador es una rata acorralada.' },
        { who: 'commander', text: 'Una rata acorralada es la más feroz. No se confíen.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Tomamos el puente! ¡Que no los empujen hacia la lava!' } ],
        wave: [ { who: 'bark', text: '¡Baja una orden de caballería del castillo! ¡Al final del puente!' } ],
        last: [ { who: 'kasha', text: 'El último. ¡Preparen el corte del puente!' } ],
      },
    },
    37: {
      pre: [
        { who: 'narrator', text: 'El cuartel rebelde. El emperador lanzó su último contraataque.' },
        { who: 'narrator', text: 'Bolas de fuego caían del cielo como lluvia.' },
        { who: 'sera', text: '¡Hay heridos por todas partes! ¡Si cae el cuartel, mueren todos!' },
        { who: 'bram', text: 'En esta batalla gana quien aguanta. Defiendan la posición.' },
        { who: 'commander', text: '¡Repartimos: unos aguantan en defensa y otros atacan!' },
      ],
      post: [
        { who: 'narrator', text: 'La lluvia de fuego cesó, y el ejército del emperador se retiró.' },
        { who: 'sera', text: 'Aguantamos… lo logramos.' },
        { who: 'bram', text: 'Excelente, comandante. Ya no podré llamarte peque.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Los que estén ante la barrera, aguanten! ¡Relevo a mi señal!' } ],
        wave: [ { who: 'bram', text: '¡Entran asesinos por los huecos de la barrera! ¡Miren atrás!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡No te quedes entre las llamas!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡El cuartel está a salvo!' } ],
      },
    },
    38: {
      pre: [
        { who: 'narrator', text: 'Las afueras del castillo imperial de Volkar. Tres murallas lo rodeaban.' },
        { who: 'kasha', text: 'Nosotros rompemos la primera muralla; los rebeldes cubren la retaguardia.' },
        { who: 'bram', text: 'Lanceros y arqueros dominan el terreno alto sobre la muralla.' },
        { who: 'commander', text: 'Golpeamos a los que están fuera de la cobertura de los caballeros y abrimos brecha.' },
      ],
      post: [
        { who: 'narrator', text: 'Cayó la muralla exterior del castillo. Del interior brotaba un calor abrasador.' },
        { who: 'commander', text: 'Bajo el palacio hay una energía tan fuerte que me duele la cicatriz.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Apunten a lo alto de la muralla! ¡Quitémosles el terreno alto!' } ],
        wave: [ { who: 'kasha', text: 'La guardia del palacio. ¡Estos son fuertes de verdad!' } ],
        danger: [ { who: 'bram', text: '{ally}, ¡no te quedes bajo la muralla! ¡Muévete!' } ],
      },
    },
    39: {
      pre: [
        { who: 'narrator', text: 'Bajo el palacio. Una grieta enorme latía en rojo.' },
        { who: 'sera', text: 'Mucho más grande que la del norte o la del pantano. Es la tercera.' },
        { who: 'bram', text: 'Si se juntan las tres grietas… se abrirá alguna puerta colosal.' },
        { who: 'commander', text: 'Primero quitamos a sus guardianes. Hay que sellar la grieta.' },
      ],
      post: [
        { who: 'narrator', text: 'En el altar ante la grieta había una carta sellada.' },
        { who: 'commander', text: '"Aviva las llamas, según lo acordado. Cuando se abra la puerta, te recompensaré."' },
        { who: 'commander', text: 'El sello… es de Ordin. El Archimago Real.' },
        { who: 'sera', text: 'Entonces, ¿por quién hemos estado luchando todo este tiempo?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡A por los hechiceros que guardan la grieta! ¡Adentro!' } ],
        wave: [ { who: 'bark', text: '¡La grieta crece y hasta salen zapadores!' } ],
        danger: [ { who: 'sera', text: '¡La energía de la grieta se concentra, {ally}! ¡Apártate!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Vamos al altar!' } ],
      },
    },
    40: {
      pre: [
        { who: 'narrator', text: 'La sala del trono imperial. Todo ardía con el brillo de la lava.' },
        { who: 'boss', text: 'Así que los perros del reino llegaron hasta aquí.' },
        { who: 'commander', text: 'Esta carta te la envió Ordin, ¿verdad? ¿Qué te prometió?' },
        { who: 'boss', text: '¿Promesa? Que si avivaba el fuego, me daría un mundo nuevo.' },
        { who: 'boss', text: 'Ya da igual. ¡Lo reduciré todo a cenizas!' },
      ],
      post: [
        { who: 'boss', text: 'Ugh… nosotros… solo éramos el repuesto….' },
        { who: 'boss', text: 'La verdadera puerta… está en el Abismo… lo que quiere su archimago….' },
        { who: 'narrator', text: 'El cuerpo del emperador se convirtió en llamas y se extinguió.' },
        { who: 'commander', text: 'Repuesto… Entonces lo verdadero ni siquiera ha empezado.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero los magos que rodean al emperador! ¡Cortamos el fuego!' } ],
        boss: [ { who: 'boss', text: '¡Ardan! ¡El fuego del Imperio jamás se apaga!' } ],
        wave: [ { who: 'kasha', text: '¡Salen invocadores de la guardia tras el trono!' } ],
        danger: [ { who: 'bram', text: '¡{ally}! ¡Viene una columna de fuego, esquívala!' } ],
        last: [ { who: 'sera', text: '¡El último! ¡Acabemos con este fuego!' } ],
      },
    },
    // ═══ Episode 5: El Fin del Abismo ═══
    41: {
      pre: [
        { who: 'narrator', text: 'El borde del Abismo. Una base avanzada levantada a toda prisa por los rebeldes y el clan.' },
        { who: 'bram', text: 'Aquí frenamos a lo que suba desde abajo.' },
        { who: 'bark', text: 'Esta empalizada se cae con un soplo de viento fuerte.' },
        { who: 'commander', text: 'Si la empalizada es débil, seremos nosotros el muro. ¡Mantengan sus puestos!' },
      ],
      post: [
        { who: 'sera', text: 'Esos monstruos tienen los ojos vacíos, como los no muertos del norte.' },
        { who: 'commander', text: 'Salieron de la misma mano. Tenemos que bajar.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Suben del Abismo! ¡Defiendan la base!' } ],
        wave: [ { who: 'bram', text: 'La segunda oleada. Los caballeros van al frente.' } ],
        last: [ { who: 'bark', text: '¡El último! ¡Devolvámoslo al agujero!' } ],
      },
    },
    42: {
      pre: [
        { who: 'narrator', text: 'Un sendero en espiral bajaba sin fin por la pared del Abismo.' },
        { who: 'sera', text: 'Cuanto más bajamos, menos luz. Hasta rezar pesa más.' },
        { who: 'bram', text: 'En un camino estrecho, los empujones son temibles. Pónganse del lado de la pared.' },
        { who: 'commander', text: 'Hay enemigos en cada recodo. Bajamos abriéndonos paso uno a uno.' },
      ],
      post: [
        { who: 'narrator', text: 'En la oscuridad, alguien susurró el nombre de {commander}.' },
        { who: 'commander', text: '……¿Alguien me acaba de llamar?' },
        { who: 'bark', text: 'Nadie te llamó, capi. No digas esas cosas, que me dan escalofríos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Aprovechemos la bajada para empujar! ¡Adelante!' } ],
        wave: [ { who: 'bram', text: 'Arqueros abajo. Péguense a la sombra de la pared.' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡estás junto al precipicio! ¡Cuidado!' } ],
      },
    },

    43: {
      pre: [
        { who: 'narrator', text: 'El altar elevador de los antiguos. El único camino hacia abajo.' },
        { who: 'bram', text: 'El altar tarda en ponerse en marcha. Aguanten mientras tanto.' },
        { who: 'commander', text: 'Formación circular alrededor del altar. No dejen ningún lado vacío.' },
        { who: 'bark', text: 'Los guerreros vienen en manada. Hoy toca usar los puños.' },
      ],
      post: [
        { who: 'narrator', text: 'El altar de piedra retumbó y empezó a hundirse en el Abismo.' },
        { who: 'sera', text: '¿De verdad lo hizo gente este altar? Es demasiado antiguo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Aguantamos hasta que el altar se mueva! ¡Mantengan la formación!' } ],
        wave: [ { who: 'bram', text: 'Gladiadores. Cuidado con el contraataque, ¡golpeen de a dos!' } ],
        danger: [ { who: 'bram', text: '{ally}, ¡ponte a la defensiva y recupera el aliento!' } ],
        last: [ { who: 'sera', text: '¡Queda uno! ¡El altar empieza a moverse!' } ],
      },
    },
    44: {
      pre: [
        { who: 'narrator', text: 'A media altura del Abismo, una enorme fortaleza antigua dormía en la oscuridad.' },
        { who: 'bram', text: 'Los grabados de esta muralla... la hicieron los mismos de las ruinas del norte.' },
        { who: 'commander', text: 'Echamos a los que la ocupan y buscamos los registros.' },
      ],
      post: [
        { who: 'narrator', text: 'En los murales de la fortaleza había gente sosteniendo una estrella partida.' },
        { who: 'sera', text: 'Esta gente... está cerrando la brecha del cielo con las manos.' },
        { who: 'commander', text: '"Selladores." Dice que la Llave... se hereda por la sangre.' },
        { who: 'bram', text: '……Ha llegado la hora. Cuando acabe esta pelea, te lo contaré todo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Rompemos la puerta y entramos! ¡Recuperen la fortaleza antigua!' } ],
        wave: [ { who: 'bark', text: '¡Del fondo del castillo salen hechiceros a montones!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Abrimos camino hasta los murales!' } ],
      },
    },
    45: {
      pre: [
        { who: 'narrator', text: 'Más allá de la fortaleza, más abajo. Un caballero de armadura negra esperaba.' },
        { who: 'boss', text: 'La Llave ha bajado por su propio pie.' },
        { who: 'commander', text: 'Llave, Llave... Me llamo {commander}. Recuérdalo.' },
        { who: 'boss', text: 'Ante la puerta, los nombres no significan nada.' },
        { who: 'bram', text: 'Es un caballero. Su frente es duro. Ataquen por la espalda.' },
      ],
      post: [
        { who: 'boss', text: 'Yo solo soy... un guardián menor... más abajo hay...' },
        { who: 'narrator', text: 'Donde cayó el caballero, el suelo se hundió aún más.' },
        { who: 'commander', text: 'Esto no es el fondo. Hay algo más grande.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Quitamos la escolta y rodeamos al caballero!' } ],
        boss: [ { who: 'boss', text: 'La Llave, a la puerta. El resto, a la oscuridad.' } ],
        wave: [ { who: 'bram', text: 'La orden de caballeros del Abismo. ¡Rompan su formación de cobertura!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Ese caballero va solo a por ti!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Fundamos esta lata!' } ],
      },
    },
    46: {
      pre: [
        { who: 'narrator', text: 'Las profundidades del Abismo. Los invocadores llamaban monstruos sin cesar.' },
        { who: 'bram', text: 'Si no caen los invocadores, las invocaciones no se acaban.' },
        { who: 'kasha', text: 'Entonces me cuelo por detrás. Los caminos de sombra son lo mío.' },
        { who: 'commander', text: 'Mientras Kasha va a por los invocadores, nosotros sujetamos el frente.' },
      ],
      post: [
        { who: 'kasha', text: 'Doce invocadores. Siete son míos. Esta vez gano yo.' },
        { who: 'commander', text: 'Vale, esta vez te lo concedo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero los invocadores! ¡Que no los atrapen las invocaciones!' } ],
        wave: [ { who: 'kasha', text: '¡Los invocadores formaron otra vez! ¡Ahora por detrás!' } ],
        last: [ { who: 'kasha', text: '¡El último invocador es mío!' } ],
      },
    },
    47: {
      pre: [
        { who: 'narrator', text: 'Una cueva cerrada por todos lados. El clan quedó aislado.' },
        { who: 'sera', text: 'No... no me salen las plegarias. Me quedé sin fuerzas.' },
        { who: 'commander', text: 'Sera, descansa atrás. El frente lo cubrimos nosotros.' },
        { who: 'bram', text: 'Hay magos mirándonos desde arriba. Busquen cobertura.' },
        { who: 'commander', text: 'En guardia. Golpeamos primero a los que se acerquen.' },
      ],
      post: [
        { who: 'sera', text: 'Lo siento. Por mi culpa todos salieron más heridos.' },
        { who: 'commander', text: 'Gracias a que descansaste, habrá otra batalla. No te disculpes.' },
        { who: 'bram', text: '(...Cuánto has crecido. Eres igual que ellos.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Bloqueen la entrada de la cueva! ¡Protejan a Sera!' } ],
        wave: [ { who: 'bark', text: '¡Caen invocaciones del techo!' } ],
        danger: [ { who: 'commander', text: '¡Los heridos, atrás primero! ¡Rehacemos la formación!' } ],
        last: [ { who: 'bram', text: 'Queda uno. Termínenlo con calma.' } ],
      },
    },
    48: {
      pre: [
        { who: 'narrator', text: 'Un puente de piedra que cruzaba el Abismo. Agrietado por todas partes.' },
        { who: 'bram', text: 'Al otro lado está el fondo del Abismo. Siento su presencia.' },
        { who: 'bark', text: 'Si se cae este puente, no hay vuelta atrás.' },
        { who: 'commander', text: 'Cruzamos rápido y defendemos la otra orilla. Hay que hacer las dos cosas.' },
      ],
      post: [
        { who: 'narrator', text: 'Medio puente se vino abajo. La pierna de Bram sangraba.' },
        { who: 'sera', text: 'Tío Bram, tu pierna... ¡Te curo ahora mismo!' },
        { who: 'bram', text: 'Estoy bien. Un cuerpo viejo siempre cruje.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Avancen por el puente! ¡No se queden sobre las grietas!' } ],
        wave: [ { who: 'kasha', text: '¡Los caballeros bloquean el puente desde el otro lado!' } ],
        danger: [ { who: 'bram', text: '{ally}, ¡si te empujan al borde del puente, se acabó!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Crucemos el puente!' } ],
      },
    },
    49: {
      pre: [
        { who: 'bram', text: 'Te lo contaré, como prometí. Lo de aquella noche, hace quince años.' },
        { who: 'bram', text: 'Tus padres eran Selladores reales. Los que cerraban las brechas del cielo.' },
        { who: 'bram', text: 'Ordin quiso abrir esa brecha, y ellos la cerraron con su vida.' },
        { who: 'bram', text: 'Ese día les prometí a tus padres que te protegería.' },
        { who: 'commander', text: '……¿Por eso estabas en la aldea? ¿Durante quince años?' },
        { who: 'bram', text: 'Sí. Y hoy es el día de cumplir esa promesa.' },
      ],
      post: [
        { who: 'bram', text: 'Comandante. Yo defiendo ese paso. Ustedes, al fondo.' },
        { who: 'commander', text: '¡No! ¡Vamos juntos, tienes la pierna herida!' },
        { who: 'bram', text: 'Con esta pierna sería un lastre. Como Comandante, lo sabes.' },
        { who: 'bram', text: 'No se puede salvar a todos, pero no se abandona a nadie. Vete.' },
      ],
      battle: {
        start: [ { who: 'bram', text: 'Solo hay que defender este paso. ¡Yo voy delante!' } ],
        wave: [ { who: 'commander', text: 'No se acaban... ¡Bram, aguanta un poco más!' } ],
        danger: [ { who: 'bram', text: '¡Los heridos, atrás! ¡Este paso lo aguanto yo!' } ],
        last: [ { who: 'bram', text: 'Queda uno. Es hora de irse, Comandante.' } ],
      },
    },
    50: {
      pre: [
        { who: 'narrator', text: 'El fondo del Abismo. El choque de espadas en el paso de atrás se apagó.' },
        { who: 'sera', text: '{commander}... ya no oigo al tío Bram.' },
        { who: 'commander', text: '……Mira solo hacia delante. Es el camino que nos abrió Bram.' },
        { who: 'boss', text: 'El viejo caballero estuvo a la altura. Ahora te toca a ti, Llave.' },
        { who: 'commander', text: '¡No pronuncies el nombre de Bram con esa boca!' },
      ],
      post: [
        { who: 'boss', text: 'El Abismo... era solo el preparativo... el camino al Reino Demoníaco... se abre...' },
        { who: 'narrator', text: 'Al final del paso de regreso solo quedaba una espada rota.' },
        { who: 'commander', text: 'Bram... cumpliste tu promesa. Hasta el final.' },
        { who: 'commander', text: 'Ahora me toca a mí proteger. A todos los que quedan.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Todos al ataque! ¡Que no sea en vano el camino que defendió Bram!' } ],
        boss: [ { who: 'boss', text: 'Un mando nublado por la ira está lleno de huecos. ¡Ven!' } ],
        wave: [ { who: 'kasha', text: '¡La élite despierta en el fondo! ¡Atentos!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡no avances! ¡Aguanta hasta que llegue!' } ],
        last: [ { who: 'bark', text: '¡Queda uno, capi! ¡Y este va por el viejo!' } ],
      },
    },
    // ═══ Episode 6: Puerta del Infierno ═══
    51: {
      pre: [
        { who: 'narrator', text: 'Campos al sur de la capital real. Los refugiados se agolpaban bajo la grieta del cielo.' },
        { who: 'sera', text: 'Dicen que el camino a la capital está cortado. Nadie puede ir ni volver.' },
        { who: 'commander', text: 'Montamos un campamento de refugiados. Paren todo lo que baje de la grieta.' },
        { who: 'bark', text: 'Primera defensa sin el viejo. Vamos allá.' },
      ],
      post: [
        { who: 'narrator', text: 'Un anciano tomó la mano de {commander} e inclinó la cabeza.' },
        { who: 'commander', text: '(Bram también aguantaba mirando caras como estas.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan el campamento! ¡Que ni uno llegue a los refugiados!' } ],
        wave: [ { who: 'kasha', text: '¡Segunda oleada de la grieta! ¡Esta es más grande!' } ],
        last: [ { who: 'sera', text: '¡Queda uno! ¡Un poco más, todos!' } ],
      },
    },
    52: {
      pre: [
        { who: 'narrator', text: 'Segundo día. Entre los enemigos de la grieta había caras conocidas.' },
        { who: 'bark', text: 'Esos... son mis chicos de la banda. Tienen los ojos rojos.' },
        { who: 'sera', text: 'También hay soldados de hielo del norte. El Reino Demoníaco se los llevó a todos.' },
        { who: 'bark', text: 'Capi, a esos... les daré descanso con mis propias manos.' },
        { who: 'commander', text: 'No cargues con todo tú solo, Bark. Vamos juntos.' },
      ],
      post: [
        { who: 'bark', text: '……Lo siento, chicos. Ya no pasarán hambre.' },
        { who: 'commander', text: 'Bark, ¿estás bien?' },
        { who: 'bark', text: 'Cómo voy a estarlo. Pero menos mal que estás a mi lado, capi.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Aunque fueran viejos enemigos, ahora son marionetas del Reino Demoníaco. ¡Aguanten!' } ],
        wave: [ { who: 'kasha', text: '¡Los caballeros rodean el flanco del campamento!' } ],
        danger: [ { who: 'bark', text: '{ally}, ¡detrás de mí, ya!' } ],
      },
    },
    53: {
      pre: [
        { who: 'narrator', text: 'Justo bajo la grieta, un bastión donde anidaban los monstruos.' },
        { who: 'kasha', text: 'Ese nido sostiene la grieta. Si lo rompemos, la brecha se encoge.' },
        { who: 'commander', text: 'Esta vez atacamos nosotros. ¡Destruyan el nido!' },
      ],
      post: [
        { who: 'narrator', text: 'Al caer el nido, una de las grietas del cielo se desvaneció.' },
        { who: 'sera', text: 'Se pueden cerrar. ¡Una a una, se pueden cerrar!' },
        { who: 'commander', text: 'Pero esa puerta del norte... no es de este tamaño.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Abrimos camino hasta el nido! ¡Derriben primero los flancos!' } ],
        wave: [ { who: 'bark', text: '¡Del nido salen más monstruos!' } ],
        last: [ { who: 'kasha', text: 'Queda uno. ¡Al corazón del nido!' } ],
      },
    },
    54: {
      pre: [
        { who: 'narrator', text: 'La región volcánica del Imperio Volkar. Aquí también se abrió una grieta.' },
        { who: 'narrator', text: 'Los rebeldes ya eran el gobierno provisional del Imperio.' },
        { who: 'kasha', text: 'La gente del Imperio pide ayuda. Quieren pagarte lo que te deben.' },
        { who: 'commander', text: 'Luchemos juntos. Las zonas de lava ya las conocemos.' },
      ],
      post: [
        { who: 'narrator', text: 'Los soldados imperiales formaron bajo la bandera del clan.' },
        { who: 'bark', text: 'Codo a codo con el ejército imperial. Hay que vivir mucho para ver esto.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡No terminen el turno junto a la lava! ¡Cuidado con las quemaduras!' } ],
        wave: [ { who: 'kasha', text: '¡Bajan más de la grieta! ¡Los imperiales cubren la izquierda!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡la quemadura es grave! ¡Retírate!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡Quedemos bien delante de los imperiales!' } ],
      },
    },
    55: {
      pre: [
        { who: 'narrator', text: 'El paso hacia la capital real. La barrera se estaba desmoronando.' },
        { who: 'sera', text: 'Esta vez levanto yo la barrera. Ya puedo volver a rezar.' },
        { who: 'commander', text: 'No te fuerces. Si caes tú, cae la barrera.' },
        { who: 'sera', text: 'Lo sé. Por eso protéjanme ustedes. Confíen en mí.' },
      ],
      post: [
        { who: 'sera', text: 'Lo logré... mis plegarias vuelven a llegar.' },
        { who: 'commander', text: 'Aguantamos gracias a ti, Sera.' },
        { who: 'sera', text: 'Lo decía el tío Bram, ¿no? Nadie lo hace a solas.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Protejan la barrera de Sera! ¡Golpeen primero a los que se acerquen!' } ],
        wave: [ { who: 'kasha', text: '¡Los hechiceros apuntan a la barrera! ¡Deténganlos!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡entra en la barrera!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡La barrera sigue entera!' } ],
      },
    },
    56: {
      pre: [
        { who: 'narrator', text: 'Una grieta profunda en las afueras de la capital. El aire del Reino Demoníaco brotaba espeso.' },
        { who: 'kasha', text: 'Esa grieta llega hasta la capital. La capital está en peligro.' },
        { who: 'commander', text: 'Atravesamos de frente. Seguimos la grieta hasta la capital.' },
      ],
      post: [
        { who: 'narrator', text: 'Al final de la grieta asomaron las murallas de la capital. Subía humo.' },
        { who: 'sera', text: '¡La capital está ardiendo...!' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Avancen por la grieta! ¡No se detengan!' } ],
        wave: [ { who: 'bark', text: '¡Nos cerraron por delante y por detrás! ¡Rompamos un lado primero!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡A la capital!' } ],
      },
    },
    57: {
      pre: [
        { who: 'narrator', text: 'La capital del Reino de Arden. La mitad de la muralla había caído ante las huestes demoníacas.' },
        { who: 'narrator', text: 'La guardia real ya se había replegado al palacio.' },
        { who: 'commander', text: 'Recuperamos la muralla y abrimos paso para que salga la gente.' },
        { who: 'kasha', text: 'Los del palacio abandonaron al pueblo y se escondieron. Patético.' },
        { who: 'commander', text: 'Por eso estamos aquí.' },
      ],
      post: [
        { who: 'narrator', text: 'La gente de la capital empezó a salir por la puerta sur.' },
        { who: 'sera', text: 'Dicen que la torre del archimago está vacía. ¿Adónde fue Ordin?' },
        { who: 'commander', text: 'Registramos bajo la torre. La respuesta estará ahí.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Recuperen lo alto de la muralla! ¡Tomen el terreno elevado!' } ],
        wave: [ { who: 'kasha', text: '¡Los caballeros presionan hacia la puerta!' } ],
        danger: [ { who: 'bark', text: '¡{ally} está en apuros! ¡Por la escalera de la muralla, atrás!' } ],
        last: [ { who: 'sera', text: '¡El último! ¡La puerta sur está abierta!' } ],
      },
    },
    58: {
      pre: [
        { who: 'narrator', text: 'Bajo la torre del archimago. La escalera se adentraba en una grieta.' },
        { who: 'kasha', text: 'Estaba cultivando una grieta bajo su propia torre.' },
        { who: 'commander', text: 'Hay guardianes. Los atravesamos hasta el laboratorio.' },
      ],
      post: [
        { who: 'commander', text: 'Es el diario de Ordin. "Abrir la puerta para invocar al dios."' },
        { who: 'commander', text: '"Solo el dios purificará el Reino Demoníaco. La Llave que abre la puerta es esa criatura."' },
        { who: 'sera', text: '¿Dejó el mundo así solo para invocar a un dios?' },
        { who: 'kasha', text: 'Eso no es fe. Es locura.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Quiten a los guardianes del laboratorio! ¡Adentro!' } ],
        wave: [ { who: 'bark', text: '¡Salen invocaciones de las paredes!' } ],
        last: [ { who: 'kasha', text: 'Queda uno. Estamos ante la puerta del laboratorio.' } ],
      },
    },
    59: {
      pre: [
        { who: 'narrator', text: 'Las Llanuras Cenicientas, al norte de la capital. La Puerta del Infierno se alzaba hasta el cielo.' },
        { who: 'narrator', text: 'Ante la puerta se levantó el último campamento de la alianza.' },
        { who: 'commander', text: 'Antes de ir a por el guardián de la puerta, defendemos el campamento.' },
        { who: 'bark', text: 'Lo que sale de esa puerta... no es ninguna broma.' },
        { who: 'commander', text: 'Los recibimos en guardia. Disparamos primero, golpeamos primero.' },
      ],
      post: [
        { who: 'narrator', text: 'El campamento resistió. Una sombra gigantesca se plantó ante la puerta.' },
        { who: 'sera', text: 'Ese es el guardián. Si lo superamos, podremos cerrar la puerta.' },
        { who: 'commander', text: '(¿Seguro? La cicatriz está rara, inquieta.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan el campamento! ¡Esta es la última línea!' } ],
        wave: [ { who: 'kasha', text: '¡Refuerzos desde la puerta! ¡No se les ve el fin!' } ],
        danger: [ { who: 'commander', text: '¡Cubran el puesto de {ally}! ¡El campamento no se entrega!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡El campamento es nuestro!' } ],
      },
    },
    60: {
      pre: [
        { who: 'narrator', text: 'Ante la Puerta del Infierno. Un caballero gigantesco le daba la espalda a la puerta.' },
        { who: 'boss', text: 'Esta puerta solo se cruza con la sangre de la Llave.' },
        { who: 'commander', text: 'No pienso cruzarla. Vengo a cerrarla.' },
        { who: 'boss', text: 'Cerrarla o abrirla... se decidirá en cuanto me derribes.' },
        { who: 'kasha', text: 'Algo no cuadra. Esas palabras huelen a trampa.' },
      ],
      post: [
        { who: 'boss', text: 'Bien... la sangre de la Llave... ha tocado la puerta...' },
        { who: 'narrator', text: 'Tras caer el guardián, la cicatriz de {commander} empezó a sangrar.' },
        { who: 'narrator', text: 'Desde la punta de los dedos, una gota de sangre tocó la puerta.' },
        { who: 'commander', text: 'La cicatriz me arde... ¿¡la puerta se mueve!?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero, la escolta que rodea al guardián!' } ],
        boss: [ { who: 'boss', text: 'Yo soy la puerta. Para cruzarla, tendrás que cruzarme a mí.' } ],
        wave: [ { who: 'kasha', text: '¡Refuerzos desde dentro de la puerta! ¡Nos cierran por ambos lados!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Estás sangrando demasiado!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Con este se acaba!' } ],
      },
    },
    // ═══ Episode 7: Reino Demoníaco ═══
    61: {
      pre: [
        { who: 'narrator', text: 'La primera tierra tras la puerta. El clan levantó una cabeza de puente sobre roca negra.' },
        { who: 'kasha', text: 'La puerta de regreso está a nuestra espalda. Si perdemos esto, se acabó.' },
        { who: 'commander', text: 'Defendemos la cabeza de puente. No le cedan el paso al Reino Demoníaco.' },
        { who: 'sera', text: 'Este aire... cada vez que respiro me zumba la cabeza.' },
      ],
      post: [
        { who: 'bark', text: 'Aguantamos. Pero el sol no se pone. ¿Aquí no hay noche?' },
        { who: 'commander', text: 'No se fíen del tiempo ni del camino. Fiémonos solo unos de otros.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan la cabeza de puente! ¡Protejan el camino a la puerta!' } ],
        wave: [ { who: 'kasha', text: '¡Caballeros demoníacos entre las rocas! ¡Son muchos!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡reacciona! ¿Me oyes?' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Por la primera victoria en el Reino Demoníaco!' } ],
      },
    },
    62: {
      pre: [
        { who: 'narrator', text: 'Se extendía un campo de hierba roja que ondulaba sin fin.' },
        { who: 'sera', text: '{commander}... mira, es la aldea de Solbit. Esa colina, ese molino.' },
        { who: 'commander', text: 'No. La aldea no es tan roja. Es una ilusión.' },
        { who: 'kasha', text: 'Hay enemigos de verdad mezclados en la ilusión. Ojo.' },
        { who: 'commander', text: 'Aunque parezca nuestro hogar, no duden. ¡Adelante!' },
      ],
      post: [
        { who: 'narrator', text: 'Al disiparse la ilusión, la aldea desapareció y solo quedaron cenizas.' },
        { who: 'commander', text: 'El Reino Demoníaco usa lo que más queremos como arma.' },
        { who: 'bark', text: 'Rastreros. Pues habrá que pegarles más fuerte.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡No crean lo que ven! ¡Miren solo al enemigo y golpeen!' } ],
        wave: [ { who: 'kasha', text: '¡Salen más tras la colina! ¡No es ilusión, son de verdad!' } ],
        last: [ { who: 'sera', text: 'El último. Ahora vamos por el camino de verdad.' } ],
      },
    },
    63: {
      pre: [
        { who: 'narrator', text: 'Árboles de hueso blanco formaban un bosque.' },
        { who: 'bark', text: 'Las ramas se mueven como dedos. Qué escalofríos.' },
        { who: 'kasha', text: 'Pero un bosque es un bosque. Podemos escondernos en la sombra.' },
        { who: 'commander', text: 'Luchamos pegados al bosque. Si se amontonan, atacamos el flanco.' },
      ],
      post: [
        { who: 'narrator', text: 'Al final del bosque hallaron un viejo poste indicador. Letra humana.' },
        { who: 'commander', text: '"El camino de los Selladores." ...Mis padres también pasaron por aquí.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Usen los árboles de hueso como cobertura! ¡No se expongan!' } ],
        wave: [ { who: 'kasha', text: '¡Nos rodean desde el otro lado del bosque! ¡Cuidado con la espalda!' } ],
        danger: [ { who: 'bark', text: '¡{ally}! ¡Yo aparto las ramas, tú sal de ahí!' } ],
      },
    },
    64: {
      pre: [
        { who: 'narrator', text: 'Una ciénaga de agua roja. Algo respiraba bajo la superficie.' },
        { who: 'sera', text: 'Se parece al Pantano de Aguanegra. Pero varias veces peor.' },
        { who: 'commander', text: 'Formamos en la isla del centro. No salgan a los bajíos.' },
        { who: 'kasha', text: 'Si aguantamos aquí, se cansarán cruzando la ciénaga.' },
      ],
      post: [
        { who: 'sera', text: 'Me acuerdo del pantano. Entonces estaba el tío Bram.' },
        { who: 'commander', text: 'Sigue estando. En lo que decimos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan la isla! ¡Apunten a los que estén en los bajíos!' } ],
        wave: [ { who: 'bark', text: '¡Siguen trepando desde el fondo de la ciénaga!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡aléjate de la orilla!' } ],
        last: [ { who: 'kasha', text: 'Queda uno. ¡Cruzamos la ciénaga!' } ],
      },
    },
    65: {
      pre: [
        { who: 'narrator', text: 'Un cañón que gritaba cada vez que pasaba el viento.' },
        { who: 'bark', text: 'Me van a reventar los oídos. ¿Todo esto es el viento?' },
        { who: 'kasha', text: 'Gana quien tome las rocas de arriba. Es una pelea por la altura.' },
        { who: 'commander', text: 'Los de distancia, a la colina. Así llegan más lejos.' },
      ],
      post: [
        { who: 'narrator', text: 'Al final del cañón, una ciudadela negra se clavaba en el cielo.' },
        { who: 'commander', text: 'Dicen que tras esa ciudadela está la torre del Hechicero.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Tomen primero lo alto! ¡Golpeamos desde arriba!' } ],
        wave: [ { who: 'kasha', text: '¡Hay hechiceros en la altura de enfrente!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Cruzamos el cañón!' } ],
      },
    },
    66: {
      pre: [
        { who: 'narrator', text: 'La ciudadela negra del Reino Demoníaco. Sus muros se retorcían como si vivieran.' },
        { who: 'kasha', text: 'El grueso de la Pluma Negra nos siguió por la puerta. Ya estamos todos.' },
        { who: 'commander', text: 'Qué alivio. Defendemos la ciudadela y nos abrimos paso hacia dentro.' },
        { who: 'kasha', text: '...Qué tontería parece ahora lo de competir contigo.' },
      ],
      post: [
        { who: 'kasha', text: '{commander}. Ya no somos rivales. Somos camaradas.' },
        { who: 'commander', text: 'Lo sé. Pero de vez en cuando, compitamos.' },
        { who: 'kasha', text: 'Hmph. La próxima gano yo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Tomamos la entrada y empujamos hacia dentro!' } ],
        wave: [ { who: 'kasha', text: '¡Pluma Negra, muralla izquierda! ¡Ahora!' } ],
        danger: [ { who: 'kasha', text: '{ally}, ¡detrás de mí! ¡Te cubro!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡La ciudadela cae!' } ],
      },
    },
    67: {
      pre: [
        { who: 'narrator', text: 'En pleno Reino Demoníaco había unas ruinas levantadas por manos humanas.' },
        { who: 'sera', text: 'Aquí también está el símbolo de la estrella partida. Ruinas de los Selladores.' },
        { who: 'commander', text: 'La cicatriz vibra. Algo nos espera aquí.' },
        { who: 'kasha', text: '¡Los demonios quieren destruir las ruinas! ¡Hay que protegerlas!' },
      ],
      post: [
        { who: 'narrator', text: 'La piedra del centro brilló y resonaron dos voces.' },
        { who: 'narrator', text: '"Cariño. La Llave no se gira en soledad."' },
        { who: 'narrator', text: '"Gírala con las manos que te acompañan. Así se cerrará."' },
        { who: 'commander', text: '……¿Mamá? ¿Papá? ¡Esperen, todavía tengo que decirles...!' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Protejan las ruinas! ¡Que nadie toque esa piedra!' } ],
        wave: [ { who: 'bark', text: '¡Vienen de todos lados! ¡Formen en círculo!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Nosotros protegemos las ruinas, retírate!' } ],
        last: [ { who: 'sera', text: '¡Queda uno! ¡La piedra empieza a brillar!' } ],
      },
    },
    68: {
      pre: [
        { who: 'sera', text: '{commander}, esa voz de antes... ¿estás bien?' },
        { who: 'commander', text: 'Sí. Al contrario, siento que por fin veo el camino.' },
        { who: 'commander', text: 'No a solas, sino juntos. Esa es la Llave.' },
        { who: 'narrator', text: 'El clan entró en el corredor abisal que lleva a la torre del Hechicero.' },
      ],
      post: [
        { who: 'bark', text: 'Al final del corredor se ve la torre. El Hechicero estará en la cima.' },
        { who: 'kasha', text: 'Ordin también pasó por ahí. El rastro es fuerte.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Atravesamos el corredor! ¡Muévanse juntos!' } ],
        wave: [ { who: 'kasha', text: '¡Se abrieron las dos paredes! ¡Emboscada!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡A la torre!' } ],
      },
    },
    69: {
      pre: [
        { who: 'narrator', text: 'La fortaleza bajo la torre del Hechicero. La última muralla que la protege.' },
        { who: 'kasha', text: 'Desde la muralla llueve magia.' },
        { who: 'commander', text: 'Se marca al miembro del clan que el enemigo apunta. Dejen libre ese sitio.' },
        { who: 'bark', text: 'Si ves a quién apuntan, lo esquivas. ¡Fácil!' },
      ],
      post: [
        { who: 'narrator', text: 'La muralla se derrumbó y la puerta de la torre se abrió sola.' },
        { who: 'sera', text: 'Nos está invitando. Qué mala espina.' },
        { who: 'commander', text: 'Si nos invitan, habrá que ir. Con cortesía, y con el bastón de mando en alto.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Miren las marcas de objetivo! ¡Despejen el sitio apuntado!' } ],
        wave: [ { who: 'kasha', text: '¡Baja la élite de la torre! ¡La escolta de magos!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡fuego mágico concentrado! ¡Esquiva!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Se abre la puerta de la torre!' } ],
      },
    },
    70: {
      pre: [
        { who: 'narrator', text: 'La cima de la torre. De la niebla salió una silueta conocida.' },
        { who: 'commander', text: '……¿Bram?' },
        { who: 'fake_bram', text: 'Sí, peque. ¿Por qué me dejaste atrás?' },
        { who: 'sera', text: '¡No te dejes engañar! ¡El tío Bram nunca diría eso!' },
        { who: 'commander', text: 'Lo sé. Bram me llamó "Comandante" hasta el final.' },
        { who: 'boss', text: 'Hmph, qué aburrido. Entonces te enfrentaré con mi verdadera forma.' },
      ],
      post: [
        { who: 'boss', text: 'Aun sacudiendo su corazón... un humano que no se quiebra...' },
        { who: 'boss', text: 'Ordin... fue a la cima del cielo... a invocar al dios...' },
        { who: 'boss', text: 'Y el Señor... ya te está observando...' },
        { who: 'commander', text: 'Que observe. Pronto iré a verle en persona.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Que no los sacudan las ilusiones! ¡A por el Hechicero!' } ],
        boss: [ { who: 'boss', text: 'Te desgarraré con tus propios recuerdos, Llave.' } ],
        wave: [ { who: 'kasha', text: '¡Refuerzos de los pisos de abajo! ¡Bloqueen la escalera!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡No escuches la ilusión, escucha mi voz!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡Tiremos esta torre abajo!' } ],
      },
    },
    // ═══ Episode 8: Juicio Divino ═══
    71: {
      pre: [
        { who: 'narrator', text: 'Un campo azotado por luz blanca. La hierba roja ardía hasta volverse blanca.' },
        { who: 'narrator', text: 'De la luz salieron figuras con armadura. Tenían alas.' },
        { who: 'sera', text: 'Avatares divinos... como los de las escrituras.' },
        { who: 'kasha', text: '¿Y por qué vienen hacia nuestro campamento?' },
        { who: 'commander', text: 'Están desenvainando. ¡Defiendan el campamento! ¡También son enemigos!' },
      ],
      post: [
        { who: 'sera', text: 'Los avatares divinos nos atacaron. ¿Por qué...?' },
        { who: 'commander', text: 'Para ellos, todo lo que tocó el Reino Demoníaco está sucio. Y eso nos incluye.' },
        { who: 'sera', text: 'Entonces, ¿para qué recé toda mi vida?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan el campamento! ¡Sea luz u oscuridad, lo paramos!' } ],
        wave: [ { who: 'kasha', text: '¡Bajan más del cielo! ¡Ahora son caballeros!' } ],
        danger: [ { who: 'bark', text: '¡{ally}! ¡Esa luz quema con solo rozarte!' } ],
        last: [ { who: 'sera', text: '……Queda uno. Acabemos.' } ],
      },
    },
    72: {
      pre: [
        { who: 'narrator', text: 'Una brecha del Abismo donde chocaban la luz y la oscuridad.' },
        { who: 'kasha', text: 'Demonios y avatares se pelean entre ellos. ¿Y nosotros qué?' },
        { who: 'commander', text: 'Ninguno está de nuestro lado. Pasamos por en medio.' },
        { who: 'bark', text: '¿Eso no es recibir palos de los dos lados?' },
      ],
      post: [
        { who: 'narrator', text: 'Más allá de la brecha, en la cima del cielo, se veía una grieta blanca.' },
        { who: 'commander', text: 'Ahí es donde Ordin invoca al dios.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Los dos bandos son enemigos! ¡Atraviesen por la brecha!' } ],
        wave: [ { who: 'kasha', text: '¡Los refuerzos demoníacos giran hacia nosotros!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Salgamos de este caos!' } ],
      },
    },
    73: {
      pre: [
        { who: 'narrator', text: 'Una ciudadela de piedra blanca. Demasiado limpia para estar en pleno Reino Demoníaco.' },
        { who: 'kasha', text: 'Dicen que la construyó Ordin. Un santuario para recibir al dios, o algo así.' },
        { who: 'commander', text: 'Tomamos la ciudadela y buscamos el camino hacia arriba.' },
        { who: 'sera', text: 'Esta ciudadela... está hecha con calaveras de gente que rezaba...' },
      ],
      post: [
        { who: 'commander', text: 'Es la gente que trajo Ordin. Ofrendas para invocar al dios.' },
        { who: 'sera', text: '¿Por un dios se le puede hacer esto a la gente?' },
        { who: 'commander', text: 'No. Por ninguna razón.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defendemos la puerta y nos abrimos paso hacia dentro!' } ],
        wave: [ { who: 'kasha', text: '¡Bajan hechiceros de luz de los pisos de arriba!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡llevas demasiado tiempo bajo la luz!' } ],
        last: [ { who: 'bark', text: '¡El último! ¡La ciudadela es nuestra!' } ],
      },
    },
    74: {
      pre: [
        { who: 'narrator', text: 'Las ruinas de un templo antiguo. Sera se arrodilló a solas.' },
        { who: 'narrator', text: '"Sacerdotisa. Apártate de la Llave. La Llave lleva la mancha."' },
        { who: 'sera', text: '……Es la voz del dios. Me dice que me vaya.' },
        { who: 'commander', text: 'Sera. Tú decides. No te lo voy a reprochar.' },
        { who: 'sera', text: 'Bobada... ¿De verdad no sabes a quién voy a elegir?' },
        { who: 'sera', text: 'Curaré incluso a quien el dios abandone. Esa es mi plegaria.' },
      ],
      post: [
        { who: 'sera', text: 'La voz del dios calló. Y en cambio, mi corazón está en calma.' },
        { who: 'commander', text: 'Gracias, Sera. De verdad.' },
        { who: 'sera', text: 'Te lo dije al principio. Si te hacen daño, yo te curo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan las ruinas! ¡Que nadie llegue hasta Sera!' } ],
        wave: [ { who: 'kasha', text: '¡Los avatares quieren llevarse a Sera! ¡Deténganlos!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Yo te curo, aguanta!' } ],
        last: [ { who: 'sera', text: 'El último. Este lo termino con mis manos.' } ],
      },
    },
    75: {
      pre: [
        { who: 'narrator', text: 'Un pilar del Abismo que subía al cielo. De él colgaba una escalera de luz.' },
        { who: 'bark', text: '¿Si subimos por esa escalera, llegamos a la cima?' },
        { who: 'kasha', text: 'Los guardianes formaron al pie de la escalera.' },
        { who: 'commander', text: 'Tomamos el pie de la escalera. Si los rodeamos, será un ataque en pinza.' },
      ],
      post: [
        { who: 'narrator', text: 'La escalera brilló al recibir el peso del clan.' },
        { who: 'bark', text: 'Aguanta hasta mi peso. Las cosas de los dioses son resistentes.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Rehagan la formación! ¡Respiren y terminen con un ataque en pinza!' } ],
        wave: [ { who: 'kasha', text: '¡Bajan desde arriba! ¡Bloqueen la escalera!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Subimos!' } ],
      },
    },
    76: {
      pre: [
        { who: 'narrator', text: 'Entre el cielo y el Abismo. Un campo de batalla donde luz y oscuridad se enredan.' },
        { who: 'kasha', text: 'Demonios, avatares y nosotros. Batalla a tres bandas.' },
        { who: 'commander', text: 'Que se peleen entre ellos. Nosotros solo abrimos camino.' },
        { who: 'bark', text: '¿Esperamos a que se cansen? Capi, cuánta astucia has ganado.' },
      ],
      post: [
        { who: 'commander', text: 'Bram lo habría hecho así. Hay que ahorrar fuerzas.' },
        { who: 'sera', text: 'Fue decisión tuya, {commander}. No del tío Bram.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡No se enfrenten a ninguno! ¡Abran camino y aguanten!' } ],
        wave: [ { who: 'kasha', text: '¡Los dos bandos van a por nosotros a la vez! ¡Cierren filas!' } ],
        danger: [ { who: 'bark', text: '¡{ally}! ¡Ponte a la defensiva y aguanta una!' } ],
        last: [ { who: 'kasha', text: '¡Queda uno! ¡Hay un hueco, ve!' } ],
      },
    },
    77: {
      pre: [
        { who: 'narrator', text: 'Una fortaleza cerca del cielo. Las huestes demoníacas subieron tras el clan.' },
        { who: 'kasha', text: 'Hay que cortar la persecución antes de llegar a la cima. Parémoslos aquí.' },
        { who: 'commander', text: 'Cerramos la puerta de la fortaleza y aguantamos. En guardia.' },
        { who: 'commander', text: 'El que entre en alcance, recibe primero.' },
      ],
      post: [
        { who: 'narrator', text: 'Los perseguidores cayeron. Desde arriba resonó la voz de Ordin.' },
        { who: 'commander', text: 'Ordin nos está hablando.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan la puerta! ¡Aquí cortamos la persecución!' } ],
        wave: [ { who: 'bark', text: '¡Siguen trepando desde abajo!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡atrás, dentro de la puerta!' } ],
        last: [ { who: 'kasha', text: 'Queda uno. ¡Fin de la persecución!' } ],
      },
    },
    78: {
      pre: [
        { who: 'ordin', text: 'Joven comandante. Hagamos un trato.' },
        { who: 'ordin', text: 'Entrégueme la Llave. Si el dios borra el Reino Demoníaco, la guerra terminará.' },
        { who: 'commander', text: 'Dicen que también borrará las tierras que tocó. Nuestro hogar incluido.' },
        { who: 'ordin', text: 'No hay salvación sin sacrificio. Sus padres lo demostraron.' },
        { who: 'commander', text: 'Mis padres eligieron por sí mismos. Tú elegiste a otros.' },
        { who: 'commander', text: 'No dejaré que un dios decida a quién abandonar.' },
      ],
      post: [
        { who: 'ordin', text: 'Qué insensatez. Entonces demuéstrelo ante el dios.' },
        { who: 'narrator', text: 'La imagen de Ordin se disipó y la luz de la cima del cielo se intensificó.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡La respuesta la da esta batalla! ¡Miembros del clan, abran camino!' } ],
        wave: [ { who: 'kasha', text: '¡Ordin invocó más avatares!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡A la cima!' } ],
      },
    },
    79: {
      pre: [
        { who: 'narrator', text: 'La última escalera hacia la cima del cielo. Flanqueada por pilares antiguos.' },
        { who: 'sera', text: 'Son ruinas de los Selladores. Aquí también intentaron cerrar la puerta.' },
        { who: 'commander', text: 'Atravesamos a los que formaron entre los pilares.' },
        { who: 'bark', text: '¿Si pasamos esto, por fin le vemos la cara al viejo?' },
      ],
      post: [
        { who: 'narrator', text: 'Al final de la escalera, Ordin esperaba ante la grieta blanca.' },
        { who: 'narrator', text: 'El cuerpo de Ordin ya era luz casi a medias.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Subimos la escalera! ¡Cuidado detrás de los pilares!' } ],
        wave: [ { who: 'kasha', text: '¡Arqueros en los pilares de arriba! ¡Tienen la altura!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Que no te empujen escalera abajo!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡La cima!' } ],
      },
    },
    80: {
      pre: [
        { who: 'narrator', text: 'Ante la grieta blanca. Ordin ya se hacía llamar el Invocador del dios.' },
        { who: 'boss', text: 'Mire, el dios ya viene. El momento que esperé quince años.' },
        { who: 'commander', text: '¡¿A cuántos sacrificaste en esos quince años?!' },
        { who: 'boss', text: 'Era el precio de salvar el mundo.' },
        { who: 'commander', text: 'Ese precio no te corresponde a ti fijarlo.' },
        { who: 'sera', text: '{commander}, hay que cortar la invocación. ¡Ya!' },
      ],
      post: [
        { who: 'boss', text: 'El dios... no viene... ¿o es que nunca pudo venir...?' },
        { who: 'narrator', text: 'La luz abandonó el cuerpo de Ordin y solo quedó un viejo mago.' },
        { who: 'bark', text: 'Capi, ¿lo rematamos?' },
        { who: 'commander', text: 'No. Que viva y vea lo que ha hecho.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero, los avatares que protegen el círculo de invocación!' } ],
        boss: [ { who: 'boss', text: '¡En nombre del dios, juzgo a los mancillados!' } ],
        wave: [ { who: 'kasha', text: '¡Bajan más avatares de la grieta! ¡Rápido!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Es la luz del juicio, esquiva!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Acabemos con esta invocación!' } ],
      },
    },
    // ═══ Episode 9: Crisis Absoluta ═══
    81: {
      pre: [
        { who: 'narrator', text: 'Las Llanuras Cenicientas ante la capital. Por primera vez, las banderas de la alianza ondeaban juntas.' },
        { who: 'kasha', text: 'Los restos del Reino, el ejército imperial, la Pluma Negra. Todos esperan tus órdenes.' },
        { who: 'commander', text: 'Primera operación de la alianza. Nadie lucha a solas.' },
        { who: 'commander', text: '¡Aquí paramos a todo lo que salga de la grieta!' },
      ],
      post: [
        { who: 'narrator', text: 'La primera defensa de la alianza terminó en victoria.' },
        { who: 'bark', text: 'Soldados de distintos países dándose palmadas en la espalda.' },
        { who: 'sera', text: 'Al tío Bram le habría encantado verlo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Alianza, mantengan la línea! ¡Bloqueen la grieta!' } ],
        wave: [ { who: 'kasha', text: '¡Un ejército entero de la grieta! ¡Los imperiales sostienen la derecha!' } ],
        danger: [ { who: 'commander', text: '¡La línea de {ally} está débil! ¡Reserva, a reforzar!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Primera victoria de la alianza!' } ],
      },
    },
    82: {
      pre: [
        { who: 'narrator', text: 'Al norte de la llanura, el campamento avanzado que las huestes demoníacas alzaron ante la grieta.' },
        { who: 'kasha', text: 'Si dejamos ese campamento, no dejarán de salir.' },
        { who: 'commander', text: 'Atacamos. Solo defendiendo no se gana esta guerra.' },
      ],
      post: [
        { who: 'narrator', text: 'El campamento demoníaco ardió y una grieta se calmó.' },
        { who: 'commander', text: 'Ahora el norte. Dicen que Puertahelada está sitiada.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Atacamos el campamento! ¡Derriben primero los flancos!' } ],
        wave: [ { who: 'kasha', text: '¡Caballeros demoníacos llegan por detrás del campamento!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Préndanle fuego al campamento!' } ],
      },
    },
    83: {
      pre: [
        { who: 'narrator', text: 'La Fortaleza Puertahelada, en el norte. Donde el clan conoció a Kasha.' },
        { who: 'kasha', text: 'Aquí me ganaste aquella vez. ¿Te acuerdas?' },
        { who: 'commander', text: 'Me acuerdo. Entonces éramos enemigos.' },
        { who: 'narrator', text: 'Los supervivientes del norte vitorearon al ver la bandera del clan.' },
        { who: 'commander', text: '¡Defendemos la fortaleza y rompemos el cerco!' },
      ],
      post: [
        { who: 'narrator', text: 'Los supervivientes del norte se unieron a la alianza.' },
        { who: 'kasha', text: 'Es gente de Fuenteblanca. La aldea que protegiste.' },
        { who: 'commander', text: 'Esta vez son ellos los que vienen a protegernos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defendemos la muralla y rompemos el cerco! ¡Las dos cosas!' } ],
        wave: [ { who: 'bark', text: '¡Más demonios en la ventisca!' } ],
        danger: [ { who: 'kasha', text: '¡El enemigo rodeó por la retaguardia! ¡Protejan el flanco de {ally}!' } ],
        last: [ { who: 'sera', text: 'Queda uno. ¡Puertahelada está a salvo!' } ],
      },
    },
    84: {
      pre: [
        { who: 'narrator', text: 'La aldea de Vado de Cañas, en el Pantano de Aguanegra del sur. Las huestes demoníacas cruzaron la ciénaga.' },
        { who: 'sera', text: '¡Es la gente que curamos aquella vez! Todos han tomado las armas.' },
        { who: 'commander', text: 'Defendemos la aldea. Esta vez, con su gente a nuestro lado.' },
        { who: 'bark', text: 'Pelea en pantano: ojo con los bajíos. Ya me lo sé con los ojos cerrados.' },
      ],
      post: [
        { who: 'narrator', text: 'La gente de Vado de Cañas rodeó a Sera e inclinó la cabeza.' },
        { who: 'sera', text: 'Los que salvamos entonces nos salvaron hoy.' },
        { who: 'commander', text: 'Por eso luchamos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan la empalizada! ¡No dejen que los arrastren al pantano!' } ],
        wave: [ { who: 'kasha', text: '¡Segunda oleada desde el otro lado del pantano!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡ya voy! ¡Un momento!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Viva Vado de Cañas!' } ],
      },
    },
    85: {
      pre: [
        { who: 'narrator', text: 'Una grieta gigantesca abierta en el centro del continente. El cauce principal de las huestes demoníacas.' },
        { who: 'kasha', text: 'Si la rompemos, el suministro demoníaco se parte por la mitad.' },
        { who: 'commander', text: 'Toda la alianza a la carga. Hoy rompemos esa grieta.' },
      ],
      post: [
        { who: 'narrator', text: 'La grieta gigante se cerró a medias y resonó un alarido del Reino Demoníaco.' },
        { who: 'ordin', text: '...Impresionante. Lo que yo no logré en quince años.' },
        { who: 'commander', text: 'No lo lograste porque querías hacerlo a solas.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Señal de carga general! ¡Barran a los demonios ante la grieta!' } ],
        wave: [ { who: 'kasha', text: '¡Caballeros de élite desde la grieta! ¡Rehagan la formación!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Rompemos la grieta!' } ],
      },
    },
    86: {
      pre: [
        { who: 'narrator', text: 'La ciudadela de la Puerta de Obsidiana. El último bastión del gobierno provisional del Imperio.' },
        { who: 'kasha', text: 'Aquí rompió su contrato la Pluma Negra. Qué sensación tan rara.' },
        { who: 'commander', text: 'Defendemos la ciudadela y rechazamos el cerco exterior.' },
        { who: 'bark', text: 'Los lanceros de la muralla para los imperiales; abajo, nosotros.' },
      ],
      post: [
        { who: 'narrator', text: 'Al resistir la Puerta de Obsidiana, la resistencia de todo el Imperio cobró fuerzas.' },
        { who: 'kasha', text: 'Romper aquel contrato fue buena decisión.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defendemos dentro y fuera de la puerta a la vez! ¡No se dispersen!' } ],
        wave: [ { who: 'bark', text: '¡Refuerzos desde el volcán! ¡Bloqueen la puerta!' } ],
        danger: [ { who: 'kasha', text: '{ally}, no te fuerces. ¡Yo te respaldo!' } ],
        last: [ { who: 'sera', text: '¡Queda uno! ¡La Puerta de Obsidiana está a salvo!' } ],
      },
    },
    87: {
      pre: [
        { who: 'narrator', text: 'Ruinas antiguas de los Selladores. Las huestes demoníacas acudieron a destruirlas.' },
        { who: 'ordin', text: 'Si estas ruinas caen, el poder de la Llave también se debilitará.' },
        { who: 'commander', text: 'Entonces las defendemos. Pase lo que pase.' },
        { who: 'bark', text: 'Capi, esta vez me pongo yo el primero.' },
      ],
      post: [
        { who: 'narrator', text: 'Las ruinas resistieron. Pero Bark yacía en el suelo.' },
        { who: 'sera', text: '¡Bark! ¡Abre los ojos! ¡Te estoy curando!' },
        { who: 'bark', text: '……Capi, no me muero. Aún tengo un campo que arar.' },
        { who: 'commander', text: 'Prométemelo. Volvemos juntos, sí o sí.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan las ruinas! ¡Luchen de espaldas a los pilares!' } ],
        wave: [ { who: 'kasha', text: '¡Rompieron la parte trasera de las ruinas! ¡Que alguien la cubra!' } ],
        danger: [ { who: 'bark', text: '¡El lado de {ally} quedó vacío! ¡Aquí aguanto yo!' } ],
        last: [ { who: 'bark', text: 'Queda... uno... ¡Capi, termínalo!' } ],
      },
    },
    88: {
      pre: [
        { who: 'narrator', text: 'Bark recibía cuidados en el campamento, y el clan volvió a salir.' },
        { who: 'commander', text: 'Luchamos también por Bark. Y volvemos todos juntos.' },
        { who: 'kasha', text: 'Tras esa grieta está el campamento del Guerrero de la guerra.' },
        { who: 'commander', text: 'Abrimos camino. Hasta tenerlo delante.' },
      ],
      post: [
        { who: 'narrator', text: 'Tras la grieta se veía la bandera roja del Gran General demoníaco.' },
        { who: 'kasha', text: 'Marcha hacia la aldea de Solbit.' },
        { who: 'commander', text: '……Vamos a casa. Allí termina todo.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Atraviesen la grieta! ¡Este golpe va por Bark!' } ],
        wave: [ { who: 'kasha', text: '¡La guardia del Gran General nos cierra el paso! ¡Son fuertes!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Vamos a casa!' } ],
      },
    },
    89: {
      pre: [
        { who: 'narrator', text: 'La aldea de Solbit. En lugar de la empalizada, se alzaba una muralla de piedra.' },
        { who: 'sera', text: 'La levantó la propia gente de la aldea. Dicen que es el lugar al que volveremos.' },
        { who: 'bark', text: '...Snif, alguien me echó arena en los ojos.' },
        { who: 'commander', text: 'Es donde di mis primeras órdenes. Aquí aguantamos.' },
        { who: 'commander', text: 'Esta vez tampoco perderé a nadie.' },
      ],
      post: [
        { who: 'narrator', text: 'La muralla de Solbit no cayó.' },
        { who: 'commander', text: 'Bram, ¿lo viste? Tu peque llegó hasta aquí.' },
        { who: 'sera', text: 'Mira, al final de la llanura se ve una armadura roja. Es el Gran General.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Es la muralla de nuestro hogar! ¡Ni un paso atrás!' } ],
        wave: [ { who: 'kasha', text: '¡Un ejército entero! ¡Cargan contra el este de la muralla!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡detrás de la muralla! ¡No aguantes con esas heridas!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Es nuestra aldea!' } ],
      },
    },
    90: {
      pre: [
        { who: 'narrator', text: 'La llanura ante la aldea de Solbit. Un gigante de armadura roja avanzó.' },
        { who: 'boss', text: 'Y pensar que esta aldehuela es el corazón de esta guerra.' },
        { who: 'commander', text: 'Da igual que sea pequeña. Es nuestro hogar.' },
        { who: 'boss', text: 'Entonces la aplastaré con hogar y todo. Así es la guerra.' },
        { who: 'kasha', text: 'Toda la alianza está lista. Solo espera tu señal.' },
      ],
      post: [
        { who: 'boss', text: 'Esta guerra... la he perdido... pero el Señor... no perderá...' },
        { who: 'narrator', text: 'Al caer el Gran General, las huestes demoníacas se derrumbaron y huyeron a la grieta.' },
        { who: 'commander', text: 'Ya solo queda uno. El Señor Demoníaco.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Alianza, ataque total! ¡Primero la escolta del Gran General!' } ],
        boss: [ { who: 'boss', text: '¡En nombre de la guerra! ¡Arrásenlo todo!' } ],
        wave: [ { who: 'kasha', text: '¡Refuerzos de élite demoníacos! ¡Será la última oleada!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡No recibas los golpes del Gran General!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Acabemos con esta guerra!' } ],
      },
    },
    // ═══ Episode 10: Reino de la Imposibilidad ═══
    91: {
      pre: [
        { who: 'narrator', text: 'El estrato más profundo del Reino Demoníaco. Bajo los pies retumbaba un corazón gigantesco.' },
        { who: 'ordin', text: 'Para llegar al trono, necesitamos aquí una cabeza de puente.' },
        { who: 'commander', text: 'La defendemos. Es el camino de vuelta y el camino de ida.' },
        { who: 'bark', text: 'Vine con las vendas puestas. Si me lo pierdo, me arrepiento toda la vida.' },
      ],
      post: [
        { who: 'narrator', text: 'Al alzarse la cabeza de puente, cinco luces se encendieron tras la oscuridad.' },
        { who: 'ordin', text: 'Son los cinco vasallos del Señor. Le aguardan uno a uno.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan la cabeza de puente! ¡Primer paso del último viaje!' } ],
        wave: [ { who: 'kasha', text: '¡No dejan de salir de la oscuridad! ¡Mantengan la formación!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡No puedes caer aquí!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Se abre el camino!' } ],
      },
    },
    92: {
      pre: [
        { who: 'narrator', text: 'La primera luz. Un caballero con una capa raída se apoyaba en su espada.' },
        { who: 'boss', text: 'Soy la primera espada del Señor. Midámonos con honor.' },
        { who: 'commander', text: '……La misma guardia que Bram. Esgrima del antiguo reino.' },
        { who: 'boss', text: 'Yo también fui un caballero humano. Hace muchísimo tiempo.' },
        { who: 'kasha', text: 'La nostalgia, luego. Su formación de cobertura es perfecta.' },
      ],
      post: [
        { who: 'boss', text: 'Magnífico... tu maestro debió de ser un buen caballero.' },
        { who: 'commander', text: 'El mejor. Y tan terco como tú.' },
        { who: 'boss', text: 'Ya veo... entonces, ya puedo descansar...' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Separen primero a los caballeros de escolta! ¡Rompan la cobertura!' } ],
        boss: [ { who: 'boss', text: 'Ese bastón de mando plateado... comandante de campo del reino. Adelante, da tus órdenes.' } ],
        wave: [ { who: 'kasha', text: '¡Refuerzos de caballeros! ¡Protejan el flanco!' } ],
        danger: [ { who: 'kasha', text: '¡Empujan a {ally}! ¡Fuera de la cobertura del caballero!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Adiós al primer vasallo!' } ],
      },
    },
    93: {
      pre: [
        { who: 'narrator', text: 'La segunda luz. Miles de círculos mágicos flotaban en el aire.' },
        { who: 'boss', text: 'Toda magia es cálculo. Tu probabilidad de victoria se acerca a cero.' },
        { who: 'ordin', text: 'Yo también viví calculando así. Y me equivoqué.' },
        { who: 'commander', text: 'Te enseñaré lo que no entra en el cálculo. Manos que se protegen unas a otras.' },
      ],
      post: [
        { who: 'boss', text: 'El cálculo... no cuadra... ¿por qué se protegen unos a otros...?' },
        { who: 'commander', text: 'Por eso ganamos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡A por los hechiceros! ¡Antes de que se completen los círculos!' } ],
        boss: [ { who: 'boss', text: 'Inicio la eliminación de variables. Una, dos, tres.' } ],
        wave: [ { who: 'kasha', text: '¡De los círculos salen invocadores a montones!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Estás en medio del círculo, sal!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Cerremos ese cálculo!' } ],
      },
    },
    94: {
      pre: [
        { who: 'narrator', text: 'La tercera luz. Una fortaleza demoníaca brotó como si quisiera tragarse al clan.' },
        { who: 'boss', text: 'Soy la hueste sin fin. Mis invocaciones jamás se agotan.' },
        { who: 'kasha', text: 'Estamos encerrados en la fortaleza. Hay que aguantar y llegar hasta él.' },
        { who: 'commander', text: 'Aguantamos en la muralla. Esperen a que bajen las invocaciones.' },
      ],
      post: [
        { who: 'boss', text: 'La invocación... se cortó... ¿mi hueste... se agotó...?' },
        { who: 'bark', text: '¡Pues nosotros no nos agotamos!' },
        { who: 'narrator', text: 'La tercera luz se apagó. Quedaban dos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan la muralla! ¡Si cae, la levantamos otra vez! ¡Resistan cada oleada!' } ],
        boss: [ { who: 'boss', text: 'Arrodíllate ante lo incontable.' } ],
        wave: [ { who: 'bark', text: '¡Siguen saliendo! ¿Es que esta invocación no se acaba nunca?' } ],
        danger: [ { who: 'sera', text: '¡Las invocaciones van hacia {ally}! ¡Deténganlas!' } ],
        last: [ { who: 'kasha', text: '¡Queda uno! ¡Se cortó la hueste!' } ],
      },
    },
    95: {
      pre: [
        { who: 'narrator', text: 'La cuarta luz. Un caballero negro encadenado alzó la cabeza.' },
        { who: 'boss', text: 'Humano. Solo una pregunta. ¿Qué es un humano?' },
        { who: 'boss', text: 'Yo quise ser humano. Por eso me prohibieron.' },
        { who: 'commander', text: '……¿Y por qué querías ser humano?' },
        { who: 'boss', text: 'No lo sé. Buscaré la respuesta luchando contra ustedes.' },
      ],
      post: [
        { who: 'boss', text: 'Tender la mano al compañero caído... ¿eso es ser humano?' },
        { who: 'commander', text: 'Sí. Al menos, eso creemos nosotros.' },
        { who: 'boss', text: 'Entonces... al final... ¿me habré parecido... un poco...?' },
        { who: 'sera', text: '……Descansa en paz. Esta es mi plegaria.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Primero la escolta de las cadenas! ¡Aíslen al caballero!' } ],
        boss: [ { who: 'boss', text: 'Muéstrenme lo que son.' } ],
        wave: [ { who: 'kasha', text: '¡Refuerzos tras las cadenas! ¡Miren atrás!' } ],
        danger: [ { who: 'bark', text: '¡{ally}! ¡Ese caballero va en serio, retrocede!' } ],
        last: [ { who: 'sera', text: 'Queda uno. Démosle su respuesta.' } ],
      },
    },
    96: {
      pre: [
        { who: 'narrator', text: 'Al caer los cuatro vasallos, se abrió el corredor hacia el trono.' },
        { who: 'ordin', text: 'Al final de este corredor está la puerta que guarda la guardia del Señor.' },
        { who: 'kasha', text: 'El corredor está vivo. Las paredes se mueven.' },
        { who: 'commander', text: 'Seguimos sin parar. Que no los atrapen las paredes.' },
      ],
      post: [
        { who: 'narrator', text: 'Al final del corredor apareció una enorme puerta de brillo negro.' },
        { who: 'ordin', text: 'Ante esa puerta hay que levantar el último campamento.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Avancen defendiendo el corredor! ¡Que no nos corten!' } ],
        wave: [ { who: 'bark', text: '¡Salen enemigos de las paredes!' } ],
        danger: [ { who: 'sera', text: '{ally}, ¡el corredor se estrecha! ¡Esquiva!' } ],
        last: [ { who: 'kasha', text: 'Queda uno. Estamos ante la puerta.' } ],
      },
    },
    97: {
      pre: [
        { who: 'narrator', text: 'Ante la puerta del trono. El clan levantó el último campamento.' },
        { who: 'ordin', text: 'Necesito tiempo para romper el sello de la puerta. Protéjanme.' },
        { who: 'kasha', text: 'Quién iba a decir que llegaría el día de proteger a este viejo.' },
        { who: 'commander', text: 'Defendemos el campamento. Hasta que Ordin rompa el sello.' },
      ],
      post: [
        { who: 'ordin', text: 'El sello casi está roto. Queda una última capa.' },
        { who: 'ordin', text: 'Esa capa... me corresponde a mí.' },
        { who: 'commander', text: '¿Qué quieres decir, Ordin?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Defiendan el último campamento! ¡Protejan a Ordin!' } ],
        wave: [ { who: 'kasha', text: '¡La guardia sale en tromba de tras la puerta!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡Adentro del campamento!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡El campamento resiste!' } ],
      },
    },
    98: {
      pre: [
        { who: 'ordin', text: 'Hace quince años, abandoné a sus padres y huí.' },
        { who: 'ordin', text: 'Todo lo que hice desde entonces nació de ese miedo.' },
        { who: 'ordin', text: 'El último sello solo se rompe con la vida de un mago.' },
        { who: 'commander', text: 'Dijiste que pagar muriendo era demasiado fácil.' },
        { who: 'ordin', text: 'Por eso abriré el camino mientras siga con vida. Protéjame hasta el final.' },
      ],
      post: [
        { who: 'narrator', text: 'El último sello se rompió y el cuerpo de Ordin se deshizo en luz.' },
        { who: 'ordin', text: 'Dígales a sus padres... que lo siento...' },
        { who: 'commander', text: '……Discúlpate tú. Algún día, al otro lado.' },
        { who: 'narrator', text: 'La puerta se abrió. Al otro lado esperaba el capitán de la guardia.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Abrimos camino mientras Ordin rompe el sello!' } ],
        wave: [ { who: 'kasha', text: '¡La guardia va a por Ordin! ¡Deténganla!' } ],
        danger: [ { who: 'sera', text: '¡Rompieron la retaguardia! ¡Todos hacia {ally}!' } ],
        last: [ { who: 'commander', text: 'Queda uno. ¡Ordin, un poco más!' } ],
      },
    },
    99: {
      pre: [
        { who: 'narrator', text: 'La antesala del trono. Un guerrero negro como la brea clavó su mandoble en el suelo.' },
        { who: 'boss', text: 'Superaste a los cuatro vasallos. Pero yo soy el escudo del Señor.' },
        { who: 'boss', text: 'Para llegar al Señor, tendrás que destrozarme.' },
        { who: 'commander', text: 'Entonces te destrozamos. Todos juntos.' },
        { who: 'bark', text: 'Me quité las vendas, capi. Iré delante hasta el final.' },
      ],
      post: [
        { who: 'boss', text: 'El escudo... se rompió... mi Señor... la Llave va hacia usted...' },
        { who: 'narrator', text: 'La última puerta se abrió sin un ruido.' },
        { who: 'sera', text: '{commander}, dame la mano. Entremos todos juntos.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Quitamos a la guardia y rodeamos al guerrero!' } ],
        boss: [ { who: 'boss', text: '¡En nombre del Señor, deténganse aquí!' } ],
        wave: [ { who: 'kasha', text: '¡La última guardia! ¡Detrás solo está el Señor!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡No recibas ese mandoble!' } ],
        last: [ { who: 'bark', text: '¡Queda uno! ¡Estamos ante la puerta!' } ],
      },
    },
    100: {
      pre: [
        { who: 'narrator', text: 'El trono del Reino Demoníaco. Allí se sentaba un guerrero gigantesco con yelmo.' },
        { who: 'boss', text: 'Hace quince años, dos humanos cerraron mi puerta.' },
        { who: 'boss', text: 'Y su cría viene por su propio pie. A ofrecerme la Llave.' },
        { who: 'commander', text: 'No vengo a ofrecerla. Vengo a echar el cerrojo.' },
        { who: 'commander', text: 'No a solas, sino con las manos de todos los que están aquí.' },
        { who: 'boss', text: 'Por muchos humanos que se junten, caerán uno a uno.' },
      ],
      post: [
        { who: 'boss', text: '¿Por qué... cuando derribo una mano... otra la sostiene...?' },
        { who: 'narrator', text: 'Con el bastón de mando bajado y la cicatriz al descubierto, todos juntaron sus manos.' },
        { who: 'commander', text: 'Esta es la Llave. Todos nosotros.' },
        { who: 'narrator', text: 'La Llave giró, y el trono del Señor Demoníaco se hundió en la luz.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '¡Última orden! ¡Clan de Solbit, todos a una!' } ],
        boss: [ { who: 'boss', text: 'Ven, Llave. Quebraré todo lo que eres.' } ],
        wave: [ { who: 'kasha', text: '¡Se alzan las sombras del trono! ¡Es la última hueste!' } ],
        danger: [ { who: 'sera', text: '¡{ally}! ¡No caigas! ¡Aquí estamos!' } ],
        last: [ { who: 'bark', text: '¡Queda uno, capi! ¡Acabemos, todos juntos!' } ],
      },
    },
  },
};
