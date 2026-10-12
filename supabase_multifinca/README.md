# Guiones del proyecto Supabase multi-finca

Solo para el proyecto NUEVO `ganaderia-comercial` (`oaukzxwcohocqafttfki`).
**Nunca** en el de la finca (`punqawvuwxlrdipapnja`).

| Guion | Estado |
|---|---|
| `001_esquema_multifinca.sql` | Ejecutado 2026-10-12 |
| `prueba_seguridad.sql` | Prueba (se deshace sola). Pasó 23/23 el 2026-10-12 (repetida tras la 002: OK) |
| `002_super_admin.sql` | Ejecutado 2026-10-12 |
| `prueba_super_admin.sql` | Prueba (se deshace sola). Pasó 16/16 el 2026-10-12 |

Súper administrador (vendedor): `yefferson2609@gmail.com`. Se nombra desde el
SQL Editor **después** de que esa cuenta exista y se compruebe que es la suya
(sin confirmación de correo, cualquiera podría registrarse con ese correo):

```sql
select id, email, created_at from auth.users where email = 'yefferson2609@gmail.com';
insert into super_admins (usuario_id, nota)
select id, 'Vendedor' from auth.users where email = 'yefferson2609@gmail.com'
on conflict do nothing;
```

Desde la app, el súper administrador activa fincas en "Panel del vendedor".

Activar una finca (como vendedor), en el SQL Editor:

```sql
select id, nombre, codigo, estado, created_at from fincas order by created_at desc;
update fincas set estado = 'activa' where codigo = 'XXXXXX';
-- o prueba por días:
update fincas set estado = 'prueba', prueba_hasta = current_date + 30 where codigo = 'XXXXXX';
```
