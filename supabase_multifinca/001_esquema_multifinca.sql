-- =====================================================================
-- Ganadería multi-finca — esquema completo
-- SOLO para el proyecto NUEVO "ganaderia-comercial" (oaukzxwcohocqafttfki).
-- NUNCA ejecutar en el proyecto de la finca (punqawvuwxlrdipapnja).
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar todo > Run
-- =====================================================================

-- Seguro: si este proyecto ya tiene datos de la app, no seguir.
do $$
begin
  if to_regclass('public.vacas') is not null then
    raise exception 'Este proyecto ya tiene tablas de la app. ¿Es el proyecto correcto?';
  end if;
end $$;

-- ============ 1) Fincas y miembros ============

create table fincas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(trim(nombre)) > 0),
  -- Código de 6 letras/números que el dueño comparte con sus trabajadores.
  codigo text not null unique,
  -- pendiente: recién creada, espera que el vendedor la active.
  -- prueba: activa por un tiempo (prueba_hasta). activa: pagando.
  -- suspendida: sin acceso.
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'prueba', 'activa', 'suspendida')),
  prueba_hasta date,
  creada_por uuid references auth.users(id),
  notas_vendedor text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table miembros_finca (
  id uuid primary key default gen_random_uuid(),
  finca_id uuid not null references fincas(id) on delete cascade,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  nombre text not null,
  correo text,
  rol text not null default 'empleado'
    check (rol in ('dueno', 'admin', 'empleado')),
  -- pendiente: pidió entrar con el código. aprobado: trabaja en la finca.
  -- rechazado / inactivo: sin acceso.
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'aprobado', 'rechazado', 'inactivo')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (finca_id, usuario_id)
);
create index miembros_finca_usuario_idx on miembros_finca (usuario_id);

create table permisos_usuario (
  id uuid primary key default gen_random_uuid(),
  finca_id uuid not null references fincas(id) on delete cascade,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  modulo text not null check (modulo in (
    'vacas','toros','terneros','caballos','lotes','eventos','salud',
    'actividades','solicitudes','ubicaciones','finanzas','reportes','usuarios'
  )),
  puede_ver boolean not null default false,
  puede_crear boolean not null default false,
  puede_editar boolean not null default false,
  puede_eliminar boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (finca_id, usuario_id, modulo)
);
create index permisos_usuario_finca_idx on permisos_usuario (finca_id);

-- ============ 2) Funciones de acceso (usadas por la seguridad) ============

