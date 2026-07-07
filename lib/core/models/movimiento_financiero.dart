class MovimientoFinanciero {
  final String id;
  final String tipo; // 'ingreso' | 'gasto'
  final String? conceptoId;
  final String? nota;
  final double monto;
  final DateTime fecha;
  final String? ubicacionId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MovimientoFinanciero({
    required this.id,
    required this.tipo,
    this.conceptoId,
    this.nota,
    required this.monto,
    required this.fecha,
    this.ubicacionId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MovimientoFinanciero.fromMap(Map<String, dynamic> map) =>
      MovimientoFinanciero(
        id: map['id'] as String,
        tipo: map['tipo'] as String,
        conceptoId: map['concepto_id'] as String?,
        nota: map['nota'] as String?,
        monto: (map['monto'] as num).toDouble(),
        fecha: DateTime.parse(map['fecha'] as String),
        ubicacionId: map['ubicacion_id'] as String?,
        createdBy: map['created_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo,
        'concepto_id': conceptoId,
        'nota': nota,
        'monto': monto,
        'fecha': fecha.toIso8601String().split('T')[0],
        'ubicacion_id': ubicacionId,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  MovimientoFinanciero copyWith({
    String? tipo,
    String? conceptoId,
    bool clearConceptoId = false,
    String? nota,
    bool clearNota = false,
    double? monto,
    DateTime? fecha,
    String? ubicacionId,
    bool clearUbicacion = false,
  }) =>
      MovimientoFinanciero(
        id: id,
        tipo: tipo ?? this.tipo,
        conceptoId:
            clearConceptoId ? null : (conceptoId ?? this.conceptoId),
        nota: clearNota ? null : (nota ?? this.nota),
        monto: monto ?? this.monto,
        fecha: fecha ?? this.fecha,
        ubicacionId:
            clearUbicacion ? null : (ubicacionId ?? this.ubicacionId),
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
