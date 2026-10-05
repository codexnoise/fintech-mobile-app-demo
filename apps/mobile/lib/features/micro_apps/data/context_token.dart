import 'package:nexo_core/nexo_core.dart';

/// `POST /micro-apps/context-token`: JWT de 5 min con claims mínimos para la
/// micro-app. Nunca se comparte el ID token del banco.
Future<Result<String>> fetchContextToken(ApiClient api, String appId) =>
    api.post(
      '/micro-apps/context-token',
      body: {'appId': appId},
      decode: (json) => (json! as Map)['token'] as String,
    );