-- ¿El usuario actual puede usar los datos de la finca f?
-- Miembro aprobado + finca activa o en prueba vigente.
create or replace function puede_usar_finca(f uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
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

-- ¿El usuario actual es dueño o administrador (aprobado) de la finca f?
create or replace function es_admin_finca(f uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select puede_usar_finca(f) and exists (
    select 1 from miembros_finca m
    where m.finca_id = f
      and m.usuario_id = auth.uid()
      and m.estado = 'aprobado'
      and m.rol in ('dueno', 'admin')
  );
$$;

-- Igual que puede_usar_finca pero recibe texto (carpeta de una foto).
create or replace function puede_usar_finca_texto(f text)
returns boolean
language plpgsql stable security definer
set search_path = public
as $$
begin
  return puede_usar_finca(f::uuid);
exception when others then
  return false;
end;
$$;

-- ============ 3) Tablas de datos de la app (todas con finca_id) ============

create table ubicaciones (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  nombre text not null,
  descripcion text,
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table tipos_evento (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  nombre text not null,
  descripcion text,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table toros (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  numero text not null,
  nombre text not null,
  fecha_nacimiento date,
  estado text not null default 'activo',
  padre_id uuid,
  madre_id uuid,
  ubicacion_id uuid,
  color text,
  nota text,
  raza text,
  foto_url text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table vacas (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  numero text not null,
  fecha_nacimiento date,
  estado text not null default 'activa',
  padre_id uuid,
  madre_id uuid,
  estado_reproductivo text not null default 'vacia',
  fecha_monta date,
  toro_id uuid,
  fecha_estimada_parto date,
  ubicacion_id uuid,
  color text,
  nota text,
  raza text,
  foto_url text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table caballos (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  nombre text not null,
  fecha_nacimiento date,
  estado text not null default 'activo',
  ubicacion_id uuid,
  color text,
  nota text,
  raza text,
  foto_url text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table terneros (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  numero text not null,
  sexo text not null,
  fecha_nacimiento date,
  etapa text not null default 'lactancia',
  categoria text,
  fecha_destete date,
  capado boolean not null default false,
  estado text not null default 'activo',
  padre_id uuid,
  madre_id uuid,
  ubicacion_id uuid,
  color text,
  nota text,
  raza text,
  foto_url text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table pesadas_ternero (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  ternero_id uuid not null,
  fecha date not null,
  peso numeric not null,
  notas text,
  created_at timestamptz not null default now()
);

create table traslados_ternero (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  ternero_id uuid not null,
  fecha date not null,
  ubicacion_origen_id uuid,
  ubicacion_destino_id uuid not null,
  notas text,
  created_at timestamptz not null default now()
);

create table lotes (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  tipo text not null,
  nombre text not null,
  hembras integer not null default 0,
  machos integer not null default 0,
  ubicacion_id uuid,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table movimientos_lote (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  lote_id uuid not null,
  tipo_movimiento text not null,
  cantidad integer not null,
  sexo text not null,
  fecha date not null,
  notas text,
  created_at timestamptz not null default now()
);

create table eventos_vaca (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  vaca_id uuid not null,
  tipo_evento_id uuid not null,
  fecha date not null,
  notas text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table eventos_masivos (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  tipo_evento_id uuid not null,
  fecha date not null,
  notas text,
  created_at timestamptz not null default now()
);

create table eventos_masivos_vacas (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  evento_masivo_id uuid not null,
  vaca_id uuid not null,
  created_at timestamptz not null default now()
);

create table registros_salud (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  animal_tipo text not null,
  animal_id uuid not null,
  fecha_inicio date not null,
  diagnostico text not null,
  estado text not null default 'activo',
  fecha_fin date,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table tratamientos_salud (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  registro_salud_id uuid not null,
  fecha date not null,
  medicamento text not null,
  dosis text,
  notas text,
  estado text not null default 'aplicado',
  created_by uuid,
  created_at timestamptz not null default now()
);

create table conceptos_financieros (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  nombre text not null,
  tipo text not null check (tipo in ('ingreso', 'gasto')),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table movimientos_financieros (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  tipo text not null check (tipo in ('ingreso', 'gasto')),
  concepto_id uuid,
  nota text,
  monto numeric(14, 2) not null check (monto > 0),
  fecha date not null,
  ubicacion_id uuid,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table actividades (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  descripcion text not null,
  fecha_limite date,
  ubicacion_id uuid,
  prioridad text not null default 'media',
  estado text not null default 'pendiente',
  asignado_a uuid not null,
  creado_por uuid,
  completado_por uuid,
  fecha_completada timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table solicitudes (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  item text not null,
  cantidad text,
  ubicacion_id uuid,
  estado text not null default 'pendiente',
  nota text,
  costo numeric,
  solicitado_por uuid,
  resuelto_por uuid,
  fecha_resolucion timestamptz,
  foto_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table produccion_leche (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  fecha date not null,
  turno text not null check (turno in ('manana', 'tarde')),
  litros numeric not null check (litros >= 0),
  vaca_id uuid,                -- null = total de la finca
  ubicacion_id uuid,
  notas text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table pesajes_animal (
  id uuid primary key,
  finca_id uuid not null references fincas(id) on delete cascade,
  animal_tipo text not null,
  animal_id uuid not null,
  fecha date not null,
  peso numeric not null check (peso > 0),
  notas text,
  created_by uuid,
  created_at timestamptz not null default now()
);

-- Índice por finca + seguridad: cada usuario solo lee y escribe filas de
-- las fincas donde es miembro aprobado (y la finca está activa/en prueba).
do $$
declare
  t text;
begin
  foreach t in array array[
    'ubicaciones','tipos_evento','toros','vacas','caballos','terneros',
    'pesadas_ternero','traslados_ternero','lotes','movimientos_lote',
    'eventos_vaca','eventos_masivos','eventos_masivos_vacas',
    'registros_salud','tratamientos_salud','conceptos_financieros',
    'movimientos_financieros','actividades','solicitudes',
    'produccion_leche','pesajes_animal'
  ]
  loop
    execute format('create index %I on %I (finca_id)', t || '_finca_idx', t);
    execute format('alter table %I enable row level security', t);
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

-- ============ 4) Seguridad de fincas, miembros y permisos ============

alter table fincas enable row level security;
alter table miembros_finca enable row level security;
alter table permisos_usuario enable row level security;

revoke all on fincas, miembros_finca, permisos_usuario from anon;
-- Fincas y miembros solo se cambian con las funciones de abajo.
revoke all on fincas, miembros_finca from authenticated;
grant select on fincas, miembros_finca to authenticated;
grant select, insert, update, delete on permisos_usuario to authenticated;

-- Cada usuario ve las fincas a las que pertenece (aunque esté pendiente,
-- para mostrarle "tu finca está en revisión").
create policy fincas_mias on fincas for select to authenticated
  using (exists (
    select 1 from miembros_finca m
    where m.finca_id = fincas.id and m.usuario_id = auth.uid()
  ));

-- Ve su propia fila de miembro, y los compañeros de fincas que puede usar.
create policy miembros_ver on miembros_finca for select to authenticated
  using (usuario_id = auth.uid() or puede_usar_finca(finca_id));

-- Permisos: cada quien ve los de su finca; solo dueño/admin los cambian,
-- y nunca los del dueño.
create policy permisos_ver on permisos_usuario for select to authenticated
  using (usuario_id = auth.uid() or puede_usar_finca(finca_id));

create policy permisos_admin on permisos_usuario for all to authenticated
  using (es_admin_finca(finca_id))
  with check (
    es_admin_finca(finca_id)
    and exists (
      select 1 from miembros_finca m
      where m.finca_id = permisos_usuario.finca_id
        and m.usuario_id = permisos_usuario.usuario_id
        and m.rol <> 'dueno'
    )
  );

-- ============ 5) Acciones de la app (funciones) ============

-- Da permisos a un miembro según su rol, sin borrar los que ya tenga.
create or replace function _dar_permisos_rol(f uuid, u uuid, r text)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  m text;
  todo boolean := r in ('dueno', 'admin');
begin
  foreach m in array array[
    'vacas','toros','terneros','caballos','lotes','eventos','salud',
    'actividades','solicitudes','ubicaciones','finanzas','reportes','usuarios'
  ]
  loop
    insert into permisos_usuario
      (finca_id, usuario_id, modulo, puede_ver, puede_crear, puede_editar, puede_eliminar)
    values (
      f, u, m,
      todo or m in ('actividades', 'solicitudes'),
      todo or m in ('actividades', 'solicitudes'),
      todo,
      todo
    )
    on conflict (finca_id, usuario_id, modulo) do update set
      puede_ver = permisos_usuario.puede_ver or excluded.puede_ver,
      puede_crear = permisos_usuario.puede_crear or excluded.puede_crear,
      puede_editar = permisos_usuario.puede_editar or excluded.puede_editar,
      puede_eliminar = permisos_usuario.puede_eliminar or excluded.puede_eliminar,
      updated_at = now();
  end loop;
end;
$$;

-- Código único de 6 caracteres (sin letras que se confunden: O/0, I/1).
create or replace function _nuevo_codigo()
returns text
language plpgsql
set search_path = public
as $$
declare
  letras constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text;
begin
  loop
    c := '';
    for i in 1..6 loop
      c := c || substr(letras, 1 + floor(random() * length(letras))::int, 1);
    end loop;
    exit when not exists (select 1 from fincas where codigo = c);
  end loop;
  return c;
end;
$$;

-- Un ganadero registra su finca. Queda "pendiente" hasta que el vendedor
-- la active. Quien la crea es el dueño, con todos los permisos.
create or replace function crear_finca(p_nombre_finca text, p_nombre_usuario text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  nueva uuid;
begin
  if uid is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if coalesce(trim(p_nombre_finca), '') = '' then
    raise exception 'Escribe el nombre de la finca';
  end if;
  -- Evita que una cuenta cree fincas sin control mientras están en revisión.
  if (select count(*) from fincas
       where creada_por = uid and estado = 'pendiente') >= 3 then
    raise exception 'Ya tienes fincas en revisión; espera a que las activen';
  end if;

  insert into fincas (nombre, codigo, creada_por)
  values (trim(p_nombre_finca), _nuevo_codigo(), uid)
  returning id into nueva;

  insert into miembros_finca (finca_id, usuario_id, nombre, correo, rol, estado)
  values (nueva, uid,
          coalesce(nullif(trim(p_nombre_usuario), ''), 'Dueño'),
          auth.jwt() ->> 'email', 'dueno', 'aprobado');

  perform _dar_permisos_rol(nueva, uid, 'dueno');
  return nueva;
end;
$$;

-- Un trabajador pide entrar con el código que le pasó el dueño.
-- Queda "pendiente" hasta que el dueño o un admin lo apruebe.
-- Devuelve el nombre de la finca.
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
    -- Si lo habían rechazado, vuelve a pedir entrada; si ya está, no cambia.
    estado = case when miembros_finca.estado = 'rechazado'
                  then 'pendiente' else miembros_finca.estado end,
    updated_at = now();

  return f.nombre;
end;
$$;

-- Dueño/admin aprueba, rechaza, desactiva o cambia el rol de un miembro.
-- p_estado: 'aprobado' | 'rechazado' | 'inactivo'. p_rol: 'admin' | 'empleado'.
create or replace function gestionar_miembro(
  p_miembro uuid, p_estado text, p_rol text default null)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  m miembros_finca%rowtype;
  rol_final text;
begin
  select * into m from miembros_finca where id = p_miembro;
  if not found then
    raise exception 'Miembro no encontrado';
  end if;
  if not es_admin_finca(m.finca_id) then
    raise exception 'Solo el dueño o un administrador puede hacer esto';
  end if;
  if m.rol = 'dueno' then
    raise exception 'Al dueño de la finca no se le puede cambiar';
  end if;
  if p_estado not in ('aprobado', 'rechazado', 'inactivo') then
    raise exception 'Estado no válido';
  end if;
  rol_final := coalesce(p_rol, m.rol);
  if rol_final not in ('admin', 'empleado') then
    raise exception 'Rol no válido';
  end if;

  update miembros_finca
     set estado = p_estado, rol = rol_final, updated_at = now()
   where id = p_miembro;

  if p_estado = 'aprobado' then
    perform _dar_permisos_rol(m.finca_id, m.usuario_id, rol_final);
  end if;
end;
$$;

-- Cambiar el nombre propio dentro de una finca.
create or replace function cambiar_mi_nombre(p_finca uuid, p_nombre text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if coalesce(trim(p_nombre), '') = '' then
    raise exception 'Escribe un nombre';
  end if;
  update miembros_finca set nombre = trim(p_nombre), updated_at = now()
   where finca_id = p_finca and usuario_id = auth.uid();
end;
$$;

-- Las funciones solo las usan usuarios con sesión iniciada; las internas
-- (_dar_permisos_rol, _nuevo_codigo) no se pueden llamar desde la app.
revoke all on function puede_usar_finca(uuid), es_admin_finca(uuid),
  puede_usar_finca_texto(text), _dar_permisos_rol(uuid, uuid, text),
  _nuevo_codigo(), crear_finca(text, text), unirse_con_codigo(text, text),
  gestionar_miembro(uuid, text, text), cambiar_mi_nombre(uuid, text)
  from public, anon;
grant execute on function puede_usar_finca(uuid), es_admin_finca(uuid),
  puede_usar_finca_texto(text), crear_finca(text, text),
  unirse_con_codigo(text, text), gestionar_miembro(uuid, text, text),
  cambiar_mi_nombre(uuid, text)
  to authenticated;
revoke all on function _dar_permisos_rol(uuid, uuid, text), _nuevo_codigo()
  from authenticated;

-- ============ 6) Fotos (Storage): cada finca en su carpeta ============
-- Ruta de cada foto: <finca_id>/<tabla>/<archivo>.jpg

insert into storage.buckets (id, name, public)
values ('solicitudes', 'solicitudes', true), ('animales', 'animales', true)
on conflict (id) do update set public = true;

create policy fotos_finca_insert on storage.objects
  for insert to authenticated
  with check (bucket_id in ('solicitudes', 'animales')
              and puede_usar_finca_texto((storage.foldername(name))[1]));

create policy fotos_finca_update on storage.objects
  for update to authenticated
  using (bucket_id in ('solicitudes', 'animales')
         and puede_usar_finca_texto((storage.foldername(name))[1]))
  with check (bucket_id in ('solicitudes', 'animales')
              and puede_usar_finca_texto((storage.foldername(name))[1]));

create policy fotos_finca_select on storage.objects
  for select to authenticated
  using (bucket_id in ('solicitudes', 'animales')
         and puede_usar_finca_texto((storage.foldername(name))[1]));

create policy fotos_finca_delete on storage.objects
  for delete to authenticated
  using (bucket_id in ('solicitudes', 'animales')
         and puede_usar_finca_texto((storage.foldername(name))[1]));

-- ============ 7) Que la API vea los cambios de inmediato ============
notify pgrst, 'reload schema';
