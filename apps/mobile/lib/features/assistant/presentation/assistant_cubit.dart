import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/assistant.dart';

sealed class AssistantState {
  const AssistantState();
}

/// Esperando que el usuario elija una pregunta.
final class AssistantIdle extends AssistantState {
  const AssistantIdle();
}

final class AssistantLoading extends AssistantState {
  const AssistantLoading(this.prompt);

  final AssistantPrompt prompt;
}

final class AssistantAnswered extends AssistantState {
  const AssistantAnswered(this.prompt, this.answer);

  final AssistantPrompt prompt;
  final AssistantAnswer answer;
}

/// Kill switch o servicio caído (503).
final class AssistantUnavailable extends AssistantState {
  const AssistantUnavailable(this.prompt);

  final AssistantPrompt prompt;
}

final class AssistantError extends AssistantState {
  const AssistantError(this.prompt, this.failure);

  final AssistantPrompt prompt;
  final Failure failure;
}

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(this._repository) : super(const AssistantIdle());

  final AssistantRepository _repository;
  AssistantPrompt? _last;

  /// [initial] viene de la acción SDUI `open_assistant{promptId}` del home.
  Future<void> start({AssistantPrompt? initial}) async {
    if (initial != null) await ask(initial);
  }

  Future<void> ask(AssistantPrompt prompt) async {
    if (state is AssistantLoading) return;
    _last = prompt;
    emit(AssistantLoading(prompt));
    final result = await _repository.ask(prompt);
    emit(switch (result) {
      Ok(:final value) => AssistantAnswered(prompt, value),
      Err(failure: ServiceUnavailableFailure()) => AssistantUnavailable(prompt),
      Err(:final failure) => AssistantError(prompt, failure),
    });
  }

  Future<void> retry() async {
    final prompt = _last;
    if (prompt != null) await ask(prompt);
  }
}
