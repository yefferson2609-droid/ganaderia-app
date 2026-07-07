# Spec: Módulo Finanzas + Módulo Usuarios/Permisos

Decisiones confirmadas con el usuario:
- Moneda: **USD** ($1,234.56 — coma de miles, 2 decimales).
- Conceptos de ingreso/gasto: **catálogo configurable** (mismo patrón que "Tipos de evento") **+ nota de texto libre opcional** por transacción.
- Permisos: **granulares por usuario** (no roles fijos) — cada usuario tiene su propia matriz de permisos por módulo.
- Alta de usuarios: **desde dentro de la app**, vía una Supabase Edge Function que usa la `service_role key` (nunca expuesta en el cliente).

---

## Módulo 1 — Finanzas

### Objetivo
Registrar entradas (ingresos) y salidas (gastos) de dinero de la finca, con concepto categorizado, y ver la utilidad (ingresos − gastos) del período.

### Modelo de datos

**`conceptos_financieros`** (catálogo, mismo patrón que `tipos_evento`)
| campo | tipo | notas |
|---|---|---|
| id | TEXT PK | uuid |
| nombre | TEXT | ej. "Venta de leche", "Compra de alimento" |
| tipo | TEXT | `ingreso` \| `gasto` |
| activo | INTEGER | soft toggle |
| created_at / updated_at | TEXT | |
| synced / deleted | INTEGER | patrón offline estándar |

**`movimientos_financieros`**
| campo | tipo | notas |
|---|---|---|
| id | TEXT PK | uuid |
| tipo | TEXT | `ingreso` \| `gasto` (denormalizado para filtrar rápido) |
| concepto_id | TEXT FK nullable | referencia a `conceptos_financieros` |
| nota | TEXT nullable | texto libre opcional |
| monto | REAL | en USD |
| fecha | TEXT | fecha del movimiento |
| ubicacion_id | TEXT FK nullable | vínculo opcional a una ubicación de la finca |
| created_by | TEXT nullable | id del usuario que lo registró (auditoría, ligado a módulo 2) |
| created_at / updated_at | TEXT | |
| synced / deleted | INTEGER | patrón offline estándar |

### Pantallas
- **`FinanzasScreen`**: lista de movimientos (tabs o filtro Ingresos/Gastos), filtro por rango de fechas y por concepto. Cabecera con 3 totales del período filtrado: **Total ingresos**, **Total gastos**, **Utilidad neta**.
- **`MovimientoFormScreen`**: alta/edición — tipo, concepto (catálogo filtrado según tipo elegido), monto, fecha, nota opcional, ubicación opcional.
- **`ConceptosFinancierosScreen`** + **`ConceptoFinancieroFormScreen`**: gestión del catálogo (idéntico patrón a `TiposEventoScreen`).
- Entrada nueva en el Dashboard: card "Finanzas" con la utilidad del mes actual.

### Sync / offline
Mismo patrón que el resto de la app: tablas locales SQLite con `synced`/`deleted`, pull+push en `SyncProvider`, tablas espejo en Supabase con RLS.

### Fuera de alcance (MVP) — proponer como fase futura si se necesita
- Gráficas de tendencia (requeriría agregar `fl_chart` u otra librería).
- Exportar a CSV/Excel.

---

## Módulo 2 — Usuarios y Permisos

### Objetivo
Un administrador puede crear usuarios nuevos y asignarles, módulo por módulo, qué pueden **ver / crear / editar / eliminar** dentro de la app.

### Módulos a controlar (lista fija)
`vacas`, `toros`, `caballos`, `lotes`, `eventos`, `ubicaciones`, `finanzas`, `usuarios`

### Modelo de datos

**`perfiles_usuario`** (una fila por usuario de Supabase Auth)
| campo | tipo | notas |
|---|---|---|
| id | TEXT PK | = `auth.users.id` |
| nombre | TEXT | |
| correo | TEXT | denormalizado, solo lectura |
| activo | INTEGER | si es false, la app le niega acceso aunque su sesión exista |
| created_at / updated_at | TEXT | |

