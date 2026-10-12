-- PRUEBA de nómina por finca y "eliminar usuario de una finca".
-- Todo se deshace al final (no deja datos). Solo en ganaderia-comercial.
do $$
declare
  ua uuid := gen_random_uuid();  -- dueño A
  ub uuid := gen_random_uuid();  -- dueño B
  uw uuid := gen_random_uuid();  -- trabajador que está en A y en B
  fa uuid; fb uuid; ta uuid := gen_random_uuid(); tb uuid := gen_random_uuid();
  dom date := current_date - extract(isodow from current_date)::int; -- domingo pasado
  n int; r text := ''; tot numeric; cod_a text; cod_b text; mw uuid;
begin
  insert into auth.users (id, email, aud, role) values
    (ua, 'a@prueba.test', 'authenticated', 'authenticated'),
    (ub, 'b@prueba.test', 'authenticated', 'authenticated'),
    (uw, 'w@prueba.test', 'authenticated', 'authenticated');

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'email', 'a@prueba.test', 'role','authenticated')::text, true);
  fa := crear_finca('Finca A', 'Ana');
  perform set_config('request.jwt.claims', json_build_object('sub', ub, 'email', 'b@prueba.test', 'role','authenticated')::text, true);
  fb := crear_finca('Finca B', 'Beto');
  reset role;
  update fincas set estado = 'activa' where id in (fa, fb);
  select codigo into cod_a from fincas where id = fa;
  select codigo into cod_b from fincas where id = fb;

  -- Cada finca con un trabajador de nómina; A además con bono y préstamo
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  insert into trabajadores (id, finca_id, nombre, salario_semanal) values (ta, fa, 'Pedro A', 100);
  insert into nomina_novedades (id, finca_id, trabajador_id, semana_fin, tipo, monto)
    values (gen_random_uuid(), fa, ta, dom, 'bono', 20);
  insert into prestamos_trabajador (id, finca_id, trabajador_id, fecha, monto_total, cuota_semanal)
    values (gen_random_uuid(), fa, ta, dom - 3, 50, 30);
  perform set_config('request.jwt.claims', json_build_object('sub', ub, 'role','authenticated')::text, true);
  insert into trabajadores (id, finca_id, nombre, salario_semanal) values (tb, fb, 'Juan B', 70);

  -- B no ve ni paga la nómina de A
  select count(*) into n from trabajadores;
  r := r || '1 B ve trabajadores: ' || n || ' (1)' || E'\n';
  begin
    perform pagar_nomina(fa, dom);
    r := r || '2 FALLO: B pagó la nómina de A' || E'\n';
  exception when others then
    r := r || '2 OK B no paga la nómina de A' || E'\n';
  end;

  -- A paga la suya: 100 + 20 bono - 30 cuota = 90
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  perform pagar_nomina(fa, dom);
  select total into tot from nomina_semanas where finca_id = fa and semana_fin = dom;
  r := r || '3 nómina A total: ' || coalesce(tot::text, 'VACÍO') || ' (90)' || E'\n';
  select count(*) into n from movimientos_financieros where finca_id = fa;
  r := r || '4 gasto en finanzas de A: ' || n || ' (1)' || E'\n';
  select count(*) into n from nomina_semanas;
  r := r || '5 A ve semanas pagadas: ' || n || ' (1, solo la suya)' || E'\n';
  reset role;

  -- Pago automático (reloj del servidor, sin usuario): paga B; A ya estaba
  perform set_config('request.jwt.claims', '', true);
  perform pagar_nominas_automaticas(dom);
  select total into tot from nomina_semanas where finca_id = fb and semana_fin = dom;
  r := r || '6 automático B total: ' || coalesce(tot::text, 'VACÍO') || ' (70)' || E'\n';
  select count(*) into n from movimientos_financieros where finca_id = fa;
  r := r || '7 A sin pago doble: ' || n || ' gasto(s) (1)' || E'\n';
  select count(*) into n from conceptos_financieros where lower(nombre) = 'nómina';
  r := r || '8 concepto Nómina por finca: ' || n || ' (2)' || E'\n';

  -- Desde la app nadie llama el pago automático
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  begin
    perform pagar_nominas_automaticas(dom);
    r := r || '9 FALLO: la app llamó el pago automático' || E'\n';
  exception when others then
    r := r || '9 OK pago automático solo del servidor' || E'\n';
  end;

  -- W trabaja en A y en B; A lo elimina de SU finca
  perform set_config('request.jwt.claims', json_build_object('sub', uw, 'email', 'w@prueba.test', 'role','authenticated')::text, true);
  perform unirse_con_codigo(cod_a, 'Walter');
  perform unirse_con_codigo(cod_b, 'Walter');
  reset role;
  update miembros_finca set estado = 'aprobado' where usuario_id = uw;
  set local role authenticated;

  perform set_config('request.jwt.claims', json_build_object('sub', ub, 'role','authenticated')::text, true);
  begin
    perform eliminar_usuario(uw, fa);
    r := r || '10 FALLO: B eliminó a alguien de A' || E'\n';
  exception when others then
    r := r || '10 OK B no elimina en A' || E'\n';
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', ua, 'role','authenticated')::text, true);
  begin
    perform eliminar_usuario(ua, fa);
    r := r || '11 FALLO: A se eliminó a sí mismo' || E'\n';
  exception when others then
    r := r || '11 OK nadie se elimina a sí mismo' || E'\n';
  end;
  perform eliminar_usuario(uw, fa);
  perform set_config('request.jwt.claims', json_build_object('sub', uw, 'role','authenticated')::text, true);
  r := r || '12 W puede usar A: ' || puede_usar_finca(fa) || ' (false) · B: ' || puede_usar_finca(fb) || ' (true)' || E'\n';
  -- Con el código vuelve a pedir entrada (queda pendiente)
  perform unirse_con_codigo(cod_a, 'Walter');
  reset role;
  r := r || '13 W tras volver a pedir entrada: '
    || coalesce((select estado from miembros_finca where usuario_id = uw and finca_id = fa), 'SIN FILA')
    || ' (pendiente)' || E'\n';

  raise exception E'RESULTADO NÓMINA / ELIMINAR (todo deshecho):\n%', r;
end $$;
