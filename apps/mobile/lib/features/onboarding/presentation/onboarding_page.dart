import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import '../domain/user_profile.dart';
import 'onboarding_cubit.dart';

const _occupationLabels = {
  Occupation.student: 'Estudiante',
  Occupation.employee: 'Empleado/a',
  Occupation.businessOwner: 'Dueño/a de negocio',
  Occupation.freelancer: 'Independiente',
  Occupation.retired: 'Jubilado/a',
  Occupation.other: 'Otra',
};

const _incomeLabels = {
  IncomeRange.low: 'Hasta USD 1.000 al mes',
  IncomeRange.medium: 'USD 1.000 a 3.000 al mes',
  IncomeRange.high: 'Más de USD 3.000 al mes',
};

const _stepTitles = ['Nombre', 'Perfil', 'Ingresos'];

/// Onboarding en 3 pasos (Stitch: "Onboarding paso 2 de 3").
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _name = TextEditingController();
  final _year = TextEditingController();
  Occupation? _occupation;
  IncomeRange? _income;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    super.dispose();
  }

  void _continue(OnboardingState state) {
    final cubit = context.read<OnboardingCubit>();
    switch (state.step) {
      case 0:
        cubit.submitName(_name.text);
      case 1:
        cubit.submitProfile(
          birthYear: int.tryParse(_year.text),
          occupation: _occupation,
        );
      default:
        cubit.submitIncome(_income);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final step = state.step;
        final busy = state is OnboardingSubmitting || state is OnboardingDone;
        final label = 'Paso ${step + 1} de $onboardingSteps';
        return PopScope(
          canPop: step == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.read<OnboardingCubit>().back();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(label),
              leading: step == 0
                  ? null
                  : BackButton(
                      onPressed: busy
                          ? null
                          : () => context.read<OnboardingCubit>().back(),
                    ),
              automaticallyImplyLeading: false,
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(NexoSpacing.lg),
                children: [
                  Semantics(
                    label: label,
                    value: _stepTitles[step],
                    child: ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: (step + 1) / onboardingSteps,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(NexoRadius.sm),
                      ),
                    ),
                  ),
                  const SizedBox(height: NexoSpacing.lg),
                  Text(
                    switch (step) {
                      0 => '¿Cómo te llamas?',
                      1 => 'Cuéntanos sobre ti',
                      _ => '¿Cuánto ganas al mes?',
                    },
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: NexoSpacing.xs),
                  Text(
                    'Personalizamos tus productos y límites según tu perfil.',
                    style: text.bodyMedium?.copyWith(
                      color: NexoColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: NexoSpacing.lg),
                  if (state case OnboardingEditing(:final error?))
                    FormErrorBanner(error),
                  ...switch (step) {
                    0 => _nameStep(state),
                    1 => _profileStep(state),
                    _ => _incomeStep(),
                  },
                  const SizedBox(height: NexoSpacing.xl),
                  PrimaryButton(
                    label: step == onboardingSteps - 1
                        ? 'Finalizar'
                        : 'Continuar',
                    loading: busy,
                    onPressed: () => _continue(state),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _nameStep(OnboardingState state) => [
    TextFormField(
      key: const ValueKey('firstName'),
      controller: _name,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.givenName],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _continue(state),
      decoration: const InputDecoration(labelText: 'Nombre'),
    ),
  ];

  List<Widget> _profileStep(OnboardingState state) => [
    TextFormField(
      key: const ValueKey('birthYear'),
      controller: _year,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: const InputDecoration(
        labelText: 'Año de nacimiento',
        hintText: 'Ej. 1995',
      ),
    ),
    const SizedBox(height: NexoSpacing.lg),
    Text('Ocupación', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: NexoSpacing.xs),
    Wrap(
      spacing: NexoSpacing.xs,
      runSpacing: NexoSpacing.xs,
      children: [
        for (final MapEntry(key: occupation, value: label)
            in _occupationLabels.entries)
          ChoiceChip(
            label: Text(label),
            selected: _occupation == occupation,
            onSelected: (_) => setState(() => _occupation = occupation),
          ),
      ],
    ),
  ];

  List<Widget> _incomeStep() => [
    RadioGroup<IncomeRange>(
      groupValue: _income,
      onChanged: (value) => setState(() => _income = value),
      child: Column(
        children: [
          for (final MapEntry(key: range, value: label)
              in _incomeLabels.entries)
            RadioListTile<IncomeRange>(value: range, title: Text(label)),
        ],
      ),
    ),
  ];
}
