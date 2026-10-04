/// Monto monetario representado SIEMPRE en unidades menores (centavos).
///
/// Nunca usamos `double` para dinero: los errores de redondeo binario son
/// inaceptables en contexto bancario (ver docs/adr/0011-money-as-integers.md).
final class Money implements Comparable<Money> {
  const Money(this.cents, {this.currency = 'USD'});

  const Money.zero({this.currency = 'USD'}) : cents = 0;

  /// Construye a partir de dígitos tipeados estilo cajero automático:
  /// "12345" -> 123,45. Ignora cualquier caracter que no sea dígito.
  /// Evita parsear separadores decimales dependientes del locale.
  factory Money.fromTypedDigits(String input, {String currency = 'USD'}) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return Money.zero(currency: currency);
    // Limitamos la longitud para evitar overflow por entradas absurdas.
    final safe = digits.length > 15 ? digits.substring(digits.length - 15) : digits;
    return Money(int.parse(safe), currency: currency);
  }

  final int cents;
  final String currency;

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;
  bool get isPositive => cents > 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(cents + other.cents, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(cents - other.cents, currency: currency);
  }

  Money operator -() => Money(-cents, currency: currency);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  Money abs() => Money(cents.abs(), currency: currency);

  /// Formato determinista e independiente de `intl` (útil en tests y logs).
  /// La UI usa el formateador localizado del design system.
  String format({
    String symbol = r'$',
    String thousands = ',',
    String decimal = '.',
  }) {
    final negative = cents < 0;
    final abs = cents.abs();
    final major = (abs ~/ 100).toString();
    final minor = (abs % 100).toString().padLeft(2, '0');
    final grouped = StringBuffer();
    for (var i = 0; i < major.length; i++) {
      final remaining = major.length - i;
      grouped.write(major[i]);
      if (remaining > 1 && remaining % 3 == 1) grouped.write(thousands);
    }
    return '${negative ? '-' : ''}$symbol$grouped$decimal$minor';
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return cents.compareTo(other.cents);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.cents == cents && other.currency == currency;

  @override
  int get hashCode => Object.hash(cents, currency);

  @override
  String toString() => 'Money($cents $currency)';
}
