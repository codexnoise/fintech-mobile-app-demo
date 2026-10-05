import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

const onboardingSteps = 3;
const _minAge = 18;
const _maxAge = 100;
final _namePattern = RegExp(r"^[\p{L} '-]+$", unicode: true);

/// Lo ingresado hasta ahora; se conserva al volver atrás.
final class OnboardingDraft {
  const OnboardingDraft({
    this.firstName = '',
    this.birthYear,
    this.occupation,
    this.incomeRange,
  });

  final String firstName;
  final int? birthYear;
  final Occupation? occupation;
  final IncomeRange? incomeRange;

  OnboardingDraft copyWith({
    String? firstName,
    int? birthYear,
    Occupation? occupation,
    IncomeRange? incomeRange,
  }) => OnboardingDraft(
    firstName: firstName ?? this.firstName,
    birthYear: birthYear ?? this.birthYear,
    occupation: occupation ?? this.occupation,
    incomeRange: incomeRange ?? this.incomeRange,
  );
}

sealed class OnboardingState {
  const OnboardingState(this.step, this.draft);

  /// Paso actual, base 0.
  final int step;
  final OnboardingDraft draft;
}

final class OnboardingEditing extends OnboardingState {
  const OnboardingEditing(super.step, super.draft, {this.error});

  final String? error;
}

final class OnboardingSubmitting extends OnboardingState {
  const OnboardingSubmitting(super.step, super.draft);
}

/// Perfil creado; la sesión ya fue notificada y el router navega.
final class OnboardingDone extends OnboardingState {
  const OnboardingDone(super.step, super.draft);
}

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._profiles, this._session, {int Function()? currentYear})
    : _currentYear = currentYear ?? (() => DateTime.now().year),
      super(const OnboardingEditing(0, OnboardingDraft()));

  final ProfileRepository _profiles;
  final SessionSignals _session;
  final int Function() _currentYear;

  void submitName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final draft = state.draft.copyWith(firstName: name);
    if (name.length < 2 || name.length > 40 || !_namePattern.hasMatch(name)) {
      return emit(
        OnboardingEditing(
          0,
          draft,
          error: 'Escribe tu nombre (solo letras, 2 a 40 caracteres).',
        ),
      );
    }
    emit(OnboardingEditing(1, draft));
  }

  void submitProfile({
    required int? birthYear,
    required Occupation? occupation,
  }) {
    final draft = state.draft.copyWith(
      birthYear: birthYear,
      occupation: occupation,
    );
    final year = _currentYear();
    final String? error;
    if (birthYear == null) {
      error = 'Ingresa tu año de nacimiento.';
    } else if (birthYear > year - _minAge) {
      error = 'Debes ser mayor de $_minAge años para abrir una cuenta.';
    } else if (birthYear < year - _maxAge) {
      error = 'Revisa tu año de nacimiento.';
    } else if (occupation == null) {
      error = 'Elige tu ocupación.';
    } else {
      error = null;
    }
    emit(OnboardingEditing(error == null ? 2 : 1, draft, error: error));
  }

  Future<void> submitIncome(IncomeRange? incomeRange) async {
    if (state is OnboardingSubmitting || state is OnboardingDone) return;
    final draft = state.draft.copyWith(incomeRange: incomeRange);
    final birthYear = draft.birthYear;
    final occupation = draft.occupation;
    if (incomeRange == null || birthYear == null || occupation == null) {
      return emit(
        OnboardingEditing(2, draft, error: 'Elige tu rango de ingresos.'),
      );
    }

    emit(OnboardingSubmitting(2, draft));
    final result = await _profiles.completeOnboarding(
      OnboardingData(
        firstName: draft.firstName,
        birthYear: birthYear,
        occupation: occupation,
        incomeRange: incomeRange,
      ),
    );
    switch (result) {
      // already_onboarded: el primer intento sí llegó (ej. timeout al volver).
      case Ok() || Err(failure: ValidationFailure(code: 'already_onboarded')):
        emit(OnboardingDone(2, draft));
        await _session.profileChanged();
      case Err(:final failure):
        emit(OnboardingEditing(2, draft, error: failure.userMessage));
    }
  }

  void back() {
    if (state.step == 0 || state is! OnboardingEditing) return;
    emit(OnboardingEditing(state.step - 1, state.draft));
  }
}
