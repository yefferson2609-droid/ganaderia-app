class Lote {
  final String id;
  final String tipo;
  final String nombre;
  final int hembras;
  final int machos;
  final String? ubicacionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lote({
    required this.id,
    required this.tipo,
    required this.nombre,
    required this.hembras,
    required this.machos,
    this.ubicacionId,
    required this.createdAt,
    required this.updatedAt,
  });

  int get total => hembras + machos;

  factory Lote.fromMap(Map<String, dynamic> map) => Lote(
        id: map['id'] as String,
        tipo: map['tipo'] as String,
        nombre: map['nombre'] as String,
        hembras: map['hembras'] as int,
        machos: map['machos'] as int,
        ubicacionId: map['ubicacion_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo,
        'nombre': nombre,
        'hembras': hembras,
        'machos': machos,
        'ubicacion_id': ubicacionId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Lote copyWith({
    String? nombre,
    int? hembras,
    int? machos,
    String? ubicacionId,
    bool clearUbicacion = false,
  }) =>
      Lote(
        id: id,
        tipo: tipo,
        nombre: nombre ?? this.nombre,
        hembras: hembras ?? this.hembras,
        machos: machos ?? this.machos,
        ubicacionId:
            clearUbicacion ? null : (ubicacionId ?? this.ubicacionId),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
