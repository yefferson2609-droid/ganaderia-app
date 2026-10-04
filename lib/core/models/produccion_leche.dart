const kTurnoLabels = {'manana': 'Mañana', 'tarde': 'Tarde'};

/// Un ordeño: total de la finca (vacaId null) o de una vaca en particular.
class ProduccionLeche {
  final String id;
  final DateTime fecha;
  final String turno; // 'manana' | 'tarde'
  final double litros;
  final String? vacaId;
  final String? ubicacionId;
  final String? notas;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProduccionLeche({
    required this.id,
    required this.fecha,
    required this.turno,
    required this.litros,
    this.vacaId,
    this.ubicacionId,
    this.notas,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProduccionLeche.fromMap(Map<String, dynamic> map) => ProduccionLeche(
        id: map['id'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        turno: map['turno'] as String,
        litros: (map['litros'] as num).toDouble(),
        vacaId: map['vaca_id'] as String?,
        ubicacionId: map['ubicacion_id'] as String?,
        notas: map['notas'] as String?,
        createdBy: map['created_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha': fecha.toIso8601String().split('T')[0],
        'turno': turno,
        'litros': litros,
        'vaca_id': vacaId,
        'ubicacion_id': ubicacionId,
        'notas': notas,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Totales de un día (solo registros de la finca).
class LecheDia {
  final DateTime fecha;
  final double manana;
  final double tarde;
  const LecheDia(this.fecha, this.manana, this.tarde);
  double get total => manana + tarde;
}