**`permisos_usuario`** (una fila por usuario × módulo)
| campo | tipo | notas |
|---|---|---|
| id | TEXT PK | uuid |
| usuario_id | TEXT FK | → `perfiles_usuario.id` |
| modulo | TEXT | uno de la lista fija de arriba |
| puede_ver / puede_crear / puede_editar / puede_eliminar | INTEGER | booleanos |
| created_at / updated_at | TEXT | |

### Flujo: crear usuario nuevo
1. Admin abre `UsuariosScreen` → "Nuevo usuario" → ingresa correo, contraseña temporal, nombre.
2. La app llama a la **Edge Function `crear-usuario`** (Supabase, Deno/TypeScript).
3. La función:
   - Verifica que quien llama esté autenticado y tenga `puede_crear=true` en el módulo `usuarios` (chequeo server-side, no confiar en el cliente).
   - Usa el cliente admin de Supabase (con `SERVICE_ROLE_KEY`, guardada como **secret** de la función, nunca en la app) para crear el usuario vía `auth.admin.createUser()`.
   - Inserta su fila en `perfiles_usuario` y filas en `permisos_usuario` para los 8 módulos, todas en `false` por defecto.
4. El admin entra a `UsuarioPermisosScreen` de ese usuario y activa los permisos que corresponda.

### Pantallas
- **`UsuariosScreen`**: lista de usuarios + botón "Nuevo usuario".
- **`UsuarioFormScreen`**: formulario de alta (llama la Edge Function).
- **`UsuarioPermisosScreen`**: grid 8 módulos × 4 acciones (checkboxes) para un usuario.

### Enforcement (dos capas, ambas necesarias)
1. **Cliente (UX)**: nuevo `PermisosProvider` carga los permisos del usuario actual al iniciar sesión (y los sincroniza offline). El router y cada pantalla ocultan menús/botones según `puede_ver`/`puede_crear`/`puede_editar`/`puede_eliminar`.
2. **Servidor (seguridad real)**: políticas **RLS** en Supabase para cada tabla existente (`vacas`, `toros`, `lotes`, etc.) y las nuevas, que verifiquen `permisos_usuario` antes de permitir `select`/`insert`/`update`/`delete`. **Sin esto, ocultar botones en la app no evita que alguien llame la API de Supabase directamente** — es un trabajo de backend que toca las 10 tablas existentes, no solo las 2 nuevas.

### Usuario inicial (bootstrap)
Como no existe un admin todavía, la primera vez se debe correr una migración SQL única que le dé permisos completos (los 4 booleanos en `true`, en los 8 módulos) al usuario dueño de la cuenta actual (`yefferson2609@gmail.com`), para que pueda administrar desde ahí a los demás.

---

## Plan de implementación sugerido (fases)

1. **Finanzas** (independiente, sin dependencias del módulo 2) — modelos, repos, tablas locales+Supabase, 4 pantallas, entrada en dashboard.
2. **Usuarios/Permisos — base**: tablas, Edge Function `crear-usuario`, `PermisosProvider`, pantallas de usuarios/permisos, bootstrap del admin inicial.
3. **Retrofit de permisos en módulos existentes**: agregar los chequeos de `PermisosProvider` en las 8 pantallas ya existentes (ocultar botones de crear/editar/eliminar, ocultar del menú si no hay `puede_ver`) + políticas RLS en las tablas existentes. Esta fase toca prácticamente todas las pantallas actuales, es la más grande de las tres.

---

## Preguntas menores para ir resolviendo sobre la marcha (no bloqueantes, defaults propuestos)
- ¿El vínculo a `ubicacion_id` en movimientos financieros es útil o prefieres omitirlo en el MVP? (default: incluido pero opcional)
- ¿"Desactivar" un usuario (campo `activo`) debe además revocar su sesión en Supabase (requiere llamada admin adicional) o basta con que la app le niegue acceso? (default: solo a nivel app en el MVP)
