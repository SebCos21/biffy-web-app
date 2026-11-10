import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/state/catalog_controller.dart';
import 'ui.dart';

/// Aviso de catálogo sin conexión: franja si hay copia guardada y pantalla de
/// error con reintento si no hay nada que mostrar. Con red no ocupa espacio.
class OfflineBanner extends StatelessWidget {
  /// Crea el aviso; lee el estado del [CatalogController] del árbol.
  const OfflineBanner({super.key});

  /// Dibuja el aviso según el estado de conexión del catálogo.
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    if (!catalog.offline) return const SizedBox.shrink();

    if (!catalog.hasCatalog) {
      return ErrorView(
        key: const Key('offline-empty'),
        title: 'Sin conexión',
        body:
            'No hay una copia guardada del menú en este equipo. '
            'Conéctate a internet e inténtalo de nuevo.',
        onRetry: catalog.refresh,
      );
    }

    return Container(
      key: const Key('offline-banner'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Sin conexión · mostrando el menú guardado. '
              'Puede estar desactualizado.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: catalog.refresh,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
