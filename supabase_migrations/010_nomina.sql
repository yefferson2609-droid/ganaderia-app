-- Nómina semanal: trabajadores, bonos/anticipos, préstamos en cuotas y pago
-- automático cada domingo a las 11:55 p. m. (hora de Venezuela).
-- Se puede ejecutar varias veces sin problema.

-- ============ Tablas ============
create table if not exists trabajadores (
  id uuid primary key,
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

-- Bonos (se suman el domingo) y anticipos (se descuentan el domingo; el
-- gasto ya se registró el día que se entregaron).
create table if not exists nomina_novedades (
  id uuid primary key,
  trabajador_id uuid not null references trabajadores(id) on delete cascade,
  semana_fin date not null,             -- domingo de la semana
  tipo text not null check (tipo in ('bono', 'anticipo')),
  monto numeric not null check (monto > 0),
  descripcion text,
  movimiento_id uuid,                   -- gasto del anticipo
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists nomina_novedades_semana_idx on nomina_novedades (semana_fin);

create table if not exists prestamos_trabajador (
  id uuid primary key,
  trabajador_id uuid not null references trabajadores(id) on delete cascade,
  fecha date not null,
  monto_total numeric not null check (monto_total > 0),
  cuota_semanal numeric not null check (cuota_semanal > 0),
  descripcion text,
  estado text not null default 'activo' check (estado in ('activo', 'pagado')),
  movimiento_id uuid,                   -- gasto del préstamo
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists nomina_semanas (
  id uuid primary key,
  semana_fin date not null unique,      -- domingo
  estado text not null default 'pendiente' check (estado in ('pendiente', 'pagada')),
  total numeric not null default 0,
  trabajadores int not null default 0,
  movimiento_id uuid,                   -- el gasto en Finanzas
  automatica boolean not null default false,
  pagada_por uuid,
  pagada_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Detalle exacto de cada trabajador en una semana pagada.
create table if not exists nomina_detalle (
  id uuid primary key,
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
  prestamo_id uuid not null references prestamos_trabajador(id) on delete cascade,
  nomina_id uuid not null references nomina_semanas(id) on delete cascade,
  monto numeric not null,
  created_at timestamptz not null default now()
);

-- Acceso: usuarios con sesión iniciada (igual que el resto de la app).
do $$
declare t text;
begin
  foreach t in array array['trabajadores','nomina_novedades','prestamos_trabajador',
                           'nomina_semanas','nomina_detalle','prestamo_cuotas']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_todo', t);
    execute format('create policy %I on %I for all to authenticated using (true) with check (true)',
                   t || '_todo', t);
  end loop;
end $$;

-- Concepto de gasto "Nómina" (lo usan el pago, anticipos y préstamos).
insert into conceptos_financieros (id, nombre, tipo, activo, created_at, updated_at)
select gen_random_uuid(), 'Nómina', 'gasto', true, now(), now()
where not exists (
  select 1 from conceptos_financieros where lower(nombre) = 'nómina' and tipo = 'gasto'
);

-- ============ Pago de la nómina ============
-- Calcula sueldo + bonos − anticipos − cuotas de préstamos de cada
-- trabajador activo, guarda el detalle y registra UN gasto en Finanzas.
-- Si la semana ya está pagada no hace nada.
create or replace function pagar_nomina(p_semana date, p_automatica boolean default false)
returns uuid
language plpgsql
security definer
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
  if extract(isodow from p_semana) <> 7 then
    raise exception 'La semana de nómina debe terminar en domingo';
  end if;
  -- Desde la app: solo quien ve Finanzas o es administrador.
  if auth.uid() is not null and not exists (
      select 1 from permisos_usuario
       where usuario_id = auth.uid() and modulo in ('finanzas', 'usuarios') and puede_ver) then
    raise exception 'No tienes permiso para pagar la nómina';
  end if;

  select id into v_nomina from nomina_semanas where semana_fin = p_semana;
  if v_nomina is not null and
     exists (select 1 from nomina_semanas where id = v_nomina and estado = 'pagada') then
    return v_nomina;
  end if;
  if v_nomina is null then
    v_nomina := gen_random_uuid();
    insert into nomina_semanas (id, semana_fin) values (v_nomina, p_semana);
  end if;
  delete from nomina_detalle where nomina_id = v_nomina;
  delete from prestamo_cuotas where nomina_id = v_nomina;

  for r in
    select * from trabajadores
     where activo and (fecha_ingreso is null or fecha_ingreso <= p_semana)
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
        insert into prestamo_cuotas (id, prestamo_id, nomina_id, monto)
        values (gen_random_uuid(), p.id, v_nomina, v_cuota);
        v_cuotas := v_cuotas + v_cuota;
      end if;
      if p.saldo - v_cuota <= 0 then
        update prestamos_trabajador set estado = 'pagado', updated_at = now() where id = p.id;
      end if;
    end loop;

    v_neto := r.salario_semanal + v_bonos - v_anticipos - v_cuotas;
    insert into nomina_detalle (id, nomina_id, trabajador_id, trabajador_nombre,
                                salario, bonos, anticipos, cuotas, neto)
    values (gen_random_uuid(), v_nomina, r.id, r.nombre,
            r.salario_semanal, v_bonos, v_anticipos, v_cuotas, v_neto);
    v_total := v_total + v_neto;
    v_n := v_n + 1;
  end loop;

  if v_n > 0 and v_total > 0 then
    select id into v_concepto from conceptos_financieros
     where lower(nombre) = 'nómina' and tipo = 'gasto' order by created_at limit 1;
    v_mov := gen_random_uuid();
    insert into movimientos_financieros
      (id, tipo, concepto_id, nota, monto, fecha, created_by, created_at, updated_at)
    values
      (v_mov, 'gasto', v_concepto,
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

-- Supabase da permiso de ejecutar funciones al rol "anon" (sin sesión) por
-- defecto: hay que quitárselo explícitamente.
revoke all on function pagar_nomina(date, boolean) from public, anon;
grant execute on function pagar_nomina(date, boolean) to authenticated;
revoke execute on function eliminar_usuario(uuid) from public, anon;

-- ============ Pago automático: domingos 11:55 p. m. de Venezuela ============
-- (03:55 UTC del lunes = 23:55 del domingo en Caracas, UTC-4)
create extension if not exists pg_cron;

select cron.unschedule(jobid) from cron.job where jobname = 'nomina-domingo';
select cron.schedule(
  'nomina-domingo',
  '55 3 * * 1',
  $c$select public.pagar_nomina((now() at time zone 'America/Caracas')::date, true)$c$
);

notify pgrst, 'reload schema';
