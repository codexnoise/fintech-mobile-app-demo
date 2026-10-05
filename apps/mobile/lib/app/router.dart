import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';

import '../features/accounts/presentation/account_detail_cubit.dart';
import '../features/accounts/presentation/account_detail_page.dart';
import '../features/accounts/presentation/accounts_cubit.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/accounts/presentation/balance_summary.dart';
import '../features/assistant/domain/assistant.dart';
import '../features/assistant/presentation/assistant_cubit.dart';
import '../features/assistant/presentation/assistant_page.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/logout.dart';
import '../features/auth/presentation/biometric_setup_cubit.dart';
import '../features/auth/presentation/biometric_setup_page.dart';
import '../features/auth/presentation/lock_cubit.dart';
import '../features/auth/presentation/lock_page.dart';
import '../features/auth/presentation/login_cubit.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_cubit.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/experience/presentation/home_cubit.dart';
import '../features/experience/presentation/home_page.dart';
import '../features/micro_apps/data/context_token.dart';
import '../features/micro_apps/domain/micro_app.dart';
import '../features/micro_apps/presentation/micro_app_page.dart';
import '../features/network_lab/network_lab_page.dart';
import '../features/notifications/presentation/notification_opt_in.dart';
import '../features/notifications/presentation/push_coordinator.dart';
import '../features/onboarding/presentation/onboarding_cubit.dart';
import '../features/transfers/presentation/transfer_cubit.dart';
import '../features/transfers/presentation/transfer_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import 'env.dart';
import 'placeholder_page.dart';
import 'sdui_actions.dart';
import 'session/session_cubit.dart';
import 'session/session_redirect.dart';
import 'session/session_status.dart';
import 'splash_page.dart';

/// Construye el router. Los guards dependen de [session]; [di] resuelve las
/// dependencias de cada pantalla.
GoRouter buildRouter({
  required AppEnv env,
  required SessionCubit session,
  required GetIt di,
  String initialLocation = NexoRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: env.isDev,
    refreshListenable: _StreamListenable(session.stream),
    redirect: (_, state) => sessionRedirect(session.state, state.uri),
    routes: [
      GoRoute(path: NexoRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: NexoRoutes.login,
        builder: (_, _) => BlocProvider(
          create: (_) => LoginCubit(di()),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.register,
        builder: (_, _) => BlocProvider(
          create: (_) => RegisterCubit(di()),
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.onboarding,
        builder: (_, _) => BlocProvider(
          create: (_) => OnboardingCubit(di(), di()),
          child: const OnboardingPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.biometricSetup,
        builder: (_, _) => BlocProvider(
          create: (_) => BiometricSetupCubit(di(), di(), di(), di()),
          child: const BiometricSetupPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.lock,
        builder: (_, _) => BlocProvider(
          create: (_) => LockCubit(
            di(),
            di(),
            di(),
            di(),
            method: switch (session.state) {
              SessionLocked(:final method) => method,
              _ => UnlockMethod.password,
            },
          ),
          child: LockPage(email: di<AuthRepository>().currentUser?.email),
        ),
      ),
      GoRoute(
        path: NexoRoutes.home,
        builder: (context, _) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => HomeCubit(
                di(),
                segment: switch (session.state) {
                  SessionReady(:final profile) => profile.segment.wire,
                  _ => 'default',
                },
                analytics: di(),
              )..start(),
            ),
            BlocProvider(create: (_) => AccountsCubit(di())..start()),
          ],
          child: HomePage(
            registry: di(),
            parser: di(),
            errorReporter: di(),
            onAction: dispatchSduiAction,
            header: di.isRegistered<PushCoordinator>()
                ? NotificationOptInCard(coordinator: di())
                : null,
            slots: {
              'balance_summary': (_, component) => BalanceSummary(
                showAccounts: component.props['showAccounts'] != false,
              ),
            },
            actions: [
              if (env.isDev)
                IconButton(
                  tooltip: 'Network Lab',
                  icon: const Icon(Icons.science_outlined),
                  onPressed: () => context.push(NexoRoutes.networkLab),
                ),
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: () => di<LogoutUseCase>()(),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: NexoRoutes.accounts,
        builder: (_, _) => BlocProvider(
          create: (_) => AccountsCubit(di())..start(),
          child: const AccountsPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.accountPattern,
        builder: (_, state) => BlocProvider(
          create: (_) =>
              AccountDetailCubit(di(), accountId: state.pathParameters['id']!)
                ..start(),
          child: const AccountDetailPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.transferNew,
        builder: (_, state) => BlocProvider(
          create: (_) => TransferCubit(
            di(),
            di(),
            di(),
            initialFromId: state.uri.queryParameters['from'],
            analytics: di(),
          )..start(),
          child: const TransferPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.microAppPattern,
        builder: (_, state) {
          final app = microApps[state.pathParameters['appId']];
          return app == null
              ? PlaceholderPage(
                  title: 'Servicio no disponible',
                  location: state.uri,
                )
              : MicroAppPage(
                  app: app,
                  apiBase: env.apiBaseUrl,
                  analytics: di(),
                  fetchToken: (appId) => fetchContextToken(di(), appId),
                );
        },
      ),
      GoRoute(
        path: NexoRoutes.assistant,
        builder: (_, state) => BlocProvider(
          create: (_) => AssistantCubit(di())
            ..start(
              initial: AssistantPrompt.fromWire(
                state.uri.queryParameters['promptId'],
              ),
            ),
          child: AssistantPage(
            registry: di(),
            parser: di(),
            errorReporter: di(),
          ),
        ),
      ),
      // Herramienta de demo: no existe en builds de producción.
      if (env.isDev)
        GoRoute(
          path: NexoRoutes.networkLab,
          builder: (_, _) => NetworkLabPage(chaos: di(), breaker: di()),
        ),
    ],
    errorBuilder: (_, state) =>
        PlaceholderPage(title: 'Página no encontrada', location: state.uri),
  );
}

/// Re-evalúa los redirects cada vez que cambia la sesión.
final class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
