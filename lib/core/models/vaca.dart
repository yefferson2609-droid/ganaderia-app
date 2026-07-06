class Vaca {
  final String id;
  final String numero;
  final DateTime? fechaNacimiento;
  final String estado;
  final String? padreId;
  final String? madreId;
  final String estadoReproductivo;
  final DateTime? fechaMonta;
  final String? toroId;
  final DateTime? fechaEstimadaParto;
  final String? ubicacionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vaca({
    required this.id,
    required this.numero,
    this.fechaNacimiento,
    required this.estado,
    this.padreId,
    this.madreId,
    this.estadoReproductivo = 'vacia',
    this.fechaMonta,
    this.toroId,
    this.fechaEstimadaParto,
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
    if (years > 0) return '$years año${years > 1 ? 's' : ''} $months mes${months != 1 ? 'es' : ''}';
    if (months > 0) return '$months mes${months != 1 ? 'es' : ''}';
    return '${diff.inDays} días';
  }

  // Días de gestación transcurridos
  int? get diasGestacion {
    if (fechaMonta == null) return null;
    return DateTime.now().difference(fechaMonta!).inDays;
  }

  // Porcentaje de gestación (283 días promedio bovino)
  double? get porcentajeGestacion {
    final dias = diasGestacion;
    if (dias == null) return null;
    return (dias / 283 * 100).clamp(0, 100);
  }

  factory Vaca.fromMap(Map<String, dynamic> map) => Vaca(
        id: map['id'] as String,
        numero: map['numero'] as String,
        fechaNacimiento: map['fecha_nacimiento'] != null
            ? DateTime.tryParse(map['fecha_nacimiento'] as String)
            : null,
        estado: map['estado'] as String,
        padreId: map['padre_id'] as String?,
        madreId: map['madre_id'] as String?,
        estadoReproductivo: map['estado_reproductivo'] as String? ?? 'vacia',
        fechaMonta: map['fecha_monta'] != null
            ? DateTime.tryParse(map['fecha_monta'] as String)
            : null,
        toroId: map['toro_id'] as String?,
        fechaEstimadaParto: map['fecha_estimada_parto'] != null
            ? DateTime.tryParse(map['fecha_estimada_parto'] as String)
            : null,
        ubicacionId: map['ubicacion_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
        'estado': estado,
        'padre_id': padreId,
        'madre_id': madreId,
        'estado_reproductivo': estadoReproductivo,
        'fecha_monta': fechaMonta?.toIso8601String().split('T')[0],
        'toro_id': toroId,
        'fecha_estimada_parto':
            fechaEstimadaParto?.toIso8601String().split('T')[0],
        'ubicacion_id': ubicacionId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Vaca copyWith({
    String? numero,
    DateTime? fechaNacimiento,
    String? estado,
    String? padreId,
    String? madreId,
    String? estadoReproductivo,
    DateTime? fechaMonta,
    String? toroId,
    DateTime? fechaEstimadaParto,
    bool clearFechaMonta = false,
    bool clearToroId = false,
    bool clearFechaParto = false,
    String? ubicacionId,
    bool clearUbicacion = false,
  }) =>
      Vaca(
        id: id,
        numero: numero ?? this.numero,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        estado: estado ?? this.estado,
        padreId: padreId ?? this.padreId,
        madreId: madreId ?? this.madreId,
        estadoReproductivo: estadoReproductivo ?? this.estadoReproductivo,
        fechaMonta: clearFechaMonta ? null : (fechaMonta ?? this.fechaMonta),
        toroId: clearToroId ? null : (toroId ?? this.toroId),
        fechaEstimadaParto: clearFechaParto
            ? null
            : (fechaEstimadaParto ?? this.fechaEstimadaParto),
        ubicacionId: clearUbicacion ? null : (ubicacionId ?? this.ubicacionId),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
