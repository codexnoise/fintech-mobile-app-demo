import 'package:flutter/material.dart';

/// Design tokens de Nexo. Fuente: diseños de Google Stitch
/// (ver docs/ux.md). Cambiar un token aquí lo propaga a toda la app.
abstract final class NexoColors {
  static const brand = Color(0xFF0F766E); // deep teal
  static const onBrand = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF111827);
  static const onSurfaceMuted = Color(0xFF4B5563); // AA sobre surface
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFB91C1C);
}

abstract final class NexoSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class NexoRadius {
  static const sm = 12.0;
  static const md = 16.0;
}

/// Tamaño mínimo de área táctil (Material / WCAG 2.5.5).
const double kMinTapTarget = 48;
