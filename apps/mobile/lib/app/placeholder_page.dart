import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'router.dart';

/// Pantalla provisional para rutas cuya feature aún no existe.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.location,
    super.key,
  });

  final String title;
  final Uri location;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NexoSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: text.headlineSmall),
              const SizedBox(height: NexoSpacing.xs),
              Text(
                location.toString(),
                style: text.bodyMedium?.copyWith(
                  color: NexoColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Splash provisional. En dev lista las rutas para navegar sin sesión
/// mientras no existan los flujos reales (se reemplaza en F2).
class SplashPlaceholder extends StatelessWidget {
  const SplashPlaceholder({required this.showRouteIndex, super.key});

  final bool showRouteIndex;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(NexoSpacing.lg),
          children: [
            Text(
              'Nexo',
              style: text.displaySmall?.copyWith(color: NexoColors.brand),
            ),
            const SizedBox(height: NexoSpacing.lg),
            if (showRouteIndex)
              for (final (label, route) in devRouteIndex)
                ListTile(
                  title: Text(label),
                  subtitle: Text(route),
                  trailing: const Icon(Icons.chevron_right),
                  minTileHeight: kMinTapTarget,
                  onTap: () => context.push(route),
                ),
          ],
        ),
      ),
    );
  }
}
