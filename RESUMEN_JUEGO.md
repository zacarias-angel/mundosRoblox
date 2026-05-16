# Resumen Del Juego

## Vision general

Este proyecto mezcla dos sistemas principales:

1. Un sistema de combate tipo match-3 por arrastre de fichas.
2. Un sistema de gravedad planetaria para personajes que recorren planetas.

El sistema de combate esta planteado con autoridad en servidor:

- El cliente solo propone el recorrido de swaps.
- El servidor valida el movimiento.
- El servidor resuelve combinaciones, cascadas, gravedad y relleno.
- El cliente solo representa visualmente el resultado sincronizado.

## Cantidad de scripts

- Scripts y modulos principales del proyecto: 10
- Scripts de referencia en `otrojuegosimilar/`: 3
- Total de archivos de logica encontrados: 13

## Scripts principales

### Combate match-3

#### `StarterPlayer/StarterPlayerScripts/CombatUI.lua`

Tipo: LocalScript  
Contexto: Cliente

Que hace:

- Construye la UI del tablero de combate.
- Detecta input de mouse y touch para arrastrar fichas.
- Hace preview local del recorrido de swaps.
- Envia al servidor la ruta final con `CombatSubmit`.
- Recibe el estado canonico con `CombatSync`.
- Reproduce animaciones de:
  - desaparicion secuencial de combinaciones
  - caida de fichas
  - relleno de nuevas fichas
  - rebote al aterrizar
  - contador visual de combo

#### `ServerScriptService/CombatServer.server.lua`

Tipo: Script  
Contexto: Servidor

Que hace:

- Mantiene el tablero real de cada jugador.
- Valida el payload enviado por el cliente.
- Verifica que la ruta de swaps sea valida.
- Aplica los swaps en servidor.
- Detecta combinaciones y cascadas.
- Aplica gravedad y relleno.
- Calcula dano por celdas eliminadas.
- Sincroniza al cliente con el grid final y los datos de cascadas.

#### `ServerScriptService/CombatRemoteSetup.server.lua`

Tipo: Script  
Contexto: Servidor

Que hace:

- Crea la carpeta `ReplicatedStorage/RemoteEvents` si no existe.
- Crea los RemoteEvents del combate:
  - `CombatSubmit`
  - `CombatSync`

#### `ReplicatedStorage/Modules/CombatGrid.module.lua`

Tipo: ModuleScript  
Contexto: Compartido

Que hace:

- Contiene toda la logica pura del tablero.
- Crea grids nuevos sin matches iniciales.
- Valida celdas y adyacencia.
- Detecta matches horizontales y verticales.
- Aplica swaps.
- Elimina combinaciones.
- Aplica gravedad.
- Genera nuevas fichas.
- Resuelve cascadas completas.

#### `ReplicatedStorage/Modules/Debug.lua`

Tipo: ModuleScript  
Contexto: Compartido

Que hace:

- Provee una API simple de logs, warnings y errores.
- Sirve para centralizar debug y luego apagarlo en produccion.

### Sistema de gravedad planetaria

#### `StarterPlayer/StarterCharacterScripts/PlanetGravityController.client`

Tipo: LocalScript  
Contexto: Cliente

Que hace:

- Controla la gravedad personalizada del personaje.
- Busca el planeta activo segun influencia.
- Usa modulos compartidos para direccion de gravedad y registro de planetas.
- Tiene fallbacks por si los modulos no estan disponibles al iniciar.

#### `ServerScriptService/PlanetGravityServer.server`

Tipo: Script  
Contexto: Servidor

Que hace:

- Desactiva la gravedad global de Roblox poniendo `workspace.Gravity = 0`.
- Deja el espacio listo para usar gravedad personalizada.

#### `ServerScriptService/PlanetBootstrap.server`

Tipo: Script  
Contexto: Servidor

Que hace:

- Crea o asegura la carpeta `Workspace/Planets`.
- Prepara planetas recorribles con partes y atributos necesarios.
- Configura valores por defecto de gravedad e influencia.

#### `ReplicatedStorage/Modules/PlanetGravityMath.module.lua`

Tipo: ModuleScript  
Contexto: Compartido

Que hace:

- Calcula direccion de gravedad hacia el centro del planeta.
- Proyecta movimiento sobre la tangente de la superficie.

#### `ReplicatedStorage/Modules/PlanetRegistry.module`

Tipo: ModuleScript  
Contexto: Compartido

Que hace:

- Valida si un modelo puede actuar como planeta.
- Busca la parte de superficie correcta.
- Centraliza acceso a configuracion y estructura de planetas.

## Scripts de referencia

Estos archivos parecen venir de otro prototipo y sirven como referencia para el sistema match-3 actual.

#### `otrojuegosimilar/boarlogi.lua`

- Logica vieja de tablero.
- Detecta combinaciones, elimina piezas, aplica gravedad y relleno.

#### `otrojuegosimilar/celdacontroler.lua`

- Genera o controla celdas del tablero en una UI anterior.
- Verifica combinaciones iniciales.

#### `otrojuegosimilar/dragandrop.lua`

- Maneja arrastre de piezas, timer y restauracion de estado.
- Sirve como referencia de interaccion anterior.

## Avance actual

### Lo que ya esta funcionando

- El tablero match-3 ya existe y se renderiza en cliente.
- El jugador puede arrastrar una ficha por celdas adyacentes.
- El cliente envia la ruta al servidor.
- El servidor valida el movimiento y no delega autoridad al cliente.
- El servidor resuelve combinaciones, cascadas, gravedad y relleno.
- El cliente recibe cascadas y las representa visualmente.
- Las combinaciones desaparecen secuencialmente.
- Las fichas caen con animacion de movimiento.
- Las nuevas fichas entran desde arriba.
- Las fichas hacen un pequeno rebote al aterrizar.
- El contador de combo ya existe y se esta mostrando segun multiples combinaciones.

### Estado puntual del combate

Actualmente el sistema de combate ya paso de una fase base a una fase jugable:

- UI operativa
- logica de servidor operativa
- motor de grid modularizado
- sincronizacion cliente-servidor operativa
- cascadas operativas
- animaciones base operativas

### Lo ultimo trabajado

En el `CombatUI` se estuvo afinando:

- desaparicion secuencial de combos
- animacion de gravedad y relleno
- rebote de fichas al aterrizar
- texto de combo arriba del tablero
- suma progresiva del combo durante la resolucion visual

### Pendientes probables

Estos no necesariamente estan rotos, pero son pasos naturales siguientes:

- pulir el contador de combo hasta que quede exactamente sincronizado con cada combinacion
- agregar efectos visuales y sonido
- conectar dano del combate con un sistema real de enemigos o stats
- ordenar mejor documentacion y estructura de carpetas para seguir el estandar interno
- revisar si `otrojuegosimilar/` debe mantenerse como referencia o archivarse

## Resumen corto del estado del proyecto

El proyecto ya tiene una base funcional solida en dos frentes: gravedad planetaria y combate match-3.  
La parte mas avanzada y en ajuste fino ahora mismo es el sistema de combate visual, especialmente la presentacion de combos, cascadas y feedback del jugador.

## Cierre de sesion (hoy)

- Se probo un ajuste en el controlador de movimiento para habilitar mejor desplazamiento en movil.
- El ajuste no resolvio lo que se buscaba, por eso se revirtio y el codigo quedo tal cual estaba antes.
- Se decide cerrar la jornada sin mas cambios de logica.