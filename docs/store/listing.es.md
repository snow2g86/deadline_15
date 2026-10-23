# DEADLINE 15 — Texto para la ficha de las tiendas (español)

> Escrito el 2026-10-23 para la versión 0.4.2 del juego. Borrador. El recuento de caracteres está al final del archivo.
> Los términos coinciden con `godot/data/lang/es.json` (miembro del clan, Comandante, piedra de alma, Mazmorra diaria, Santuario, runa, oro).
> `[확인 필요]` (= "por confirmar") marca datos que no pude confirmar en el código ni en los documentos.
> Nota: en el juego el sistema de garantía se llama "Piedad" (`gacha_pity`); en la ficha uso "garantía" porque se entiende mejor. Conviene revisarlo con un hablante nativo [확인 필요].

## 1. Nombre de la app (máx. 30 caracteres)

```
DEADLINE 15 - RPG por turnos
```

- Sirve para Google Play y para App Store. App Store rechaza nombres ya en uso [확인 필요: disponibilidad del nombre].
- Nombre bajo el icono: `DEADLINE 15` (`config/name` en project.godot).

## 2. Descripción corta (máx. 80 caracteres, Google Play)

```
15 casillas de punta a punta: bloquea ese extremo. RPG de defensa por turnos.
```

## 3. Solo para App Store

- Subtítulo (máx. 30): `RPG de defensa por turnos`
- Texto promocional (máx. 170): `Lidera a cinco miembros del clan y defiende el castillo. Usa terreno, flancos y cobertura por turnos, entrena 12 clases y mejora tu equipo. Sin cuenta.`
- Palabras clave (máx. 100, separadas por comas, sin espacios):

```
por turnos,estrategia,defensa,tactica,RPG,pixel,isometrico,SRPG,clan,mazmorra,fantasia,torres
```

## 4. Descripción completa (máx. 4000 caracteres)

```
Resiste antes de que caiga la puerta.

El nombre DEADLINE 15: el mapa mide 15 casillas de punta a punta, y debes bloquear ese extremo y defenderlo.

DEADLINE 15 es un RPG táctico de defensa por turnos. Forma un equipo de cinco miembros del clan y defiende tu castillo en mapas isométricos de píxel art, avanzando casilla a casilla para impedir que el enemigo irrumpa. Tú eres el Comandante: diriges al clan desde la retaguardia y no combates.

CÓMO SE JUEGA
- Tácticas por turnos: elige movimiento, ataque o habilidad de cada miembro.
- Si demasiados enemigos cruzan la muralla ("irrupciones"), pierdes. Bloquea la puerta con un Caballero y apoya desde atrás.
- 100 fases en 10 episodios, con un jefe cada 10.

COMBATE
- Usa el terreno: el bosque permite esquivar ataques normales, las unidades a distancia en una colina disparan más lejos y con más fuerza, y los enemigos en aguas poco profundas reciben más daño.
- Tácticas de posición: ataques por la espalda y por el flanco, ataques combinados, cobertura y empujones.
- Cada tipo de mapa tiene su propio efecto negativo del entorno (calor, frío, veneno, maldiciones y más) que puedes bloquear con la runa de encantamiento adecuada.
- Bonificaciones de sinergia según las clases del equipo.
- Objetos de asedio, cofres del tesoro y pociones de combate.
- Los enemigos se fortalecen: el nivel por sí solo no basta.

12 CLASES PARA ENTRENAR
Guerrero, Caballero, Asesino, Mago, Arquero, Sacerdote, Novato, Invocador, Chamán, Peleador, Lancero y Zapador. Los Novatos pueden cambiar de clase en la Academia.
- En el Santuario, sube el grado (C > B > A > S) sacrificando miembros del clan de la misma clase. Los ascensos B→A y A→S también requieren piedras de alma.
- Los miembros caídos se pueden resucitar en el Santuario con oro.

PROGRESIÓN
- Mazmorra diaria: cada día se abren clases distintas con sus fragmentos de alma, que se combinan en piedras de alma.
- Equipo: armas de clase, armaduras compartidas, equipo legendario y conjuntos de clase.
- Mejora de +1 a +10: si falla, el nivel puede bajar o el objeto romperse. Un pergamino de protección evita la rotura.
- Encantamiento: usa runas para dar al equipo resistencia al entorno y efectos de ataque (filo ígneo, escarcha, veneno, trueno, robo de vida, quiebre).

ADEMÁS
- 6 idiomas: coreano, inglés, español, japonés, chino simplificado y chino tradicional
- Empieza a jugar sin crear una cuenta
- Códice y guía de estrategia en el juego

PROBABILIDADES DE OBJETOS ALEATORIOS
Este juego contiene objetos aleatorios.
- Sorteo de equipo (tienda): las probabilidades varían según el grado y hay una garantía (el sorteo 100 sin legendario asegura uno).
- Sorteo de runa (tienda): las 12 runas tienen la misma probabilidad.
- Mejora de equipo: cada nivel tiene probabilidades de éxito, fallo y rotura.
La tabla completa está en las pantallas de tienda y mejora ("Probabilidades") y en esta dirección.
Tabla de probabilidades: [URL de la tabla -- dirección publicada de docs/store/probabilities.es.md [확인 필요]]

OBJETOS DE PAGO Y ANUNCIOS
- Paquetes de oro (compra dentro de la app, consumible): 500 / 1.200 / 3.000 / 6.500 de oro. El oro sirve para reclutar mercenarios, resucitar, sortear equipo, mejorar y más. También se consigue jugando.
- Anuncios con recompensa: mira un anuncio completo para recibir 100 de oro (hasta 3 veces al día). Puedes jugar sin ver anuncios.
- Los anuncios los ofrece Google AdMob. Según tu región, puede aparecer una ventana de consentimiento de privacidad; puedes cambiar tu elección en Ajustes.
- En iOS se te puede pedir permiso para el seguimiento mediante el identificador de tu dispositivo. El juego funciona exactamente igual si no lo permites.
- Para verificar las compras, se envían a nuestro servidor de verificación un ID de instalación generado al azar y los datos del recibo de compra. Consulta la Política de privacidad para más detalles.

Política de privacidad: [URL de la política de privacidad [확인 필요]]
Contacto: [correo de soporte [확인 필요]]
```

