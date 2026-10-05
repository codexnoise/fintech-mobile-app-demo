import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/assistant/data/api_assistant_repository.dart';
import 'package:nexo_mobile/features/assistant/domain/assistant.dart';
import 'package:nexo_mobile/features/assistant/presentation/assistant_cubit.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

final _parser = SduiParser(
  supportedTypes: SduiRegistry.standardTypes,
  allowedRoutes: const {},
  allowedMicroApps: const {},
);

Map<String, Object?> _doc(String source) => {
  'schemaVersion': 1,
  'screen': 'assistant',
  'segment': 'any',
  'version': 'a',
  'ttlSeconds': 60,
  'source': source,
  'components': [
    {
      'id': 'headline',
      'type': 'greeting_header',
      'props': {'title': '¿Cómo voy este mes?'},
    },
    {
      'id': 'tips',
      'type': 'tip_list',
      'props': {
        'items': ['Revisa tus suscripciones'],
      },
    },
  ],
};

class _FakeRepo implements AssistantRepository {
  Result<AssistantAnswer> next = Result.ok(
    parseAssistantAnswer(_doc('model'), _parser, '1.0.0'),
  );
  final asked = <AssistantPrompt>[];

  @override
  Future<Result<AssistantAnswer>> ask(AssistantPrompt prompt) async {
    asked.add(prompt);
    return next;
  }
}

void main() {
  group('parseAssistantAnswer', () {
    test('documento del modelo: cifras verificadas', () {
      final a = parseAssistantAnswer(_doc('model'), _parser, '1.0.0');
      expect(a.generatedByModel, isTrue);
      expect(a.document.components, hasLength(2));
    });

    test('fallback determinista', () {
      final a = parseAssistantAnswer(
        _doc('deterministic_fallback'),
        _parser,
        '1.0.0',
      );
      expect(a.generatedByModel, isFalse);
    });

    test('contrato roto -> FormatException (el ApiClient lo mapea)', () {
      expect(
        () => parseAssistantAnswer({'schemaVersion': 99}, _parser, '1.0.0'),
        throwsFormatException,
      );
    });
  });

  test('promptId desde la ruta', () {
    expect(
      AssistantPrompt.fromWire('savings_tips'),
      AssistantPrompt.savingsTips,
    );
    expect(AssistantPrompt.fromWire('otro'), isNull);
  });

  group('AssistantCubit', () {
    late _FakeRepo repo;
    setUp(() => repo = _FakeRepo());

    blocTest<AssistantCubit, AssistantState>(
      'sin prompt inicial espera la elección del usuario',
      build: () => AssistantCubit(repo),
      act: (c) => c.start(),
      expect: () => <AssistantState>[],
    );

    blocTest<AssistantCubit, AssistantState>(
      'con prompt desde el home pregunta de inmediato',
      build: () => AssistantCubit(repo),
      act: (c) => c.start(initial: AssistantPrompt.monthlySummary),
      expect: () => [
        isA<AssistantLoading>(),
        isA<AssistantAnswered>().having(
          (s) => s.answer.generatedByModel,
          'model',
          isTrue,
        ),
      ],
    );

    blocTest<AssistantCubit, AssistantState>(
      '503 -> asistente no disponible',
      setUp: () => repo.next = const Result.err(ServiceUnavailableFailure()),
      build: () => AssistantCubit(repo),
      act: (c) => c.ask(AssistantPrompt.savingsTips),
      expect: () => [isA<AssistantLoading>(), isA<AssistantUnavailable>()],
    );

    blocTest<AssistantCubit, AssistantState>(
      'otros errores -> error con reintento del mismo prompt',
      setUp: () => repo.next = const Result.err(NetworkFailure()),
      build: () => AssistantCubit(repo),
      act: (c) async {
        await c.ask(AssistantPrompt.spendingBreakdown);
        repo.next = Result.ok(
          parseAssistantAnswer(_doc('deterministic_fallback'), _parser, '1'),
        );
        await c.retry();
      },
      expect: () => [
        isA<AssistantLoading>(),
        isA<AssistantError>(),
        isA<AssistantLoading>(),
        isA<AssistantAnswered>(),
      ],
      verify: (_) => expect(repo.asked, [
        AssistantPrompt.spendingBreakdown,
        AssistantPrompt.spendingBreakdown,
      ]),
    );
  });
}
