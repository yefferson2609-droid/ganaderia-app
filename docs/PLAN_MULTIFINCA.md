# Plan: versión comercial multi-finca

Objetivo: **vender la app a otros ganaderos**. Una sola app y una sola base de
datos para muchas fincas, donde cada usuario solo ve las fincas a las que
pertenece.

## Decisiones tomadas (2026-10-04)
- Modelo: **multi-finca en un solo proyecto** (no una copia por finca).
- Se construye en un **proyecto NUEVO de Supabase** (`ganaderia-comercial`),
  para no arriesgar los datos reales de la finca del usuario. Cuando todo esté
  probado se migran sus datos y su finca pasa a ser la primera cliente.
- El usuario crea el proyecto en supabase.com (con su contraseña) y le da a
  Claude solo la URL y la clave anon/public.
- Trabajo en una rama git nueva: `multi-finca` (partiendo de
  `reconstruccion-desde-apk`).
- Moneda: **USD** por ahora.
- Forma de cobro y medio de pago: **sin definir** (no bloquea la Fase 1).
- Nombre comercial: **sin definir** (por ahora "Ganadería").

## Decisiones de la Fase 1 (2026-10-12)
- Alta de finca: el ganadero se registra y crea su finca, pero queda
  **pendiente hasta que el vendedor (el usuario) la active**. Más adelante
  cambiará a prueba gratis automática, así que dejar el estado flexible
  (`pendiente` / `prueba` / `activa` / `suspendida`).
- Trabajadores: entran con el **código de la finca** (6 letras que el dueño
  comparte); quedan pendientes hasta que el dueño o un admin los apruebe.
- Una persona puede pertenecer a **varias fincas**: selector al entrar y en el
  menú; los datos de cada finca no se mezclan.
- Permisos por módulo **igual que hoy, pero por finca** (dueño y admin ven
  todo y marcan qué módulos ve cada trabajador).

## Proyecto Supabase nuevo (creado 2026-10-12)
- Nombre `ganaderia-comercial`, región East US (us-east-1), organización
  "Proyectos" (plan gratis), misma cuenta que el proyecto de la finca.
- URL: `https://oaukzxwcohocqafttfki.supabase.co`
- Clave pública (publishable, "default"):
  `sb_publishable_T5it3WU9nc1f95IXtbCQ9w_3W5aG7HV`
  (supabase_flutter 2.15 la acepta como anonKey). La secreta nunca va al código.
- Esquema ejecutado (2026-10-12): `supabase_multifinca/001_esquema_multifinca.sql`.
  Prueba de seguridad 23/23 OK (`supabase_multifinca/prueba_seguridad.sql`).
  Sin datos todavía.

## Diseño del servidor (hecho)
- `fincas` (codigo único de 6, estado pendiente/prueba/activa/suspendida,
  prueba_hasta), `miembros_finca` (rol dueno/admin/empleado, estado
  pendiente/aprobado/rechazado/inactivo; guarda nombre y correo — reemplaza a
  `perfiles_usuario`, que NO existe en el proyecto nuevo), `permisos_usuario`
  con `finca_id`.
- Las 21 tablas de datos tienen `finca_id`; RLS `puede_usar_finca(finca_id)`
  (miembro aprobado + finca activa o prueba vigente). Sin llaves foráneas
  entre tablas de datos (solo a fincas) para no frenar la sincronización.
- `terneros.capado` es boolean en el servidor (la app debe agregarlo a
  `_columnasBool`).
- Fincas y miembros solo se modifican con funciones: `crear_finca(nombre_finca,
  nombre_usuario)`, `unirse_con_codigo(codigo, nombre)`,
  `gestionar_miembro(miembro_id, estado, rol)`, `cambiar_mi_nombre(finca, nombre)`.
- Fotos: ruta `<finca_id>/<tabla>/<archivo>.jpg` en buckets `animales` y
  `solicitudes`.

## App (paso 2, hecho en código 2026-10-12, sin compilar)
- `main.dart` apunta al proyecto nuevo (publishableKey).
- Base local **un archivo por finca** (`finca_<id>.db`, `LocalDb.abrirFinca`,
  `LocalDb.fincaAbierta`); las tablas locales no llevan `finca_id`: la sync
  lo agrega al subir y filtra por él al bajar. `syncAll` fija finca y base
  al empezar (cambiar de finca a mitad no cruza datos).
- `FincaProvider`: lista de fincas (guardada en el teléfono para entrar sin
  internet), abrir/cambiar, `crear_finca`, `unirse_con_codigo`. Si la finca
  abierta deja de estar disponible, se cierra y el router vuelve a /fincas.
- Pantallas: `/registro` (crear cuenta), `/fincas` (Mis fincas: registrar,
  unirse con código, estados "en revisión"/"esperando aprobación"),
  Usuarios (código para copiar, aprobar como trabajador/admin, rechazar,
  quitar/devolver acceso, cambiar rol). Menú: "Cambiar de finca".
- `perfiles_usuario` local se llena desde `miembros_finca` (no se sube).
- Dos formas de sumar trabajadores (decisión 2026-10-12): código de la finca
  y "Crear usuario" como antes; la función `supabase/functions/crear-usuario`
  ahora recibe `finca_id`, exige `es_admin_finca` y deja al trabajador
  aprobado en esa finca. Se despliega con "Verify JWT" desactivado.
- Supabase nuevo: **confirmación de correo desactivada** (2026-10-12).
- Fotos: `<finca_id>/<tabla>/<archivo>`.
- Pruebas: `test/multifinca_test.dart` (bases separadas por finca, estados).

## Pendiente / ideas
- Los permisos por módulo se aplican en la app, no en el servidor (igual que
  antes): un trabajador recibe por sync los datos de la finca aunque no vea
  el módulo. Evaluar reforzarlo en el servidor más adelante.
- Panel del vendedor para activar fincas (hoy por SQL, ver
  `supabase_multifinca/README.md`).

## Fase 1 — Multi-finca segura (siguiente paso)
1. Tablas `fincas` (nombre, logo, dueño, estado/suscripción) y
   `miembros_finca` (usuario, finca, rol: dueño / admin / empleado).
2. Columna `finca_id` en **todas** las tablas de datos; la app la llena sola.
3. RLS: cada usuario solo lee/escribe filas de fincas donde es miembro.
   Probar con dos usuarios de fincas distintas que no se vean entre sí.
4. Permisos por módulo pasan a ser por usuario **y finca**.
5. App: registro de finca nueva (el que la crea es dueño), selector de finca
   al entrar y en el menú, invitar miembros por correo, base local separada o
   filtrada por finca.
6. Script de migración de los datos de la finca actual al proyecto nuevo.

## Fase 2 — Personalización por finca
- Nombre y logo propios (hoy el hierro AgroYeff está fijo en assets).
- Ajustes por finca guardados en la base: días de vitamina, días de secado,
  moneda, razas.

## Fase 3 — Lista para vender
- Publicación en Google Play. Ojo: con **cuenta personal** Google exige prueba
  cerrada con **12+ testers durante 14 días** antes de publicar; con cuenta de
  empresa no.
- Cobro y periodo de prueba; panel del vendedor para activar/suspender fincas.
- Supabase de pago (~25 USD/mes) para que no se pause y tenga backups.
- Política de privacidad y términos.

## Fase 4 — Pulir
- Reporte de fallos, guía inicial para ganaderos nuevos, ayuda en la app.
