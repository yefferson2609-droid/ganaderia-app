-- =====================================================================
-- Multi-finca: lo que trajeron las versiones 1.0.14–1.0.21 de la app de la
-- finca (009_usuarios_eliminar.sql y 010_nomina.sql), adaptado por finca.
-- SOLO para el proyecto NUEVO "ganaderia-comercial" (oaukzxwcohocqafttfki).
-- Requiere 001 y 002. Se puede ejecutar varias veces.
-- =====================================================================

do $$
begin
  if to_regclass('public.fincas') is null or to_regclass('public.super_admins') is null then
    raise exception 'Faltan los guiones 001/002 multi-finca. ¿Es el proyecto correcto?';
  end if;
end $$;

-- ============ 1) Eliminar usuario DE UNA FINCA ============
-- Nuevo estado de miembro: 'eliminado' (no sale en las listas; su nombre se
-- conserva en el historial). La cuenta NO se bloquea: puede estar en otras
-- fincas.
alter table miembros_finca drop constraint if exists miembros_finca_estado_check;
alter table miembros_finca add constraint miembros_finca_estado_check
  check (estado in ('pendiente', 'aprobado', 'rechazado', 'inactivo', 'eliminado'));

create or replace function eliminar_usuario(p_usuario uuid, p_finca uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  m miembros_finca%rowtype;
begin
  if not es_admin_finca(p_finca) then
    raise exception 'Solo el dueño o un administrador puede eliminar usuarios';
  end if;
  if p_usuario = auth.uid() then
    raise exception 'No puedes eliminar tu propio usuario';
  end if;
  select * into m from miembros_finca
   where finca_id = p_finca and usuario_id = p_usuario;
  if not found then
    raise exception 'Ese usuario no pertenece a esta finca';
  end if;
  if m.rol = 'dueno' then
    raise exception 'Al dueño de la finca no se le puede eliminar';
  end if;
  update miembros_finca set estado = 'eliminado', updated_at = now()
   where id = m.id;
  delete from permisos_usuario
   where finca_id = p_finca and usuario_id = p_usuario;
end;
$$;

-- Quien fue eliminado o rechazado puede volver a pedir entrada con el código.
create or replace function unirse_con_codigo(p_codigo text, p_nombre_usuario text)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  f fincas%rowtype;
begin
  if uid is null then
    raise exception 'Debes iniciar sesión';
  end if;
  select * into f from fincas
   where codigo = upper(replace(trim(coalesce(p_codigo, '')), ' ', ''));
  if not found then
    raise exception 'Código no válido. Revísalo con el dueño de la finca';
  end if;

  insert into miembros_finca (finca_id, usuario_id, nombre, correo, rol, estado)
  values (f.id, uid,
          coalesce(nullif(trim(p_nombre_usuario), ''), 'Trabajador'),
          auth.jwt() ->> 'email', 'empleado', 'pendiente')
  on conflict (finca_id, usuario_id) do update set
    estado = case when miembros_finca.estado in ('rechazado', 'eliminado')
                  then 'pendiente' else miembros_finca.estado end,
    updated_at = now();

  return f.nombre;
end;
$$;

revoke all on function eliminar_usuario(uuid, uuid) from public, anon;
grant execute on function eliminar_usuario(uuid, uuid) to authenticated;

-- ============ 2) Nómina (tablas con finca_id) ============
create table if not exists trabajadores (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  nombre text not null,
  cedula text,
  cargo text,
  telefono text,
  salario_semanal numeric not null default 0 check (salario_semanal >= 0),
  fecha_ingreso date,
  activo boolean not null default true,
  ubicacion_id uuid,
  notas text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists nomina_novedades (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  trabajador_id uuid not null references trabajadores(id) on delete cascade,
  semana_fin date not null,             -- domingo de la semana
  tipo text not null check (tipo in ('bono', 'anticipo')),
  monto numeric not null check (monto > 0),
  descripcion text,
  movimiento_id uuid,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists nomina_novedades_semana_idx on nomina_novedades (finca_id, semana_fin);

create table if not exists prestamos_trabajador (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  trabajador_id uuid not null references trabajadores(id) on delete cascade,
  fecha date not null,
  monto_total numeric not null check (monto_total > 0),
  cuota_semanal numeric not null check (cuota_semanal > 0),
  descripcion text,
  estado text not null default 'activo' check (estado in ('activo', 'pagado')),
  movimiento_id uuid,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists nomina_semanas (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  semana_fin date not null,             -- domingo
  estado text not null default 'pendiente' check (estado in ('pendiente', 'pagada')),
  total numeric not null default 0,
  trabajadores int not null default 0,
  movimiento_id uuid,
  automatica boolean not null default false,
  pagada_por uuid,
  pagada_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (finca_id, semana_fin)
);

create table if not exists nomina_detalle (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  nomina_id uuid not null references nomina_semanas(id) on delete cascade,
  trabajador_id uuid not null,
  trabajador_nombre text not null,
  salario numeric not null default 0,
  bonos numeric not null default 0,
  anticipos numeric not null default 0,
  cuotas numeric not null default 0,
  neto numeric not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists prestamo_cuotas (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  prestamo_id uuid not null references prestamos_trabajador(id) on delete cascade,
  nomina_id uuid not null references nomina_semanas(id) on delete cascade,
  monto numeric not null,
  created_at timestamptz not null default now()
);

-- Seguridad igual que el resto: solo filas de fincas que el usuario puede usar.
do $$
declare t text;
begin
  foreach t in array array['trabajadores','nomina_novedades','prestamos_trabajador',
                           'nomina_semanas','nomina_detalle','prestamo_cuotas']
  loop
    execute format('create index if not exists %I on %I (finca_id)', t || '_finca_idx', t);
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_por_finca', t);
    execute format(
      'create policy %I on %I for all to authenticated '
      'using (puede_usar_finca(finca_id)) '
      'with check (puede_usar_finca(finca_id))',
      t || '_por_finca', t);
    execute format('revoke all on %I from anon', t);
    execute format(
      'grant select, insert, update, delete on %I to authenticated', t);
  end loop;
end $$;

-- ============ 3) Pago de la nómina de UNA finca ============
-- Sueldo + bonos − anticipos − cuotas de préstamos de cada trabajador activo
-- de la finca; guarda el detalle y registra UN gasto en Finanzas de esa
-- finca. Si la semana ya está pagada no hace nada.
drop function if exists pagar_nomina(date, boolean);

create or replace function pagar_nomina(
  p_finca uuid, p_semana date, p_automatica boolean default false)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_nomina uuid;
  v_mov uuid;
  v_concepto uuid;
  v_total numeric := 0;
  v_n int := 0;
  v_bonos numeric;
  v_anticipos numeric;
  v_cuotas numeric;
  v_cuota numeric;
  v_neto numeric;
  r record;
  p record;
begin
  if p_finca is null then
    raise exception 'Falta la finca';
  end if;
  if extract(isodow from p_semana) <> 7 then
    raise exception 'La semana de nómina debe terminar en domingo';
  end if;
  -- Desde la app: dueño/admin de la finca, o quien ve Finanzas en ella.
  if auth.uid() is not null and not (
      es_admin_finca(p_finca) or (puede_usar_finca(p_finca) and exists (
        select 1 from permisos_usuario
         where finca_id = p_finca and usuario_id = auth.uid()
           and modulo in ('finanzas', 'usuarios') and puede_ver))) then
    raise exception 'No tienes permiso para pagar la nómina';
  end if;

  select id into v_nomina from nomina_semanas
   where finca_id = p_finca and semana_fin = p_semana;
  if v_nomina is not null and exists (
      select 1 from nomina_semanas where id = v_nomina and estado = 'pagada') then
    return v_nomina;
  end if;
  if v_nomina is null then
    v_nomina := gen_random_uuid();
    insert into nomina_semanas (id, finca_id, semana_fin)
    values (v_nomina, p_finca, p_semana);
  end if;
  delete from nomina_detalle where nomina_id = v_nomina;
  delete from prestamo_cuotas where nomina_id = v_nomina;

  for r in
    select * from trabajadores
     where finca_id = p_finca and activo
       and (fecha_ingreso is null or fecha_ingreso <= p_semana)
     order by nombre
  loop
    select coalesce(sum(monto), 0) into v_bonos from nomina_novedades
     where trabajador_id = r.id and semana_fin = p_semana and tipo = 'bono';
    select coalesce(sum(monto), 0) into v_anticipos from nomina_novedades
     where trabajador_id = r.id and semana_fin = p_semana and tipo = 'anticipo';

    v_cuotas := 0;
    for p in
      select pr.id, pr.cuota_semanal,
             pr.monto_total - coalesce((select sum(c.monto) from prestamo_cuotas c
                                         where c.prestamo_id = pr.id), 0) as saldo
        from prestamos_trabajador pr
       where pr.trabajador_id = r.id and pr.estado = 'activo' and pr.fecha <= p_semana
    loop
      v_cuota := least(p.cuota_semanal, greatest(p.saldo, 0));
      if v_cuota > 0 then
        insert into prestamo_cuotas (id, finca_id, prestamo_id, nomina_id, monto)
        values (gen_random_uuid(), p_finca, p.id, v_nomina, v_cuota);
        v_cuotas := v_cuotas + v_cuota;
      end if;
      if p.saldo - v_cuota <= 0 then
        update prestamos_trabajador set estado = 'pagado', updated_at = now() where id = p.id;
      end if;
    end loop;

    v_neto := r.salario_semanal + v_bonos - v_anticipos - v_cuotas;
    insert into nomina_detalle (id, finca_id, nomina_id, trabajador_id, trabajador_nombre,
                                salario, bonos, anticipos, cuotas, neto)
    values (gen_random_uuid(), p_finca, v_nomina, r.id, r.nombre,
            r.salario_semanal, v_bonos, v_anticipos, v_cuotas, v_neto);
    v_total := v_total + v_neto;
    v_n := v_n + 1;
  end loop;

  if v_n > 0 and v_total > 0 then
    -- Concepto de gasto "Nómina" de esta finca (se crea si no existe).
    select id into v_concepto from conceptos_financieros
     where finca_id = p_finca and lower(nombre) in ('nómina', 'nomina') and tipo = 'gasto'
     order by created_at limit 1;
    if v_concepto is null then
      v_concepto := gen_random_uuid();
      insert into conceptos_financieros (id, finca_id, nombre, tipo, activo)
      values (v_concepto, p_finca, 'Nómina', 'gasto', true);
    end if;
    v_mov := gen_random_uuid();
    insert into movimientos_financieros
      (id, finca_id, tipo, concepto_id, nota, monto, fecha, created_by, created_at, updated_at)
    values
      (v_mov, p_finca, 'gasto', v_concepto,
       'Pago de nómina semana ' || to_char(p_semana - 6, 'DD/MM') || ' al ' ||
         to_char(p_semana, 'DD/MM/YYYY') || ' · ' || v_n ||
         case when v_n = 1 then ' trabajador' else ' trabajadores' end ||
         case when p_automatica then ' (automático)' else '' end,
       v_total, p_semana, auth.uid(), now(), now());
  end if;

  update nomina_semanas
     set estado = 'pagada', total = v_total, trabajadores = v_n,
         movimiento_id = v_mov, automatica = p_automatica,
         pagada_por = auth.uid(), pagada_at = now(), updated_at = now()
   where id = v_nomina;
  return v_nomina;
end;
$$;

-- Pago automático de TODAS las fincas activas (lo llama el reloj del
-- servidor). No se puede llamar desde la app.
create or replace function pagar_nominas_automaticas(p_semana date)
returns int
language plpgsql security definer
set search_path = public
as $$
declare
  f record;
  n int := 0;
begin
  for f in
    select x.id from fincas x
     where (x.estado = 'activa'
            or (x.estado = 'prueba'
                and (x.prueba_hasta is null or x.prueba_hasta >= current_date)))
       and exists (select 1 from trabajadores t where t.finca_id = x.id and t.activo)
  loop
    begin
      perform pagar_nomina(f.id, p_semana, true);
      n := n + 1;
    exception when others then
      raise warning 'Nómina de la finca % no se pagó: %', f.id, sqlerrm;
    end;
  end loop;
  return n;
end;
$$;

revoke all on function pagar_nomina(uuid, date, boolean) from public, anon;
grant execute on function pagar_nomina(uuid, date, boolean) to authenticated;
revoke all on function pagar_nominas_automaticas(date) from public, anon, authenticated;

-- ============ 4) Pago automático: domingos 11:55 p. m. de Venezuela ============
-- (03:55 UTC del lunes = 23:55 del domingo en Caracas, UTC-4)
create extension if not exists pg_cron;

select cron.unschedule(jobid) from cron.job where jobname = 'nomina-domingo';
select cron.schedule(
  'nomina-domingo',
  '55 3 * * 1',
  $c$select public.pagar_nominas_automaticas((now() at time zone 'America/Caracas')::date)$c$
);

notify pgrst, 'reload schema';
