# Arquitectura — Nexo

Nexo es el núcleo de una **plataforma financiera digital componible**: un shell móvil Flutter
seguro que orquesta dominios independientes (identidad, cuentas, transferencias, experiencias,
micro-apps). La experiencia se **compone desde el servidor** (SDUI) según el segmento y el
comportamiento del cliente, terceros se integran como **micro-apps aisladas**, y todo lo que
mueve dinero o identidad es **determinista y server-side**.

> Decisiones detalladas en [`docs/adr/`](./adr). Contrato del backend en [`docs/api.md`](./api.md).

## 1. Contexto (C4 nivel 1)

```mermaid
flowchart LR
  cliente([Cliente]) -->|usa| app[App móvil Nexo<br/>Flutter]
  negocio([Equipo de negocio / Ops]) -->|publica experiencias,<br/>kill switches, campañas| bff
  app -->|HTTPS + ID token + App Check| bff[BFF<br/>Cloud Functions · Node/TS]
  app -->|lecturas propias, tiempo real, cache offline| fs[(Firestore)]
  app -->|login| auth[Firebase Auth]
  app -->|WebView + bridge v1| micro[Micro-app Viaja Seguro<br/>equipo independiente · Hosting]
  micro -->|introspección de token| bff
  bff --> fs
  bff -->|push por usuario y por segmento| fcm[FCM]
  fcm --> app
  bff -->|structured output, sin PII| gemini[Gemini]
  app -->|crashes, trazas, eventos| obs[Crashlytics · Performance · Analytics]
```

## 2. Contenedores y dependencias del monorepo (C4 nivel 2)

```mermaid
flowchart TB
  subgraph mobile[apps/mobile]
    shell[app shell<br/>bootstrap · DI · router · lifecycle lock]
    features[features/*<br/>auth · onboarding · accounts · transfers ·<br/>experience · micro_apps · notifications · assistant · network_lab]
  end
  subgraph packages[packages/ · versionados con CHANGELOG]
    sdui[nexo_sdui_engine<br/>contrato · parser · registry · renderer]
    ds[nexo_design_system<br/>tokens · theme · componentes]
    core[nexo_core<br/>Money · Result/Failure · ApiClient · resiliencia]
  end
  shell --> features
  features --> sdui & ds & core
  sdui --> ds --> core
```

**Regla de dependencias:** `apps/mobile → packages/*` y `sdui_engine → design_system → core`. Nunca al
revés; las features no se importan entre sí (se comunican por rutas y contratos de `core`).
Cada feature sigue Clean Architecture: `domain` (Dart puro) · `data` (Dio/Firestore → `Result<T>`) ·
`presentation` (Cubit + sealed states).

## 3. Backend: arquitectura hexagonal

```mermaid
flowchart LR
  http[HTTP · Express<br/>request-id · headers · App Check · auth ·<br/>kill switch · zod · error envelope] --> uc[Casos de uso]
  uc --> dom[Dominio puro<br/>segmentación · seed · transfer · insights ·<br/>experience SDUI · assistant]
  uc --> ports{{Puertos}}
  ports --> fb[Adaptadores Firebase<br/>Firestore tx · FCM · Auth · App Check · JWT · Gemini]
  ports --> mem[Adaptadores en memoria<br/>tests deterministas]
```

Toda escritura pasa por el BFF (las reglas de Firestore niegan escrituras del cliente). Las
transferencias corren en una transacción de Firestore con **idempotency key** (TTL 24 h).

## 4. Flujos clave

### 4.1 Home personalizada (SDUI) con cascada de fallback

```mermaid
sequenceDiagram
  participant A as App
  participant B as BFF
  participant F as Firestore
  A->>B: GET /experience?screen=home&appVersion
  B->>F: perfil · movimientos · experiences/{segment}__home · ops/flags
  B->>B: valida config (zod) → si inválida usa default versionado
  B->>B: filtra minAppVersion · kill switches · interpola {{firstName}}, {{insight}}
  B-->>A: documento SDUI
  A->>A: SduiParser (allowlist) → guarda last-known-good
  Note over A: Si falla: last-known-good → default embebido.<br/>La home nunca queda vacía.
```

### 4.2 Transferencia idempotente + push

```mermaid
sequenceDiagram
  participant A as App
  participant B as BFF
  participant F as Firestore
  participant M as FCM
  A->>B: POST /transfers {idempotencyKey (uuid), amountCents}
  B->>F: runTransaction: idempotency? cuentas, límite diario
  alt key ya usada (reintento)
    F-->>B: resultado original
    B-->>A: 200 replayed=true (sin doble débito)
  else nueva
    B->>F: saldos + débito + crédito + idempotency (atómico)
    B-->>A: 201 completed
    B-)M: push "Transferencia exitosa" (best-effort)
  end
  F-->>A: stream de saldos actualizado
```

### 4.3 Micro-app con token de contexto

```mermaid
sequenceDiagram
  participant A as App (WebView host)
  participant B as BFF
  participant W as Micro-app
  A->>B: POST /micro-apps/context-token {appId}
  B-->>A: JWT 5 min (aud=appId, claims mínimos)
  A->>W: carga URL allowlisted
  W-->>A: {v:1, type:'ready'}
  A->>W: window.nexo.receive({context, nonce, token, apiBase})
  W->>B: POST /micro-apps/introspect
  B-->>W: {active, firstName, segment}
  W-->>A: {v:1, type:'quote_accepted', nonce, payload}
  A->>A: valida v/type/nonce → confirmación nativa
```

## 5. Escalamiento y evolución

| Hoy | Evolución |
|---|---|
| Features como módulos internos de la app | Package por feature → equipos dueños de dominio con releases independientes |
| Packages en el mismo repo (pub workspace) | Multirepo con registry privado de packages y versionado semver |
| SDUI con 8 componentes y config por segmento | Versionado/rollback de experiencias, A/B testing, targeting por reglas de comportamiento |
| Micro-apps web en WebView | Micro-apps nativas/Flutter cargadas por feature flag; SDK de bridge publicado para aliados |
| Un proyecto Firebase | Proyectos dev/staging/prod, staged rollout, kill switches por región |
| Core bancario simulado en Firestore | Adaptador del puerto `Ledger` hacia el core real (sin tocar casos de uso) |
