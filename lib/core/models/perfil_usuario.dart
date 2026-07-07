class PerfilUsuario {
  final String id;
  final String nombre;
  final String correo;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PerfilUsuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PerfilUsuario.fromMap(Map<String, dynamic> map) => PerfilUsuario(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        correo: map['correo'] as String,
        activo: (map['activo'] is int)
            ? (map['activo'] as int) == 1
            : map['activo'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
        'activo': activo ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  PerfilUsuario copyWith({String? nombre, bool? activo}) => PerfilUsuario(
        id: id,
        nombre: nombre ?? this.nombre,
        correo: correo,
        activo: activo ?? this.activo,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
