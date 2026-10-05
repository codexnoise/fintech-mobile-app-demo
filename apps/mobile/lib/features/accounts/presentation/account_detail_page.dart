import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import '../domain/accounts_repository.dart';
import 'account_detail_cubit.dart';
import 'movement_grouping.dart';
import 'widgets/account_widgets.dart';

/// Detalle de cuenta con movimientos agrupados por día (Stitch: pantalla 5).
class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountDetailCubit, AccountDetailState>(
      builder: (context, state) {
        final cubit = context.read<AccountDetailCubit>();
        return Scaffold(
          appBar: AppBar(
            title: Text(switch (state) {
              AccountDetailLoaded(:final account) => account.alias,
              _ => 'Cuenta',
            }),
          ),
          body: switch (state) {
            AccountDetailLoading() => ListView(
              padding: const EdgeInsets.all(NexoSpacing.md),
              children: const [AccountCardSkeleton()],
            ),
            AccountDetailError(:final failure) => _ErrorView(
              message: switch (failure) {
                ValidationFailure(code: accountNotFoundCode) =>
                  'No encontramos esta cuenta.',
                _ => 'No pudimos cargar la cuenta. ${failure.userMessage}',
              },
              onRetry: cubit.retry,
            ),
            AccountDetailLoaded() => _Loaded(state),
          },
        );
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded(this.state);

  final AccountDetailLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountDetailCubit>();
    final text = Theme.of(context).textTheme;
    final account = state.account;
    final movements = state.movements;
    final updatedAt = account.updatedAt;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(NexoSpacing.md),
          sliver: SliverList.list(
            children: [
              if (state.isStale) ...[
                StatusBanner.offline(
                  [
                    'Sin conexión. Mostrando datos guardados.',
                    if (updatedAt != null)
                      relativeUpdatedLabel(updatedAt.toLocal(), DateTime.now()),
                  ].join(' '),
                ),
                const SizedBox(height: NexoSpacing.md),
              ],
              AccountCard(account: account),
              const SizedBox(height: NexoSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  Uri(
                    path: NexoRoutes.transferNew,
                    queryParameters: {'from': account.id},
                  ).toString(),
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Transferir desde esta cuenta'),
              ),
              const SizedBox(height: NexoSpacing.lg),
              Text('Movimientos', style: text.titleLarge),
              if (state.movementsFailure case final failure?) ...[
                const SizedBox(height: NexoSpacing.sm),
                StatusBanner.error(
                  'No pudimos actualizar tus movimientos. '
                  '${failure.userMessage}',
                  action: TextButton(
                    onPressed: cubit.retry,
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (movements == null)
          SliverList.list(
            children: [
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: NexoSpacing.md,
                    vertical: NexoSpacing.xs,
                  ),
                  child: Skeleton(height: 48),
                ),
            ],
          )
        else if (movements.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(NexoSpacing.lg),
              child: Text(
                'Aún no hay movimientos en esta cuenta.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final day in groupMovementsByDay(
            movements,
            now: DateTime.now(),
          )) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NexoSpacing.md,
                  NexoSpacing.md,
                  NexoSpacing.md,
                  NexoSpacing.xs,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    day.label.toUpperCase(),
                    style: text.labelMedium?.copyWith(
                      color: NexoColors.onSurfaceMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: day.movements.length,
              itemBuilder: (_, i) => MovementTile(day.movements[i]),
            ),
          ],
        SliverPadding(
          padding: const EdgeInsets.all(NexoSpacing.md),
          sliver: SliverToBoxAdapter(
            child: state.canLoadMore
                ? OutlinedButton(
                    onPressed: cubit.loadMore,
                    child: const Text('Ver más movimientos'),
                  )
                : state.reachedQueryCap
                ? Text(
                    'Mostramos tus últimos $maxMovementsPerQuery movimientos.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: NexoColors.onSurfaceMuted,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(NexoSpacing.md),
    children: [
      StatusBanner.error(message),
      const SizedBox(height: NexoSpacing.md),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    ],
  );
}
