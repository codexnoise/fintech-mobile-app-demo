import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import '../domain/transfer.dart';
import 'transfer_cubit.dart';

/// Transferencia entre cuentas propias (Stitch: pantalla 6).
class TransferPage extends StatelessWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TransferCubit, TransferState>(
      listenWhen: (prev, curr) =>
          curr is TransferReviewing && prev is! TransferReviewing,
      listener: (context, _) => _showConfirmation(context),
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            state is TransferSucceeded
                ? 'Comprobante'
                : 'Entre cuentas propias',
          ),
          automaticallyImplyLeading: state is! TransferSucceeded,
        ),
        body: SafeArea(
          child: switch (state) {
            TransferLoading() => ListView(
              padding: const EdgeInsets.all(NexoSpacing.md),
              children: const [
                Skeleton(height: 88),
                SizedBox(height: NexoSpacing.md),
                Skeleton(height: 88),
                SizedBox(height: NexoSpacing.md),
                Skeleton(height: 140),
              ],
            ),
            TransferLoadFailed(:final failure) => Padding(
              padding: const EdgeInsets.all(NexoSpacing.md),
              child: StatusBanner.error(
                'No pudimos cargar tus cuentas. ${failure.userMessage}',
              ),
            ),
            TransferSucceeded() => _SuccessView(state),
            TransferReady() => _Form(state),
          },
        ),
      ),
    );
  }

  static Future<void> _showConfirmation(BuildContext context) async {
    final cubit = context.read<TransferCubit>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _ConfirmationSheet()),
    );
    // Cerrado por el usuario (arrastre o atrás) antes de confirmar.
    cubit.cancelReview();
  }
}

class _Form extends StatelessWidget {
  const _Form(this.state);

