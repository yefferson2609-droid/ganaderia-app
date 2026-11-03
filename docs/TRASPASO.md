# Traspaso del proyecto Ganadería (AgroYeff)

Documento para que **otra IA o un programador** continúe el trabajo sin
empezar de cero. Escrito el 2026-11-03. Léase junto con `CLAUDE.md` (en la
raíz del proyecto), que tiene los detalles técnicos de compilación.

---

## 1. Qué es

App Android (Flutter) para manejar la finca ganadera del dueño
(GitHub `yefferson2609-droid`): vacas, toros, levante y ceba, caballos,
cerdos/ovejos (lotes), leche, partos, palpaciones, salud, ventas, finanzas,
nómina semanal, solicitudes de empleados, usuarios con permisos y reportes PDF.

- Funciona **sin internet** (base SQLite en el teléfono) y se **sincroniza**
  con **Supabase** cuando hay señal (cada minuto envía, cada 5 min trae).
- Varios empleados usan la app con su propio usuario y permisos.
- El dueño **no es programador**: hay que hablarle en español, sencillo, paso
  a paso.

## 2. Dónde está todo

| Qué | Dónde |
|---|---|
| Código | GitHub `yefferson2609-droid/ganaderia-app` |
| App de la finca (la que se usa a diario) | rama **`reconstruccion-desde-apk`** · carpeta `C:\proyecto ganaderoapp` |
| Versión comercial para vender a otros ganaderos | rama **`multi-finca`** · carpeta `C:\proyecto ganaderoapp-multifinca` · plan en `docs/PLAN_MULTIFINCA.md` |
| Base de datos de la finca (datos reales) | Supabase proyecto **`punqawvuwxlrdipapnja`** (cuenta del dueño) |
| Base de datos de la versión comercial | Supabase proyecto **`oaukzxwcohocqafttfki`** (`ganaderia-comercial`) |
| Cambios hechos a la base de la finca | `supabase_migrations/` 001 a 011, **todas ejecutadas** |
| Instrucciones técnicas y trampas conocidas | `CLAUDE.md` |
| APKs entregados | `Escritorio\APK Ganaderia\ganaderia-NUEVA-prueba-vX.Y.Z.apk` |

**Versión actual entregada: 1.0.25** (base local SQLite versión 12).

## 3. Lo que NO está en GitHub (guardarlo aparte)

1. **Llave de firma de la app**: `android/app/ganaderia-release.jks` y
   `android/key.properties`. **Sin estos dos archivos no se puede actualizar
   la app instalada en los teléfonos** (habría que desinstalar y perder los
   datos no sincronizados). Copiarlos a un pendrive y a la nube del dueño.
2. Contraseñas de Supabase y GitHub: las tiene el dueño. **Nunca** las escribe
   la IA; si hace falta entrar, el dueño inicia sesión.

## 4. Cómo trabajar con el dueño (reglas acordadas)

- **Siempre preguntar antes de hacer** cualquier pedido: hacer preguntas con
  opciones para entender bien qué quiere, y confirmar el plan en pocas líneas.
- **No compilar** hasta que diga **"compila"** (suele juntar varios cambios).
- **No pedir que conecte el teléfono por USB**: se le entrega el APK en el
  Escritorio.
- Cada entrega: subir la versión en `pubspec.yaml`, `flutter analyze` sin
  errores, `flutter test` (todas pasan), compilar, copiar el APK y hacer
  commit + push.
- Al terminar: explicar qué cambió, dónde está el APK y qué debe probar, y
  decir con honestidad lo que no se pudo probar (pantalla, cámara, sync real).
- **Base de datos de la finca = MUY delicada.** Antes de cualquier cambio:
  1. solo leer y buscar cada animal por su número (ojo: "22" vs "022", y
     nombres dentro del número, p. ej. "7201 pan de leche");
  2. no adivinar: si hay dudas o coincidencias dobles, preguntar;
  3. mostrar una tabla "cómo está → cómo queda";
  4. ejecutar **solo después de un "sí"**, en una sola transacción, por id
     exacto, con verificación de cuántas filas cambia (si no coincide, se
     cancela todo);
  5. volver a leer y confirmar el resultado;
  6. pedir que sincronice el teléfono antes.
- Verificar siempre que se está en el proyecto Supabase correcto (URL) y en la
  rama correcta (`git status -sb`).
- La versión multi-finca debe ser **igual** a la de la finca más solo lo
  necesario para varias fincas; en ella **no se toca** la base de la finca.
- El APK se deja como está (~65 MB, sirve en cualquier teléfono).

## 5. Cómo ejecutar SQL en Supabase (sin contraseñas)

El dueño inicia sesión en supabase.com en un navegador. Luego se abre
`https://supabase.com/dashboard/project/punqawvuwxlrdipapnja/sql/new`, se
escribe el guion en el editor y se ejecuta con "Run" (si borra filas, Supabase
pide confirmar). Para leer resultados largos conviene devolver todo en un solo
`json_build_object(...)::text`. Columnas con el mismo nombre en dos tablas
(p. ej. `madre_id`) confunden las subconsultas: usar alias.

