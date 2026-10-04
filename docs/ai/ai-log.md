# Registro de uso de IA

Registro por tarea para medir el impacto real de la IA (productividad, calidad, documentación y pruebas).
Se completa al cerrar cada tarea. Resumen e interpretación en [`ai-usage.md`](./ai-usage.md).

| # | Fecha/hora | Tarea | Herramienta(s) | Estimado sin IA | Real | % generado por IA | Retrabajo / defectos detectados | Nota |
|---|---|---|---|---|---|---|---|---|
| 1 | 2026-10-04 | Spec, plan y decisiones de arquitectura | Claude (Cowork) | 4 h | 1.5 h | 70 % | Ajustes por criterios de evaluación y versión de Flutter | Preguntas de clarificación antes de inferir |
| 2 | 2026-10-04 | Reestructura a monorepo (pub workspace) + rename de bundle id | Claude (Cowork) | 1 h | 0.3 h | 90 % | Lints incompatibles con formatter de Dart 3.7+ removidos | Revisión humana del diff |
| 3 | 2026-10-04 | `nexo_core` (Money, Result/Failure) + tests | Claude (Cowork) | 1 h | 0.3 h | 90 % | Pendiente: validar en CI | Lógica crítica de dinero revisada línea por línea |
| 4 | 2026-10-04 | Parser SDUI seguro + tests | Claude (Cowork) | 1.5 h | 0.4 h | 90 % | — | Allowlist de acciones revisado manualmente |
| 5 | 2026-10-04 | Backend BFF completo (dominio, casos de uso, middleware, adaptadores Firebase/memoria) + 56 tests | Claude (Cowork) | 8 h | 1.5 h | 90 % | 1 defecto detectado por tests (adaptador en memoria devolvía referencias mutables) | Arquitectura hexagonal decidida por el humano; transferencias y middleware revisados línea por línea |
| 6 | 2026-10-04 | Reglas Firestore, config emuladores, micro-app web con bridge, CI/CD | Claude (Cowork) | 3 h | 0.6 h | 85 % | — | Reglas deny-by-default revisadas manualmente |
| 7 | 2026-10-04 | Contrato de API y prompts versionados para bloques Flutter | Claude (Cowork) | 1.5 h | 0.3 h | 80 % | — | Los prompts definen restricciones y criterios de aceptación para el agente local |
