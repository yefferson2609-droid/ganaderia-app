-- Permisos para los módulos agregados (terneros, salud, actividades,
-- solicitudes, reportes). Se puede ejecutar varias veces sin problema.
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar y Run

alter table permisos_usuario drop constraint if exists permisos_usuario_modulo_check;
alter table permisos_usuario add constraint permisos_usuario_modulo_check
  check (modulo in (
    'vacas','toros','terneros','caballos','lotes','eventos','salud',
    'actividades','solicitudes','ubicaciones','finanzas','reportes','usuarios'
  ));

-- Los administradores (quienes ven 'usuarios') reciben acceso completo
-- a los módulos nuevos.
insert into permisos_usuario (usuario_id, modulo, puede_ver, puede_crear, puede_editar, puede_eliminar)
select p.usuario_id, m.modulo, true, true, true, true
from permisos_usuario p
cross join (values ('terneros'),('salud'),('actividades'),('solicitudes'),('reportes')) as m(modulo)
where p.modulo = 'usuarios' and p.puede_ver = true
on conflict (usuario_id, modulo) do nothing;

-- El resto de usuarios: pueden ver y crear actividades y solicitudes,
-- y ver terneros y salud. Reportes queda cerrado (lo da el admin).
insert into permisos_usuario (usuario_id, modulo, puede_ver, puede_crear, puede_editar, puede_eliminar)
select u.id, m.modulo, m.ver, m.crear, false, false
from perfiles_usuario u
cross join (values
  ('terneros', true, false),
  ('salud', true, false),
  ('actividades', true, true),
  ('solicitudes', true, true),
  ('reportes', false, false)
) as m(modulo, ver, crear)
on conflict (usuario_id, modulo) do nothing;
