import 'package:intl/intl.dart';

import '../domain/movement.dart';

final class MovementDay {
  const MovementDay(this.label, this.movements);

  final String label;
  final List<Movement> movements;
}

/// Agrupa por día local: "Hoy, 5 de octubre", "Ayer, …", "20 de septiembre".
/// Requiere `initializeDateFormatting('es')`.
List<MovementDay> groupMovementsByDay(
  List<Movement> movements, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final dayMonth = DateFormat("d 'de' MMMM", 'es');
  final fullDate = DateFormat("d 'de' MMMM 'de' y", 'es');

  final groups = <DateTime, List<Movement>>{};
  for (final m in movements) {
    final local = m.createdAt.toLocal();
    groups
        .putIfAbsent(DateTime(local.year, local.month, local.day), () => [])
        .add(m);
  }

  return [
    for (final MapEntry(key: day, value: items) in groups.entries)
      MovementDay(switch (today.difference(day).inDays) {
        0 => 'Hoy, ${dayMonth.format(day)}',
        1 => 'Ayer, ${dayMonth.format(day)}',
        _ when day.year == today.year => dayMonth.format(day),
        _ => fullDate.format(day),
      }, items),
  ];
}
