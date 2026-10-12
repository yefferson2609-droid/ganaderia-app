-- PRUEBA del súper administrador. Todo se deshace al final (no deja datos).
-- Solo en el proyecto ganaderia-comercial (oaukzxwcohocqafttfki).
do $$
declare
  ua uuid := gen_random_uuid();  -- dueño A
  us uuid := gen_random_uuid();  -- súper administrador
  ux uuid := gen_random_uuid();  -- usuario cualquiera
  fa uuid; n int; r text := ''; hasta date;
begin
  insert into auth.users (id, email, aud, role) values
    (ua, 'a@prueba.test', 'authenticated', 'authenticated'),
    (us, 's@prueba.test', 'authenticated', 'authenticated'),
    (ux, 'x@prueba.test', 'authenticated', 'authenticated');
  insert into super_admins (usuario_id, nota) values (us, 'prueba');

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'email', 'a@prueba.test', 'role','authenticated')::text, true);
  fa := crear_finca('Finca A', 'Ana');

  -- Súper administrador
  perform set_config('request.jwt.claims', json_build_object('sub', us, 'role','authenticated')::text, true);
  r := r || '1 S es súper: ' || es_super_admin() || ' (true)' || E'\n';
  select count(*) into n from panel_fincas();
  r := r || '2 S panel: ' || n || ' finca(s), dueño ' || (select dueno_nombre || ' ' || dueno_correo from panel_fincas() limit 1) || E'\n';
  select count(*) into n from fincas;
  r := r || '3 S ve fincas: ' || n || ' (1)' || E'\n';
  insert into vacas (id, finca_id, numero) values (gen_random_uuid(), fa, 'S-001');
  r := r || '4 OK S guarda en finca pendiente (soporte)' || E'\n';
  perform cambiar_estado_finca(fa, 'prueba', 15);
  reset role;
  select prueba_hasta into hasta from fincas where id = fa;
  r := r || '5 prueba hasta: ' || hasta || ' (hoy+15 = ' || (current_date + 15) || ')' || E'\n';
  set local role authenticated;
  perform cambiar_estado_finca(fa, 'activa');
  r := r || '6 fotos S carpeta A: ' || puede_usar_finca_texto(fa::text) || ' (true)' || E'\n';
  select count(*) into n from miembros_finca;
  r := r || '7 S ve miembros: ' || n || ' (1)' || E'\n';

  -- Usuario cualquiera: nada de lo del vendedor
  perform set_config('request.jwt.claims', json_build_object('sub', ux, 'role','authenticated')::text, true);
  r := r || '8 X es súper: ' || es_super_admin() || ' (false)' || E'\n';
  begin
    perform * from panel_fincas();
    r := r || '9 FALLO: X vio el panel' || E'\n';
  exception when others then
    r := r || '9 OK X sin panel' || E'\n';
  end;
  begin
    perform cambiar_estado_finca(fa, 'suspendida');
    r := r || '10 FALLO: X cambió el estado' || E'\n';
  exception when others then
    r := r || '10 OK X no cambia estados' || E'\n';
  end;
  begin
    insert into super_admins (usuario_id) values (ux);
    r := r || '11 FALLO: X se hizo súper' || E'\n';
  exception when others then
    r := r || '11 OK X no se hace súper' || E'\n';
  end;
  begin
    select count(*) into n from super_admins;
    r := r || '12 FALLO: X lee super_admins' || E'\n';
  exception when others then
    r := r || '12 OK X no lee super_admins' || E'\n';
  end;
  select count(*) into n from fincas;
  r := r || '13 X ve fincas: ' || n || ' (0)' || E'\n';
  select count(*) into n from vacas;
  r := r || '14 X ve vacas: ' || n || ' (0)' || E'\n';

  -- El dueño ve lo que guardó soporte, pero no el panel
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  select count(*) into n from vacas;
  r := r || '15 A ve vacas: ' || n || ' (1)' || E'\n';
  begin
    perform * from panel_fincas();
    r := r || '16 FALLO: dueño vio el panel' || E'\n';
  exception when others then
    r := r || '16 OK dueño sin panel' || E'\n';
  end;
  reset role;

  raise exception E'RESULTADO SÚPER ADMIN (todo deshecho):\n%', r;
end $$;
