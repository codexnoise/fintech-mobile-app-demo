import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

sealed class AccountsState {
  const AccountsState();
}

final class AccountsLoading extends AccountsState {
  const AccountsLoading();
}

final class AccountsLoaded extends AccountsState {
  const AccountsLoaded(this.accounts, {required this.isStale});

  final List<Account> accounts;

  /// Datos de la caché local (sin conexión o sin confirmar con el servidor).
  final bool isStale;
}

final class AccountsError extends AccountsState {
  const AccountsError(this.failure);

  final Failure failure;
}

class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit(this._source) : super(const AccountsLoading());

  final AccountsSource _source;
  StreamSubscription<Result<Live<List<Account>>>>? _subscription;

  void start() {
    _subscription ??= _source.watchAccounts().listen(_onResult);
  }

  Future<void> retry() async {
    await _subscription?.cancel();
    _subscription = null;
    emit(const AccountsLoading());
    start();
  }

  void _onResult(Result<Live<List<Account>>> result) {
    switch (result) {
      case Ok(:final value):
        emit(AccountsLoaded(value.data, isStale: value.isFromCache));
      // Si ya mostrábamos datos, mejor datos viejos marcados que un error.
      case Err() when state is AccountsLoaded:
        emit(AccountsLoaded((state as AccountsLoaded).accounts, isStale: true));
      case Err(:final failure):
        emit(AccountsError(failure));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
