import '../utils/auditoria.dart';
import '../utils/edad.dart';

class Caballo {
  final String id;
  final String nombre;
  final DateTime? fechaNacimiento;
  final String estado;
  final String? ubicacionId;
  final String? color;
  final String? nota;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Caballo({
    required this.id,
    required this.nombre,
    this.fechaNacimiento,
    required this.estado,
    this.ubicacionId,
    this.color,
    this.nota,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  String get edad => edadTexto(fechaNacimiento);

  factory Caballo.fromMap(Map<String, dynamic> map) => Caballo(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        fechaNacimiento: map['fecha_nacimiento'] != null
            ? DateTime.tryParse(map['fecha_nacimiento'] as String)
            : null,
        estado: map['estado'] as String,
        ubicacionId: map['ubicacion_id'] as String?,
        color: map['color'] as String?,
        nota: map['nota'] as String?,
        createdBy: map['created_by'] as String?,
        updatedBy: map['updated_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
        'estado': estado,
        'ubicacion_id': ubicacionId,
        'color': color,
        'nota': nota,
        'created_by': createdBy,
        'updated_by': updatedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Caballo copyWith({
    String? nombre,
    Object? fechaNacimiento = sinCambio,
    String? estado,
    String? ubicacionId,
    bool clearUbicacion = false,
    Object? color = sinCambio,
    Object? nota = sinCambio,
  }) =>
      Caballo(
        id: id,
        nombre: nombre ?? this.nombre,
        fechaNacimiento:
            valorOAnterior<DateTime>(fechaNacimiento, this.fechaNacimiento),
        estado: estado ?? this.estado,
        ubicacionId: clearUbicacion ? null : (ubicacionId ?? this.ubicacionId),
        color: valorOAnterior<String>(color, this.color),
        nota: valorOAnterior<String>(nota, this.nota),
        createdBy: createdBy,
        updatedBy: updatedBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