## 6. Reglas de negocio que ya se acordaron (no cambiarlas sin preguntar)

**Un solo camino para cada proceso** (se corrigió porque había varios y
dejaban datos distintos):

| Proceso | Cómo se registra | Detalle |
|---|---|---|
| Parto | Ficha de la vaca → **Registrar parto** (o **Agregar cría** si la cría ya existe) | No se repite un parto a menos de 30 días (gemelos = un parto). Deja la vaca vacía, salvo que el parto sea anterior a su monta actual. Poner la madre a una cría también anota el parto si falta. En Vacas hay un aviso de "crías sin parto" para revisar antes de registrar. |
| Palpación | Pantalla **Palpación**, o editar la vaca | Cambiar la preñez editando la vaca deja una "Palpación" en el historial. |
| Secado | Botón **Secar vaca** | — |
| Venta | Botón **Vender** en la ficha (o seleccionar varios manteniendo presionado en Vacas/Levante) | Una ventana: precio, fecha, comprador, nota. Marca vendido y anota UN ingreso con concepto **"Venta de animal"**; avisa si ya hay un ingreso igual. En lotes, la baja por venta pide precio. "Vendida" ya no está en el lápiz. Volver a activo ofrece borrar el ingreso. |
| Vitamina | Evento cuyo tipo dice "vitamina" o tratamiento en **Salud** cuyo medicamento lo dice | Cuenta para la alerta de vitamina vencida (120 días). |

Partos, secados y palpaciones **no** aparecen en el botón "Evento" ni en
"Evento masivo" (tienen su botón propio).

**Finanzas**
- Conceptos: tocar uno lo abre para editar. **Finalizar (archivar)** para
  labores terminadas (p. ej. Cochinera, Linderos pajón): no salen al
  registrar, se conservan sus movimientos; ocultos con botón "Archivados".
- Un concepto con movimientos **no se borra**: se archiva (la sync también lo
  hace sola si el servidor rechaza el borrado).
- "Otro (gasto especial)": sin concepto, con descripción obligatoria; sale
  como "Otros" con la descripción de título.
- Conceptos actuales: Compra de insumos, Nómina, quesos, Venta de animal
  (activos); Cochinera y Linderos pajón (archivados).
- **Nómina**: la paga el servidor los domingos a las 23:55 (Caracas) con la
  función `pagar_nomina`; no anotar la nómina a mano.

**Animales**
- El nombre se escribe junto al número ("60 hija de portillo").
- Descendencia: madre, padre y lista de crías en la ficha de vacas y toros.
- Procedencia: nacido en la finca / comprado / importado, registro y
  padre/madre de fuera.
- Levante y ceba: categorías por edad y sexo; destete a los 9 meses; novilla
  de vientre a los 24; novilla preñada pasa a Vacas.

## 7. Arquitectura en pocas palabras

- `lib/core/database/local_db.dart`: SQLite local (versión 12), migraciones.
- `lib/core/providers/sync_provider.dart`: sincronización con Supabase
  (`kTablasSync`), errores por registro, fotos a Storage.
- `lib/core/repositories/`: una clase por tabla. Lógica de partos, secado,
  palpación y vitamina en `reproduccion_repository.dart`.
- `lib/core/widgets/venta_dialog.dart`: venta única de animales.
- `lib/features/<módulo>/`: pantallas.
- `test/logica_test.dart`: 29 pruebas de la lógica (usa sqflite_common_ffi).
- Cada tabla local tiene `synced` (0 = pendiente) y `deleted` (borrado lógico).

## 8. Pendiente al momento del traspaso

1. **5 vacas con el parto de su cría sin registrar**: 012coquito (cría coqui,
   27/03/2026), 09 cachito (cacho, 24/04/2026), 5969 Lucero (pinto,
   07/05/2026), 5224 Pajarón (chamo loco, 24/10/2025) y 1601 linda dama
   (capito, 04/12/2025; está preñada). Falta preguntar al dueño cuáles están
   hoy en ordeño y cuáles secas antes de registrar (si no, todas quedarían
   "En ordeño"). Se puede hacer desde el aviso de Vacas en la app.
2. **7 crías sin fecha de nacimiento** (no se puede calcular su parto):
   029luna clara, 25juaquina, 26daniela, 026catalina, 023pajarita,
   042coral, 046mis amores.
3. Versión comercial multi-finca: ver `docs/PLAN_MULTIFINCA.md` y la rama
   `multi-finca`.

## 9. Cómo arrancar con una IA nueva

Decirle: *"Lee `CLAUDE.md` y `docs/TRASPASO.md` del repositorio
`yefferson2609-droid/ganaderia-app`, rama `reconstruccion-desde-apk`, y
sigue esas reglas."* Si la IA no puede abrir GitHub, descargar el proyecto
como ZIP desde GitHub y darle estos dos archivos.
