import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:uuid/uuid.dart';

import '../domain/transfer.dart';

const offlineTransferMessage =
    'Sin conexión. Las transferencias no se guardan para enviarse después: '
    'conéctate e intenta de nuevo.';

final class TransferDraft {
  const TransferDraft({
    required this.accounts,
    this.fromId,
    this.toId,
    this.amount = const Money.zero(),
    this.note = '',
  });

  final List<Account> accounts;
  final String? fromId;
  final String? toId;
  final Money amount;
  final String note;

  Account? _find(String? id) => accounts.where((a) => a.id == id).firstOrNull;
  Account? get from => _find(fromId);
  Account? get to => _find(toId);

  TransferDraft copyWith({
    List<Account>? accounts,
    String? fromId,
    String? toId,
    Money? amount,
    String? note,
  }) => TransferDraft(
    accounts: accounts ?? this.accounts,
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    amount: amount ?? this.amount,
    note: note ?? this.note,
  );
}

sealed class TransferState {
  const TransferState();
}

final class TransferLoading extends TransferState {
  const TransferLoading();
}

final class TransferLoadFailed extends TransferState {
  const TransferLoadFailed(this.failure);

  final Failure failure;
}

/// Estados con formulario: comparten el borrador y la conectividad.
sealed class TransferReady extends TransferState {
  const TransferReady(this.draft, {required this.online});

  final TransferDraft draft;
  final bool online;
}

final class TransferEditing extends TransferReady {
  const TransferEditing(super.draft, {required super.online, this.error});

  final String? error;
}

/// El usuario revisa el resumen antes de confirmar (bottom sheet).
final class TransferReviewing extends TransferReady {
  const TransferReviewing(super.draft, {required super.online});
}

final class TransferSubmitting extends TransferReady {
  const TransferSubmitting(super.draft, {required super.online});
}

/// El BFF respondió 503: transferencias deshabilitadas temporalmente.
final class TransferMaintenance extends TransferReady {
  const TransferMaintenance(super.draft, {required super.online});
}

final class TransferSucceeded extends TransferState {
  const TransferSucceeded(this.receipt, this.draft);

  final TransferReceipt receipt;
  final TransferDraft draft;
}

class TransferCubit extends Cubit<TransferState> {
  TransferCubit(
    this._accounts,
    this._transfers,
    this._connectivity, {
    String Function()? newIdempotencyKey,
    this._initialFromId,
    this._analytics = const NoopAnalytics(),
  }) : _newKey = newIdempotencyKey ?? const Uuid().v4,
       super(const TransferLoading());

  final AccountsSource _accounts;
  final TransfersRepository _transfers;
  final ConnectivityMonitor _connectivity;
  final String Function() _newKey;
  final AnalyticsTracker _analytics;
  final String? _initialFromId;

  StreamSubscription<Result<Live<List<Account>>>>? _accountsSub;
  StreamSubscription<bool>? _onlineSub;
  bool _online = true;

  /// Key del intento en curso. Se conserva en reintentos y se descarta cuando
  /// el usuario cambia algo (es otra transferencia) o el resultado es final.
  String? _attemptKey;

  Future<void> start() async {
    _online = await _connectivity.isOnline();
    _onlineSub ??= _connectivity.onlineChanges.listen((online) {
      _online = online;
      final current = state;
      if (current is TransferEditing) {
        emit(TransferEditing(current.draft, online: online));
      }
    });
    _accountsSub ??= _accounts.watchAccounts().listen(_onAccounts);
  }

  void _onAccounts(Result<Live<List<Account>>> result) {
    final current = state;
    switch (result) {
      case Ok(:final value):
        final accounts = value.data;
        if (current is TransferReady) {
          // Saldos en vivo: actualizar sin perder lo ingresado.
          final draft = current.draft.copyWith(accounts: accounts);
          emit(switch (current) {
            TransferEditing(:final error) => TransferEditing(
              draft,
              online: _online,
              error: error,
            ),
            TransferReviewing() => TransferReviewing(draft, online: _online),
            TransferSubmitting() => TransferSubmitting(draft, online: _online),
            TransferMaintenance() => TransferMaintenance(
              draft,
              online: _online,
            ),
          });
        } else if (current is! TransferSucceeded) {
          emit(TransferEditing(_initialDraft(accounts), online: _online));
        }
      case Err(:final failure) when current is TransferLoading:
        emit(TransferLoadFailed(failure));
      case Err():
        break; // Se conservan los últimos saldos conocidos.
    }
  }

