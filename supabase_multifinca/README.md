# Guiones del proyecto Supabase multi-finca

Solo para el proyecto NUEVO `ganaderia-comercial` (`oaukzxwcohocqafttfki`).
**Nunca** en el de la finca (`punqawvuwxlrdipapnja`).

| Guion | Estado |
|---|---|
| `001_esquema_multifinca.sql` | Ejecutado 2026-10-12 |
| `prueba_seguridad.sql` | Prueba (se deshace sola). Pasó 23/23 el 2026-10-12 |

Activar una finca (como vendedor), en el SQL Editor:

```sql
select id, nombre, codigo, estado, created_at from fincas order by created_at desc;
update fincas set estado = 'activa' where codigo = 'XXXXXX';
-- o prueba por días:
update fincas set estado = 'prueba', prueba_hasta = current_date + 30 where codigo = 'XXXXXX';
```
