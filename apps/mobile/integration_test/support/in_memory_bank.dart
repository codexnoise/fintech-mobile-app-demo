import 'dart:async';

import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/accounts/domain/accounts_repository.dart';
import 'package:nexo_mobile/features/accounts/domain/movement.dart';
import 'package:nexo_mobile/features/transfers/domain/transfer.dart';

/// Core bancario en memoria para el E2E: mismas interfaces que Firestore y el
/// BFF, con saldos que cambian en vivo tras una transferencia.
final class InMemoryBank implements AccountsRepository, TransfersRepository {
  InMemoryBank({required Map<String, int> balances}) {
    balances.forEach((id, cents) {
      _accounts[id] = Account(
        id: id,
        type: id == 'savings' ? AccountType.savings : AccountType.checking,
        alias: id == 'savings' ? 'Cuenta de ahorros' : 'Cuenta corriente',
        maskedNumber: id == 'savings' ? '•••• 2622' : '•••• 8225',
        balance: Money(cents),
        updatedAt: DateTime.now(),
      );
      _movements[id] = [];
    });
  }

  final _accounts = <String, Account>{};
  final _movements = <String, List<Movement>>{};
  final _changes = StreamController<void>.broadcast();
  var _seq = 0;

  Money balanceOf(String id) => _accounts[id]!.balance;

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<Result<Live<List<Account>>>> watchAccounts() => _live(
    () => Result.ok(Live(_accounts.values.toList(), isFromCache: false)),
  );

  @override
  Stream<Result<Live<Account>>> watchAccount(String id) => _live(() {
    final account = _accounts[id];
    return account == null
        ? const Result.err(ValidationFailure(accountNotFoundCode))
        : Result.ok(Live(account, isFromCache: false));
  });

  @override
  Stream<Result<Live<List<Movement>>>> watchMovements(
    String accountId, {
    required int limit,
  }) => _live(
    () => Result.ok(
      Live(
        (_movements[accountId] ?? []).reversed.take(limit).toList(),
        isFromCache: false,
      ),
    ),
  );

  @override
  Future<Result<TransferReceipt>> submit(TransferRequest request) async {
    final from = _accounts[request.fromAccountId]!;
    final to = _accounts[request.toAccountId]!;
    if (request.amount > from.balance) {
      return const Result.err(
        ValidationFailure('insufficient_funds', 'Saldo insuficiente.'),
      );
    }
    final now = DateTime.now();
    _accounts[from.id] = _with(from, from.balance - request.amount, now);
    _accounts[to.id] = _with(to, to.balance + request.amount, now);
    for (final (account, amount) in [
      (from.id, -request.amount),
      (to.id, request.amount),
    ]) {
      _movements[account]!.add(
        Movement(
          id: 'm${_seq++}',
          accountId: account,
          amount: amount,
          description: 'Transferencia entre cuentas propias',
          category: MovementCategory.transfer,
          createdAt: now,
          balanceAfter: _accounts[account]!.balance,
        ),
      );
    }
    _changes.add(null);
    return Result.ok(
      TransferReceipt(
        transferId: 't${_seq++}',
        fromAccountId: from.id,
        toAccountId: to.id,
        amount: request.amount,
        fromBalance: _accounts[from.id]!.balance,
        toBalance: _accounts[to.id]!.balance,
        createdAt: now,
        replayed: false,
      ),
    );
  }

  static Account _with(Account a, Money balance, DateTime at) => Account(
    id: a.id,
    type: a.type,
    alias: a.alias,
    maskedNumber: a.maskedNumber,
    balance: balance,
    updatedAt: at,
  );
}
