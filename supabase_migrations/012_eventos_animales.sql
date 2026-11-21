-- Historial de eventos (vacunas, desparasitación, baños…) para toros,
-- levante y ceba y caballos. Las vacas siguen usando eventos_vaca.
-- Proyecto de la FINCA (punqawvuwxlrdipapnja). Ejecutar solo con permiso
-- del usuario. Solo crea una tabla nueva; no cambia datos existentes.
-- Se puede ejecutar varias veces sin problema.

create table if not exists eventos_animal (
  id uuid primary key,
  animal_tipo text not null check (animal_tipo in ('toro', 'ternero', 'caballo')),
  animal_id uuid not null,
  tipo_evento_id uuid not null references tipos_evento(id),
  fecha date not null,
  notas text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists eventos_animal_animal_idx
  on eventos_animal (animal_tipo, animal_id);

-- Acceso: cualquier usuario con sesión iniciada (igual que el resto de la app)
alter table eventos_animal enable row level security;
drop policy if exists "eventos_animal_todo" on eventos_animal;
create policy "eventos_animal_todo" on eventos_animal
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
