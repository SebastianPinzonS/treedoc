# Validación y siguiente integración

## Estado de verificación al crear el repositorio

Se revisaron las cuatro copias locales y se comparó el núcleo de Felipe/Diego.
Se escribieron pruebas ExUnit y un script que carga módulos reales de Carla y
Andrés. **Todavía no se han ejecutado:** este entorno no tiene `elixir` ni `mix`
y el usuario actual no tiene acceso al socket Docker. No se afirma compilación,
pruebas exitosas ni interoperabilidad de red a partir de revisión estática.

Con el runtime disponible, ejecutar desde la raíz:

```sh
mix format
mix compile --warnings-as-errors
mix test
mix run scripts/compare_references.exs ..
```

La suite cubre los cinco vectores del borrador, leyes del merge, concurrencia,
duplicados, tombstone adelantado, Unicode, índices, rechazo de mensajes completos
y recepción tanto por send como por cast. El script de referencias verifica el
intercambio básico y reproduce dos incompatibilidades actuales de Andrés.

## Prueba de aceptación en laboratorio

1. Arrancar nuestro nodo y uno de Carla en la misma LAN con nombres largos y
   cookie común. Comprobar `Node.connect/1` y `Node.list/0`.
2. Insertar y borrar en ambos. Comparar texto y estado normalizado (las listas
   de átomos/tombstones pueden tener distinto orden de serialización).
3. Insertar concurrentemente en el mismo índice: ambos textos deben coincidir
   cuando hayan recibido los cambios. No exigir un orden particular de autores.
4. Desconectar un nodo sin apagarlo, editar en ambos y reconectar. Comprobar
   convergencia tras la sincronización completa.
5. Detener nuestra VM dejando otro nodo vivo; arrancarla de nuevo y esperar
   hasta un período de sincronización. Debe recuperar el documento del par.
6. Repetir con Andrés después de alinear `max`, aceptación de binarios y límites.
7. Repetir sobre Raspberry. No dar por verificado firmware a partir de una
   ejecución en computador.

## Antes de considerar lista la entrega

- Obtener el enunciado original y confirmar fecha, API exigida y si se exige
  explícitamente reloj vectorial/operation-based pese al nuevo acuerdo del chat.
- Confirmar modelo de nuestra Pi, sistema operativo y quién aporta hardware.
- Añadir persistencia probada: reinicio de todas las réplicas, contador/identidad,
  log truncado y errores de escritura. Hoy el estado es volátil.
- Acordar red, versiones de runtime, frecuencia de estados y límites comunes.
- Preparar imagen Nerves si es requerida, o ejecutar en Raspberry Pi OS.
- Ejecutar las pruebas escritas y las pruebas reales de red.
- Decidir si se necesita interfaz gráfica o compilación LaTeX: no está demostrado
  por el chat y no se incluye en esta primera base.
