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