  TransferDraft _initialDraft(List<Account> accounts) {
    final from =
        accounts.where((a) => a.id == _initialFromId).firstOrNull ??
        accounts.firstOrNull;
    final to = accounts.where((a) => a.id != from?.id).firstOrNull;
    return TransferDraft(accounts: accounts, fromId: from?.id, toId: to?.id);
  }

  void _edit(TransferDraft Function(TransferDraft) change) {
    final current = state;
    if (current is! TransferEditing && current is! TransferMaintenance) return;
    _attemptKey = null;
    emit(
      TransferEditing(
        change((current as TransferReady).draft),
        online: _online,
      ),
    );
  }

  void selectFrom(String id) => _edit((d) {
    // Elegir como origen la cuenta destino equivale a intercambiarlas.
    final to = d.toId == id ? d.fromId : d.toId;
    return d.copyWith(fromId: id, toId: to);
  });

  void selectTo(String id) => _edit((d) {
    final from = d.fromId == id ? d.toId : d.fromId;
    return d.copyWith(fromId: from, toId: id);
  });

  void swap() => _edit((d) => d.copyWith(fromId: d.toId, toId: d.fromId));

  void setAmount(Money amount) => _edit((d) => d.copyWith(amount: amount));

  void addAmount(Money delta) =>
      _edit((d) => d.copyWith(amount: d.amount + delta));

  /// Transferir todo el saldo disponible del origen.
  void setAll() =>
      _edit((d) => d.copyWith(amount: d.from?.balance ?? const Money.zero()));

  void setNote(String note) => _edit((d) => d.copyWith(note: note));

  void review() {
    final current = state;
    if (current is! TransferEditing) return;
    final error = _validate(current.draft);
    if (error != null) {
      return emit(
        TransferEditing(current.draft, online: _online, error: error),
      );
    }
    _attemptKey ??= _newKey();
    emit(TransferReviewing(current.draft, online: _online));
  }

  void cancelReview() {
    final current = state;
    if (current is TransferReviewing) {
      emit(TransferEditing(current.draft, online: _online));
    }
  }

  Future<void> confirm() async {
    final current = state;
    final key = _attemptKey;
    if (current is! TransferReviewing || key == null) return;
    final draft = current.draft;
    if (!_online) {
      return emit(
        TransferEditing(draft, online: false, error: offlineTransferMessage),
      );
    }

    emit(TransferSubmitting(draft, online: _online));
    final note = draft.note.trim();
    final result = await _transfers.submit(
      TransferRequest(
        fromAccountId: draft.fromId!,
        toAccountId: draft.toId!,
        amount: draft.amount,
        note: note.isEmpty ? null : note,
        idempotencyKey: key,
      ),
    );

    switch (result) {
      case Ok(:final value):
        _attemptKey = null;
        _analytics.track(AnalyticsEvents.transferCompleted, {
          'replayed': value.replayed,
        });
        emit(TransferSucceeded(value, draft));
      case Err(failure: ServiceUnavailableFailure()):
        emit(TransferMaintenance(draft, online: _online));
      // Rechazo de negocio definitivo: el próximo intento es otro.
      case Err(failure: final ValidationFailure failure):
        _attemptKey = null;
        emit(
          TransferEditing(draft, online: _online, error: failure.userMessage),
        );
      // Resultado incierto (red, timeout, 5xx): se reintenta con la misma key
      // y el backend garantiza que no se debite dos veces.
      case Err(:final failure):
        emit(
          TransferEditing(
            draft,
            online: _online,
            error:
                '${failure.userMessage} Si reintentas, no se duplicará '
                'la transferencia.',
          ),
        );
    }
  }

  String? _validate(TransferDraft d) {
    final from = d.from;
    final to = d.to;
    if (!_online) return offlineTransferMessage;
    if (from == null || to == null) {
      return 'Elige la cuenta de origen y destino.';
    }
    if (from.id == to.id) return 'Elige cuentas distintas.';
    if (!d.amount.isPositive) return 'Ingresa el monto a transferir.';
    if (d.amount > maxPerTransfer) {
      return 'El máximo por transferencia es ${maxPerTransfer.format()}.';
    }
    if (d.amount > from.balance) {
      return 'Saldo insuficiente en ${from.alias} '
          '(disponible ${from.balance.format()}).';
    }
    if (d.note.trim().length > maxNoteLength) {
      return 'La nota admite hasta $maxNoteLength caracteres.';
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _accountsSub?.cancel();
    await _onlineSub?.cancel();
    return super.close();
  }
}
