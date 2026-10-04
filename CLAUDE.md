# Ganadería (AgroYeff) — contexto para Claude

App Flutter de gestión ganadera, offline-first (SQLite local) con sincronización a
Supabase. Dueño: yefferson2609-droid (GitHub). Repo:
`yefferson2609-droid/ganaderia-app`. Trabajo actual en la rama
`reconstruccion-desde-apk` (no tocar `main` sin pedirlo).

## Carpetas (no mezclar)
- `C:\proyecto ganaderoapp` → rama `reconstruccion-desde-apk`: la app de la
  finca del usuario.
- `C:\proyecto ganaderoapp-multifinca` (git worktree) → rama `multi-finca`:
  versión comercial para vender. Cada conversación trabaja solo en su carpeta;
  antes de hacer commit, verificar la rama con `git status -sb`.

## Cómo trabajar con el usuario
- Hablar **en español**, claro y sin tecnicismos; el usuario no es programador.
  Instrucciones paso a paso, de a una cosa.
- **No compilar hasta que diga "compila"**: suele pedir varios cambios juntos.
- **No pedir que conecte el teléfono por USB.** Se le entrega el APK.
- Antes de cambios grandes, hacer las preguntas de negocio necesarias
  (con opciones) y confirmar el plan.
- Al terminar: resumir qué cambió, dónde está el APK y qué debe probar.
  Decir con honestidad qué no se pudo probar (pantallas, cámara, sync real).
- Las contraseñas (Supabase, GitHub) las escribe el usuario; Claude nunca.

## Compilar
PowerShell, desde `C:\proyecto ganaderoapp`:
```
$env:Path = "C:\flutter\bin;$env:Path"
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=C:\gtmp"   # evita "Unable to establish loopback connection"
$env:GANADERIA_PRUEBA = "1"   # versión de prueba instalable junto a la vieja
flutter build apk --release
```
- Ejecutar con `dangerouslyDisableSandbox` (Gradle necesita red/loopback).
- Con `GANADERIA_PRUEBA=1` el paquete es `com.agroyeff.ganaderia.prueba` y el
  nombre "Ganadería (nueva)". Sin la variable: `com.agroyeff.ganaderia`, "ganaderia".
- Subir `version:` en pubspec.yaml en cada entrega (va en 1.0.13+13).
- Copiar el APK a `%USERPROFILE%\Desktop\APK Ganaderia\ganaderia-NUEVA-prueba-vX.Y.Z.apk`.
- Firma fija: `android/key.properties` + `android/app/ganaderia-release.jks`
  (fuera de git; si se pierden no se puede actualizar encima). NDK 28.2.13676358
  instalado a mano en `%LOCALAPPDATA%\Android\sdk\ndk`.
- Antes de compilar: `flutter analyze --no-pub` (sin errores) y `flutter test`
  (test/logica_test.dart usa sqflite_common_ffi; deben pasar todas).
- Git: commits con `-c user.name="yefferson2609-droid" -c user.email="yefferson2609@gmail.com"`
  y `git push` (credenciales ya guardadas en la PC).

## Trampas conocidas
- **No usar funciones "Patch" de PowerShell con arrays de un solo par**:
  `@(@(a,b))` se aplana y reemplaza caracteres sueltos en TODO el archivo
  (ya rompió 4 pantallas una vez). Usar la herramienta Edit.
- En SQL de SQLite usar comillas simples para textos (`estado = 'activa'`),
  nunca dobles.
- Los archivos del repo usan LF; PowerShell lee UTF-8 sin BOM como ANSI al
  mostrar (los acentos "se ven mal" pero están bien).

## Arquitectura
- `lib/core/database/local_db.dart`: SQLite local, versión **10**. Migraciones en
  `_onUpgrade`; `_createV8` agrega raza/foto, produccion_leche, pesajes_animal;
  `_createV9` agrega `categoria` y `fecha_destete` a terneros.
- **"Levante y ceba"** (tabla/ruta `terneros`): categorías en
  `lib/core/models/ternero.dart` (ternera, novilla_levante, novilla_vientre,
  ternero, torete, torete_venta, novillo_ceba). `categoria` null = sin
  clasificar (se usa la sugerida). La columna antigua `etapa` se deriva de la
  categoría. Destete a los 9 meses, novilla de vientre a los 24 (ajustes.dart).
  Novilla preñada (ficha o Palpación) pasa a Vacas con fecha de parto.
- Sincronización automática: revisa cada minuto (envía cambios nuevos), trae
  datos cada 5 min y al volver a la app.
  Cada tabla tiene `synced` (0 = pendiente de subir) y `deleted` (borrado lógico).
- `lib/core/providers/sync_provider.dart`: baja (filtra columnas, no pisa filas
  con synced=0, borra localmente lo eliminado en el servidor) y luego sube.
  Errores por registro, sin detener el resto; columnas que el servidor no tiene
  se omiten y la fila queda pendiente. Sube fotos a Storage (buckets
  `solicitudes` y `animales`). Lista de tablas: `kTablasSync`.
- Partos, secados y palpaciones se guardan como **eventos de la vaca**
  (tipos "Parto", "Secado", "Palpación", creados solos). Vitamina = eventos cuyo
  tipo contiene "vitamin". Lógica en `reproduccion_repository.dart`.
- Ajustes de manejo en `lib/core/config/ajustes.dart` (vitamina 120 días,
  secado 60 días por defecto, aviso de parto 30 días, vacía 90 días).
- Permisos por módulo: `permisos_provider.dart` (admin = quien ve 'usuarios').

## Supabase (proyecto actual, una sola finca)
- URL `https://punqawvuwxlrdipapnja.supabase.co` (clave anon en lib/main.dart).
- Migraciones en `supabase_migrations/`; **todas ejecutadas hasta la 009**
  (la 007 reúne 005 y 006). Ejecutadas por Claude desde el navegador integrado
  con la sesión del usuario (editor SQL vía `monaco.editor.getEditors()[0]`).
- Usuarios: "Eliminar" llama a la función `eliminar_usuario` (solo admin, no a sí mismo): bloquea la cuenta (banned_until), cierra sesiones, borra permisos y marca `eliminado` (no se borra la cuenta porque hay FK created_by → auth.users). Usuario inactivo/eliminado no puede entrar y se le cierra la sesión al sincronizar. La sync, si un upsert es rechazado por RLS (42501), intenta update.
- RLS actual: cualquier usuario autenticado ve todo → **no crear usuarios de
  otras fincas aquí**.

## Estado
- Funciona: vacas, toros, terneros (etapas lactancia / "Levante" (valor
  guardado 'destete') / ceba, pesadas, traslados, promoción), caballos, lotes,
  eventos y evento masivo, salud y dosis, actividades, solicitudes con foto,
  finanzas, usuarios/permisos, reportes PDF, inventario por ubicación,
  producción de leche (mañana/tarde y por vaca), ordeño/secas, sugerencia de
  secado por raza, alertas del hato, palpación, raza/foto/peso por animal.
- El usuario tiene instaladas la app vieja (v1.0.7, firma de otra PC) y
  "Ganadería (nueva)" de prueba (última entregada: 1.0.13).
- Pendiente de que el usuario pruebe la 1.0.13 en el teléfono.
- Hecho en código y sin compilar aún (será la 1.0.14): Levante y ceba por
  categorías + sincronización automática.

## Próximo trabajo: versión comercial multi-finca
Ver `docs/PLAN_MULTIFINCA.md`.
