import 'package:flutter/material.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

/// Herramienta de demo (solo builds dev): simula fallas de red contra el BFF
/// para mostrar los estados offline, latencia y caída parcial.
class NetworkLabPage extends StatefulWidget {
  const NetworkLabPage({required this.chaos, required this.breaker, super.key});

  final ChaosSettings chaos;
  final CircuitBreaker breaker;

  @override
  State<NetworkLabPage> createState() => _NetworkLabPageState();
}

class _NetworkLabPageState extends State<NetworkLabPage> {
  static const _latency = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chaos = widget.chaos;
    return Scaffold(
      appBar: AppBar(title: const Text('Network Lab')),
      body: ListenableBuilder(
        listenable: chaos,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(NexoSpacing.md),
          children: [
            const StatusBanner.maintenance(
              'Solo en builds de desarrollo. Afecta las llamadas al BFF; '
              'para Firestore usa el modo avión del dispositivo.',
            ),
            const SizedBox(height: NexoSpacing.md),
            SwitchListTile(
              title: const Text('Sin conexión'),
              subtitle: const Text('Toda llamada al BFF falla por red.'),
              value: chaos.offline,
              onChanged: (v) => chaos.offline = v,
            ),
            SwitchListTile(
              title: const Text('Latencia +3 s'),
              subtitle: const Text('Cada llamada espera 3 s antes de salir.'),
              value: chaos.extraLatency == _latency,
              onChanged: (v) =>
                  chaos.extraLatency = v ? _latency : Duration.zero,
            ),
            SwitchListTile(
              title: const Text('Forzar 503'),
              subtitle: const Text(
                'El BFF responde "en mantenimiento" (Retry-After 60 s).',
              ),
              value: chaos.force503,
              onChanged: (v) => chaos.force503 = v,
            ),
            const Divider(height: NexoSpacing.xl),
            Text('Circuit breaker por servicio', style: text.titleMedium),
            const SizedBox(height: NexoSpacing.xs),
            Text(
              'Se abre tras 3 fallas seguidas y falla rápido 30 s; luego '
              'deja pasar una prueba.',
              style: text.bodySmall?.copyWith(color: NexoColors.onSurfaceMuted),
            ),
            for (final MapEntry(:key, :value)
                in widget.breaker.snapshot.entries)
              ListTile(
                title: Text(key),
                trailing: Text(switch (value) {
                  CircuitState.closed => 'Cerrado',
                  CircuitState.open => 'Abierto',
                  CircuitState.halfOpen => 'Probando',
                }),
              ),
            if (widget.breaker.snapshot.isEmpty)
              const ListTile(title: Text('Todos los servicios sanos')),
            const SizedBox(height: NexoSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                chaos
                  ..offline = false
                  ..force503 = false
                  ..extraLatency = Duration.zero;
                widget.breaker.reset();
                setState(() {});
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restablecer todo'),
            ),
          ],
        ),
      ),
    );
  }
}
