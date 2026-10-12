// Crear la cuenta de un trabajador desde la app (versión multi-finca).
// Solo el dueño o un administrador de la finca puede usarla; el trabajador
// queda aprobado en ESA finca, con permisos de trabajador.
// Proyecto: ganaderia-comercial (oaukzxwcohocqafttfki).
// Desplegar con "Verify JWT" desactivado: la identidad se verifica aquí.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// Clave del proyecto: las antiguas (SUPABASE_ANON_KEY / SERVICE_ROLE_KEY) o
// las nuevas (SUPABASE_PUBLISHABLE_KEYS / SUPABASE_SECRET_KEYS, en JSON).
function clave(antigua: string, nuevas: string): string {
  const v = Deno.env.get(antigua);
  if (v) return v;
  const json = Deno.env.get(nuevas);
  if (json) {
    try {
      const obj = JSON.parse(json) as Record<string, string>;
      return obj['default'] ?? Object.values(obj)[0];
    } catch {
      return json;
    }
  }
  throw new Error('Falta la clave ' + antigua);
}

function respuesta(cuerpo: unknown, status = 200) {
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return respuesta({ error: 'No autorizado' }, 401);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = clave('SUPABASE_ANON_KEY', 'SUPABASE_PUBLISHABLE_KEYS');
    const serviceRoleKey = clave(
      'SUPABASE_SERVICE_ROLE_KEY',
      'SUPABASE_SECRET_KEYS',
    );

    // Cliente con la sesión de quien llama: identidad y permisos vía RLS.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const token = authHeader.replace(/^Bearer\s+/i, '');
    const { data: userData, error: userError } =
      await callerClient.auth.getUser(token);
    if (userError || !userData.user) {
      return respuesta({ error: 'No autorizado' }, 401);
    }

    const { finca_id, correo, password, nombre } = await req.json();
    if (!finca_id || !correo || !password || !nombre) {
      return respuesta({ error: 'Faltan campos requeridos' }, 400);
    }

    // ¿Quien llama es dueño o administrador de esa finca (y está activa)?
    const { data: esAdmin, error: adminError } = await callerClient.rpc(
      'es_admin_finca',
      { f: finca_id },
    );
    if (adminError || esAdmin !== true) {
      return respuesta(
        { error: 'Solo el dueño o un administrador puede crear usuarios' },
        403,
      );
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: newUser, error: createError } =
      await adminClient.auth.admin.createUser({
        email: String(correo).trim(),
        password,
        email_confirm: true,
        user_metadata: { nombre },
      });

    if (createError || !newUser.user) {
      const msg = createError?.message ?? '';
      if (/already|registered|exists/i.test(msg)) {
        return respuesta({
          error:
            'Ese correo ya tiene cuenta. Pídele que entre con el código de la finca.',
        }, 400);
      }
      return respuesta({ error: msg || 'Error creando usuario' }, 400);
    }

    const uid = newUser.user.id;
    const { error: miembroError } = await adminClient
      .from('miembros_finca')
      .insert({
        finca_id,
        usuario_id: uid,
        nombre: String(nombre).trim(),
        correo: String(correo).trim(),
        rol: 'empleado',
        estado: 'aprobado',
      });
    if (miembroError) {
      // Sin miembro la cuenta no sirve: se borra para poder reintentar.
      await adminClient.auth.admin.deleteUser(uid);
      return respuesta({ error: miembroError.message }, 400);
    }

    // Mismos permisos que un trabajador aprobado con código.
    await adminClient.rpc('_dar_permisos_rol', {
      f: finca_id,
      u: uid,
      r: 'empleado',
    });

    return respuesta({ id: uid });
  } catch (e) {
    return respuesta({ error: String(e) }, 500);
  }
});
