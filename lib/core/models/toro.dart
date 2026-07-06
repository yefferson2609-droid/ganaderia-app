class Toro {
  final String id;
  final String numero;
  final String nombre;
  final String estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Toro({
    required this.id,
    required this.numero,
    required this.nombre,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Toro.fromMap(Map<String, dynamic> map) => Toro(
        id: map['id'] as String,
        numero: map['numero'] as String,
        nombre: map['nombre'] as String,
        estado: map['estado'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'nombre': nombre,
        'estado': estado,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Toro copyWith({String? numero, String? nombre, String? estado}) => Toro(
        id: id,
        numero: numero ?? this.numero,
        nombre: nombre ?? this.nombre,
        estado: estado ?? this.estado,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  String get displayName => '#$numero - $nombre';
}
