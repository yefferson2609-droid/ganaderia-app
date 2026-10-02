import 'package:supabase_flutter/supabase_flutter.dart';

/// Id del usuario con sesión iniciada (o null si no hay sesión).
String? usuarioActualId() => Supabase.instance.client.auth.currentUser?.id;

/// Marca una fila nueva como pendiente de subir y registra quién la creó.
Map<String, dynamic> filaNueva(Map<String, dynamic> map,
    {bool conAuditoria = true}) {
  map['synced'] = 0;
  map['deleted'] = 0;
  if (conAuditoria) {
    final uid = usuarioActualId();
    map['created_by'] ??= uid;
    map['updated_by'] = uid;
  }
  return map;
}

/// Marca una fila editada como pendiente de subir y registra quién la cambió.
Map<String, dynamic> filaEditada(Map<String, dynamic> map,
    {bool conAuditoria = true}) {
  map['synced'] = 0;
  map['deleted'] = 0;
  if (conAuditoria) map['updated_by'] = usuarioActualId();
  return map;
}

/// Valor centinela para `copyWith`: distingue "no cambiar" de "poner null".
const sinCambio = Object();

T? valorOAnterior<T>(Object? nuevo, T? anterior) =>
    identical(nuevo, sinCambio) ? anterior : nuevo as T?;

/// Convierte el texto de un campo opcional en null si está vacío.
String? textoONull(String texto) {
  final t = texto.trim();
  return t.isEmpty ? null : t;
}
