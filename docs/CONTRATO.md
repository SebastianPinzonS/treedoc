# Contrato propuesto para nuestro equipo

Base: borrador de Carla del 22/11/2026 a las 15:20. Adoptado para este repositorio;
no equivale a una ratificación adicional de todos los equipos.

## Red

Una LAN con conectividad entre pares, nombres largos Erlang y cookie `cpd2026`.
En laboratorio: `doc@<IPv4>`; en pruebas locales varios nombres distintos por IP.
EPMD usa 4369 y la distribución otro puerto TCP; la red/firewall debe permitirlos.
No se necesita un servidor HTTP ni un puerto TCP de aplicación adicional.
Discovery, SSID y credenciales de Wi-Fi quedan fuera del núcleo. Se conecta con
`Node.connect/1` y se comprueba con `Node.list/0`.

## Mensaje y destinatario

Proceso registrado `:cpd_doc`; acepta `send/2` y también `GenServer.cast/2`.

```elixir
{:cpd, 1, origin, {:estado, atoms, tombstones}}
# origin: atom del nodo emisor
# atoms: lista propia de {posid, binary}
# tombstones: lista propia de posid
# posid: lista propia NO vacía de {bit, {counter, {writer, incarnation}}}
# bit: 0 o 1; counter e incarnation: enteros; writer: atom
```

Mismo formato para delta y estado completo. Un delta de inserción lleva un
átomo; uno de borrado lleva un tombstone. Se envía a todos los nodos conectados.
El estado completo se envía al arrancar, al recibir nodeup y cada 30 segundos.
El período es un valor inicial, pendiente de acuerdo de rendimiento del grupo.

## Reglas obligatorias de convergencia

- Validar el mensaje completo antes de modificar estado. Rechazar versiones,
  formas o tipos desconocidos; nunca mezclar parcialmente un mensaje inválido.
- Al recibir, aceptar cualquier binario como carácter. Al insertar localmente,
  exigir UTF-8 válido y exactamente un grafema.
- Combinar por ID. Ante varios caracteres con el mismo ID, conservar `max` en
  orden de términos Erlang, incluso si el conflicto está dentro de un mensaje.
- Unir tombstones; conservar los que lleguen antes de sus átomos.
- No eliminar físicamente átomos ni tombstones. No implementar garbage collection
  sin un acuerdo de estabilidad causal de todos los participantes.
- Texto visible: átomos no borrados, ordenados con `Document.less?/2`, equivalente
  al comparador del borrador. No usar directamente orden lexicográfico de listas.
- Generar IDs entre vecinos del orden completo, incluyendo borrados, y nunca
  reutilizarlos. Contador por inserción; identidad `{node(), incarnation}`.

Nuestra implementación usa encarnación aleatoria de 128 bits por inicio de
réplica. El contrato solo exige un entero: no obliga al rango aleatorio de Carla.
La unicidad es probabilística; la persistencia durable queda pendiente.

## API local de nuestra aplicación

| Función | Resultado |
|---|---|
| `TreedocEquipo.insert(index, grapheme)` | `:ok` o error; inserta un grafema |
| `TreedocEquipo.delete(index)` | `:ok` o error; borra un grafema visible |
| `TreedocEquipo.text()` | Binario con el texto visible |
| `TreedocEquipo.state()` | `{atoms, tombstones}` |
| `TreedocEquipo.sync()` | Solicita difusión completa asincrónica |

Esta API es una decisión interna. Los otros equipos solo necesitan el contrato
de mensajes, no el nombre de nuestros módulos ni nuestras funciones locales.
No se prometen llamadas remotas síncronas, varios documentos ni edición por bytes.
