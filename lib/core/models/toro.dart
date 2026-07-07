class Toro {
  final String id;
  final String numero;
  final String nombre;
  final DateTime? fechaNacimiento;
  final String estado;
  final String? padreId;
  final String? madreId;
  final String? ubicacionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Toro({
    required this.id,
    required this.numero,
    required this.nombre,
    this.fechaNacimiento,
    required this.estado,
    this.padreId,
    this.madreId,
    this.ubicacionId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Edad en texto legible
  String get edad {
    if (fechaNacimiento == null) return 'Sin fecha';
    final diff = DateTime.now().difference(fechaNacimiento!);
    final years = diff.inDays ~/ 365;
    final months = (diff.inDays % 365) ~/ 30;
    if (years > 0) {
      return '$years año${years > 1 ? 's' : ''} $months mes${months != 1 ? 'es' : ''}';
    }
    if (months > 0) return '$months mes${months != 1 ? 'es' : ''}';
    return '${diff.inDays} días';
  }

  factory Toro.fromMap(Map<String, dynamic> map) => Toro(
        id: map['id'] as String,
        numero: map['numero'] as String,
        nombre: map['nombre'] as String,
        fechaNacimiento: map['fecha_nacimiento'] != null
            ? DateTime.tryParse(map['fecha_nacimiento'] as String)
            : null,
        estado: map['estado'] as String,
        padreId: map['padre_id'] as String?,
        madreId: map['madre_id'] as String?,
        ubicacionId: map['ubicacion_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'nombre': nombre,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
        'estado': estado,
        'padre_id': padreId,
        'madre_id': madreId,
        'ubicacion_id': ubicacionId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Toro copyWith({
    String? numero,
    String? nombre,
    DateTime? fechaNacimiento,
    String? estado,
    String? padreId,
    bool clearPadreId = false,
    String? madreId,
    bool clearMadreId = false,
    String? ubicacionId,
    bool clearUbicacion = false,
  }) =>
      Toro(
        id: id,
        numero: numero ?? this.numero,
        nombre: nombre ?? this.nombre,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        estado: estado ?? this.estado,
        padreId: clearPadreId ? null : (padreId ?? this.padreId),
        madreId: clearMadreId ? null : (madreId ?? this.madreId),
        ubicacionId:
            clearUbicacion ? null : (ubicacionId ?? this.ubicacionId),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  String get displayName => '#$numero - $nombre';
}
