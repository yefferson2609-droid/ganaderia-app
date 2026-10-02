const kPrioridadLabels = {
  'alta': 'Alta',
  'media': 'Media',
  'baja': 'Baja',
};

class Actividad {
  final String id;
  final String descripcion;
  final DateTime? fechaLimite;
  final String? ubicacionId;
  final String prioridad; // 'alta' | 'media' | 'baja'
  final String estado; // 'pendiente' | 'completada'
  final String asignadoA;
  final String? creadoPor;
  final String? completadoPor;
  final DateTime? fechaCompletada;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Actividad({
    required this.id,
    required this.descripcion,
    this.fechaLimite,
    this.ubicacionId,
    this.prioridad = 'media',
    this.estado = 'pendiente',
    required this.asignadoA,
    this.creadoPor,
    this.completadoPor,
    this.fechaCompletada,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get completada => estado == 'completada';

  bool get vencida =>
      !completada &&
      fechaLimite != null &&
      fechaLimite!.isBefore(DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day));

  factory Actividad.fromMap(Map<String, dynamic> map) => Actividad(
        id: map['id'] as String,
        descripcion: map['descripcion'] as String,
        fechaLimite: map['fecha_limite'] != null
            ? DateTime.tryParse(map['fecha_limite'] as String)
            : null,
        ubicacionId: map['ubicacion_id'] as String?,
        prioridad: map['prioridad'] as String? ?? 'media',
        estado: map['estado'] as String? ?? 'pendiente',
        asignadoA: map['asignado_a'] as String,
        creadoPor: map['creado_por'] as String?,
        completadoPor: map['completado_por'] as String?,
        fechaCompletada: map['fecha_completada'] != null
            ? DateTime.tryParse(map['fecha_completada'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'descripcion': descripcion,
        'fecha_limite': fechaLimite?.toIso8601String().split('T')[0],
        'ubicacion_id': ubicacionId,
        'prioridad': prioridad,
        'estado': estado,
        'asignado_a': asignadoA,
        'creado_por': creadoPor,
        'completado_por': completadoPor,
        'fecha_completada': fechaCompletada?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
