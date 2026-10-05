import 'dart:convert';

import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/experience.dart';

/// Cascada: BFF -> last-known-good (por segmento) -> JSON embebido.
final class CascadingExperienceRepository implements ExperienceRepository {
  CascadingExperienceRepository({
    required this._fetchRemote,
    required this._cache,
    required this._loadBundled,
    required this._parser,
    required this._appVersion,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// `GET /experience?screen=…&appVersion=…` con el [ApiClient].
  static Future<Result<Object?>> Function(String) remoteFrom(
    ApiClient api,
    String appVersion,
  ) =>
      (screen) => api.get(
        '/experience',
        query: {'screen': screen, 'appVersion': appVersion},
        decode: (json) => json,
      );

  final Future<Result<Object?>> Function(String) _fetchRemote;
  final ExperienceCache _cache;
  final Future<String> Function(String) _loadBundled;
  final SduiParser _parser;
  final String _appVersion;
  final DateTime Function() _now;

  static String cacheKey(String screen, String segment) =>
      'sdui.lkg.$screen.$segment';

  @override
  Future<Result<Experience>> load({
    required String screen,
    required String segment,
  }) async {
    final key = cacheKey(screen, segment);

    final Failure remoteFailure;
    switch (await _fetchRemote(screen)) {
      case Ok(:final value):
        final parsed = _tryParse(value);
        if (parsed != null) {
          // Solo se guarda lo que pasó el parser: la caché nunca tiene basura.
          await _cache.write(key, jsonEncode(value));
          return Result.ok(_experience(parsed, ExperienceSource.remote));
        }
        remoteFailure = const ServerFailure(code: 'invalid_sdui_document');
      case Err(:final failure):
        remoteFailure = failure;
    }

    final cached = _tryParse(_decode(await _cache.read(key)));
    if (cached != null) {
      return Result.ok(
        _experience(cached, ExperienceSource.cache, remoteFailure),
      );
    }

    try {
      final bundled = _tryParse(_decode(await _loadBundled(screen)));
      if (bundled != null) {
        return Result.ok(
          _experience(bundled, ExperienceSource.bundled, remoteFailure),
        );
      }
    } on Object {
      // Sin asset embebido: se reporta el error del remoto.
    }
    return Result.err(remoteFailure);
  }

  Experience _experience(
    SduiParseResult parsed,
    ExperienceSource source, [
    Failure? remoteFailure,
  ]) => Experience(
    document: parsed.document,
    source: source,
    loadedAt: _now(),
    warnings: parsed.warnings,
    remoteFailure: remoteFailure,
  );

  SduiParseResult? _tryParse(Object? json) {
    if (json == null) return null;
    try {
      return _parser.parse(json, appVersion: _appVersion);
    } on SduiFormatException {
      return null;
    }
  }

  static Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// Caché en shared_preferences. Contiene el nombre del usuario (saludo), así
/// que se borra al cerrar sesión.
final class SharedPrefsExperienceCache implements ExperienceCache {
  SharedPrefsExperienceCache([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _prefix = 'sdui.lkg.';

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> clear() async {
    final keys = await _prefs.getKeys();
    for (final key in keys.where((k) => k.startsWith(_prefix))) {
      await _prefs.remove(key);
    }
  }
}
