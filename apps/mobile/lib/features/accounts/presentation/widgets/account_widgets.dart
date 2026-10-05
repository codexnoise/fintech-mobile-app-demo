import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import '../../domain/movement.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({required this.account, this.onTap, super.key});

  final Account account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(NexoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      backgroundColor: NexoColors.brandContainer,
                      foregroundColor: NexoColors.brand,
                      child: Icon(switch (account.type) {
                        AccountType.savings => Icons.savings_outlined,
                        _ => Icons.account_balance_wallet_outlined,
                      }),
                    ),
                  ),
                  const SizedBox(width: NexoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.alias, style: text.titleMedium),
                        Text(
                          account.maskedNumber,
                          style: text.bodySmall?.copyWith(
                            color: NexoColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                ],
              ),
              const SizedBox(height: NexoSpacing.md),
              Text(
                'Saldo disponible',
                style: text.labelMedium?.copyWith(
                  color: NexoColors.onSurfaceMuted,
                ),
              ),
              MoneyText(
                account.balance,
                semanticsPrefix: 'Saldo disponible de ${account.alias}',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: NexoColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _categoryLabels = {
  MovementCategory.salary: 'Sueldo',
  MovementCategory.transfer: 'Transferencia',
  MovementCategory.food: 'Alimentación',
  MovementCategory.transport: 'Transporte',
  MovementCategory.shopping: 'Compras',
  MovementCategory.services: 'Servicios',
  MovementCategory.entertainment: 'Entretenimiento',
  MovementCategory.health: 'Salud',
  MovementCategory.other: 'Otros',
};

const _categoryIcons = {
  MovementCategory.salary: Icons.payments_outlined,
  MovementCategory.transfer: Icons.swap_horiz_rounded,
  MovementCategory.food: Icons.shopping_cart_outlined,
  MovementCategory.transport: Icons.directions_car_outlined,
  MovementCategory.shopping: Icons.shopping_bag_outlined,
  MovementCategory.services: Icons.bolt_outlined,
  MovementCategory.entertainment: Icons.movie_outlined,
  MovementCategory.health: Icons.local_hospital_outlined,
  MovementCategory.other: Icons.receipt_long_outlined,
};

class MovementTile extends StatelessWidget {
  const MovementTile(this.movement, {super.key});

  final Movement movement;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final credit = movement.amount.isPositive;
    final time = DateFormat.Hm('es').format(movement.createdAt.toLocal());
    final category = _categoryLabels[movement.category]!;
    return MergeSemantics(
      child: ListTile(
        minTileHeight: kMinTapTarget + 16,
        leading: ExcludeSemantics(
          child: CircleAvatar(
            backgroundColor: credit
                ? NexoColors.brandContainer
                : NexoColors.border,
            foregroundColor: credit ? NexoColors.brand : NexoColors.onSurface,
            child: Icon(_categoryIcons[movement.category]),
          ),
        ),
        title: Text(
          movement.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$time · $category',
          style: text.bodySmall?.copyWith(color: NexoColors.onSurfaceMuted),
        ),
        trailing: MoneyText(
          movement.amount,
          signed: true,
          colorBySign: true,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Placeholder de una tarjeta de cuenta mientras carga.
class AccountCardSkeleton extends StatelessWidget {
  const AccountCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(NexoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 160, height: 18),
          SizedBox(height: NexoSpacing.md),
          Skeleton(width: 220, height: 32),
        ],
      ),
    ),
  );
}
