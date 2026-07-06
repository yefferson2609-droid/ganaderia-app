class Ubicacion {
  final String id;
  final String nombre;
  final String? descripcion;
  final bool activa;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Ubicacion({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activa,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ubicacion.fromMap(Map<String, dynamic> map) => Ubicacion(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        descripcion: map['descripcion'] as String?,
        activa: (map['activa'] is int)
            ? (map['activa'] as int) == 1
            : map['activa'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'activa': activa ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Ubicacion copyWith({String? nombre, String? descripcion, bool? activa}) =>
      Ubicacion(
        id: id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        activa: activa ?? this.activa,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
