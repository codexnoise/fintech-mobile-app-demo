import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'accounts_cubit.dart';
import 'widgets/account_widgets.dart';

/// Lista de cuentas propias con saldos en tiempo real.
class AccountsPage extends StatelessWidget {
  const AccountsPage({this.title = 'Mis cuentas', this.actions, super.key});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(NexoRoutes.transferNew),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Transferir'),
      ),
      body: BlocBuilder<AccountsCubit, AccountsState>(
        builder: (context, state) {
          final cubit = context.read<AccountsCubit>();
          return RefreshIndicator(
            onRefresh: cubit.retry,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NexoSpacing.md,
                NexoSpacing.md,
                NexoSpacing.md,
                NexoSpacing.xl * 3,
              ),
              children: switch (state) {
                AccountsLoading() => const [
                  AccountCardSkeleton(),
                  SizedBox(height: NexoSpacing.md),
                  AccountCardSkeleton(),
                ],
                AccountsError(:final failure) => [
                  StatusBanner.error(
                    'No pudimos cargar tus cuentas. ${failure.userMessage}',
                  ),
                  const SizedBox(height: NexoSpacing.md),
                  OutlinedButton.icon(
                    onPressed: cubit.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
                AccountsLoaded(accounts: []) => const [
                  Padding(
                    padding: EdgeInsets.all(NexoSpacing.lg),
                    child: Text(
                      'Aún no tienes cuentas. Si acabas de registrarte, '
                      'espera unos segundos.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                AccountsLoaded(:final accounts, :final isStale) => [
                  if (isStale) ...[
                    const StatusBanner.offline(
                      'Sin conexión. Mostrando los últimos datos guardados '
                      'en tu dispositivo.',
                    ),
                    const SizedBox(height: NexoSpacing.md),
                  ],
                  for (final account in accounts) ...[
                    AccountCard(
                      account: account,
                      onTap: () => context.push(NexoRoutes.account(account.id)),
                    ),
                    const SizedBox(height: NexoSpacing.md),
                  ],
                ],
              },
            ),
          );
        },
      ),
    );
  }
}
