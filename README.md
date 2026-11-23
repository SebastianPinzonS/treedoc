# Treedoc Equipo

Implementación inicial independiente en Elixir para editar un documento compartido.
Adopta CPD v1 del borrador de Carla del 22 de noviembre de 2026: Treedoc,
deltas por edición y estados completos periódicos. Sin dependencias externas.

## Estado del proyecto

Incluye núcleo CRDT, validación del contrato, réplica GenServer supervisada,
API de consola y pruebas automatizadas. Es una base de implementación, no una
entrega completa de Overleaf. El código de los otros equipos no se modifica.

- [Comparación de las cuatro implementaciones](docs/COMPARACION.md).
- [Contrato de red y API local](docs/CONTRATO.md).
- [Validación y pendientes para laboratorio](docs/VALIDACION.md).

## Ejecutar

Requiere Elixir >= 1.18 y < 2.0 con una versión compatible de Erlang/OTP.
No se necesita Nerves para desarrollar ni para ejecutarlo sobre Raspberry Pi OS.

```sh
mix compile --warnings-as-errors
mix test
iex --name doc@TU_IP --cookie cpd2026 -S mix
```

Reemplaza `TU_IP` por la IPv4 real. En IEx:

```elixir
Node.connect(:"doc@IP_DEL_OTRO")
Node.list()
TreedocEquipo.insert(0, "H")
TreedocEquipo.insert(1, "á")
TreedocEquipo.text()
TreedocEquipo.delete(0)
TreedocEquipo.state()
TreedocEquipo.sync()
```

Cada inserción acepta **un grafema**. Los índices empiezan en cero; un emoji
compuesto cuenta como un grafema. `insert/2` y `delete/1` devuelven `:ok` o
`{:error, motivo}`. Son llamadas locales, no un contrato RPC entre grupos.

Para dos nodos en un computador, usa dos terminales con nombres diferentes:

```sh
iex --name equipo1@127.0.0.1 --cookie cpd2026 -S mix
iex --name equipo2@127.0.0.1 --cookie cpd2026 -S mix
```

Desde el primero: `Node.connect(:"equipo2@127.0.0.1")`. Escribe en ambos y
consulta `TreedocEquipo.text()`. Cada VM tiene su propio proceso `:cpd_doc`.
La cookie del curso sirve para una red de laboratorio de confianza.

## Comparar con las descargas

Conservando la estructura actual de carpetas:

```sh
mix run scripts/compare_references.exs ..
```

El script carga únicamente los módulos puros de Carla y Andrés, sin sus
aplicaciones Nerves. Comprueba intercambio en ambos sentidos y reproduce las
diferencias `max/min` y validación de caracteres. No cambia las referencias.
Los resultados esperados de incompatibilidad son hallazgos, no errores de la prueba.

## Límites actuales

El estado vive en memoria: reiniciar pierde las ediciones que no conserve otro
nodo. Una nueva encarnación aleatoria de 128 bits reduce el riesgo de repetir
identificadores, pero no reemplaza la persistencia. No hay firmware Nerves,
interfaz web, LaTeX, discovery automático, balanceo ni recolección de tombstones.
El árbol simple puede producir mensajes grandes al escribir textos largos.

La sincronización completa cada 30 s permite reparar deltas perdidos mientras
exista una réplica con esos cambios y vuelvan a entregarse mensajes. No es una
confirmación de entrega durable. Los nodos deben conectarse con `Node.connect/1`.

Repositorio Git local creado en `treedoc-equipo/`, rama `main`. No se ha creado
ni publicado un repositorio remoto.
