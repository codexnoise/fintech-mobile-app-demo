import 'package:flutter/material.dart';

import '../tokens.dart';

/// "Actualizado hace 5 min" para datos que pueden estar desactualizados.
String relativeUpdatedLabel(DateTime updatedAt, DateTime now) {
  final diff = now.difference(updatedAt);
  if (diff.inMinutes < 1) return 'Actualizado hace un momento';
  if (diff.inHours < 1) return 'Actualizado hace ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'Actualizado hace ${diff.inHours} h';
  final days = diff.inDays;
  return 'Actualizado hace $days ${days == 1 ? 'día' : 'días'}';
}

enum _BannerKind { offline, error, maintenance }

/// Aviso de estado de pantalla (Stitch: "Estados offline, stale y error").
class StatusBanner extends StatelessWidget {
  const StatusBanner.offline(this.message, {this.action, super.key})
    : _kind = _BannerKind.offline;

  const StatusBanner.error(this.message, {this.action, super.key})
    : _kind = _BannerKind.error;

  const StatusBanner.maintenance(this.message, {this.action, super.key})
    : _kind = _BannerKind.maintenance;

  final String message;
  final Widget? action;
  final _BannerKind _kind;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (_kind) {
      _BannerKind.offline => (
        NexoColors.warningContainer,
        NexoColors.warning,
        Icons.wifi_off_rounded,
      ),
      _BannerKind.error => (
        NexoColors.errorContainer,
        NexoColors.error,
        Icons.error_outline_rounded,
      ),
      _BannerKind.maintenance => (
        NexoColors.warningContainer,
        NexoColors.warning,
        Icons.construction_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(NexoRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NexoSpacing.sm),
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(icon, color: foreground)),
              const SizedBox(width: NexoSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: foreground),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder de carga. Estático (sin animación) para no consumir batería
/// ni bloquear `pumpAndSettle` en tests.
class Skeleton extends StatelessWidget {
  const Skeleton({this.height = 16, this.width, this.radius, super.key});

  final double height;
  final double? width;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: NexoColors.border,
          borderRadius: BorderRadius.circular(radius ?? NexoRadius.sm / 2),
        ),
      ),
    );
  }
}
