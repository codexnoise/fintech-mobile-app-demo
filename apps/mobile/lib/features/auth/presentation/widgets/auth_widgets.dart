import 'package:flutter/material.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

/// Campo de contraseña con botón para mostrar/ocultar.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    required this.validator,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// Encabezado con marca para las pantallas de acceso (Stitch: login).
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: NexoColors.brand,
              borderRadius: BorderRadius.all(Radius.circular(NexoRadius.md)),
            ),
            child: Padding(
              padding: EdgeInsets.all(NexoSpacing.md),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: NexoColors.onBrand,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: NexoSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: NexoSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: NexoColors.onSurfaceMuted),
        ),
      ],
    );
  }
}
