-- Agrega a "toros" los mismos campos que ya tiene "vacas" (excepto estado
-- reproductivo): fecha de nacimiento, padre (otro toro) y madre (una vaca).
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar y Run

alter table toros add column if not exists fecha_nacimiento date;
alter table toros add column if not exists padre_id uuid references toros(id);
alter table toros add column if not exists madre_id uuid references vacas(id);
