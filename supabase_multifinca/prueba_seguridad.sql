-- PRUEBA de seguridad multi-finca. Todo se deshace al final (no deja datos):
-- termina con un error a propósito que muestra el resultado y anula todo.
-- Solo en el proyecto ganaderia-comercial (oaukzxwcohocqafttfki).
do $$
declare
  ua uuid := gen_random_uuid();  -- dueño A
  ub uuid := gen_random_uuid();  -- dueño B
  uw uuid := gen_random_uuid();  -- trabajador que pide entrar a A
  fa uuid; fb uuid; cod_a text; mw uuid; n int; r text := ''; nom text;
begin
  insert into auth.users (id, email, aud, role) values
    (ua, 'a@prueba.test', 'authenticated', 'authenticated'),
    (ub, 'b@prueba.test', 'authenticated', 'authenticated'),
    (uw, 'w@prueba.test', 'authenticated', 'authenticated');

  -- A y B crean sus fincas
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'email', 'a@prueba.test', 'role','authenticated')::text, true);
  fa := crear_finca('Finca A', 'Ana');
  perform set_config('request.jwt.claims', json_build_object('sub', ub, 'email', 'b@prueba.test', 'role','authenticated')::text, true);
  fb := crear_finca('Finca B', 'Beto');
  reset role;
  select codigo into cod_a from fincas where id = fa;
  r := r || '1 fincas creadas pendientes: ' || (select string_agg(estado, ',') from fincas) || E'\n';

  -- A no puede usar su finca mientras está pendiente
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  begin
    insert into vacas (id, finca_id, numero) values (gen_random_uuid(), fa, '1');
    r := r || '2 FALLO: A guardó vaca con finca pendiente' || E'\n';
  exception when others then
    r := r || '2 OK pendiente bloquea: ' || sqlerrm || E'\n';
  end;
  reset role;

  update fincas set estado = 'activa' where id in (fa, fb);

  -- Cada dueño guarda una vaca en su finca
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  insert into vacas (id, finca_id, numero) values (gen_random_uuid(), fa, 'A-001');
  perform set_config('request.jwt.claims', json_build_object('sub', ub, 'role','authenticated')::text, true);
  insert into vacas (id, finca_id, numero) values (gen_random_uuid(), fb, 'B-001');

  -- B solo ve lo suyo
  select count(*) into n from vacas;
  r := r || '3 B ve vacas: ' || n || ' (debe ser 1) ' || (select string_agg(numero, ',') from vacas) || E'\n';
  select count(*) into n from fincas;
  r := r || '4 B ve fincas: ' || n || ' (debe ser 1)' || E'\n';
  select count(*) into n from miembros_finca;
  r := r || '5 B ve miembros: ' || n || ' (debe ser 1)' || E'\n';
  begin
    insert into vacas (id, finca_id, numero) values (gen_random_uuid(), fa, 'intruso');
    r := r || '6 FALLO: B guardó vaca en finca A' || E'\n';
  exception when others then
    r := r || '6 OK B no escribe en A' || E'\n';
  end;
  update vacas set numero = 'cambiado' where finca_id = fa;
  get diagnostics n = row_count;
  r := r || '7 B modificó vacas de A: ' || n || ' (debe ser 0)' || E'\n';
  delete from vacas where finca_id = fa;
  get diagnostics n = row_count;
  r := r || '8 B borró vacas de A: ' || n || ' (debe ser 0)' || E'\n';

  -- Trabajador W pide entrar a A con el código
  perform set_config('request.jwt.claims', json_build_object('sub', uw, 'email', 'w@prueba.test', 'role','authenticated')::text, true);
  nom := unirse_con_codigo(lower(cod_a), 'Walter');
  r := r || '9 W se unió a: ' || nom || E'\n';
  select count(*) into n from vacas;
  r := r || '10 W pendiente ve vacas: ' || n || ' (debe ser 0)' || E'\n';
  begin
    perform unirse_con_codigo('ZZZZZZ', 'Walter');
    r := r || '11 FALLO: código falso aceptado' || E'\n';
  exception when others then
    r := r || '11 OK código falso rechazado: ' || sqlerrm || E'\n';
  end;
  reset role;
  select id into mw from miembros_finca where usuario_id = uw;
  set local role authenticated;

  -- W no puede aprobarse a sí mismo; B (otra finca) tampoco puede aprobarlo
  begin
    perform gestionar_miembro(mw, 'aprobado', 'admin');
    r := r || '12 FALLO: W se aprobó solo' || E'\n';
  exception when others then
    r := r || '12 OK W no se aprueba solo' || E'\n';
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', ub, 'role','authenticated')::text, true);
  begin
    perform gestionar_miembro(mw, 'aprobado', 'admin');
    r := r || '13 FALLO: B aprobó a alguien de A' || E'\n';
  exception when others then
    r := r || '13 OK B no aprueba en A' || E'\n';
  end;

  -- A aprueba a W como empleado
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  perform gestionar_miembro(mw, 'aprobado', 'empleado');
  select count(*) into n from miembros_finca;
  r := r || '14 A ve miembros de su finca: ' || n || ' (debe ser 2)' || E'\n';

  perform set_config('request.jwt.claims', json_build_object('sub', uw, 'role','authenticated')::text, true);
  select count(*) into n from vacas;
  r := r || '15 W aprobado ve vacas: ' || n || ' (debe ser 1) ' || (select string_agg(numero, ',') from vacas) || E'\n';
  r := r || '16 permisos W: ' || (select string_agg(modulo, ',' order by modulo) from permisos_usuario where usuario_id = uw and puede_ver) || ' (solo actividades,solicitudes)' || E'\n';
  begin
    update permisos_usuario set puede_ver = true where usuario_id = uw;
    get diagnostics n = row_count;
    r := r || '17 W se dio permisos: ' || n || ' filas (debe ser 0)' || E'\n';
  exception when others then
    r := r || '17 OK W no se da permisos' || E'\n';
  end;
  begin
    perform _dar_permisos_rol(fa, uw, 'admin');
    r := r || '18 FALLO: W usó función interna' || E'\n';
  exception when others then
    r := r || '18 OK función interna bloqueada' || E'\n';
  end;
  begin
    update fincas set estado = 'activa' where id = fa;
    r := r || '19 FALLO: W cambió la finca' || E'\n';
  exception when others then
    r := r || '19 OK W no cambia la finca' || E'\n';
  end;
  r := r || '20 fotos: W carpeta A=' || puede_usar_finca_texto(fa::text) || ' carpeta B=' || puede_usar_finca_texto(fb::text) || ' (true/false)' || E'\n';

  -- Los permisos del dueño no se pueden cambiar
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  begin
    update permisos_usuario set puede_ver = false where usuario_id = ua and finca_id = fa;
    get diagnostics n = row_count;
    r := r || '21 permisos del dueño cambiados: ' || n || ' (debe ser 0)' || E'\n';
  exception when others then
    r := r || '21 OK permisos del dueño protegidos' || E'\n';
  end;
  reset role;

  -- Finca suspendida: nadie de A ve datos
  update fincas set estado = 'suspendida' where id = fa;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  select count(*) into n from vacas;
  r := r || '22 A suspendida ve vacas: ' || n || ' (debe ser 0); ve su finca: ' || (select count(*) from fincas) || ' (debe ser 1)' || E'\n';
  reset role;

  -- Sin sesión (anon) no ve nada
  set local role anon;
  begin
    select count(*) into n from vacas;
    r := r || '23 FALLO: anon ve vacas ' || n || E'\n';
  exception when others then
    r := r || '23 OK anon sin acceso' || E'\n';
  end;
  reset role;

  raise exception E'RESULTADO DE LA PRUEBA (todo deshecho):\n%', r;
end $$;
