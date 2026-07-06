class TipoEvento {
  final String id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TipoEvento({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TipoEvento.fromMap(Map<String, dynamic> map) => TipoEvento(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        descripcion: map['descripcion'] as String?,
        activo: (map['activo'] is int)
            ? (map['activo'] as int) == 1
            : map['activo'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'activo': activo ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TipoEvento copyWith({String? nombre, String? descripcion, bool? activo}) =>
      TipoEvento(
        id: id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        activo: activo ?? this.activo,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
