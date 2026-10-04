-- TODO lo pendiente en un solo script (incluye 005 y 006).
-- Se puede ejecutar varias veces sin problema.
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar todo > Run

-- ============ 1) Columnas nuevas en tablas existentes ============
alter table solicitudes add column if not exists foto_url text;
alter table caballos    add column if not exists fecha_nacimiento date;

alter table vacas    add column if not exists raza text;
alter table toros    add column if not exists raza text;
alter table terneros add column if not exists raza text;
alter table caballos add column if not exists raza text;

alter table vacas    add column if not exists foto_url text;
alter table toros    add column if not exists foto_url text;
alter table terneros add column if not exists foto_url text;
alter table caballos add column if not exists foto_url text;

-- ============ 2) Producción de leche ============
create table if not exists produccion_leche (
  id uuid primary key,
  fecha date not null,
  turno text not null check (turno in ('manana', 'tarde')),
  litros numeric not null check (litros >= 0),
  vaca_id uuid references vacas(id) on delete cascade,  -- null = total de la finca
  ubicacion_id uuid,
  notas text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists produccion_leche_fecha_idx on produccion_leche (fecha);

-- ============ 3) Pesajes de animales adultos ============
create table if not exists pesajes_animal (
  id uuid primary key,
  animal_tipo text not null,
  animal_id uuid not null,
  fecha date not null,
  peso numeric not null check (peso > 0),
  notas text,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists pesajes_animal_animal_idx on pesajes_animal (animal_tipo, animal_id);

-- Acceso: cualquier usuario con sesión iniciada (igual que el resto de la app)
alter table produccion_leche enable row level security;
alter table pesajes_animal   enable row level security;

drop policy if exists "produccion_leche_todo" on produccion_leche;
create policy "produccion_leche_todo" on produccion_leche
  for all to authenticated using (true) with check (true);

drop policy if exists "pesajes_animal_todo" on pesajes_animal;
create policy "pesajes_animal_todo" on pesajes_animal
  for all to authenticated using (true) with check (true);

-- ============ 4) Carpetas de fotos (Storage) ============
insert into storage.buckets (id, name, public)
values ('solicitudes', 'solicitudes', true), ('animales', 'animales', true)
on conflict (id) do update set public = true;

drop policy if exists "solicitudes_fotos_insert" on storage.objects;
drop policy if exists "solicitudes_fotos_update" on storage.objects;
drop policy if exists "solicitudes_fotos_select" on storage.objects;
drop policy if exists "fotos_app_insert" on storage.objects;
drop policy if exists "fotos_app_update" on storage.objects;
drop policy if exists "fotos_app_select" on storage.objects;

create policy "fotos_app_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('solicitudes', 'animales'));

create policy "fotos_app_update" on storage.objects
  for update to authenticated
  using (bucket_id in ('solicitudes', 'animales'))
  with check (bucket_id in ('solicitudes', 'animales'));

create policy "fotos_app_select" on storage.objects
  for select to authenticated
  using (bucket_id in ('solicitudes', 'animales'));

-- ============ 5) Que la API vea los cambios de inmediato ============
notify pgrst, 'reload schema';
