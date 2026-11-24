part of 'catalog_bloc.dart';

/// Resultado de la última acción. [id] crece con cada resultado para que un
/// `BlocListener` reaccione una sola vez.
final class CatalogOutcome {
  /// Crea el resultado numerado.
  const CatalogOutcome(this.id, this.result);

  /// Número creciente del resultado.
  final int id;

  /// Resultado tipado con su mensaje en español.
  final CatalogResult result;

  /// `true` si la acción terminó bien.
  bool get ok => result.ok;
}

/// Estado inmutable del catálogo.
///
/// Sedes y platos son entidades mutables que el repositorio actualiza en
/// sitio; [revision] sube con cada cambio para que la UI se vuelva a pintar.
/// Las pantallas leen el catálogo con los atajos de [CatalogBloc].
final class CatalogState {
  /// Crea el estado.
  const CatalogState({this.revision = 0, this.offline = false, this.outcome});

  /// Contador de cambios.
  final int revision;

  /// `true` si se muestra la copia guardada por falta de red.
  final bool offline;

  /// Resultado de la última acción, si hubo.
  final CatalogOutcome? outcome;

  /// Copia el estado cambiando solo lo indicado.
  CatalogState copyWith({
    int? revision,
    bool? offline,
    CatalogOutcome? outcome,
  }) => CatalogState(
    revision: revision ?? this.revision,
    offline: offline ?? this.offline,
    outcome: outcome ?? this.outcome,
  );
}
