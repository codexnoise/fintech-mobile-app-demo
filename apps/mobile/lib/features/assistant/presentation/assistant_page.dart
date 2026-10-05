import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

import '../domain/assistant.dart';
import 'assistant_cubit.dart';

/// Asistente de solo lectura: preguntas predefinidas y respuesta dibujada
/// con el mismo renderer SDUI del home (el LLM no emite UI ni acciones).
class AssistantPage extends StatelessWidget {
  const AssistantPage({
    required this.registry,
    required this.parser,
    this.errorReporter,
    super.key,
  });

  final SduiRegistry registry;
  final SduiParser parser;
  final ErrorReporter? errorReporter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: BlocBuilder<AssistantCubit, AssistantState>(
        builder: (context, state) {
          final cubit = context.read<AssistantCubit>();
          final selected = switch (state) {
            AssistantIdle() => null,
            AssistantLoading(:final prompt) ||
            AssistantAnswered(:final prompt) ||
            AssistantUnavailable(:final prompt) ||
            AssistantError(:final prompt) => prompt,
          };
          return ListView(
            padding: const EdgeInsets.all(NexoSpacing.md),
            children: [
              Text(
                'Elige una pregunta. Respondemos con tus movimientos reales; '
                'no es asesoría financiera.',
                style: text.bodyMedium?.copyWith(
                  color: NexoColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: NexoSpacing.sm),
              Wrap(
                spacing: NexoSpacing.xs,
                runSpacing: NexoSpacing.xs,
                children: [
                  for (final prompt in AssistantPrompt.values)
                    ChoiceChip(
                      label: Text(prompt.label),
                      selected: prompt == selected,
                      onSelected: state is AssistantLoading
                          ? null
                          : (_) => cubit.ask(prompt),
                    ),
                ],
              ),
              const SizedBox(height: NexoSpacing.lg),
              ...switch (state) {
                AssistantIdle() => const <Widget>[],
                AssistantLoading() => const [
                  Skeleton(height: 28, width: 240),
                  SizedBox(height: NexoSpacing.md),
                  Skeleton(height: 96),
                  SizedBox(height: NexoSpacing.md),
                  Skeleton(height: 96),
                ],
                AssistantUnavailable() => const [
                  StatusBanner.maintenance(
                    'El asistente no está disponible por ahora. Intenta en '
                    'unos minutos.',
                  ),
                ],
                AssistantError(:final failure) => [
                  StatusBanner.error(failure.userMessage),
                  const SizedBox(height: NexoSpacing.md),
                  OutlinedButton.icon(
                    onPressed: cubit.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
                AssistantAnswered(:final answer) => [
                  _SourceBadge(generatedByModel: answer.generatedByModel),
                  const SizedBox(height: NexoSpacing.md),
                  SduiView(
                    document: answer.document,
                    registry: registry,
                    context: SduiRenderContext(
                      parser: parser,
                      // Solo lectura: el asistente no dispara acciones.
                      onAction: (_) {},
                      onComponentError: (component, error, stack) =>
                          errorReporter?.report(
                            error,
                            stack,
                            reason:
                                'assistant ${component.type}/${component.id}',
                          ),
                    ),
                  ),
                ],
              },
            ],
          );
        },
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.generatedByModel});

  final bool generatedByModel;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = generatedByModel
        ? (Icons.auto_awesome, 'Generado con IA · cifras verificadas')
        : (Icons.calculate_outlined, 'Resumen automático con tus movimientos');
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(icon, size: 18, color: NexoColors.brand),
        label: Text(label),
        backgroundColor: NexoColors.brandContainer,
        side: BorderSide.none,
      ),
    );
  }
}
