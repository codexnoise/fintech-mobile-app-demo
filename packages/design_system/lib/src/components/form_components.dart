import 'package:flutter/material.dart';

import '../tokens.dart';

/// Mensaje de error accesible (se anuncia a lectores de pantalla).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: NexoSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: NexoColors.error),
            const SizedBox(width: NexoSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: NexoColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón primario que muestra progreso y se deshabilita mientras carga.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
