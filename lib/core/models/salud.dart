/// Tipos de animal que pueden tener registros de salud.
const kAnimalTipoLabels = {
  'vaca': 'Vaca',
  'toro': 'Toro',
  'ternero': 'Ternero',
  'caballo': 'Caballo',
};

class RegistroSalud {
  final String id;
  final String animalTipo; // 'vaca' | 'toro' | 'ternero' | 'caballo'
  final String animalId;
  final DateTime fechaInicio;
  final String diagnostico;
  final String estado; // 'activo' | 'recuperado'
  final DateTime? fechaFin;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RegistroSalud({
    required this.id,
    required this.animalTipo,
    required this.animalId,
    required this.fechaInicio,
    required this.diagnostico,
    this.estado = 'activo',
    this.fechaFin,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get activo => estado == 'activo';

  factory RegistroSalud.fromMap(Map<String, dynamic> map) => RegistroSalud(
        id: map['id'] as String,
        animalTipo: map['animal_tipo'] as String,
        animalId: map['animal_id'] as String,
        fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
        diagnostico: map['diagnostico'] as String,
        estado: map['estado'] as String? ?? 'activo',
        fechaFin: map['fecha_fin'] != null
            ? DateTime.tryParse(map['fecha_fin'] as String)
            : null,
        createdBy: map['created_by'] as String?,
        updatedBy: map['updated_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'animal_tipo': animalTipo,
        'animal_id': animalId,
        'fecha_inicio': fechaInicio.toIso8601String().split('T')[0],
        'diagnostico': diagnostico,
        'estado': estado,
        'fecha_fin': fechaFin?.toIso8601String().split('T')[0],
        'created_by': createdBy,
        'updated_by': updatedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class TratamientoSalud {
  final String id;
  final String registroSaludId;
  final DateTime fecha;
  final String medicamento;
  final String? dosis;
  final String? notas;
  final String estado; // 'aplicado' | 'programado'
  final String? createdBy;
  final DateTime createdAt;

  // Datos del registro (solo en consultas con JOIN)
  final String? animalTipo;
  final String? animalId;

  const TratamientoSalud({
    required this.id,
    required this.registroSaludId,
    required this.fecha,
    required this.medicamento,
    this.dosis,
    this.notas,
    this.estado = 'aplicado',
    this.createdBy,
    required this.createdAt,
    this.animalTipo,
    this.animalId,
  });

  bool get programado => estado == 'programado';

  factory TratamientoSalud.fromMap(Map<String, dynamic> map) =>
      TratamientoSalud(
        id: map['id'] as String,
        registroSaludId: map['registro_salud_id'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        medicamento: map['medicamento'] as String,
        dosis: map['dosis'] as String?,
        notas: map['notas'] as String?,
        estado: map['estado'] as String? ?? 'aplicado',
        createdBy: map['created_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        animalTipo: map['animal_tipo'] as String?,
        animalId: map['animal_id'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'registro_salud_id': registroSaludId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'medicamento': medicamento,
        'dosis': dosis,
        'notas': notas,
        'estado': estado,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}
