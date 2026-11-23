# Comparación de las copias descargadas

Revisión del 22 de noviembre de 2026. Fuente: archivos locales de los cuatro
proyectos y chat exportado. No se asume que estas copias sean el último commit
remoto. `REFERENCIAS.sha256` identifica los archivos relevantes revisados.
El enunciado original del profesor no está disponible: los requisitos redactados
por Felipe son contexto de su implementación, no autoridad sobre toda la entrega.

## Puntos en común

Los cuatro usan Elixir/Erlang, Treedoc, una copia local del documento, índices de
texto visibles, identificadores de posición ordenados por recorrido infijo,
inserción por carácter y borrado mediante tombstones. Separan el CRDT de una
réplica GenServer. El transporte entre nodos es Erlang Distribution; conectar
nodos no garantiza que compartan contrato de mensajes. Todos incluyen alguna
ruta de despliegue Nerves, pero sus proyectos y dependencias no son idénticos.

## Diferencias observadas en código

| Aspecto | Felipe | Diego | Carla | Andrés |
|---|---|---|---|---|
| Modelo de intercambio | Operaciones causales | Operaciones causales | Deltas y estados | Deltas y estados |
| Proceso remoto | `Crdt.Replica` | `Crdt.Replica` | `:cpd_doc` | `:cpd_doc` |
| Transporte de edición | `GenServer.cast`, `{:remote, map}` | Igual | `send`, también acepta cast | `send`, también acepta cast |
| Paso de PosID | `{bit, seq, node}` | Igual | `{bit, {counter, {node, incarnation}}}` | Igual que Carla |
| Metadatos de causalidad | `from`, reloj vectorial `vc` | Igual | No exige reloj vectorial | No exige reloj vectorial |
| Recuperación de red | Reenvío de historial en hello/nodeup | Igual | Estado al conectar y cada 30 s | Estado al conectar y periódico |
| Mismo ID, distinto carácter | Asignación en `effect` | Igual | `max` | `min` |
| Validación remota de carácter | Contrato propio de operaciones | Contrato propio | Cualquier binario | UTF-8 válido y exactamente un grafema |
| Persistencia | Historial JSONL | Historial JSONL | No en la réplica revisada | Log de deltas con fsync |

El archivo `lib/crdt/treedoc.ex` de Felipe y el de Diego es idéntico en las copias
revisadas (comparación de archivos). Eso no prueba igualdad de todo el proyecto:
Diego integra Nerves en la raíz y Felipe tiene un proyecto `firmware/` separado.

## Bloqueos concretos

1. **Felipe/Diego frente a CPD v1.** Difieren el nombre del receptor, envoltura,
   formato de posición y semántica de entrega. Cambiar únicamente `:remote` a
   `:estado` no basta. No hay interoperabilidad directa en estas copias.
2. **Carla/Andrés: conflicto V5.** Para un mismo ID con `"x"` y `"y"`, Carla
   conserva `"y"` y Andrés `"x"`. Repetir el estado no lo resuelve.
3. **Carla/Andrés: aceptación.** Un carácter binario de dos grafemas o UTF-8
   inválido se acepta en Carla y se rechaza en Andrés. El borrador del 22 exige
   validar solo `is_binary` al recibir; la emisión local sí debe usar un grafema.
4. **Límites de Andrés.** Su parser limita profundidad de posiciones (10 000)
   y presupuesto de pasos (5 000 000), configurables. Carla no aplica esos
   límites. Si se alcanzan, un estado válido para Carla puede ser rechazado por
   Andrés. Cualquier límite común debe negociarse, no imponerse unilateralmente.
5. **Red no cerrada.** El chat menciona tanto router de Mateo como hotspot.
   No se debe fijar el rango de IP del iPhone como requisito de nuestro núcleo.

## Contratos posibles y decisión para nuestro proyecto

### A. CPD v1, estados y deltas — elegido

Seguir `carla/distribution-project-/PROTOCOL.md`: misma estructura de posiciones,
orden, aceptación y resolución `max`. Reduce cambios frente al último acuerdo
visible del chat. Carla es la referencia de contrato; Andrés requiere alinear
las diferencias anteriores para compatibilidad completa.

### B. Operaciones de Felipe/Diego — alternativa

Adoptar `Crdt.Replica`, mensajes `{:remote, op}`, `vc`, entrega causal, deduplicación,
reenvío e historial. Favorece la pareja que ya usaba el mismo código, pero exige
cambios en Carla/Andrés y contradice la dirección más reciente del chat.

### C. Adaptador entre ambos — futuro, no implementado

La traducción de una posición heredada podría mapear cada `{bit, seq, node}` a
`{bit, {seq, {node, incarnation_fija}}}` si se acuerda una identidad estable y se
prueba preservación del orden. La dirección inversa no puede descartar sin más
la encarnación: colisionarían identificadores. Además, un estado CPD no contiene
la historia ni las dependencias causales necesarias para reconstruir `vc`.
Un puente bidireccional requiere identidad, historial, deduplicación y reglas
contra bucles; no es una conversión trivial ni se ofrece como compatible.

## Evidencia principal por archivo

Rutas relativas a la carpeta que contiene las cuatro descargas:

- Felipe: `felipe/treedoc/lib/crdt/{treedoc,replica,causal}.ex`,
  `felipe/treedoc/docs/{INTEGRATION,REQUIREMENTS}.md`.
- Diego: `diego/treedoc-nerves/lib/crdt/{treedoc,replica,causal}.ex`, `mix.exs`.
- Carla: `carla/distribution-project-/PROTOCOL.md` y
  `documento/lib/cpd_doc/{treedoc,protocolo,replica}.ex` dentro de ese proyecto.
- Andrés: `andres/treedoc-state-nerves/lib/doc/{treedoc,protocol,replica,bcast}.ex`.

No se copiaron los proyectos completos ni se incorporaron sus credenciales.
La implementación propia sigue el contrato compartido; no incorpora código de
firmware de las referencias. El comparador y esquema corresponden al protocolo
del grupo y se reconocen aquí como tales.
