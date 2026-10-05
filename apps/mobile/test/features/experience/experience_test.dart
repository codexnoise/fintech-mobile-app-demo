import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/experience/data/cascading_experience_repository.dart';
import 'package:nexo_mobile/features/experience/domain/experience.dart';
import 'package:nexo_mobile/features/experience/presentation/home_cubit.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

final _parser = SduiParser(
  supportedTypes: SduiRegistry.standardTypes,
  allowedRoutes: const {'/transfers/new'},
  allowedMicroApps: const {'travel_insurance'},
);

Map<String, Object?> _doc(String title, {int ttl = 300}) => {
  'schemaVersion': 1,
  'screen': 'home',
  'segment': 'premium',
  'version': title,
  'ttlSeconds': ttl,
  'components': [
    {
      'id': 'greeting',
      'type': 'greeting_header',
      'props': {'title': title},
    },
  ],
};

class _FakeRemote {
  Result<Object?> next = Result.ok(_doc('remoto'));
  int calls = 0;

  Future<Result<Object?>> call(String screen) async {
    calls++;
    return next;
  }
}

final class _MemoryCache implements ExperienceCache {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> clear() async => values.clear();
}

void main() {
  late _FakeRemote remote;
  late _MemoryCache cache;
  late String? bundled;

  setUp(() {
    remote = _FakeRemote();
    cache = _MemoryCache();
    bundled = jsonEncode(_doc('embebido'));
  });

  CascadingExperienceRepository repo() => CascadingExperienceRepository(
    fetchRemote: remote.call,
    cache: cache,
    loadBundled: (_) async => bundled ?? (throw StateError('sin asset')),
    parser: _parser,
    appVersion: '1.0.0',
  );

  String title(Experience e) =>
      e.document.components.single.props['title']! as String;

  group('cascada de fallback', () {
    test('remoto OK -> usa remoto y lo guarda como last-known-good', () async {
      final e = (await repo().load(
        screen: 'home',
        segment: 'premium',
      )).valueOrNull!;

      expect(e.source, ExperienceSource.remote);
      expect(title(e), 'remoto');
      expect(cache.values.keys, ['sdui.lkg.home.premium']);
    });

    test('remoto falla -> last-known-good del segmento', () async {
      cache.values['sdui.lkg.home.premium'] = jsonEncode(_doc('guardado'));
      remote.next = const Result.err(NetworkFailure());

      final e = (await repo().load(
        screen: 'home',
        segment: 'premium',
      )).valueOrNull!;

      expect(e.source, ExperienceSource.cache);
      expect(title(e), 'guardado');
      expect(e.remoteFailure, isA<NetworkFailure>());
    });

    test('no mezcla segmentos: sin caché propia usa el embebido', () async {
      cache.values['sdui.lkg.home.premium'] = jsonEncode(_doc('de otro'));
      remote.next = const Result.err(NetworkFailure());

      final e = (await repo().load(
        screen: 'home',
        segment: 'young_digital',
      )).valueOrNull!;

      expect(e.source, ExperienceSource.bundled);
      expect(title(e), 'embebido');
    });

    test('remoto con contrato roto -> fallback y no pisa la caché', () async {
      cache.values['sdui.lkg.home.premium'] = jsonEncode(_doc('guardado'));
      remote.next = const Result.ok({'schemaVersion': 99});

      final e = (await repo().load(
        screen: 'home',
        segment: 'premium',
      )).valueOrNull!;

      expect(e.source, ExperienceSource.cache);
      expect(
        jsonDecode(cache.values['sdui.lkg.home.premium']!),
        _doc('guardado'),
      );
    });

    test('caché corrupta -> embebido', () async {
      cache.values['sdui.lkg.home.premium'] = '{no es json';
      remote.next = const Result.err(TimeoutFailure());

      final e = (await repo().load(
        screen: 'home',
        segment: 'premium',
      )).valueOrNull!;

      expect(e.source, ExperienceSource.bundled);
    });

    test('sin nada disponible -> error', () async {
      remote.next = const Result.err(NetworkFailure());
      bundled = null;

      final r = await repo().load(screen: 'home', segment: 'premium');

      expect(r.isErr, isTrue);
    });
  });

  group('HomeCubit', () {
    late DateTime now;

    HomeCubit cubit() => HomeCubit(repo(), segment: 'premium', now: () => now);

    setUp(() => now = DateTime(2026, 10, 5, 12));

    test('carga y respeta el ttl', () async {
      final c = cubit();
      await c.start();
      expect(c.state, isA<HomeLoaded>());

      now = now.add(const Duration(seconds: 100));
      await c.refresh();
      expect(remote.calls, 1, reason: 'dentro del ttl no vuelve a pedir');

      now = now.add(const Duration(seconds: 300));
      await c.refresh();
      expect(remote.calls, 2);
    });

    test('pull-to-refresh fuerza la recarga aunque no venza el ttl', () async {
      final c = cubit();
      await c.start();
      remote.next = Result.ok(_doc('nuevo'));

      await c.refresh(force: true);

      expect(remote.calls, 2);
      expect(title((c.state as HomeLoaded).experience), 'nuevo');
    });

    test('si el refresh falla conserva lo que mostraba', () async {
      final c = cubit();
      await c.start();
      remote.next = const Result.err(NetworkFailure());

      await c.refresh(force: true);

      final state = c.state as HomeLoaded;
      expect(title(state.experience), 'remoto');
      expect(state.experience.source, ExperienceSource.cache);
    });
  });
}
