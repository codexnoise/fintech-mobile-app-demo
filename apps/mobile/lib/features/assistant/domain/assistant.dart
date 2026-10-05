import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

/// Preguntas predefinidas: sin texto libre (decisión de seguridad, ADR 0012).
enum AssistantPrompt {
  monthlySummary('monthly_summary', 'Resumen del mes'),
  spendingBreakdown('spending_breakdown', 'Gastos por categoría'),
  savingsTips('savings_tips', 'Cómo ahorrar más');

  const AssistantPrompt(this.wire, this.label);

  final String wire;
  final String label;

  static AssistantPrompt? fromWire(String? value) =>
      values.where((p) => p.wire == value).firstOrNull;
}

/// Respuesta de solo lectura dibujada con el mismo renderer SDUI del home.
final class AssistantAnswer {
  const AssistantAnswer({
    required this.document,
    required this.generatedByModel,
  });

  final SduiDocument document;

  /// `true` si la generó el modelo (cifras verificadas por el backend);
  /// `false` si es el resumen determinista (sin key de IA o modelo caído).
  final bool generatedByModel;
}

abstract interface class AssistantRepository {
  Future<Result<AssistantAnswer>> ask(AssistantPrompt prompt);
}
