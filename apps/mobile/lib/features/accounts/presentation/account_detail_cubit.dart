import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/accounts_repository.dart';
import '../domain/movement.dart';

sealed class AccountDetailState {
  const AccountDetailState();
}

final class AccountDetailLoading extends AccountDetailState {
  const AccountDetailLoading();
}

final class AccountDetailLoaded extends AccountDetailState {
  const AccountDetailLoaded({
    required this.account,
    required this.movements,
    required this.isStale,
    required this.limit,
    this.movementsFailure,
  });

  final Account account;

  /// `null` mientras cargan los movimientos (skeleton).
  final List<Movement>? movements;
  final bool isStale;
  final int limit;

  /// Error al cargar movimientos; la cuenta sigue visible.
  final Failure? movementsFailure;

  bool get canLoadMore =>
      movements != null &&
      movements!.length >= limit &&
      limit < maxMovementsPerQuery;

  /// Llegamos al tope que permiten las reglas de Firestore.
  bool get reachedQueryCap =>
      movements != null && movements!.length >= maxMovementsPerQuery;
}

final class AccountDetailError extends AccountDetailState {
  const AccountDetailError(this.failure);

  final Failure failure;
}

class AccountDetailCubit extends Cubit<AccountDetailState> {
  AccountDetailCubit(this._repository, {required this.accountId})
    : super(const AccountDetailLoading());

  final AccountsRepository _repository;
  final String accountId;

  StreamSubscription<Result<Live<Account>>>? _accountSub;
  StreamSubscription<Result<Live<List<Movement>>>>? _movementsSub;

  Live<Account>? _account;
  Live<List<Movement>>? _movements;
  Failure? _movementsFailure;
  int _limit = movementsPageSize;

  void start() {
    _accountSub ??= _repository.watchAccount(accountId).listen(_onAccount);
    _subscribeMovements();
  }

  Future<void> retry() async {
    await _cancel();
    _account = null;
    _movements = null;
    _movementsFailure = null;
    emit(const AccountDetailLoading());
    start();
  }

  void loadMore() {
    final current = state;
    if (current is! AccountDetailLoaded || !current.canLoadMore) return;
    _limit = min(_limit + movementsPageSize, maxMovementsPerQuery);
    unawaited(_movementsSub?.cancel());
    _movementsSub = null;
    _subscribeMovements();
    _emitLoaded();
  }

  void _subscribeMovements() {
    _movementsSub ??= _repository
        .watchMovements(accountId, limit: _limit)
        .listen((result) {
          switch (result) {
            case Ok(:final value):
              _movements = value;
              _movementsFailure = null;
            case Err(:final failure):
              _movementsFailure = failure;
          }
          _emitLoaded();
        });
  }

  void _onAccount(Result<Live<Account>> result) {
    switch (result) {
      case Ok(:final value):
        _account = value;
        _emitLoaded();
      case Err() when _account != null:
        // Conservar lo último que vimos, marcado como desactualizado.
        _account = Live(_account!.data, isFromCache: true);
        _emitLoaded();
      case Err(:final failure):
        emit(AccountDetailError(failure));
    }
  }

  void _emitLoaded() {
    final account = _account;
    if (account == null) return;
    final movements = _movements;
    emit(
      AccountDetailLoaded(
        account: account.data,
        movements: movements?.data,
        isStale: account.isFromCache || (movements?.isFromCache ?? false),
        limit: _limit,
        movementsFailure: _movementsFailure,
      ),
    );
  }

  Future<void> _cancel() async {
    await _accountSub?.cancel();
    await _movementsSub?.cancel();
    _accountSub = null;
    _movementsSub = null;
  }

  @override
  Future<void> close() async {
    await _cancel();
    return super.close();
  }
}
