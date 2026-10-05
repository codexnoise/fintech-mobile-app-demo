import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/accounts_repository.dart';
import '../domain/movement.dart';

/// Lee cuentas y movimientos directo de Firestore. Las reglas solo permiten
/// leer los documentos propios; las escrituras están prohibidas al cliente.
final class FirestoreAccountsRepository implements AccountsRepository {
  FirestoreAccountsRepository(this._db, this._user);

  /// Accessor: la instancia se recrea tras el logout (terminate).
  final FirebaseFirestore Function() _db;
  final CurrentUserProvider _user;

  CollectionReference<Map<String, Object?>>? _accounts() {
    final uid = _user.uid;
    if (uid == null) return null;
    return _db().collection('users').doc(uid).collection('accounts');
  }

  @override
  Stream<Result<Live<List<Account>>>> watchAccounts() {
    final ref = _accounts();
    if (ref == null) return _noSession();
    return _guard(
      ref.snapshots(includeMetadataChanges: true).map((snap) {
        final accounts = [
          for (final doc in snap.docs) parseAccount(doc.id, doc.data()),
        ]..sort((a, b) => a.type.index.compareTo(b.type.index));
        return Live(accounts, isFromCache: snap.metadata.isFromCache);
      }),
    );
  }

  @override
  Stream<Result<Live<Account>>> watchAccount(String id) {
    final ref = _accounts();
    if (ref == null) return _noSession();
    return ref
        .doc(id)
        .snapshots(includeMetadataChanges: true)
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (doc, sink) {
              final data = doc.data();
              if (data == null) {
                // En caché puede faltar aún: esperar la respuesta del servidor.
                if (!doc.metadata.isFromCache) {
                  sink.add(
                    const Result.err(ValidationFailure(accountNotFoundCode)),
                  );
                }
                return;
              }
              _addParsed(
                sink,
                () => Live(
                  parseAccount(doc.id, data),
                  isFromCache: doc.metadata.isFromCache,
                ),
              );
            },
            handleError: (e, _, sink) =>
                sink.add(Result.err(mapFirestoreError(e))),
          ),
        );
  }

  @override
  Stream<Result<Live<List<Movement>>>> watchMovements(
    String accountId, {
    required int limit,
  }) {
    final ref = _accounts();
    if (ref == null) return _noSession();
    final query = ref
        .doc(accountId)
        .collection('movements')
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, maxMovementsPerQuery));
    return _guard(
      query
          .snapshots(includeMetadataChanges: true)
          .map(
            (snap) => Live([
              for (final doc in snap.docs) parseMovement(doc.id, doc.data()),
            ], isFromCache: snap.metadata.isFromCache),
          ),
    );
  }

  static Stream<Result<T>> _noSession<T>() =>
      Stream.value(const Result.err(UnauthorizedFailure()));

  /// Convierte datos y errores (de Firestore o de parseo) en [Result].
  static Stream<Result<T>> _guard<T>(Stream<T> source) => source.transform(
    StreamTransformer.fromHandlers(
      handleData: (data, sink) => sink.add(Result.ok(data)),
      handleError: (e, _, sink) => sink.add(Result.err(mapFirestoreError(e))),
    ),
  );

  static void _addParsed<T>(EventSink<Result<T>> sink, T Function() parse) {
    try {
      sink.add(Result.ok(parse()));
    } on Object catch (e) {
      sink.add(Result.err(mapFirestoreError(e)));
    }
  }
}

Failure mapFirestoreError(Object error) => switch (error) {
  FirebaseException(code: 'permission-denied' || 'unauthenticated') =>
    const UnauthorizedFailure(),
  FirebaseException(code: 'unavailable') => const NetworkFailure(),
  FirebaseException(code: 'deadline-exceeded') => const TimeoutFailure(),
  FirebaseException(:final code) => UnknownFailure(code),
  FormatException() ||
  TypeError() => ServerFailure(code: 'invalid_response', message: '$error'),
  _ => UnknownFailure('$error'),
};

int _cents(Object? value, String field) {
  // Dinero siempre entero: un double indica un dato corrupto.
  if (value is int) return value;
  throw FormatException('$field debe ser un entero en centavos');
}

DateTime? _date(Object? value) => switch (value) {
  final String s => DateTime.tryParse(s),
  final Timestamp t => t.toDate(),
  _ => null,
};

Account parseAccount(String id, Map<String, Object?> data) => Account(
  id: id,
  type: switch (data['type']) {
    'checking' => AccountType.checking,
    'savings' => AccountType.savings,
    _ => AccountType.unknown,
  },
  alias: data['alias'] as String? ?? 'Cuenta',
  maskedNumber: data['maskedNumber'] as String? ?? '',
  balance: Money(
    _cents(data['balanceCents'], 'balanceCents'),
    currency: data['currency'] as String? ?? 'USD',
  ),
  updatedAt: _date(data['updatedAt']),
);

Movement parseMovement(String id, Map<String, Object?> data) {
  final createdAt = _date(data['createdAt']);
  if (createdAt == null) throw const FormatException('createdAt inválido');
  return Movement(
    id: id,
    accountId: data['accountId'] as String? ?? '',
    amount: Money(_cents(data['amountCents'], 'amountCents')),
    description: data['description'] as String? ?? '',
    category: MovementCategory.fromWire(data['category'] as String?),
    createdAt: createdAt,
    balanceAfter: Money(_cents(data['balanceAfterCents'], 'balanceAfterCents')),
  );
}
