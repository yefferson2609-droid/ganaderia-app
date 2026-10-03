-- Fotos opcionales en las solicitudes de insumos.
-- Se puede ejecutar varias veces sin problema.
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar y Run

-- 1) Columna con el enlace de la foto
alter table solicitudes add column if not exists foto_url text;

-- 2) Carpeta (bucket) pública donde se guardan las fotos
insert into storage.buckets (id, name, public)
values ('solicitudes', 'solicitudes', true)
on conflict (id) do update set public = true;

-- 3) Solo usuarios con sesión iniciada pueden subir o reemplazar fotos
drop policy if exists "solicitudes_fotos_insert" on storage.objects;
create policy "solicitudes_fotos_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'solicitudes');

drop policy if exists "solicitudes_fotos_update" on storage.objects;
create policy "solicitudes_fotos_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'solicitudes')
  with check (bucket_id = 'solicitudes');

drop policy if exists "solicitudes_fotos_select" on storage.objects;
create policy "solicitudes_fotos_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'solicitudes');

-- 4) Que la API reconozca la columna nueva de inmediato
notify pgrst, 'reload schema';
