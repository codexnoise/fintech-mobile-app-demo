import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/transfers/data/api_transfers_repository.dart';
import 'package:nexo_mobile/features/transfers/domain/transfer.dart';
import 'package:nexo_mobile/features/transfers/presentation/transfer_cubit.dart';

import '../../helpers/fakes.dart';

Account _account(String id, int cents) => Account(
  id: id,
  type: id == 'savings' ? AccountType.savings : AccountType.checking,
  alias: id,
  maskedNumber: '•••• 0000',
  balance: Money(cents),
  updatedAt: null,
);

final _receipt = TransferReceipt(
  transferId: 't1',
  fromAccountId: 'checking',
  toAccountId: 'savings',
  amount: const Money(2500),
  fromBalance: const Money(97500),
  toBalance: const Money(52500),
  createdAt: DateTime.utc(2026, 10, 5),
  replayed: false,
);

class FakeTransfersRepository implements TransfersRepository {
  final requests = <TransferRequest>[];
  final results = <Result<TransferReceipt>>[];

  @override
  Future<Result<TransferReceipt>> submit(TransferRequest request) async {
    requests.add(request);
    return results.isEmpty ? Result.ok(_receipt) : results.removeAt(0);
  }
}

class FakeConnectivity implements ConnectivityMonitor {
  FakeConnectivity({this.online = true});

  bool online;
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => changes.stream;
}

void main() {
  late FakeAccountsRepository accounts;
  late FakeTransfersRepository transfers;
  late FakeConnectivity connectivity;
  late int keys;

  setUp(() {
    accounts = FakeAccountsRepository();
    transfers = FakeTransfersRepository();
    connectivity = FakeConnectivity();
    keys = 0;
  });

  Future<TransferCubit> ready({String? from}) async {
    final cubit = TransferCubit(
      accounts,
      transfers,
      connectivity,
      newIdempotencyKey: () => 'key-${++keys}',
      initialFromId: from,
    );
    await cubit.start();
    accounts.accounts.add(
      Result.ok(
        Live([
          _account('checking', 100000),
          _account('savings', 50000),
        ], isFromCache: false),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  test('preselecciona origen y destino distintos', () async {
    final cubit = await ready(from: 'savings');
    final state = cubit.state as TransferEditing;

    expect(state.draft.from?.id, 'savings');
    expect(state.draft.to?.id, 'checking');
  });

  test('éxito: revisa, confirma y envía con idempotencyKey', () async {
    final cubit = await ready();
    cubit
      ..setAmount(const Money(2500))
      ..setNote('  Ahorro  ')
      ..review();
    expect(cubit.state, isA<TransferReviewing>());

    await cubit.confirm();

    expect(cubit.state, isA<TransferSucceeded>());
    final sent = transfers.requests.single;
    expect(sent.fromAccountId, 'checking');
    expect(sent.toAccountId, 'savings');
    expect(sent.amount, const Money(2500));
    expect(sent.note, 'Ahorro');
    expect(sent.idempotencyKey, 'key-1');
  });

  test('saldo insuficiente se detecta antes de enviar', () async {
    final cubit = await ready();
    cubit
      ..setAmount(const Money(100001))
      ..review();

    expect(
      cubit.state,
      isA<TransferEditing>().having((s) => s.error, 'error', contains('Saldo')),
    );
    expect(transfers.requests, isEmpty);
  });

  test('límite por transferencia (USD 5.000)', () async {
    final cubit = await ready();
    accounts.accounts.add(
      Result.ok(
        Live([
          _account('checking', 10000000),
          _account('savings', 0),
        ], isFromCache: false),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    cubit
      ..setAmount(const Money(500001))
      ..review();

    expect((cubit.state as TransferEditing).error, contains(r'$5,000.00'));
  });

  test('insuficiente según el backend (422) muestra su mensaje', () async {
    transfers.results.add(
      const Result.err(
        ValidationFailure('insufficient_funds', 'Saldo insuficiente.'),
      ),
    );
    final cubit = await ready();
    cubit
      ..setAmount(const Money(2500))
      ..review();
    await cubit.confirm();

    expect(
      cubit.state,
      isA<TransferEditing>().having(
        (s) => s.error,
        'error',
        'Saldo insuficiente.',
      ),
    );
  });

  test('503 -> transferencias en mantenimiento', () async {
    transfers.results.add(
      const Result.err(ServiceUnavailableFailure(service: 'transfers')),
    );
    final cubit = await ready();
    cubit
      ..setAmount(const Money(2500))
      ..review();
    await cubit.confirm();

    expect(cubit.state, isA<TransferMaintenance>());
  });

  test('reintento tras falla de red conserva la misma key', () async {
    transfers.results.add(const Result.err(TimeoutFailure()));
    final cubit = await ready();
    cubit
      ..setAmount(const Money(2500))
      ..review();
    await cubit.confirm();
    expect(cubit.state, isA<TransferEditing>());

    cubit.review();
    await cubit.confirm();

    expect(cubit.state, isA<TransferSucceeded>());
    expect(transfers.requests.map((r) => r.idempotencyKey), ['key-1', 'key-1']);
  });

  test('editar el monto inicia un intento nuevo (otra key)', () async {
    transfers.results.add(const Result.err(TimeoutFailure()));
    final cubit = await ready();
    cubit
      ..setAmount(const Money(2500))
      ..review();
    await cubit.confirm();

    cubit
      ..setAmount(const Money(3000))
      ..review();
    await cubit.confirm();

    expect(transfers.requests.map((r) => r.idempotencyKey), ['key-1', 'key-2']);
  });

  test('sin conexión no se puede revisar ni enviar', () async {
    connectivity.online = false;
    final cubit = await ready();
    cubit
      ..setAmount(const Money(2500))
      ..review();

    final state = cubit.state as TransferEditing;
    expect(state.online, isFalse);
    expect(state.error, contains('no se guardan'));
    expect(transfers.requests, isEmpty);
  });

  test('se entera cuando vuelve la conexión', () async {
    connectivity.online = false;
    final cubit = await ready();
    connectivity.changes.add(true);
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as TransferEditing).online, isTrue);
  });

  test('swap intercambia origen y destino; Todo usa el saldo', () async {
    final cubit = await ready();
    cubit
      ..swap()
      ..setAll();

    final draft = (cubit.state as TransferEditing).draft;
    expect(draft.from?.id, 'savings');
    expect(draft.amount, const Money(50000));
  });

  test('parsea el recibo del BFF', () {
    final r = parseTransferReceipt({
      'transferId': 't1',
      'status': 'completed',
      'fromAccountId': 'checking',
      'toAccountId': 'savings',
      'amountCents': 2500,
      'debitMovementId': 'd',
      'creditMovementId': 'c',
      'fromBalanceCents': 97500,
      'toBalanceCents': 52500,
      'createdAt': '2026-10-05T00:00:00.000Z',
      'replayed': true,
    });
    expect(r.amount, const Money(2500));
    expect(r.replayed, isTrue);
  });
}
