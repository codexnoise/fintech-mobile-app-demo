import 'dart:async';

import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/accounts/domain/accounts_repository.dart';
import 'package:nexo_mobile/features/accounts/domain/movement.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';
import 'package:nexo_mobile/features/auth/domain/biometrics.dart';
import 'package:nexo_mobile/features/onboarding/domain/profile_repository.dart';
import 'package:nexo_mobile/features/onboarding/domain/user_profile.dart';

const testProfile = UserProfile(
  uid: 'u1',
  firstName: 'Ana',
  segment: Segment.youngDigital,
);

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  /// Resultado del próximo signIn/register; por defecto éxito.
  Failure? nextFailure;
  String? lastPassword;
  int signOutCalls = 0;

  @override
  Stream<AuthUser?> userChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  Future<Result<AuthUser>> _login(String email, String password) async {
    lastPassword = password;
    final failure = nextFailure;
    if (failure != null) return Result.err(failure);
    final user = AuthUser(uid: 'u1', email: email);
    _user = user;
    _changes.add(user);
    return Result.ok(user);
  }

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) => _login(email, password);

  @override
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
  }) => _login(email, password);

  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Result.ok(null);

  @override
  Future<Result<void>> reauthenticate(String password) async {
    lastPassword = password;
    final failure = nextFailure;
    return failure == null ? const Result.ok(null) : Result.err(failure);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _user = null;
    _changes.add(null);
  }
}

final class FakeBiometricAuthenticator implements BiometricAuthenticator {
  bool available = true;
  BiometricResult result = BiometricResult.success;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    calls++;
    return result;
  }
}

final class FakeBiometricPreferences implements BiometricPreferences {
  final Set<String> enabled = {};
  final Set<String> offered = {};

  @override
  Future<bool> isEnabled(String uid) async => enabled.contains(uid);

  @override
  Future<void> setEnabled(String uid, {required bool enabled}) async =>
      enabled ? this.enabled.add(uid) : this.enabled.remove(uid);

  @override
  Future<bool> wasOffered(String uid) async => offered.contains(uid);

  @override
  Future<void> markOffered(String uid) async => offered.add(uid);

  @override
  Future<void> clear() async {
    enabled.clear();
    offered.clear();
  }
}

final class FakeProfileRepository implements ProfileRepository {
  Result<UserProfile> profile = const Result.ok(testProfile);
  Result<UserProfile> completeResult = const Result.ok(testProfile);
  OnboardingData? submitted;

  @override
  Future<Result<UserProfile>> fetchProfile() async => profile;

  @override
  Future<Result<UserProfile>> completeOnboarding(OnboardingData data) async {
    submitted = data;
    if (completeResult.isOk) profile = completeResult;
    return completeResult;
  }
}

class FakeAccountsRepository implements AccountsRepository {
  final accounts = StreamController<Result<Live<List<Account>>>>.broadcast();
  final account = StreamController<Result<Live<Account>>>.broadcast();
  final movements = StreamController<Result<Live<List<Movement>>>>.broadcast();
  final requestedLimits = <int>[];

  @override
  Stream<Result<Live<List<Account>>>> watchAccounts() => accounts.stream;

  @override
  Stream<Result<Live<Account>>> watchAccount(String id) => account.stream;

  @override
  Stream<Result<Live<List<Movement>>>> watchMovements(
    String accountId, {
    required int limit,
  }) {
    requestedLimits.add(limit);
    return movements.stream;
  }
}

final class FakeCurrentUser implements CurrentUserProvider {
  FakeCurrentUser([this.uid = 'u1']);

  @override
  String? uid;
}

final class FakeAnalytics implements AnalyticsTracker {
  final events = <(String, Map<String, Object>)>[];
  final userProperties = <String, String?>{};

  @override
  void track(String event, [Map<String, Object> params = const {}]) =>
      events.add((event, params));

  @override
  void setUserProperty(String name, String? value) =>
      userProperties[name] = value;
}
