import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const MODULOS = [
  'vacas', 'toros', 'caballos', 'lotes', 'eventos',
  'ubicaciones', 'finanzas', 'usuarios',
];

Deno.serve(async (req) => {
  const jsonHeaders = { 'Content-Type': 'application/json' };

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No autorizado' }), {
        status: 401, headers: jsonHeaders,
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Cliente con el JWT de quien llama, para verificar identidad y permisos via RLS.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: 'No autorizado' }), {
        status: 401, headers: jsonHeaders,
      });
    }

    const { data: permiso } = await callerClient
      .from('permisos_usuario')
      .select('puede_crear')
      .eq('usuario_id', userData.user.id)
      .eq('modulo', 'usuarios')
      .maybeSingle();

    if (!permiso?.puede_crear) {
      return new Response(
        JSON.stringify({ error: 'No tienes permiso para crear usuarios' }),
        { status: 403, headers: jsonHeaders },
      );
    }

    const { correo, password, nombre } = await req.json();
    if (!correo || !password || !nombre) {
      return new Response(
        JSON.stringify({ error: 'Faltan campos requeridos' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email: correo,
      password,
      email_confirm: true,
    });

    if (createError || !newUser.user) {
      return new Response(
        JSON.stringify({ error: createError?.message ?? 'Error creando usuario' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const now = new Date().toISOString();

    await adminClient.from('perfiles_usuario').insert({
      id: newUser.user.id,
      nombre,
      correo,
      activo: true,
      created_at: now,
      updated_at: now,
    });

    await adminClient.from('permisos_usuario').insert(
      MODULOS.map((modulo) => ({
        usuario_id: newUser.user.id,
        modulo,
        puede_ver: false,
        puede_crear: false,
        puede_editar: false,
        puede_eliminar: false,
        created_at: now,
        updated_at: now,
      })),
    );

    return new Response(JSON.stringify({ id: newUser.user.id }), {
      status: 200, headers: jsonHeaders,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: jsonHeaders,
    });
  }
});
