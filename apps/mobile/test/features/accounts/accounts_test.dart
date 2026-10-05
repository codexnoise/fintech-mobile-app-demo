import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/accounts/data/firestore_accounts_repository.dart';
import 'package:nexo_mobile/features/accounts/domain/accounts_repository.dart';
import 'package:nexo_mobile/features/accounts/domain/movement.dart';
import 'package:nexo_mobile/features/accounts/presentation/account_detail_cubit.dart';
import 'package:nexo_mobile/features/accounts/presentation/accounts_cubit.dart';
import 'package:nexo_mobile/features/accounts/presentation/movement_grouping.dart';

import '../../helpers/fakes.dart';

final _now = DateTime(2026, 10, 5, 12);

Account account(String id, int cents) => Account(
  id: id,
  type: AccountType.checking,
  alias: 'Cuenta $id',
  maskedNumber: '•••• 1234',
  balance: Money(cents),
  updatedAt: _now,
);

Movement movement(String id, DateTime at, int cents) => Movement(
  id: id,
  accountId: 'checking',
  amount: Money(cents),
  description: 'Mov $id',
  category: MovementCategory.food,
  createdAt: at,
  balanceAfter: const Money(0),
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('parseo de Firestore', () {
    test('cuenta', () {
      final a = parseAccount('checking', {
        'type': 'checking',
        'alias': 'Cuenta corriente',
        'maskedNumber': '•••• 9619',
        'balanceCents': 477426,
        'currency': 'USD',
        'updatedAt': '2026-10-05T02:23:59.420Z',
      });
      expect(a.balance, const Money(477426));
      expect(a.type, AccountType.checking);
      expect(a.updatedAt, DateTime.utc(2026, 10, 5, 2, 23, 59, 420));
    });

    test('movimiento con monto firmado', () {
      final m = parseMovement('seed-000', {
        'accountId': 'checking',
        'amountCents': -12188,
        'description': 'Farmacia',
        'category': 'health',
        'createdAt': '2026-09-05T10:23:59.420Z',
        'balanceAfterCents': 215312,
      });
      expect(m.amount, const Money(-12188));
      expect(m.category, MovementCategory.health);
    });

    test('categoría nueva no rompe', () {
      final m = parseMovement('x', {
        'accountId': 'checking',
        'amountCents': 1,
        'description': 'x',
        'category': 'crypto',
        'createdAt': '2026-09-05T10:23:59.420Z',
        'balanceAfterCents': 1,
      });
      expect(m.category, MovementCategory.other);
    });

    test('saldo con decimales (no entero) -> FormatException', () {
      expect(
        () => parseAccount('a', {'balanceCents': 10.5, 'alias': 'x'}),
        throwsFormatException,
      );
    });

    test('errores de Firestore', () {
      expect(
        mapFirestoreError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isA<NetworkFailure>(),
      );
      expect(
        mapFirestoreError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isA<UnauthorizedFailure>(),
      );
    });
  });

  test('agrupa movimientos por día con etiquetas en español', () {
    final groups = groupMovementsByDay([
      movement('1', DateTime(2026, 10, 5, 9), -100),
      movement('2', DateTime(2026, 10, 5, 8), 200),
      movement('3', DateTime(2026, 10, 4, 20), -300),
      movement('4', DateTime(2026, 9, 20, 8), -400),
      movement('5', DateTime(2025, 12, 31, 8), -500),
    ], now: _now);

    expect(groups.map((g) => g.label), [
      'Hoy, 5 de octubre',
      'Ayer, 4 de octubre',
      '20 de septiembre',
      '31 de diciembre de 2025',
    ]);
    expect(groups.first.movements.map((m) => m.id), ['1', '2']);
  });

  group('AccountsCubit', () {
    late FakeAccountsRepository repo;
    setUp(() => repo = FakeAccountsRepository());

    blocTest<AccountsCubit, AccountsState>(
      'cargando -> cuentas en vivo',
      build: () => AccountsCubit(repo)..start(),
      act: (_) => repo.accounts.add(
        Result.ok(Live([account('checking', 100)], isFromCache: false)),
      ),
      expect: () => [
        isA<AccountsLoaded>()
            .having((s) => s.accounts.length, 'n', 1)
            .having((s) => s.isStale, 'stale', false),
      ],
    );

    blocTest<AccountsCubit, AccountsState>(
      'datos de caché se marcan desactualizados',
      build: () => AccountsCubit(repo)..start(),
      act: (_) => repo.accounts.add(
        Result.ok(Live([account('checking', 100)], isFromCache: true)),
      ),
      expect: () => [isA<AccountsLoaded>().having((s) => s.isStale, 's', true)],
    );

    blocTest<AccountsCubit, AccountsState>(
      'error sin datos previos -> error con reintento',
      build: () => AccountsCubit(repo)..start(),
      act: (_) => repo.accounts.add(const Result.err(NetworkFailure())),
      expect: () => [isA<AccountsError>()],
    );

    blocTest<AccountsCubit, AccountsState>(
      'error con datos previos conserva los datos como desactualizados',
      build: () => AccountsCubit(repo)..start(),
      act: (_) async {
        repo.accounts.add(
          Result.ok(Live([account('checking', 100)], isFromCache: false)),
        );
        await Future<void>.delayed(Duration.zero);
        repo.accounts.add(const Result.err(NetworkFailure()));
      },
      expect: () => [
        isA<AccountsLoaded>().having((s) => s.isStale, 's', false),
        isA<AccountsLoaded>()
            .having((s) => s.isStale, 's', true)
            .having((s) => s.accounts.length, 'n', 1),
      ],
    );
  });

  group('AccountDetailCubit', () {
    late FakeAccountsRepository repo;
    setUp(() => repo = FakeAccountsRepository());

    blocTest<AccountDetailCubit, AccountDetailState>(
      'combina cuenta y movimientos en tiempo real',
      build: () => AccountDetailCubit(repo, accountId: 'checking')..start(),
      act: (_) async {
        repo.account.add(
          Result.ok(Live(account('checking', 1000), isFromCache: false)),
        );
        await Future<void>.delayed(Duration.zero);
        repo.movements.add(
          Result.ok(Live([movement('1', _now, -100)], isFromCache: false)),
        );
        await Future<void>.delayed(Duration.zero);
        // Llega una transferencia: el saldo y la lista se actualizan solos.
        repo.account.add(
          Result.ok(Live(account('checking', 900), isFromCache: false)),
        );
      },
      expect: () => [
        isA<AccountDetailLoaded>().having((s) => s.movements, 'movs', isNull),
        isA<AccountDetailLoaded>().having(
          (s) => s.movements?.length,
          'movs',
          1,
        ),
        isA<AccountDetailLoaded>().having(
          (s) => s.account.balance,
          'saldo',
          const Money(900),
        ),
      ],
    );

    blocTest<AccountDetailCubit, AccountDetailState>(
      'cuenta inexistente -> error',
      build: () => AccountDetailCubit(repo, accountId: 'x')..start(),
      act: (_) => repo.account.add(
        const Result.err(ValidationFailure(accountNotFoundCode)),
      ),
      expect: () => [isA<AccountDetailError>()],
    );

    blocTest<AccountDetailCubit, AccountDetailState>(
      'cargar más amplía el límite hasta el máximo permitido por reglas',
      build: () => AccountDetailCubit(repo, accountId: 'checking')..start(),
      act: (cubit) async {
        repo.account.add(
          Result.ok(Live(account('checking', 1000), isFromCache: false)),
        );
        await Future<void>.delayed(Duration.zero);
        repo.movements.add(
          Result.ok(
            Live([
              for (var i = 0; i < movementsPageSize; i++)
                movement('$i', _now, -1),
            ], isFromCache: false),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect((cubit.state as AccountDetailLoaded).canLoadMore, isTrue);
        cubit.loadMore();
        cubit.loadMore();
      },
      verify: (_) => expect(repo.requestedLimits, [
        movementsPageSize,
        maxMovementsPerQuery,
      ]),
    );
  });
}
