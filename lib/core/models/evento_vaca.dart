class EventoVaca {
  final String id;
  final String vacaId;
  final String tipoEventoId;
  final String? tipoEventoNombre; // join local
  final DateTime fecha;
  final String? notas;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventoVaca({
    required this.id,
    required this.vacaId,
    required this.tipoEventoId,
    this.tipoEventoNombre,
    required this.fecha,
    this.notas,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventoVaca.fromMap(Map<String, dynamic> map) => EventoVaca(
        id: map['id'] as String,
        vacaId: map['vaca_id'] as String,
        tipoEventoId: map['tipo_evento_id'] as String,
        tipoEventoNombre: map['tipo_evento_nombre'] as String?,
        fecha: DateTime.parse(map['fecha'] as String),
        notas: map['notas'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'vaca_id': vacaId,
        'tipo_evento_id': tipoEventoId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'notas': notas,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
