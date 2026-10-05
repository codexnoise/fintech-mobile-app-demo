import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'sdui_models.dart';
import 'sdui_render.dart';

// --- Lectura de props: tipos estrictos, error explícito -------------------

String _required(SduiComponent c, String key) {
  final value = c.props[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('${c.type}/${c.id}: "$key" es obligatorio');
}

String? _optional(SduiComponent c, String key) {
  final value = c.props[key];
  return value is String && value.trim().isNotEmpty ? value : null;
}

List<Map<String, Object?>> _objects(SduiComponent c, String key) {
  final value = c.props[key];
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map<String, Object?>) item,
  ];
}

/// Íconos permitidos por nombre (el servidor no puede pedir assets arbitrarios).
const _icons = <String, IconData>{
  'swap_horiz': Icons.swap_horiz_rounded,
  'flight': Icons.flight_rounded,
  'auto_awesome': Icons.auto_awesome_rounded,
  'insights': Icons.insights_rounded,
  'savings': Icons.savings_outlined,
  'receipt': Icons.receipt_long_outlined,
  'shield': Icons.shield_outlined,
};

IconData _icon(String? name) => _icons[name] ?? Icons.circle_outlined;

TextTheme _text(BuildContext context) => Theme.of(context).textTheme;

// --- Componentes ---------------------------------------------------------

Widget buildGreetingHeader(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext _,
) {
  final text = _text(context);
  final subtitle = _optional(c, 'subtitle');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          _required(c, 'title'),
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      if (subtitle != null)
        Text(
          subtitle,
          style: text.bodyMedium?.copyWith(color: NexoColors.onSurfaceMuted),
        ),
    ],
  );
}

/// Los saldos los dibuja la app (slot): nunca vienen en el JSON.
Widget buildBalanceSummary(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext render,
) {
  final slot = render.slots['balance_summary'];
  return slot == null ? const SizedBox.shrink() : slot(context, c);
}

Widget buildQuickActions(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext render,
) {
  final items = [
    for (final raw in _objects(c, 'actions'))
      if (raw['label'] case final String label)
        if (render.actionFor(raw['action']) case final onTap?)
          (label: label, icon: _icon(raw['icon'] as String?), onTap: onTap),
  ];
  if (items.isEmpty) return const SizedBox.shrink();
  return Wrap(
    alignment: WrapAlignment.spaceAround,
    spacing: NexoSpacing.sm,
    runSpacing: NexoSpacing.sm,
    children: [
      for (final item in items)
        SizedBox(
          width: 88,
          child: Semantics(
            button: true,
            label: item.label,
            excludeSemantics: true,
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(NexoRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: NexoSpacing.xs),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: NexoColors.brandContainer,
                      foregroundColor: NexoColors.brand,
                      child: Icon(item.icon),
                    ),
                    const SizedBox(height: NexoSpacing.xs),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _text(context).labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

Widget buildPromoBanner(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext render,
) {
  final text = _text(context);
  final onTap = render.actionFor(c.props['action']);
  final cta = _optional(c, 'cta');
  final (background, foreground) = switch (_optional(c, 'tone')) {
    'premium' => (NexoColors.onSurface, NexoColors.surface),
    'neutral' => (NexoColors.surface, NexoColors.onSurface),
    _ => (NexoColors.brandContainer, NexoColors.onSurface),
  };
  return Card(
    color: background,
    child: Padding(
      padding: const EdgeInsets.all(NexoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _required(c, 'title'),
            style: text.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_optional(c, 'body') case final body?) ...[
            const SizedBox(height: NexoSpacing.xs),
            Text(body, style: text.bodyMedium?.copyWith(color: foreground)),
          ],
          if (cta != null && onTap != null) ...[
            const SizedBox(height: NexoSpacing.md),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size(kMinTapTarget * 2, kMinTapTarget),
              ),
              child: Text(cta),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget buildInsightCard(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext _,
) {
  final text = _text(context);
  final title = _optional(c, 'title');
  final verified = c.props['verified'] == true;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(NexoSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: CircleAvatar(
              backgroundColor: NexoColors.brandContainer,
              foregroundColor: NexoColors.brand,
              child: Icon(Icons.insights_rounded),
            ),
          ),
          const SizedBox(width: NexoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(_required(c, 'text'), style: text.bodyMedium),
                if (verified) ...[
                  const SizedBox(height: NexoSpacing.xs),
                  Text(
                    'Cifras verificadas con tus movimientos',
                    style: text.labelSmall?.copyWith(
                      color: NexoColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildMicroAppTile(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext render,
) {
  final onTap = render.actionFor(c.props['action']);
  return Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minTileHeight: kMinTapTarget + 24,
      onTap: onTap,
      leading: const ExcludeSemantics(
        child: CircleAvatar(
          backgroundColor: NexoColors.brandContainer,
          foregroundColor: NexoColors.brand,
          child: Icon(Icons.apps_rounded),
        ),
      ),
      title: Text(_required(c, 'title')),
      subtitle: switch (_optional(c, 'body')) {
        final body? => Text(body),
        null => null,
      },
      trailing: onTap == null
          ? null
          : const ExcludeSemantics(child: Icon(Icons.chevron_right)),
    ),
  );
}

Widget buildTipList(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext _,
) {
  final text = _text(context);
  final items = [
    for (final item in c.props['items'] as List? ?? const [])
      if (item is String && item.isNotEmpty) item,
  ];
  if (items.isEmpty) throw FormatException('tip_list/${c.id}: sin items');
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(NexoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_optional(c, 'title') case final title?)
            Text(title, style: text.titleMedium),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: NexoSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: NexoColors.brand,
                    ),
                  ),
                  const SizedBox(width: NexoSpacing.xs),
                  Expanded(child: Text(item, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Widget buildSpendingBars(
  BuildContext context,
  SduiComponent c,
  SduiRenderContext _,
) {
  final text = _text(context);
  final bars = [
    for (final raw in _objects(c, 'bars'))
      if ((raw['label'], raw['amountCents']) case (
        final String label,
        final int cents,
      ))
        (label: label, amount: Money(cents)),
  ];
  if (bars.isEmpty) throw FormatException('spending_bars/${c.id}: sin barras');
  final maxCents = bars.map((b) => b.amount.cents).reduce(max);
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(NexoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_optional(c, 'title') case final title?)
            Text(title, style: text.titleMedium),
          for (final bar in bars)
            Semantics(
              label: '${bar.label}, ${moneySemanticsLabel(bar.amount)}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(top: NexoSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(bar.label)),
                        MoneyText(bar.amount),
                      ],
                    ),
                    const SizedBox(height: NexoSpacing.xxs),
                    LinearProgressIndicator(
                      value: maxCents == 0 ? 0 : bar.amount.cents / maxCents,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(NexoRadius.sm),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
