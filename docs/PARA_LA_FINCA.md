# Llevar a la app de la finca lo nuevo de multi-finca

Preparado el 2026-10-18 desde la conversación de multi-finca. Es para la
conversación de `C:\proyecto ganaderoapp` (rama `reconstruccion-desde-apk`,
app de la finca en la 1.0.21, Supabase `punqawvuwxlrdipapnja`).

La finca no tiene nada que falte en multi-finca. Al revés faltan 4 cosas.
Todos los commits están en `origin/multi-finca`; se traen con
`git fetch origin` y `git cherry-pick <commit>`, **en este orden** (cada
uno se apoya en el anterior):

| # | Commit | Qué trae | Cuidado en la finca |
|---|--------|----------|---------------------|
| 1 | `5875aa4` | Apariencia "Campo moderno" etapa 1: tema verde/crema (`app_theme.dart`), `MarcaLogo`, vista previa | Es la **marca neutra**: el PDF queda sin el hierro AgroYeff. En la finca, conservar el hierro (preguntar al usuario). Ignorar los cambios a `docs/PLAN_MULTIFINCA.md`. |
| 2 | `9b0ecd9` | Etapa 2: panel con encabezado verde, entrada nueva, ícono del teléfono | Toca `fincas_screen.dart` (Mis fincas), que **no existe** en la finca: descartar esa parte. El ícono es una hoja neutra: preguntar si se cambia el de la finca. |
| 3 | `d4bd0eb` | Etapa 3: `ficha_animal.dart` (`Etiqueta`, `AnimalTile`, `PortadaAnimal`); listas y fichas de vacas, toros, levante y caballos | Choques probables en esas pantallas: conservar el diseño nuevo sin perder lo de la finca. |
| 4 | `430cb06` | Procedencia: foto al registrar, fecha de nacimiento borrable, origen (nacido aquí/comprado/importado), registro propio, padre/madre de fuera. Base local v12 | Además, ejecutar en el Supabase de la finca `supabase_migrations/011_procedencia.sql` (viene en el commit), **con permiso del usuario**. Descartar `supabase_multifinca/004_procedencia.sql`. |
| 5 | `549bb0f` | Colores con más contraste para leer al sol (medidos: 7:1 o más en letra y verde) | Toca `fincas_screen.dart` y `panel_vendedor_screen.dart`, que no existen en la finca: descartar esa parte. |

Los commits solo de multi-finca (registro de fincas, código, Mis fincas,
panel del vendedor, Supabase nuevo) **no** se traen.

## Al terminar
- `flutter analyze --no-pub` sin errores y `flutter test` (deben pasar todas;
  incluye `test/procedencia_test.dart` y `test/vista_previa_test.dart`).
- Compilar solo cuando el usuario diga "compila", sin `GANADERIA_PRUEBA`
  de multi-finca (paquete de la finca). En multi-finca se compila solo para
  64 bits (`--target-platform android-arm64`, APK ~21 MB); preguntar si la
  finca también.
- Comparación de colores en Design:
  https://claude.ai/artifact/NbKufCVfM9gZCzLFRn7hTv
