class Caballo {
  final String id;
  final String nombre;
  final String estado;
  final String? ubicacionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Caballo({
    required this.id,
    required this.nombre,
    required this.estado,
    this.ubicacionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Caballo.fromMap(Map<String, dynamic> map) => Caballo(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        estado: map['estado'] as String,
        ubicacionId: map['ubicacion_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'estado': estado,
        'ubicacion_id': ubicacionId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Caballo copyWith({String? nombre, String? estado, String? ubicacionId, bool clearUbicacion = false}) => Caballo(
        id: id,
        nombre: nombre ?? this.nombre,
        estado: estado ?? this.estado,
        ubicacionId: clearUbicacion ? null : (ubicacionId ?? this.ubicacionId),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
