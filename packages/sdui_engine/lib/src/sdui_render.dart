import 'package:flutter/widgets.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'components.dart';
import 'sdui_models.dart';
import 'sdui_parser.dart';

/// Construye el widget de un componente. Puede lanzar si las props no
/// cumplen el contrato: [SduiView] lo omite y lo reporta.
typedef SduiWidgetBuilder = Widget Function(
  BuildContext context,
  SduiComponent component,
  SduiRenderContext render,
);

/// Contenido que provee la app (ej. saldos reales, que nunca viajan en el
/// documento SDUI).
typedef SduiSlotBuilder = Widget Function(
  BuildContext context,
  SduiComponent component,
);

/// Dependencias del render: acciones (pasan por el allowlist del parser),
/// slots de la app y reporte de errores.
final class SduiRenderContext {
  const SduiRenderContext({
    required this.parser,
    required this.onAction,
    this.slots = const {},
    this.onComponentError,
  });

  final SduiParser parser;
  final ValueChanged<SduiAction> onAction;
  final Map<String, SduiSlotBuilder> slots;
  final void Function(SduiComponent, Object, StackTrace)? onComponentError;

  /// `null` si la acción no está permitida: el widget se dibuja sin acción.
  VoidCallback? actionFor(Object? raw) {
    final action = parser.parseAction(raw);
    return action == null ? null : () => onAction(action);
  }
}

/// Catálogo cerrado de componentes. Agregar un tipo = un builder aquí + el
/// tipo en el contrato del backend.
final class SduiRegistry {
  const SduiRegistry(this.builders);

  factory SduiRegistry.standard() => const SduiRegistry(standardBuilders);

  static const standardBuilders = <String, SduiWidgetBuilder>{
    'greeting_header': buildGreetingHeader,
    'balance_summary': buildBalanceSummary,
    'quick_actions': buildQuickActions,
    'promo_banner': buildPromoBanner,
    'insight_card': buildInsightCard,
    'micro_app_tile': buildMicroAppTile,
    'tip_list': buildTipList,
    'spending_bars': buildSpendingBars,
  };

  static Set<String> get standardTypes => standardBuilders.keys.toSet();

  final Map<String, SduiWidgetBuilder> builders;

  Set<String> get types => builders.keys.toSet();
}

/// Dibuja un documento SDUI. Un componente que falla se reemplaza por nada
/// y se reporta: nunca rompe la pantalla.
class SduiView extends StatelessWidget {
  const SduiView({
    required this.document,
    required this.registry,
    required this.context,
    super.key,
  });

  final SduiDocument document;
  final SduiRegistry registry;
  final SduiRenderContext context;

  @override
  Widget build(BuildContext buildContext) {
    final children = <Widget>[];
    for (final component in document.components) {
      final builder = registry.builders[component.type];
      if (builder == null) continue;
      try {
        children.add(
          KeyedSubtree(
            key: ValueKey(component.id),
            child: builder(buildContext, component, context),
          ),
        );
      } on Object catch (error, stack) {
        context.onComponentError?.call(component, error, stack);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: NexoSpacing.md),
          child,
        ],
      ],
    );
  }
}
