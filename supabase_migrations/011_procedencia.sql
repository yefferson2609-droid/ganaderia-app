-- Procedencia de vacas, toros y levante: origen (nacida en la finca /
-- comprada / importada), número de registro y padre/madre de fuera de la
-- finca (nombre, registro y raza). Viene de la rama multi-finca.
-- Proyecto de la FINCA (punqawvuwxlrdipapnja). Ejecutar solo con permiso
-- del usuario, después de traer el cambio de la app.
-- Se puede ejecutar varias veces sin problema.

do $$
declare
  t text;
  c text;
begin
  foreach t in array array['vacas', 'toros', 'terneros'] loop
    foreach c in array array['origen', 'registro',
        'padre_ext_nombre', 'padre_ext_registro', 'padre_ext_raza',
        'madre_ext_nombre', 'madre_ext_registro', 'madre_ext_raza'] loop
      execute format('alter table %I add column if not exists %I text', t, c);
    end loop;
    execute format('alter table %I drop constraint if exists %I', t, t || '_origen_check');
    execute format(
      'alter table %I add constraint %I check (origen is null or origen in (''finca'', ''comprada'', ''importada''))',
      t, t || '_origen_check');
  end loop;
end $$;

notify pgrst, 'reload schema';
