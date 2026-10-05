import 'package:flutter/material.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

/// Pantalla provisional para rutas cuya feature aún no existe.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.location,
    this.onSignOut,
    super.key,
  });

  final String title;
  final Uri location;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onSignOut != null)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: onSignOut,
            ),
        ],
      ),
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
