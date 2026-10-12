-- =====================================================================
-- Súper administrador (el vendedor): ve y maneja TODAS las fincas.
-- SOLO para el proyecto NUEVO "ganaderia-comercial" (oaukzxwcohocqafttfki).
-- Requiere 001_esquema_multifinca.sql. Se puede ejecutar varias veces.
-- =====================================================================

do $$
begin
  if to_regclass('public.fincas') is null then
    raise exception 'Falta el esquema multi-finca (001). ¿Es el proyecto correcto?';
  end if;
end $$;

-- Quiénes son súper administradores. La app NO puede leer ni escribir esta
-- tabla (sin políticas): solo se agrega gente desde el SQL Editor.
create table if not exists super_admins (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  nota text,
  created_at timestamptz not null default now()
);
alter table super_admins enable row level security;
revoke all on super_admins from anon, authenticated;

create or replace function es_super_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from super_admins where usuario_id = auth.uid());
$$;

-- El súper administrador puede usar cualquier finca (aunque esté pendiente
-- o suspendida) y administrarla, para dar soporte.
create or replace function puede_usar_finca(f uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select es_super_admin() or exists (
    select 1
    from miembros_finca m
    join fincas x on x.id = m.finca_id
    where m.finca_id = f
      and m.usuario_id = auth.uid()
      and m.estado = 'aprobado'
      and (x.estado = 'activa'
           or (x.estado = 'prueba'
               and (x.prueba_hasta is null or x.prueba_hasta >= current_date)))
  );
$$;

create or replace function es_admin_finca(f uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select es_super_admin() or (puede_usar_finca(f) and exists (
    select 1 from miembros_finca m
    where m.finca_id = f
      and m.usuario_id = auth.uid()
      and m.estado = 'aprobado'
      and m.rol in ('dueno', 'admin')
  ));
$$;

-- Ve todas las fincas.
drop policy if exists fincas_super on fincas;
create policy fincas_super on fincas for select to authenticated
  using (es_super_admin());

-- Resumen de todas las fincas para el panel del vendedor.
create or replace function panel_fincas()
returns table (
  id uuid,
  nombre text,
  codigo text,
  estado text,
  prueba_hasta date,
  notas_vendedor text,
  created_at timestamptz,
  dueno_id uuid,
  dueno_nombre text,
  dueno_correo text,
  miembros bigint,
  pendientes bigint,
  vacas bigint,
  toros bigint,
  terneros bigint,
  caballos bigint,
  ultima_actividad timestamptz
)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not es_super_admin() then
    raise exception 'Solo para el administrador del sistema';
  end if;
  return query
  select
    f.id, f.nombre, f.codigo, f.estado, f.prueba_hasta, f.notas_vendedor,
    f.created_at,
    d.usuario_id, d.nombre, d.correo,
    (select count(*) from miembros_finca m
      where m.finca_id = f.id and m.estado = 'aprobado'),
    (select count(*) from miembros_finca m
      where m.finca_id = f.id and m.estado = 'pendiente'),
    (select count(*) from vacas v where v.finca_id = f.id),
    (select count(*) from toros t where t.finca_id = f.id),
    (select count(*) from terneros t where t.finca_id = f.id),
    (select count(*) from caballos c where c.finca_id = f.id),
    greatest(
      (select max(v.updated_at) from vacas v where v.finca_id = f.id),
      (select max(t.updated_at) from terneros t where t.finca_id = f.id),
      (select max(e.updated_at) from eventos_vaca e where e.finca_id = f.id),
      (select max(p.updated_at) from produccion_leche p where p.finca_id = f.id),
      (select max(a.updated_at) from actividades a where a.finca_id = f.id),
      (select max(s.updated_at) from solicitudes s where s.finca_id = f.id),
      (select max(m.updated_at) from movimientos_financieros m where m.finca_id = f.id)
    )
  from fincas f
  left join lateral (
    select m.usuario_id, m.nombre, m.correo
    from miembros_finca m
    where m.finca_id = f.id and m.rol = 'dueno'
    order by m.created_at
    limit 1
  ) d on true
  order by f.created_at desc;
end;
$$;

-- Activar, dar prueba por días, dejar pendiente o suspender una finca.
create or replace function cambiar_estado_finca(
  p_finca uuid, p_estado text, p_dias_prueba int default null,
  p_nota text default null)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not es_super_admin() then
    raise exception 'Solo para el administrador del sistema';
  end if;
  if p_estado not in ('pendiente', 'prueba', 'activa', 'suspendida') then
    raise exception 'Estado no válido';
  end if;
  update fincas set
    estado = p_estado,
    prueba_hasta = case
      when p_estado = 'prueba' and p_dias_prueba is not null
        then current_date + p_dias_prueba
      when p_estado = 'prueba' then prueba_hasta
      else null end,
    notas_vendedor = coalesce(p_nota, notas_vendedor),
    updated_at = now()
  where id = p_finca;
  if not found then
    raise exception 'Finca no encontrada';
  end if;
end;
$$;

revoke all on function es_super_admin(), panel_fincas(),
  cambiar_estado_finca(uuid, text, int, text) from public, anon;
grant execute on function es_super_admin(), panel_fincas(),
  cambiar_estado_finca(uuid, text, int, text) to authenticated;

notify pgrst, 'reload schema';

-- Para nombrar súper administrador (después de que la cuenta exista y se
-- haya comprobado que es la correcta):
-- insert into super_admins (usuario_id, nota)
-- select id, 'Vendedor' from auth.users where email = 'yefferson2609@gmail.com'
-- on conflict do nothing;
