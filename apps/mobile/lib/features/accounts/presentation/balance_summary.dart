import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'accounts_cubit.dart';
import 'widgets/account_widgets.dart';

/// Slot `balance_summary` del home SDUI: los saldos salen de Firestore, nunca
/// del documento SDUI.
class BalanceSummary extends StatelessWidget {
  const BalanceSummary({this.showAccounts = true, super.key});

  final bool showAccounts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<AccountsCubit, AccountsState>(
      builder: (context, state) => switch (state) {
        AccountsLoading() => const AccountCardSkeleton(),
        AccountsError(:final failure) => StatusBanner.error(
          'No pudimos cargar tus saldos. ${failure.userMessage}',
          action: TextButton(
            onPressed: context.read<AccountsCubit>().retry,
            child: const Text('Reintentar'),
          ),
        ),
        AccountsLoaded(:final accounts, :final isStale) => Card(
          child: Padding(
            padding: const EdgeInsets.all(NexoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStale
                      ? 'Saldo total (sin conexión)'
                      : 'Saldo total disponible',
                  style: text.labelLarge?.copyWith(
                    color: NexoColors.onSurfaceMuted,
                  ),
                ),
                MoneyText(
                  _total(accounts),
                  semanticsPrefix: 'Saldo total disponible',
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NexoColors.onSurface,
                  ),
                ),
                if (showAccounts) ...[
                  const SizedBox(height: NexoSpacing.sm),
                  for (final account in accounts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: kMinTapTarget,
                      title: Text(account.alias),
                      subtitle: Text(account.maskedNumber),
                      trailing: MoneyText(
                        account.balance,
                        semanticsPrefix: 'Saldo de ${account.alias}',
                        style: text.titleMedium,
                      ),
                      onTap: () => context.push(NexoRoutes.account(account.id)),
                    ),
                ],
              ],
            ),
          ),
        ),
      },
    );
  }

  static Money _total(List<Account> accounts) => accounts.fold(
    const Money.zero(),
    (sum, a) => a.balance.currency == sum.currency ? sum + a.balance : sum,
  );
}
