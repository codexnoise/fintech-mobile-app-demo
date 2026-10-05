import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'session/session_cubit.dart';
import 'session/session_status.dart';

/// Pantalla mientras se resuelve la sesión, o error si el perfil no cargó.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(NexoSpacing.lg),
            child: BlocBuilder<SessionCubit, SessionStatus>(
              builder: (context, status) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nexo',
                    style: text.displaySmall?.copyWith(color: NexoColors.brand),
                  ),
                  const SizedBox(height: NexoSpacing.lg),
                  if (status case SessionProfileUnavailable(
                    :final failure,
                  )) ...[
                    Text(
                      failure.userMessage,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge,
                    ),
                    const SizedBox(height: NexoSpacing.md),
                    FilledButton(
                      onPressed: () => context.read<SessionCubit>().retry(),
                      child: const Text('Reintentar'),
                    ),
                  ] else
                    const CircularProgressIndicator(semanticsLabel: 'Cargando'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
