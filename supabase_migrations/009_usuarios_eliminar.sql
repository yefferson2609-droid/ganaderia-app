-- Usuarios: corrige guardar cambios de perfiles y permite eliminar usuarios.
-- Se puede ejecutar varias veces sin problema.

-- 1) La app guarda con "insertar o actualizar" (upsert): faltaba la regla de
--    INSERT en perfiles_usuario y por eso fallaba al guardar cambios.
drop policy if exists "insert_perfiles_admin" on perfiles_usuario;
create policy "insert_perfiles_admin" on perfiles_usuario for insert
  with check (is_admin_usuarios());

-- 2) Marca de usuario eliminado (se conserva su nombre en el historial).
alter table perfiles_usuario add column if not exists eliminado boolean not null default false;

-- 3) Eliminar usuario: solo un administrador, nunca a sí mismo.
--    No se borra la cuenta (sus registros "creado por" apuntan a ella):
--    se bloquea el acceso, se cierran sus sesiones y se quitan sus permisos.
create or replace function eliminar_usuario(p_usuario uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not is_admin_usuarios() then
    raise exception 'Solo un administrador puede eliminar usuarios';
  end if;
  if p_usuario = auth.uid() then
    raise exception 'No puedes eliminar tu propio usuario';
  end if;

  update auth.users set banned_until = 'infinity' where id = p_usuario;
  delete from auth.sessions where user_id = p_usuario;
  delete from permisos_usuario where usuario_id = p_usuario;
  update perfiles_usuario
     set activo = false, eliminado = true, updated_at = now()
   where id = p_usuario;
end;
$$;

revoke all on function eliminar_usuario(uuid) from public;
grant execute on function eliminar_usuario(uuid) to authenticated;

-- 4) Permisos: aceptar también los módulos nuevos de la app.
alter table permisos_usuario drop constraint if exists permisos_usuario_modulo_check;
alter table permisos_usuario add constraint permisos_usuario_modulo_check
  check (modulo in (
    'vacas','toros','terneros','caballos','lotes','eventos','salud',
    'actividades','solicitudes','ubicaciones','finanzas','reportes','usuarios'
  ));

notify pgrst, 'reload schema';
