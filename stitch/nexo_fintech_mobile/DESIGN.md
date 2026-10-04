---
name: Nexo Fintech Mobile
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f4'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#eaedff'
  surface-container-high: '#e2e7ff'
  surface-container-highest: '#dae2fd'
  on-surface: '#131b2e'
  on-surface-variant: '#3e4947'
  inverse-surface: '#283044'
  inverse-on-surface: '#eef0ff'
  outline: '#6e7977'
  outline-variant: '#bdc9c6'
  surface-tint: '#006a63'
  primary: '#005c55'
  on-primary: '#ffffff'
  primary-container: '#0f766e'
  on-primary-container: '#a3faef'
  inverse-primary: '#80d5cb'
  secondary: '#55615f'
  on-secondary: '#ffffff'
  secondary-container: '#d8e5e2'
  on-secondary-container: '#5b6765'
  tertiary: '#7f4025'
  on-tertiary: '#ffffff'
  tertiary-container: '#9c573a'
  on-tertiary-container: '#ffe5db'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#9cf2e8'
  primary-fixed-dim: '#80d5cb'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#00504a'
  secondary-fixed: '#d8e5e2'
  secondary-fixed-dim: '#bcc9c6'
  on-secondary-fixed: '#121e1c'
  on-secondary-fixed-variant: '#3d4947'
  tertiary-fixed: '#ffdbce'
  tertiary-fixed-dim: '#ffb598'
  on-tertiary-fixed: '#370e00'
  on-tertiary-fixed-variant: '#72361b'
  background: '#faf8ff'
  on-background: '#131b2e'
  surface-variant: '#dae2fd'
typography:
  display-currency:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.03em
  display-currency-mobile:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.03em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.03em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.75rem
  margin: 1.25rem
  margin-sm: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system establishes a premium, disciplined, and frictionless mobile banking experience tailored to the Ecuadorian market, operating in US Dollars (USD). The design language merges Nordic minimalism with modern Latin American digital banking utility: restrained, dependable, and precision-engineered.

### Target Audience & Emotional Intent
- **Target Audience:** Digital-first professionals, entrepreneurs, and modern consumers in Ecuador requiring dependable account control, local transfers (SPI/PCE), and card management.
- **Emotional Intent:** Unwavering institutional security balanced by immediate tactile simplicity. The UI should instill tranquility, financial clarity, and absolute speed.

### Design Movement: Modern Corporate Minimalism
- **Canvas Purity:** Crisp `#FFFFFF` elevated on neutral slate-tinted canvas `#F6F7F9` to enforce structural hierarchy without heavy shadows.
- **Precision Restraint:** Generous whitespace, razor-thin structural dividers, micro-status pill tags, and deliberate lack of visual clutter.
- **Localization:** Native Latin American Spanish terminology throughout all core financial flows (`Transferir`, `Cuentas`, `Movimientos`, `Tarjetas`, `Pagar servicios`).

## Colors

The palette is anchored by deep teal `#0F766E`, signaling fiscal responsibility, precision, and institutional prestige, paired against high-clarity slate neutrals.

### Palette Architecture
- **Primary Accent (`#0F766E`):** Reserved for core interactive drivers, primary actions, positive states, and verified security cues.
- **Active / Highlight Tint (`#F0FDFA`):** Teal-50 surface fill used for badge containers, active tab fills, transaction category badges, and selected card states.
- **Neutral Canvas (`#F6F7F9`):** Application base background across screen views, separating elevated white containers.
- **Surface Elevation (`#FFFFFF`):** High-priority card containers, modals, bottom sheets, and input fields.
- **Text Headings (`#0F172A`):** Deep slate providing high-contrast readability for monetary balances, modal titles, and section headers.
- **Text Body (`#334155`):** Mid-tone slate for supporting descriptions, transaction counterparts, and metadata.
- **Muted Text & Labels (`#64748B`):** Secondary metadata, timestamps, input placeholders, and inactive tab labels.
- **Structural Outlines (`#E2E8F0`):** Uniform 1px hairline perimeter borders to define cards, inputs, and list dividers.
- **Functional Semantics:**
  - Positive / Credit: `#0F766E` / `#16A34A`
  - Warning / Pending: `#D97706`
  - Negative / Debit / Error: `#DC2626`

## Typography

The type system is powered by Inter, optimized for financial precision, legibility under varied lighting, and monospaced balance rendering.

### Financial Numbers & Currency Display
- **Tabular Numerals:** Apply `font-feature-settings: "tnum" 1` across all balance values, card numbers, transaction listings, and input figures to ensure vertical alignment of digits.
- **Currency Symbols:** The USD indicator (`$`) scales slightly smaller than the integer string (e.g., 24px sign with 32px or 36px numerals) to preserve clean horizontal balance. Cents remain aligned to the baseline.
- **Language Formatting:** Spanish numeric conventions (thousands marked with dot or space, decimals marked with comma, or standard Ecuadorian banking format `$1.250,50`) must be preserved consistently.

## Layout & Spacing

The layout is built mobile-first, targeting modern high-density smartphones with strict adherence to screen edge margins and one-hand touch ergonomics.

