# UX: principios aplicados

Diseño base en **Google Stitch** (estilo *minimal fintech* claro) traducido a tokens en
`packages/design_system/lib/src/tokens.dart`: un solo color de marca **teal `#0F766E`**, superficies blancas y
gris claro, escala de spacing 4/8/12/16/24/32 y radios 12/16. Ninguna pantalla usa colores ni espaciados
hardcodeados: todo sale de `nexo_design_system` (tema, `StatusBanner`, `SkeletonBox`, componentes de dinero y
formularios).

| Principio | Cómo se aplica (código real) |
|---|---|
| **Jerarquía: el saldo primero** | Los tres homes por segmento (`backend/functions/src/experience/defaults/*__home.json`) empiezan con `greeting_header` → `balance_summary` → acciones. Las acciones frecuentes (transferir, cuentas, micro-app) quedan a 1 tap en `quick_actions`. |
| **Confianza antes de mover dinero** | La transferencia pasa por `TransferEditing` → `TransferReviewing` (resumen en bottom sheet que se confirma explícitamente) → `TransferSubmitting` → `TransferSucceeded`. Montos con formato USD desde `Money` (centavos `int`). Validación en vivo: límite USD 5.000, saldo y cuentas distintas. |
| **Errores en lenguaje humano** | Nunca códigos: `failure_messages.dart` traduce cada `Failure` ("Sin conexión. Revisa tu internet e intenta de nuevo."). Mantenimiento: "Las transferencias están en mantenimiento. Tu dinero está seguro; intenta en unos minutos." Offline: "Las transferencias no se guardan para enviarse después: conéctate e intenta de nuevo." Un 422 muestra el mensaje del BFF. |
| **Estados siempre diseñados** | Skeleton al cargar (home, cuentas, detalle, transferencia); vacío ("Aún no hay movimientos en esta cuenta."); offline/stale con banner ("Sin conexión. Mostrando datos guardados.", "Saldo total (sin conexión)") alimentado por los metadatos de caché de Firestore; mantenimiento cuando el BFF responde 503 (kill switch); error con reintento. Home sin red: "Sin conexión. Mostrando tu inicio guardado." (last-known-good). |
| **Accesibilidad** | Montos con `Semantics` legible (`"8740 dólares con 25 centavos"`, `"menos 84 dólares con 20 centavos"`), tap targets ≥ 48 dp y contraste AA verificados con `meetsGuideline` en el design system y el SDUI (ver [testing](testing.md)). El ícono de débitos se corrigió por contraste tras la prueba en emulador. |
| **Personalización con límites** | El SDUI decide **contenido y orden** del home (8 tipos cerrados: `greeting_header`, `balance_summary`, `quick_actions`, `promo_banner`, `insight_card`, `micro_app_tile`, `tip_list`, `spending_bars`). **No** cambia la navegación principal ni los flujos de dinero: solo hay 3 acciones permitidas (`navigate` a rutas allowlisted, `open_micro_app`, `open_assistant`) y `balance_summary` es un *slot* de la app — los saldos nunca viajan en el documento SDUI. |
| **Permisos en contexto** | La notificación no se pide al arrancar: una tarjeta en el home explica el beneficio ("Entérate al instante de tus movimientos… Nunca te pediremos claves por notificación.") con "Activar notificaciones" / "Ahora no"; si se descarta, no vuelve a insistir. La biometría se ofrece después del onboarding, opcional. |
| **Seguridad visible y sin fricción** | Desbloqueo biométrico al reabrir y auto-lock tras 30 s en background; los deep links de push esperan a que la sesión esté lista (tras `/lock`) para no saltarse el bloqueo. |

Variaciones por segmento: el home **Premium** antepone un `promo_banner` de tono oscuro y un `micro_app_tile`
(seguro de viaje con descuento); **Joven digital** y **Emprendedor** priorizan acciones rápidas e insights.

## Pantallas de referencia (`stitch/`)

| Carpeta | Pantalla |
|---|---|
| `stitch/1._login_biometr_a` | Login con biometría |
| `stitch/2._onboarding_paso_2_de_3` | Onboarding (paso 2 de 3, barra de progreso) |
| `stitch/3._home_cliente_joven_digital` | Home SDUI — Joven digital |
| `stitch/4._home_cliente_premium` | Home SDUI — Premium |
| `stitch/5._detalle_de_cuenta_y_movimientos` | Detalle de cuenta y movimientos |
| `stitch/6._transferencia_entre_cuentas_propias` | Transferencia entre cuentas propias |
| `stitch/7._estados_offline_stale_y_error` | Estados offline, stale y error |
| `stitch/nexo_fintech_mobile` | Sistema de diseño (`DESIGN.md`) |
| `stitch/nexo_logo`, `stitch/close_up_…` | Logo y foto de perfil de ejemplo |

Pendiente (📄): textos escalables verificados a 200 %, tema oscuro, feedback háptico en la confirmación de
transferencias y ocultar contenido en el app switcher (F10).
