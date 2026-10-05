import 'package:flutter/material.dart';
import 'package:nexo_design_system/nexo_design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/push.dart';
import 'push_coordinator.dart';

/// Pide el permiso de notificaciones en contexto, explicando el valor, en vez
/// de hacerlo al abrir la app. Se muestra una sola vez si el usuario lo
/// descarta.
class NotificationOptInCard extends StatefulWidget {
  const NotificationOptInCard({
    required this.coordinator,
    this.prefs,
    super.key,
  });

  final PushCoordinator coordinator;
  final SharedPreferencesAsync? prefs;

  static const dismissedKey = 'push.optin.dismissed';

  @override
  State<NotificationOptInCard> createState() => _NotificationOptInCardState();
}

class _NotificationOptInCardState extends State<NotificationOptInCard> {
  late final SharedPreferencesAsync _prefs =
      widget.prefs ?? SharedPreferencesAsync();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final dismissed =
        await _prefs.getBool(NotificationOptInCard.dismissedKey) ?? false;
    final permission = await widget.coordinator.permission();
    if (mounted) {
      setState(
        () =>
            _visible = !dismissed && permission == PushPermission.notDetermined,
      );
    }
  }

  Future<void> _enable() async {
    await widget.coordinator.requestPermission();
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _dismiss() async {
    await _prefs.setBool(NotificationOptInCard.dismissedKey, true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.md),
      child: Card(
        color: NexoColors.brandContainer,
        child: Padding(
          padding: const EdgeInsets.all(NexoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: NexoColors.brand,
                    ),
                  ),
                  const SizedBox(width: NexoSpacing.xs),
                  Expanded(
                    child: Text(
                      'Entérate al instante de tus movimientos',
                      style: text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NexoSpacing.xs),
              Text(
                'Te avisamos cuando una transferencia se completa. Nunca te '
                'pediremos claves por notificación.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: NexoSpacing.sm),
              Wrap(
                spacing: NexoSpacing.xs,
                children: [
                  FilledButton(
                    onPressed: _enable,
                    child: const Text('Activar notificaciones'),
                  ),
                  TextButton(
                    onPressed: _dismiss,
                    child: const Text('Ahora no'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
