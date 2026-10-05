import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

import '../domain/assistant.dart';

final class ApiAssistantRepository implements AssistantRepository {
  const ApiAssistantRepository(this._api, this._parser, this._appVersion);

  final ApiClient _api;
  final SduiParser _parser;
  final String _appVersion;

  @override
  Future<Result<AssistantAnswer>> ask(AssistantPrompt prompt) => _api.post(
    '/assistant',
    body: {'promptId': prompt.wire},
    decode: (json) => parseAssistantAnswer(json, _parser, _appVersion),
  );
}

/// Pasa por el mismo parser que el home: allowlist de tipos y acciones.
AssistantAnswer parseAssistantAnswer(
  Object? json,
  SduiParser parser,
  String appVersion,
) {
  final SduiParseResult parsed;
  try {
    parsed = parser.parse(json, appVersion: appVersion);
  } on SduiFormatException catch (e) {
    throw FormatException(e.message);
  }
  final source = json is Map ? json['source'] : null;
  return AssistantAnswer(
    document: parsed.document,
    generatedByModel: source == 'model',
  );
}