  final TransferReady state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransferCubit>();
    final draft = state.draft;
    final editable = state is TransferEditing || state is TransferMaintenance;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(NexoSpacing.md),
      children: [
        if (!state.online) ...[
          const StatusBanner.offline(offlineTransferMessage),
          const SizedBox(height: NexoSpacing.md),
        ],
        if (state is TransferMaintenance) ...[
          const StatusBanner.maintenance(
            'Las transferencias están en mantenimiento. Tu dinero está '
            'seguro; intenta en unos minutos.',
          ),
          const SizedBox(height: NexoSpacing.md),
        ],
        _AccountSelector(
          label: 'Cuenta de origen',
          account: draft.from,
          accounts: draft.accounts,
          onSelected: editable ? cubit.selectFrom : null,
        ),
        Center(
          child: IconButton.filled(
            tooltip: 'Intercambiar origen y destino',
            onPressed: editable ? cubit.swap : null,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ),
        _AccountSelector(
          label: 'Cuenta de destino',
          account: draft.to,
          accounts: draft.accounts,
          onSelected: editable ? cubit.selectTo : null,
        ),
        const SizedBox(height: NexoSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(NexoSpacing.lg),
            child: Column(
              children: [
                Text(
                  'MONTO A TRANSFERIR',
                  style: text.labelMedium?.copyWith(
                    color: NexoColors.onSurfaceMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: NexoSpacing.sm),
                AmountField(
                  value: draft.amount,
                  enabled: editable,
                  onChanged: cubit.setAmount,
                ),
                const SizedBox(height: NexoSpacing.md),
                Wrap(
                  spacing: NexoSpacing.xs,
                  runSpacing: NexoSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final dollars in const [50, 100, 200])
                      ActionChip(
                        label: Text('+\$$dollars'),
                        tooltip: 'Sumar $dollars dólares',
                        onPressed: editable
                            ? () => cubit.addAmount(Money(dollars * 100))
                            : null,
                      ),
                    ActionChip(
                      label: const Text('Todo'),
                      tooltip: 'Transferir todo el saldo disponible',
                      onPressed: editable ? cubit.setAll : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NexoSpacing.md),
        TextFormField(
          initialValue: draft.note,
          enabled: editable,
          maxLength: maxNoteLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          textCapitalization: TextCapitalization.sentences,
          onChanged: cubit.setNote,
          decoration: const InputDecoration(
            labelText: 'Concepto o detalle (opcional)',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: NexoSpacing.sm),
        if (state case TransferEditing(:final error?)) FormErrorBanner(error),
        PrimaryButton(
          label: 'Revisar transferencia',
          onPressed: editable && state.online ? cubit.review : null,
        ),
      ],
    );
  }
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({
    required this.label,
    required this.account,
    required this.accounts,
    required this.onSelected,
  });

  final String label;
  final Account? account;
  final List<Account> accounts;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final account = this.account;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelected == null ? null : () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.all(NexoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: text.labelMedium?.copyWith(
                  color: NexoColors.onSurfaceMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: NexoSpacing.xs),
              if (account == null)
                const Text('Elige una cuenta')
              else
                Row(
                  children: [
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
                    MoneyText(
                      account.balance,
                      semanticsPrefix: 'Saldo disponible',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NexoSpacing.md),
              child: Text(
                label,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final a in accounts)
              ListTile(
                selected: a.id == account?.id,
                title: Text(a.alias),
                subtitle: Text(a.maskedNumber),
                trailing: MoneyText(a.balance),
                onTap: () => Navigator.pop(sheetContext, a.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) onSelected?.call(id);
  }
}

class _ConfirmationSheet extends StatelessWidget {
  const _ConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocConsumer<TransferCubit, TransferState>(
      listenWhen: (_, curr) =>
          curr is! TransferReviewing && curr is! TransferSubmitting,
      listener: (context, _) => Navigator.of(context).pop(),
      builder: (context, state) {
        if (state is! TransferReady) return const SizedBox.shrink();
        final draft = state.draft;
        final submitting = state is TransferSubmitting;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              NexoSpacing.lg,
              0,
              NexoSpacing.lg,
              NexoSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Confirma tu transferencia', style: text.titleLarge),
                const SizedBox(height: NexoSpacing.md),
                Center(
                  child: MoneyText(
                    draft.amount,
                    semanticsPrefix: 'Monto',
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: NexoSpacing.md),
                _SummaryRow('Desde', draft.from!),
                _SummaryRow('Hacia', draft.to!),
                if (draft.note.trim().isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Concepto'),
                    subtitle: Text(draft.note.trim()),
                  ),
                const SizedBox(height: NexoSpacing.md),
                PrimaryButton(
                  label: 'Confirmar y transferir',
                  loading: submitting,
                  onPressed: context.read<TransferCubit>().confirm,
                ),
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.account);

  final String label;
  final Account account;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text('${account.alias} · ${account.maskedNumber}'),
  );
}

class _SuccessView extends StatelessWidget {
  const _SuccessView(this.state);

  final TransferSucceeded state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final receipt = state.receipt;
    final from = state.draft.from;
    final to = state.draft.to;
    return ListView(
      padding: const EdgeInsets.all(NexoSpacing.lg),
      children: [
        const SizedBox(height: NexoSpacing.lg),
        const Icon(
          Icons.check_circle_rounded,
          color: NexoColors.success,
          size: 72,
          semanticLabel: 'Éxito',
        ),
        const SizedBox(height: NexoSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            'Transferencia exitosa',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: NexoSpacing.md),
        Center(
          child: MoneyText(
            receipt.amount,
            semanticsPrefix: 'Monto transferido',
            style: text.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: NexoSpacing.lg),
        if (from != null)
          ListTile(
            title: Text('Desde ${from.alias}'),
            subtitle: const Text('Nuevo saldo'),
            trailing: MoneyText(receipt.fromBalance),
          ),
        if (to != null)
          ListTile(
            title: Text('Hacia ${to.alias}'),
            subtitle: const Text('Nuevo saldo'),
            trailing: MoneyText(receipt.toBalance),
          ),
        if (receipt.replayed)
          const Padding(
            padding: EdgeInsets.only(top: NexoSpacing.sm),
            child: StatusBanner.maintenance(
              'Esta transferencia ya se había procesado. No se debitó dos '
              'veces.',
            ),
          ),
        const SizedBox(height: NexoSpacing.xl),
        PrimaryButton(
          label: 'Ver cuenta de origen',
          // Home en la base para que "atrás" funcione desde la cuenta.
          onPressed: () => context
            ..go(NexoRoutes.home)
            ..push(NexoRoutes.account(receipt.fromAccountId)),
        ),
        TextButton(
          onPressed: () => context.go(NexoRoutes.home),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}
