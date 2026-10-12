/// Una finca a la que pertenece el usuario, con su papel en ella.
/// Viene de `miembros_finca` + `fincas` en Supabase.
class MiFinca {
  final String miembroId;
  final String fincaId;
  final String nombre;
  final String codigo;

  /// pendiente | prueba | activa | suspendida
  final String estadoFinca;
  final DateTime? pruebaHasta;

  /// dueno | admin | empleado
  final String rol;

  /// pendiente | aprobado | rechazado | inactivo
  final String estadoMiembro;

  const MiFinca({
    required this.miembroId,
    required this.fincaId,
    required this.nombre,
    required this.codigo,
    required this.estadoFinca,
    required this.pruebaHasta,
    required this.rol,
    required this.estadoMiembro,
  });

  bool get pruebaVencida {
    if (estadoFinca != 'prueba' || pruebaHasta == null) return false;
    final hoy = DateTime.now();
    return pruebaHasta!.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  bool get fincaHabilitada =>
      estadoFinca == 'activa' || (estadoFinca == 'prueba' && !pruebaVencida);

  /// Se puede abrir: miembro aprobado y finca activa o en prueba vigente.
  bool get usable => estadoMiembro == 'aprobado' && fincaHabilitada;

  bool get esAdmin => rol == 'dueno' || rol == 'admin';

  String get rolTexto => switch (rol) {
        'dueno' => 'Dueño',
        'admin' => 'Administrador',
        _ => 'Trabajador',
      };

  /// Por qué no se puede abrir (null si se puede).
  String? get motivoBloqueo {
    if (estadoMiembro == 'pendiente') {
      return 'Esperando que el dueño de la finca te apruebe';
    }
    if (estadoMiembro == 'rechazado') return 'El dueño no aprobó tu ingreso';
    if (estadoMiembro == 'inactivo') return 'Tu acceso a esta finca está desactivado';
    if (estadoFinca == 'pendiente') {
      return 'Finca en revisión. Te avisaremos cuando esté activa';
    }
    if (estadoFinca == 'suspendida') return 'Finca suspendida. Comunícate con nosotros';
    if (pruebaVencida) return 'Terminó el periodo de prueba. Comunícate con nosotros';
    return null;
  }

  factory MiFinca.fromServidor(Map<String, dynamic> m) {
    final f = (m['fincas'] as Map).cast<String, dynamic>();
    final hasta = f['prueba_hasta'] as String?;
    return MiFinca(
      miembroId: m['id'] as String,
      fincaId: f['id'] as String,
      nombre: f['nombre'] as String,
      codigo: f['codigo'] as String,
      estadoFinca: f['estado'] as String,
      pruebaHasta: hasta == null ? null : DateTime.tryParse(hasta),
      rol: m['rol'] as String,
      estadoMiembro: m['estado'] as String,
    );
  }

  /// Para guardarla en el teléfono y poder entrar sin internet.
  Map<String, dynamic> toJson() => {
        'id': miembroId,
        'rol': rol,
        'estado': estadoMiembro,
        'fincas': {
          'id': fincaId,
          'nombre': nombre,
          'codigo': codigo,
          'estado': estadoFinca,
          'prueba_hasta': pruebaHasta?.toIso8601String().substring(0, 10),
        },
      };
}
