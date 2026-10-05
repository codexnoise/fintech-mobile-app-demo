# ADR 0012 — IA generativa acotada a un asistente de solo lectura

Estado: Aceptado · Fecha: 2026-10-05

## Problema

La prueba valora el uso responsable de IA. Un asistente financiero puede aportar valor (resumir el mes,
explicar gastos, sugerir ahorro), pero un LLM puede alucinar cifras, ser manipulado por prompt
injection o, si se le permite, generar UI o acciones con efecto sobre el dinero. En banca, cualquier
cifra mostrada debe ser verificable y ninguna acción puede originarse en el modelo.

## Alternativas evaluadas

| Alternativa | Pros | Contras |
|---|---|---|
| Sin IA en el producto | Riesgo cero | Se pierde un caso de uso valioso y el criterio de evaluación |
| IA en flujos transaccionales (p. ej. "transfiere 50 a ahorros") | Experiencia conversacional completa | Riesgo inaceptable: acciones de dinero desde texto no determinista |
| SDK `genui` (A2UI): el LLM emite UI | Interfaces ricas y dinámicas | Alpha; el modelo decide UI/acciones; segundo contrato de UI |
| **Structured output → verificación de cifras → SDUI de solo lectura armado por el servidor** | Determinista en lo crítico, un solo contrato UI, auditable | Menos flexible que UI generativa |

## Opción seleccionada

Asistente en `POST /assistant` (`backend/functions/src/domain/assistant.ts`,
`backend/functions/src/application/use-cases.ts`):

1. **Entrada acotada:** solo prompts predefinidos (`monthly_summary`, `spending_breakdown`,
   `savings_tips`), sin texto libre, lo que reduce la superficie de prompt injection.
2. **Datos mínimos:** el modelo recibe agregados mensuales sin PII, construidos en el servidor. La key
   de Gemini vive en Secret Manager; la app nunca llama al modelo.
3. **Structured output:** Gemini responde con `responseSchema` (`GEMINI_RESPONSE_SCHEMA`) y la
   respuesta se valida con zod (`modelOutputSchema`); el modelo devuelve **contenido**, nunca UI ni
   acciones.
4. **Verificación de cifras:** `verifyModelOutput` compara cada monto (`amountCents` y montos en el
   texto) con los agregados reales; lo no verificable se descarta y se registra
   (`verifiedClaims`/`droppedClaims`).
5. **SDUI de solo lectura:** `buildAssistantDocument` arma en el servidor un documento SDUI con
   componentes sin acciones (`greeting_header`, `insight_card`, `spending_bars`, `tip_list`), que la app dibuja
   con el mismo renderer de [ADR 0005](0005-sdui-propio.md).
6. **Fallback determinista:** sin key (`GEMINI_API_KEY=disabled`), con timeout, error u output
   inválido, se responde con insights calculados en backend (`source: deterministic_fallback`).
   Kill switch `assistantEnabled` y servicio `assistant` en `degradedServices`.

Estado: backend ✅ y desplegado (hoy con fallback determinista porque la key está en `disabled`);
pantalla del asistente en la app ✅ (F11): preguntas predefinidas sin texto libre, respuesta parseada con el mismo
`SduiParser` (allowlist) y dibujada sin acciones, con etiqueta visible del origen de la respuesta.

## Trade-offs

- **A favor:** ninguna cifra no verificada llega al usuario y el modelo no puede disparar acciones.
- **A favor:** sin dependencia de un SDK alpha y sin segundo contrato de UI.
- **En contra:** la experiencia es menos conversacional (chips en vez de texto libre).
- **En contra:** la verificación solo cubre montos; afirmaciones cualitativas incorrectas siguen siendo
  posibles (mitigado por instrucciones de sistema y componentes acotados).
- **En contra:** costo y latencia del modelo; acotados por timeout y fallback.

## Impacto a largo plazo

- El patrón "modelo → contenido estructurado → verificación → UI determinista" se reutiliza para otros
  casos (explicación de cargos, categorización) sin ampliar la superficie de riesgo.
- Evoluciones: caché de respuestas, evaluación offline de calidad, y texto libre solo con
  clasificación de intención y guardrails adicionales; nunca acciones de dinero originadas en el LLM.
