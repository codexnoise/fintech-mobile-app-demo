import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'session/session_cubit.dart';

/// Raíz de la app: tema de Nexo, español, sesión y navegación con go_router.
class NexoApp extends StatelessWidget {
  const NexoApp({required this.router, required this.session, super.key});

  final GoRouter router;
  final SessionCubit session;

  static const locale = Locale('es', 'EC');

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: session,
      child: MaterialApp.router(
        title: 'Nexo',
        debugShowCheckedModeBanner: false,
        theme: NexoTheme.light(),
        locale: locale,
        supportedLocales: const [locale, Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    );
  }
}
