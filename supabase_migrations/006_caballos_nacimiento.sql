-- Fecha de nacimiento de los caballos (para mostrar su edad).
-- Se puede ejecutar varias veces sin problema.
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query > pegar y Run

alter table caballos add column if not exists fecha_nacimiento date;

-- Que la API reconozca la columna nueva de inmediato
notify pgrst, 'reload schema';