### Cambios para la ficha de PC (STOVE)

- Elimina la línea de "Anuncios con recompensa" y las líneas de "Google AdMob" y "seguimiento en iOS" (la edición de PC no tiene anuncios).
- Usa los precios registrados en STOVE para los paquetes de oro (ver la lista de tareas).
- Mantén el aviso de objetos aleatorios (STOVE también exige publicar las probabilidades).

## 5. Lista de características

- Combates de defensa por turnos en píxel art isométrico (100 fases, 10 episodios)
- 12 clases de miembros del clan, con ascenso de grado (C > B > A > S)
- Tácticas de terreno, ataques por la espalda y el flanco, cobertura y empujones
- Mazmorra diaria y piedras de alma, sorteos de equipo, mejora hasta +10, runas de encantamiento
- Bonificaciones de sinergia, efectos negativos del entorno y runas defensivas
- Historia del Comandante y el clan, códice y guía de estrategia
- 6 idiomas (coreano, inglés, español, japonés, chino simplificado y tradicional)
- Sin cuenta / anuncios con recompensa en móvil (3 al día) / sin anuncios en la edición de PC

## 6. Notas de la versión (primera versión)

Google Play "Novedades" (máx. 500 caracteres):

```
Bienvenido a DEADLINE 15.
- 100 fases de combates de defensa por turnos
- Entrena y asciende 12 clases de miembros del clan
- Mazmorra diaria, sorteos y mejora de equipo, runas de encantamiento
- Coreano, inglés, español, japonés, chino simplificado y tradicional
- Paquetes de oro (compra en la app) y anuncios con recompensa (3 al día)
```

Número de versión de la primera publicación: [확인 필요] (la versión interna del juego es 0.4.2).

## 7. Aviso de probabilidades (dónde va el enlace)

| Dónde | Texto |
|---|---|
| Descripción completa, párrafo "PROBABILIDADES DE OBJETOS ALEATORIOS" | El texto de arriba más la URL de la tabla [확인 필요] |
| Última línea de la descripción de Google Play | `Probabilidades de los objetos aleatorios (sorteo de equipo, sorteo de runas, mejora de equipo): [URL de la tabla]` |
| Última línea de la descripción de App Store y la página de la URL de soporte | La misma frase. La descripción de App Store no convierte las URL en enlaces, así que escribe la dirección como texto y pon también la tabla en la página de la URL de soporte. |
| En el juego | "Probabilidades" en las pantallas de tienda y de mejora (ya implementado; mismo contenido que `docs/store/probabilities.es.md`) |

## 8. Objetos de pago y anuncios (valores para los formularios)

| Elemento | Valor |
|---|---|
| Contiene compras dentro de la app | Sí (4 paquetes de oro, consumibles) |
| Rango de precios de productos (Play) | 1.200 - 12.000 KRW (precio base de Corea del Sur) |
| Contiene anuncios | Sí (solo móvil, anuncios con recompensa) |
| App Store: anuncios y seguimiento | Anuncios en la app: sí / solicitud de permiso de seguimiento (ATT): sí |

## 9. Guía para el cuestionario de clasificación por edades

Consulta `age_rating_notes.md` para la explicación completa. Respuestas en borrador:

| Pregunta | Respuesta | Base |
|---|---|---|
| Violencia | Sí: combate de fantasía con personajes de píxel art | Los personajes se atacan y caen en combate. Existe un estado "Sangrado" mostrado como texto. Si se dibuja sangre en pantalla: [확인 필요: comprobar en el juego en ejecución] |
| Miedo / terror | No [확인 필요] | |
| Contenido sexual / desnudez | No | |
| Lenguaje soez | No [확인 필요: revisar los diálogos en todos los idiomas] | |
| Drogas, alcohol, tabaco | No [확인 필요] | |
| Juego de azar | No hay apuestas con dinero real. Hay objetos aleatorios que se obtienen con moneda de pago (oro): sorteo de equipo, sorteo de runas y mejora | Responde "sí" si el formulario pregunta por objetos aleatorios o cajas de botín |
| Compras dentro de la app | Sí (paquetes de oro, consumibles) | |
| Anuncios | Sí (anuncios con recompensa en móvil, Google AdMob) | No dirigido a niños |
| Interacción entre usuarios / contenido generado por usuarios | No (solo se puede renombrar un personaje; no lo ven otros jugadores) [확인 필요] | |
| Compartir ubicación / datos personales | No | |
| Dirigido a niños | No | `child_directed=false` en iap.json |

## 10. Recuento de caracteres

(La tabla siguiente se calculó con un script después de escribir el texto.)

| Elemento | Caracteres | Límite | Resultado |
|---|---|---|---|
| Nombre de la app | 28 | 30 | OK |
| Descripción corta | 77 | 80 | OK |
| Palabras clave (App Store) | 93 | 100 | OK |
| Descripción completa | 3992 | 4000 | OK |
| Novedades (Play) | 337 | 500 | OK |
| Subtítulo (App Store) | 25 | 30 | OK |
| Texto promocional | 151 | 170 | OK |
