import 'package:intl/intl.dart';
import '../config/ajustes.dart';
import '../models/ternero.dart';
import '../repositories/reproduccion_repository.dart';
import '../repositories/ternero_repository.dart';
import '../repositories/vaca_repository.dart';

final _fmt = DateFormat('dd/MM/yyyy');

class Alerta {
  final String ruta; // ficha a la que lleva
  final String titulo; // 'Vaca #12'
  final String detalle;
  final int orden; // menor = más urgente
  const Alerta(this.ruta, this.titulo, this.detalle, this.orden);
}

enum TipoAlerta { partos, secar, vacias, vitamina, destete, categoria }

const kTipoAlertaInfo = {
  TipoAlerta.partos: (
    'Partos próximos',
    'Vacas que paren en los próximos $kDiasAvisoParto días'
  ),
  TipoAlerta.secar: (
    'Secar antes del parto',
    'Vacas en ordeño a las que ya toca secar (o en menos de 7 días)'
  ),
  TipoAlerta.vacias: (
    'Vacías mucho tiempo',
    'Más de $kDiasVaciaPostParto días desde el parto y siguen vacías'
  ),
  TipoAlerta.vitamina: (
    'Vitamina vencida',
    'Más de $kDiasVitamina días sin vitamina, o sin registro'
  ),
  TipoAlerta.destete: (
    'Por destetar',
    'Terneros con $kMesesDestete meses o más que siguen sin destetar'
  ),
  TipoAlerta.categoria: (
    'Cambio de categoría',
    'Animales de levante que ya cumplen para la siguiente categoría '
        '(p. ej. novillas de $kMesesNovillaVientre meses → vientre)'
  ),
};

class AlertasService {
  Future<Map<TipoAlerta, List<Alerta>>> generar() async {
    final repo = ReproduccionRepository();
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    final res = {for (final t in TipoAlerta.values) t: <Alerta>[]};

    for (final v in await VacaRepository().getAll(soloActivas: true)) {
      final r = await repo.resumen(v.id);
      final titulo = 'Vaca #${v.numero}';
      final prenada = v.estadoReproductivo == 'prenada';

      if (prenada && v.fechaEstimadaParto != null) {
        final faltan = v.fechaEstimadaParto!.difference(dia).inDays;
        if (faltan <= kDiasAvisoParto) {
          res[TipoAlerta.partos]!.add(Alerta(
            '/vacas/${v.id}',
            titulo,
            'Parto ${_fmt.format(v.fechaEstimadaParto!)} · '
            '${faltan >= 0 ? 'en $faltan días' : 'atrasado ${-faltan} días'}',
            faltan,
          ));
        }
        if (r.estado == EstadoProduccion.enOrdeno) {
          final s = await repo.sugerenciaSecado(v);
          if (s != null) {
            final enDias = s.fecha.difference(dia).inDays;
            if (enDias <= 7) {
              res[TipoAlerta.secar]!.add(Alerta(
                '/vacas/${v.id}',
                titulo,
                '${enDias <= 0 ? 'Secar ya' : 'Secar en $enDias días'} '
                '(${_fmt.format(s.fecha)}) · parto ${_fmt.format(v.fechaEstimadaParto!)}',
                enDias,
              ));
            }
          }
        }
      }

      if (!prenada && r.ultimoParto != null) {
        final dias = dia.difference(r.ultimoParto!).inDays;
        if (dias >= kDiasVaciaPostParto) {
          res[TipoAlerta.vacias]!.add(Alerta(
              '/vacas/${v.id}', titulo, '$dias días desde el parto (${_fmt.format(r.ultimoParto!)})', -dias));
        }
      }

      if (r.ultimaVitamina == null) {
        res[TipoAlerta.vitamina]!
            .add(Alerta('/vacas/${v.id}', titulo, 'Sin vitamina registrada', -100000));
      } else {
        final dias = dia.difference(r.ultimaVitamina!).inDays;
        if (dias > kDiasVitamina) {
          res[TipoAlerta.vitamina]!.add(Alerta('/vacas/${v.id}', titulo,
              'Última hace $dias días (${_fmt.format(r.ultimaVitamina!)})', -dias));
        }
      }
    }
    for (final t in await TerneroRepository().getAll(soloActivos: true)) {
      final ruta = '/terneros/${t.id}';
      final titulo = '${t.categoriaLabel} #${t.numero}';
      if (t.debeDestetarse) {
        res[TipoAlerta.destete]!
            .add(Alerta(ruta, titulo, '${t.meses} meses sin destetar', -(t.meses ?? 0)));
      }
      final cambio = t.cambioSugerido;
      if (cambio != null && !t.debeDestetarse) {
        res[TipoAlerta.categoria]!.add(Alerta(ruta, titulo,
            'Pasar a ${kCategoriaLabels[cambio]} · ${t.edad}', -(t.meses ?? 0)));
      }
    }

    for (final l in res.values) {
      l.sort((a, b) => a.orden.compareTo(b.orden));
    }
    return res;
  }
}
