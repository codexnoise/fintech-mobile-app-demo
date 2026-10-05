# ADR 0011 — Dinero en enteros (centavos)

Estado: Aceptado · Fecha: 2026-10-04

## Problema

Saldos, movimientos, límites y montos de transferencia se calculan, comparan, persisten y transmiten
entre Dart, TypeScript, Firestore y JSON. Los tipos de punto flotante binario (`double` en Dart,
`number` no entero en JS) no representan exactamente valores como 0,10 y acumulan errores de redondeo,
inaceptables en un contexto bancario y difíciles de auditar.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| `double` | Nativo, cómodo | Errores de redondeo (0,1 + 0,2 ≠ 0,3); comparaciones inseguras |
| Paquete `decimal` / BigDecimal | Exactitud y escala arbitraria | Dependencia extra; serialización como string; JS no tiene equivalente nativo |
| **Entero en unidad menor (centavos) + value object `Money`** | Exacto, nativo en Dart/JS/Firestore/JSON, barato | Conversión explícita para mostrar; no cubre divisas con otra escala sin cambio |

## Opción seleccionada

- **Representación única:** `int` de centavos en todas las capas. Campos `balanceCents` y `amountCents`
  en el dominio del backend (`backend/functions/src/domain/types.ts`) y en Firestore.
- **App:** value object `Money` (`packages/core/lib/src/money.dart`) con `cents: int` y `currency`
  (USD), aritmética que exige misma moneda, comparación y formato determinista;
  `Money.fromTypedDigits` construye montos estilo cajero ("12345" → 123,45) sin parsear separadores
  dependientes del locale y limita la longitud para evitar overflow.
- **Validación en el borde:** el BFF exige `z.number().int().positive()` y `Number.isSafeInteger`
  para `amountCents`; límite por transferencia `maxPerTransferCents: 500_000` (USD 5.000) en
  `backend/functions/src/domain/transfer.ts`. El cliente replica las validaciones solo como UX.
- **Presentación:** `MoneyText` y `AmountField` del design system
  (`packages/design_system/lib/src/components/money.dart`) formatean y exponen un `Semantics` legible
  ("8740 dólares con 25 centavos").
- **Asistente IA:** el modelo debe expresar montos como `amountCents` entero, que se verifica contra
  agregados reales ([ADR 0012](0012-ia-acotada-solo-lectura.md)).

Regla de proyecto (`CLAUDE.md`): nunca `double` para dinero.

## Trade-offs

- **A favor:** sumas y comparaciones exactas; mismo valor en Dart, TS, JSON y Firestore sin conversión.
- **A favor:** errores de tipo visibles: un `double` no compila donde se espera `Money` o `int`.
- **En contra:** hay que convertir explícitamente en la UI (formato y semántica), lo que se concentra
  en el design system.
- **En contra:** `Number.MAX_SAFE_INTEGER` en JS (~9×10^15 centavos) es un límite teórico; se valida
  con `isSafeInteger`.
- **En contra:** asume escala 2; divisas con 0 o 3 decimales requerirían escala por moneda.

## Impacto a largo plazo

- Multi-moneda: extender `Money` con escala por código ISO 4217 sin cambiar la representación entera.
- Cálculos con tasas (intereses, FX) deberán definir política de redondeo explícita (p. ej. bancario)
  en el dominio del backend, nunca en el cliente.
