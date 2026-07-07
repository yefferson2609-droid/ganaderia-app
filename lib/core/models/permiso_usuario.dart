const kModulos = [
  'vacas',
  'toros',
  'caballos',
  'lotes',
  'eventos',
  'ubicaciones',
  'finanzas',
  'usuarios',
];

const kModuloLabels = {
  'vacas': 'Vacas',
  'toros': 'Toros',
  'caballos': 'Caballos',
  'lotes': 'Lotes',
  'eventos': 'Eventos',
  'ubicaciones': 'Ubicaciones',
  'finanzas': 'Finanzas',
  'usuarios': 'Usuarios',
};

class PermisoUsuario {
  final String id;
  final String usuarioId;
  final String modulo;
  final bool puedeVer;
  final bool puedeCrear;
  final bool puedeEditar;
  final bool puedeEliminar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PermisoUsuario({
    required this.id,
    required this.usuarioId,
    required this.modulo,
    required this.puedeVer,
    required this.puedeCrear,
    required this.puedeEditar,
    required this.puedeEliminar,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PermisoUsuario.fromMap(Map<String, dynamic> map) => PermisoUsuario(
        id: map['id'] as String,
        usuarioId: map['usuario_id'] as String,
        modulo: map['modulo'] as String,
        puedeVer: _asBool(map['puede_ver']),
        puedeCrear: _asBool(map['puede_crear']),
        puedeEditar: _asBool(map['puede_editar']),
        puedeEliminar: _asBool(map['puede_eliminar']),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  static bool _asBool(dynamic v) => (v is int) ? v == 1 : v as bool;

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'modulo': modulo,
        'puede_ver': puedeVer ? 1 : 0,
        'puede_crear': puedeCrear ? 1 : 0,
        'puede_editar': puedeEditar ? 1 : 0,
        'puede_eliminar': puedeEliminar ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  PermisoUsuario copyWith({
    bool? puedeVer,
    bool? puedeCrear,
    bool? puedeEditar,
    bool? puedeEliminar,
  }) =>
      PermisoUsuario(
        id: id,
        usuarioId: usuarioId,
        modulo: modulo,
        puedeVer: puedeVer ?? this.puedeVer,
        puedeCrear: puedeCrear ?? this.puedeCrear,
        puedeEditar: puedeEditar ?? this.puedeEditar,
        puedeEliminar: puedeEliminar ?? this.puedeEliminar,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
