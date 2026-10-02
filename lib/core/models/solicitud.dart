const kEstadoSolicitudLabels = {
  'pendiente': 'Pendiente',
  'aprobada': 'Aprobada',
  'rechazada': 'Rechazada',
  'completada': 'Completada',
};

class Solicitud {
  final String id;
  final String item;
  final String? cantidad;
  final String? ubicacionId;
  final String estado; // 'pendiente' | 'aprobada' | 'rechazada' | 'completada'
  final String? nota;
  final double? costo;
  final String? solicitadoPor;
  final String? resueltoPor;
  final DateTime? fechaResolucion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Solicitud({
    required this.id,
    required this.item,
    this.cantidad,
    this.ubicacionId,
    this.estado = 'pendiente',
    this.nota,
    this.costo,
    this.solicitadoPor,
    this.resueltoPor,
    this.fechaResolucion,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get pendiente => estado == 'pendiente';

  factory Solicitud.fromMap(Map<String, dynamic> map) => Solicitud(
        id: map['id'] as String,
        item: map['item'] as String,
        cantidad: map['cantidad'] as String?,
        ubicacionId: map['ubicacion_id'] as String?,
        estado: map['estado'] as String? ?? 'pendiente',
        nota: map['nota'] as String?,
        costo: (map['costo'] as num?)?.toDouble(),
        solicitadoPor: map['solicitado_por'] as String?,
        resueltoPor: map['resuelto_por'] as String?,
        fechaResolucion: map['fecha_resolucion'] != null
            ? DateTime.tryParse(map['fecha_resolucion'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'item': item,
        'cantidad': cantidad,
        'ubicacion_id': ubicacionId,
        'estado': estado,
        'nota': nota,
        'costo': costo,
        'solicitado_por': solicitadoPor,
        'resuelto_por': resueltoPor,
        'fecha_resolucion': fechaResolucion?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
