import '../repositories/caballo_repository.dart';
import '../repositories/ternero_repository.dart';
import '../repositories/toro_repository.dart';
import '../repositories/vaca_repository.dart';

/// Nombre legible de un animal según su tipo e id.
Future<String> nombreAnimal(String tipo, String id) async {
  switch (tipo) {
    case 'vaca':
      final v = await VacaRepository().getById(id);
      return v != null ? 'Vaca #${v.numero}' : 'Vaca (eliminada)';
    case 'toro':
      final t = await ToroRepository().getById(id);
      return t != null ? 'Toro ${t.displayName}' : 'Toro (eliminado)';
    case 'ternero':
      final t = await TerneroRepository().getById(id);
      return t != null ? 'Ternero #${t.numero}' : 'Ternero (eliminado)';
    case 'caballo':
      final c = await CaballoRepository().getById(id);
      return c != null ? 'Caballo ${c.nombre}' : 'Caballo (eliminado)';
  }
  return 'Animal';
}

/// Ruta de la ficha del animal.
String rutaAnimal(String tipo, String id) {
  switch (tipo) {
    case 'vaca':
      return '/vacas/$id';
    case 'toro':
      return '/toros/$id';
    case 'ternero':
      return '/terneros/$id';
    case 'caballo':
      return '/caballos/$id';
  }
  return '/dashboard';
}
