class MovimientoLote {
  final String id;
  final String loteId;
  final String tipoMovimiento; // 'muerte' | 'venta'
  final int cantidad;
  final String sexo; // 'hembra' | 'macho'
  final DateTime fecha;
  final String? notas;
  final DateTime createdAt;

  const MovimientoLote({
    required this.id,
    required this.loteId,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.sexo,
    required this.fecha,
    this.notas,
    required this.createdAt,
  });

  factory MovimientoLote.fromMap(Map<String, dynamic> map) => MovimientoLote(
        id: map['id'] as String,
        loteId: map['lote_id'] as String,
        tipoMovimiento: map['tipo_movimiento'] as String,
        cantidad: map['cantidad'] as int,
        sexo: map['sexo'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        notas: map['notas'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'lote_id': loteId,
        'tipo_movimiento': tipoMovimiento,
        'cantidad': cantidad,
        'sexo': sexo,
        'fecha': fecha.toIso8601String().split('T')[0],
        'notas': notas,
        'created_at': createdAt.toIso8601String(),
      };
}
