import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/experience.dart';

sealed class HomeState {
  const HomeState();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  const HomeLoaded(this.experience, {this.refreshing = false});

  final Experience experience;
  final bool refreshing;
}

final class HomeError extends HomeState {
  const HomeError(this.failure);

  final Failure failure;
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(
    this._repository, {
    required this.segment,
    this.screen = 'home',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const HomeLoading());

  final ExperienceRepository _repository;
  final String segment;
  final String screen;
  final DateTime Function() _now;

  /// Momento de la última carga remota exitosa (reloj del cubit).
  DateTime? _remoteAt;

  Future<void> start() => _load();

  /// Sin [force] respeta el `ttlSeconds` del documento; pull-to-refresh lo
  /// fuerza para ver cambios publicados al instante.
  Future<void> refresh({bool force = false}) async {
    final current = state;
    if (current is HomeLoaded) {
      final remoteAt = _remoteAt;
      final fresh =
          remoteAt != null &&
          _now().difference(remoteAt) < current.experience.document.ttl;
      if (!force && fresh) return;
      emit(HomeLoaded(current.experience, refreshing: true));
    }
    await _load();
  }

  Future<void> _load() async {
    final result = await _repository.load(screen: screen, segment: segment);
    final current = state;
    switch (result) {
      case Ok(:final value):
        _remoteAt = value.source == ExperienceSource.remote ? _now() : null;
        emit(HomeLoaded(value));
      // Ya había algo en pantalla: mantenerlo.
      case Err() when current is HomeLoaded:
        emit(HomeLoaded(current.experience));
      case Err(:final failure):
        emit(HomeError(failure));
    }
  }
}
