# Viaja Seguro — micro-app de seguro de viaje

Micro-app de un **aliado / equipo independiente** que se integra al ecosistema Nexo
sin compartir código ni ciclo de release con la app móvil.

- **Stack:** HTML + JS vanilla (sin build). Ciclo de vida propio, desplegado en Firebase Hosting.
- **Integración:** la app la abre en un WebView endurecido (allowlist de host) y se comunican por un
  bridge JSON versionado (`v:1`) con nonce.
- **Identidad:** nunca recibe la sesión del banco. Recibe un **token de contexto** (JWT, 5 min,
  audiencia `travel_insurance`, claims mínimos) y lo valida en `POST /micro-apps/introspect`.
- **Personalización:** el segmento del cliente (claim) aplica un descuento Premium.

## Contrato del bridge (v1)

| Dirección | Mensaje |
|---|---|
| micro-app → app | `{ v:1, type:'ready' }` |
| app → micro-app | `window.nexo.receive({ v:1, type:'context', nonce, token, apiBase })` |
| micro-app → app | `{ v:1, type:'quote_accepted', nonce, payload:{ quoteId, destination, days, travelers, plan, priceCents, discountApplied } }` |
| micro-app → app | `{ v:1, type:'close', nonce }` · `{ v:1, type:'error', nonce, payload:{ code } }` |

La app descarta cualquier mensaje con `v` desconocido, `type` fuera del allowlist o `nonce` distinto.

## Correr local

```
firebase emulators:start --only hosting   # http://127.0.0.1:5000
```
Abierto en un navegador corre en **modo demostración** (sin bridge).