### Screen Geometry
- **Outer Canvas Margins:** Strict `20px` (`1.25rem`) padding on standard devices; dynamic adjustment to safe areas (notch, dynamic island, home indicator bar).
- **Vertical Spacing Scale:**
  - Card-to-card gap: `16px` (`space-md`).
  - Section-to-section gap: `24px` to `32px` (`space-lg` to `space-xl`).
  - Balance display header block to action grid: `24px`.
- **Touch Targets:** Minimum touch zone for interactive elements is `44px × 44px`.
- **Form Reflow:** For larger viewports (tablet/desktop previews), the banking surface locks to a maximum centered mobile chassis container of `480px` width, avoiding overstretched transactional forms.

## Elevation & Depth

This system avoids heavy drop shadows and artificial skeuomorphic gradients in favor of **Tonal Layers with Hairline Definition**.

### Hierarchy Through Stacking
- **Base Canvas:** Background color `#F6F7F9` sits at elevation level 0.
- **Surface Level 1 (Cards, Modules, List Blocks):** Solid `#FFFFFF` background with a mandatory subtle 1px border (`#E2E8F0`). Optional ambient shadow: `0 1px 3px rgba(15, 23, 42, 0.04)`.
- **Surface Level 2 (Modals, Action Sheets, Floating Navigation):** Crisp `#FFFFFF` elevated over a 40% `#0F172A` scrim with an ambient blur (`backdrop-filter: blur(8px)`) and a directional soft shadow: `0 12px 32px -4px rgba(15, 23, 42, 0.08)`.
- **Subtle Surface (Active Highlight):** Container backgrounds in `#F0FDFA` do not cast shadows; depth is conveyed solely via tint differentiation against white modules.

## Shapes

The design system enforces a soft, modern curvature centered on `rounded-2xl` (16px / `1rem`) for primary surfaces and containers.

### Curvature Rules
- **Cards, Modals, Action Sheets:** Standardized to `16px` (`rounded-2xl`).
- **Primary Buttons & Field Inputs:** Standardized to `16px` (`rounded-2xl`), matching the card border radii to create continuous visual harmony.
- **Pills, Micro-Badges & Interactive Chips:** Fully circular `9999px` (`rounded-full`) to differentiate transactional meta tags from structural cards.
- **Nested Inner Containers:** Use `12px` (`0.75rem`) for inner items inside cards (e.g., mini transaction icon boxes) to maintain proportional concentric geometry.

## Components

### Buttons
- **Primary Button:** Deep teal background (`#0F766E`), white text (`#FFFFFF`), `16px` roundedness, `52px` height for effortless thumb interaction. Active state shifts to `#115E59`.
- **Secondary Button:** Surface `#F0FDFA`, teal text (`#0F766E`), 1px border in `#CCFBF1`, `16px` roundedness.
- **Ghost Action Button:** Transparent background, slate text (`#334155`), for auxiliary actions like *Ver detalles* or *Cancelar*.

### Balance Hero Card
- Surface: Crisp `#FFFFFF` with 1px border `#E2E8F0`, padding `24px`, `rounded-2xl`.
- Content: Micro-label `Saldo disponible` (`#64748B`, 13px), prominent primary balance `$12,450.80` (`#0F172A`, 36px font-bold, tracking-tight).
- Embedded Quick Actions: 4-column horizontal icon grid (`Transferir`, `Ingresar`, `Tarjetas`, `Pagar`) featuring round 48px icons with `#F0FDFA` background and `#0F766E` iconography.

### Cards & Transaction Lists
- **Transaction Item:** Clean row on `#FFFFFF` surface with 1px bottom divider `#F1F5F9`.
- **Leading Element:** 40px rounded-full avatar or category icon with soft `#F8FAFC` or `#F0FDFA` background.
- **Labels:** Transaction party / merchant in `#0F172A` (`body-md` bold), category and timestamp in `#64748B` (`body-sm`).
- **Trailing Amount:** Credit amounts prefixed with `+` in `#0F766E`, debits prefixed with `-` in `#0F172A`.

### Chips & Micro-Badges
- **Status Tags:** Pill-shaped (`rounded-full`), height `24px`, padding `0 10px`.
  - *Completado / Activa:* Background `#F0FDFA`, text `#0F766E`.
  - *Pendiente:* Background `#FEF3C7`, text `#D97706`.
  - *Rechazado:* Background `#FEE2E2`, text `#DC2626`.

### Input Fields
- Height `52px`, `rounded-2xl` (16px), background `#FFFFFF`, border `1px solid #E2E8F0`.
- Text `#0F172A`, placeholder `#94A3B8`.
- Focus state: Border transitions to `#0F766E` with a 2px outer glow (`rgba(15, 118, 110, 0.15)`).
- Prefix for monetary fields: Fixed non-editable USD glyph (`$`) in `#0F766E`.

### Bottom Navigation Bar
- Fixed bottom dock, white surface `#FFFFFF`, border-top `1px solid #E2E8F0`, height `64px` + device safe inset.
- 4 primary tabs: `Inicio`, `Movimientos`, `Tarjetas`, `Perfil`.
- Active tab uses `#0F766E` filled icon with 11px bold label; inactive tabs use `#64748B` line icons.