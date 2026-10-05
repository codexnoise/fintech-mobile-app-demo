import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

import '../domain/experience.dart';
import 'home_cubit.dart';

/// Home compuesta por el servidor (SDUI) según el segmento del usuario.
class HomePage extends StatelessWidget {
  const HomePage({
    required this.registry,
    required this.parser,
    required this.onAction,
    this.slots = const {},
    this.errorReporter,
    this.actions,
    super.key,
  });

  final SduiRegistry registry;
  final SduiParser parser;
  final void Function(BuildContext context, SduiAction action) onAction;
  final Map<String, SduiSlotBuilder> slots;
  final ErrorReporter? errorReporter;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio'), actions: actions),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => cubit.refresh(force: true),
          child: ListView(
            padding: const EdgeInsets.all(NexoSpacing.md),
            children: switch (state) {
              HomeLoading() => const [
                Skeleton(height: 28, width: 220),
                SizedBox(height: NexoSpacing.md),
                Skeleton(height: 140),
                SizedBox(height: NexoSpacing.md),
                Skeleton(height: 72),
              ],
              HomeError(:final failure) => [
                StatusBanner.error(
                  'No pudimos cargar tu inicio. ${failure.userMessage}',
                ),
                const SizedBox(height: NexoSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => cubit.refresh(force: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
              HomeLoaded(:final experience) => [
                if (_sourceNotice(experience) case final notice?) ...[
                  notice,
                  const SizedBox(height: NexoSpacing.md),
                ],
                SduiView(
                  document: experience.document,
                  registry: registry,
                  context: SduiRenderContext(
                    parser: parser,
                    slots: slots,
                    onAction: (action) => onAction(context, action),
                    onComponentError: (component, error, stack) =>
                        errorReporter?.report(
                          error,
                          stack,
                          reason: 'sdui ${component.type}/${component.id}',
                        ),
                  ),
                ),
              ],
            },
          ),
        ),
      ),
    );
  }

  /// Indicador sutil de que no es la versión más reciente.
  static Widget? _sourceNotice(Experience e) =>
      switch ((e.source, e.remoteFailure)) {
        (ExperienceSource.remote, _) => null,
        (_, ServiceUnavailableFailure()) => const StatusBanner.maintenance(
          'Estamos actualizando tu inicio. Mostrando la última versión '
          'disponible.',
        ),
        (ExperienceSource.cache, _) => const StatusBanner.offline(
          'Sin conexión. Mostrando tu inicio guardado.',
        ),
        (ExperienceSource.bundled, _) => const StatusBanner.offline(
          'Mostrando una versión básica de tu inicio. Desliza hacia abajo para '
          'reintentar.',
        ),
      };
}
