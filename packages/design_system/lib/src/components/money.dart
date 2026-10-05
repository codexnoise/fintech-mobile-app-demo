import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo_core/nexo_core.dart';

import '../tokens.dart';

/// Lectura natural para lectores de pantalla: "8740 dólares con 25 centavos".
String moneySemanticsLabel(Money money, {bool signed = false}) {
  final abs = money.cents.abs();
  final dollars = abs ~/ 100;
  final cents = abs % 100;
  final buffer = StringBuffer();
  if (money.isNegative) {
    buffer.write('menos ');
  } else if (signed && money.isPositive) {
    buffer.write('más ');
  }
  buffer.write('$dollars ${dollars == 1 ? 'dólar' : 'dólares'}');
  if (cents > 0) {
    buffer.write(' con $cents ${cents == 1 ? 'centavo' : 'centavos'}');
  }
  return buffer.toString();
}

/// Monto con formato de Nexo ($1,250.50) y etiqueta accesible.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.money, {
    this.style,
    this.signed = false,
    this.colorBySign = false,
    this.semanticsPrefix,
    super.key,
  });

  final Money money;
  final TextStyle? style;

  /// Muestra "+" en créditos (movimientos).
  final bool signed;

  /// Créditos en color de marca; débitos en el color de texto normal.
  final bool colorBySign;

  /// Contexto para el lector de pantalla, ej. "Saldo disponible".
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final text = money.format();
    final shown = signed && money.isPositive ? '+$text' : text;
    final spoken = moneySemanticsLabel(money, signed: signed);
    return Semantics(
      label: semanticsPrefix == null ? spoken : '$semanticsPrefix, $spoken',
      excludeSemantics: true,
      child: Text(
        shown,
        style: (style ?? const TextStyle()).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: colorBySign && money.isPositive ? NexoColors.brand : null,
        ),
      ),
    );
  }
}

/// Campo de monto estilo cajero: los dígitos entran por la derecha
/// ("1" -> 0.01, "12345" -> 123.45). Evita parsear separadores decimales.
class AmountField extends StatefulWidget {
  const AmountField({
    required this.value,
    required this.onChanged,
    this.maxDigits = 9,
    this.enabled = true,
    super.key,
  });

  final Money value;
  final ValueChanged<Money> onChanged;

  /// 9 dígitos = hasta $9,999,999.99.
  final int maxDigits;
  final bool enabled;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );

  static String _format(Money m) => m.format(symbol: '');

  @override
  void didUpdateWidget(AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = Money.fromTypedDigits(_controller.text);
    if (widget.value != current) {
      final text = _format(widget.value);
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall;
    return Semantics(
      label: 'Monto a transferir',
      value: moneySemanticsLabel(widget.value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(r'$', style: style?.copyWith(color: NexoColors.brand)),
          const SizedBox(width: NexoSpacing.xs),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: style?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              showCursor: false,
              enableInteractiveSelection: false,
              inputFormatters: [_AtmFormatter(widget.maxDigits)],
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
              ),
              onChanged: (text) =>
                  widget.onChanged(Money.fromTypedDigits(text)),
            ),
          ),
          const SizedBox(width: NexoSpacing.xs),
          Text(
            'USD',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: NexoColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// Re-formatea en cada pulsación y deja el cursor al final.
class _AtmFormatter extends TextInputFormatter {
  _AtmFormatter(this.maxDigits);

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    digits = digits.replaceFirst(RegExp('^0+'), '');
    if (digits.length > maxDigits) return oldValue;
    final text = Money.fromTypedDigits(digits).format(symbol: '');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
