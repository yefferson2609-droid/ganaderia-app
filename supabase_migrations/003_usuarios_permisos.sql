-- Modulo Usuarios/Permisos: tablas + RLS + funcion helper + bootstrap del admin inicial
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar y Run

create table if not exists perfiles_usuario (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  correo text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists permisos_usuario (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references perfiles_usuario(id) on delete cascade,
  modulo text not null check (modulo in (
    'vacas','toros','caballos','lotes','eventos','ubicaciones','finanzas','usuarios'
  )),
  puede_ver boolean not null default false,
  puede_crear boolean not null default false,
  puede_editar boolean not null default false,
  puede_eliminar boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (usuario_id, modulo)
);

-- Chequea si el usuario actual (auth.uid()) es admin del modulo 'usuarios'.
-- security definer para evitar recursion de RLS al usarla dentro de policies.
create or replace function is_admin_usuarios()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select puede_ver from permisos_usuario
       where usuario_id = auth.uid() and modulo = 'usuarios'),
    false
  );
$$;

alter table perfiles_usuario enable row level security;
alter table permisos_usuario enable row level security;

-- Cualquier autenticado puede leer perfiles/permisos (necesario para armar el menu
-- propio y la lista de usuarios). Solo admins pueden escribir.
create policy "select_perfiles" on perfiles_usuario for select
  using (auth.role() = 'authenticated');

create policy "update_perfiles_admin" on perfiles_usuario for update
  using (is_admin_usuarios())
  with check (is_admin_usuarios());

create policy "select_permisos" on permisos_usuario for select
  using (auth.role() = 'authenticated');

create policy "insert_permisos_admin" on permisos_usuario for insert
  with check (is_admin_usuarios());

create policy "update_permisos_admin" on permisos_usuario for update
  using (is_admin_usuarios())
  with check (is_admin_usuarios());

create policy "delete_permisos_admin" on permisos_usuario for delete
  using (is_admin_usuarios());

-- Bootstrap: da permisos completos en todos los modulos al dueno de la cuenta actual,
-- para que pueda administrar desde ahi a los demas usuarios.
do $$
declare
  owner_id uuid;
  m text;
begin
  select id into owner_id from auth.users where email = 'yeffer_m@hotmail.com' limit 1;
  if owner_id is not null then
    insert into perfiles_usuario (id, nombre, correo, activo)
    values (owner_id, 'Yefferson', 'yeffer_m@hotmail.com', true)
    on conflict (id) do update set correo = excluded.correo;

    foreach m in array array['vacas','toros','caballos','lotes','eventos','ubicaciones','finanzas','usuarios']
    loop
      insert into permisos_usuario (usuario_id, modulo, puede_ver, puede_crear, puede_editar, puede_eliminar)
      values (owner_id, m, true, true, true, true)
      on conflict (usuario_id, modulo) do update set
        puede_ver = true, puede_crear = true, puede_editar = true, puede_eliminar = true;
    end loop;
  end if;
end $$;
