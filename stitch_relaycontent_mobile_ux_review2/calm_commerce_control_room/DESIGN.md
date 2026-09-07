---
name: Calm Commerce Control Room
colors:
  surface: '#0f131b'
  surface-dim: '#0f131b'
  surface-bright: '#353941'
  surface-container-lowest: '#0a0e15'
  surface-container-low: '#181c23'
  surface-container: '#1c2027'
  surface-container-high: '#262a32'
  surface-container-highest: '#31353d'
  on-surface: '#dfe2ed'
  on-surface-variant: '#bcc9cd'
  inverse-surface: '#dfe2ed'
  inverse-on-surface: '#2d3038'
  outline: '#869397'
  outline-variant: '#3d494c'
  surface-tint: '#4cd7f6'
  primary: '#4cd7f6'
  on-primary: '#003640'
  primary-container: '#06b6d4'
  on-primary-container: '#00424f'
  inverse-primary: '#00687a'
  secondary: '#ffb2b7'
  on-secondary: '#67001b'
  secondary-container: '#b50036'
  on-secondary-container: '#ffc2c4'
  tertiary: '#4edea3'
  on-tertiary: '#003824'
  tertiary-container: '#1bbd85'
  on-tertiary-container: '#00452e'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#acedff'
  primary-fixed-dim: '#4cd7f6'
  on-primary-fixed: '#001f26'
  on-primary-fixed-variant: '#004e5c'
  secondary-fixed: '#ffdadb'
  secondary-fixed-dim: '#ffb2b7'
  on-secondary-fixed: '#40000d'
  on-secondary-fixed-variant: '#92002a'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#0f131b'
  on-background: '#dfe2ed'
  surface-variant: '#31353d'
typography:
  headline-lg:
    fontFamily: Noto Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Noto Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Noto Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  body-lg:
    fontFamily: Noto Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Noto Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Noto Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-numeric-lg:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.02em
  label-numeric-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: -0.01em
  label-telemetry:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.06em
  label-thai-nav:
    fontFamily: Noto Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-screen: 1.25rem
  gutter-card: 0.75rem
  stack-tight: 0.5rem
  stack-base: 1rem
  stack-loose: 1.5rem
  nav-height: 4.5rem
  nav-item-pad: 0.5rem
  fab-elevate: -1.25rem
---

## Brand & Style

The design system embodies a **Calm Commerce Control Room** aesthetic: high-fidelity, focused, and purposeful. Built for modern Thai e-commerce operators, creators, and multi-channel merchants who orchestrate operations on the move, it balances the disciplined technical precision of an aerospace cockpit with the human warmth of modern digital workspace tools. 

### Emotional Signature
- **Controlled Command:** The UI eliminates erratic alarms, bright neon saturations, and cluttered banners in favor of deliberate, muted surfaces that signal reliability and clarity under pressure.
- **Effortless Precision:** Operational metrics, SKU telemetry, and content sync states read immediately without overwhelming the senses.
- **Tactile Decisiveness:** Actions are grounded, crisp, and responsive, instilling confidence during high-stakes inventory and campaign deployment.

### Aesthetic Foundation
The visual language fuses **Technical Minimalism** with **Subtle Tactile Skeuomorphism**. Dense, purposeful information displays pair with low-contrast structural dividers, micro-status indicators, and precise monospace-aligned numeric readouts. Restraint dictates every interaction: technical micro-labels (e.g., telemetry codes or API scopes) are limited strictly to at most one per primary view, preserving clarity while maintaining an authentic operator feel.

## Colors

The palette uses deep obsidian layers to reduce cognitive fatigue during prolonged operational shifts, paired with purposeful, semantically driven accents.

### Core Semantic Roles
- **Base Canvas (`#090D14`):** The primary deep space background. Establishes deep visual recession.
- **Surface Elevation 1 (`#0E1524`):** Base slate container for cards, list modules, and bottom sheet containers.
- **Surface Elevation 2 (`#151F32`):** Interactive card states, active pills, input fields, and elevated drawers.
- **Border Structural (`#1E293B`):** Low-contrast structural perimeter rules ensuring crisp definition without harsh contrast.
- **Border Focused (`#334155`):** Active outline state for focused inputs and selected cards.

### Functional Accent Palette
- **Telemetry & Information Primary (`#06B6D4` - Cyan):** Reserved for system telemetry, active metrics, operational data points, navigational highlights, and progress states.
- **Creative Action Secondary (`#F43F5E` - Rose):** Reserved exclusively for creative generation, publish actions, elevated trigger buttons, and campaign asset creation.
- **Success & Ready Tertiary (`#10B981` - Mint):** Indicates live sync states, operational inventory health, successful webhooks, and confirmed transactions.
- **Warning State (`#F59E0B` - Amber):** Low stock alerts, draft warnings, and pending synchronizations.

### Text & Iconography Hierarchy
- **Text Primary (`#F8FAFC`):** 98% brightness neutral for primary Thai headlines, labels, and critical values.
- **Text Secondary (`#94A3B8`):** Subtitles, meta-information, and secondary timestamps.
- **Text Muted / Tertiary (`#475569`):** Micro telemetry keys, structural units, and unselected tab labels.

## Typography

The typography strategy leverages a disciplined dual-engine approach to resolve vertical metrics and alignment balance across Thai script and Western telemetry data.

### Dual Engine Rule
- **Noto Sans (Thai):** Applied universally to all Thai language copy, structural headers, navigation labels, human-centric descriptions, tooltips, and modal titles. Ensures legibility of complex tone marks without horizontal truncation or vertical baseline clipping.
- **Inter (Latin & Numeric):** Dedicated to technical strings, numerical totals, currency counts (฿), SKUs, batch references, and system micro-labels. Tabular figures (`tnum`) must be enforced on all Inter instances displaying operational data to guarantee alignment in telemetry tables.

### Composition Guidelines
- Use `label-telemetry` (Inter, 11px uppercase, tracked at `0.06em`) strictly for contextual hardware/system tags (e.g., `SYNC::OK`, `NODE_04`, `LIVE_FEED`). Limit this treatment to a maximum of one anchor tag per viewport to preserve its diagnostic significance.
- Never use bold weights above 600 in Thai typography; legibility is preserved via size and color hierarchy rather than extreme typographical weight.

## Layout & Spacing

The layout is engineered around a core mobile viewport target of **390 × 844 pt** (standard mobile safe frame), scaling adaptively across wider mobile devices through dynamic center clamping.

### Layout Geometry
- **Horizontal Screen Margins:** `20px` (`1.25rem`) fixed gutter from hardware screen boundaries to card perimeters.
- **Vertical Safe Area:** Dedicated top safe buffer of `44px` for hardware notches and dynamic islands; bottom buffer of `34px` beneath navigation to prevent home-indicator collision.
- **Card Spacing:** Dense, vertical rhythm with `12px` (`0.75rem`) separation between adjacent interactive modules.

### Grid & Telemetry Density
Components follow an **8-point system**, with a secondary **4-point micro-scale** for fine badge padding, label gaps, and status pips. Grid layouts within cards use strict dual-column or triple-column modular splits to balance metric counters with their operational Thai descriptive tags.

## Elevation & Depth

Visual hierarchy uses a dark-toned layered architecture combined with precise structural outlines rather than heavy drop shadows.

### Surface Tiers
1. **Level 0 (Canvas):** `#090D14` – Primary app canvas. Flat, unlit.
2. **Level 1 (Card & Module Foundation):** `#0E1524` with a mandatory `1px` border of `#1E293B`. Zero standard box-shadow; physical separation is established strictly through boundary contrast.
3. **Level 2 (Active/Selected Components & Elevated Modals):** `#151F32` with a `1px` border of `#334155` and a subtle ambient occlusion glow: `0px 12px 32px rgba(6, 182, 212, 0.05)`.
4. **Level 3 (Command Layer / Floating Navigation):** `#0E1524` at 92% opacity with a `16px` backdrop blur (glass layer) and an upper boundary border of `1px` `#1E293B`.

### Action Highlighting
Primary action points receive dedicated luminance rather than heavy drop shadows:
- The **Rose Creative Button** utilizes a localized drop-bloom: `0px 8px 24px rgba(244, 63, 94, 0.28)`.
- Live status indicators receive a localized mint radiation: `0px 0px 8px rgba(16, 185, 129, 0.4)`.

## Shapes

The design system maintains a **Level 2 (Rounded)** geometric posture. Corners balance sharp digital precision with ergonomic tactile handling for thumb-driven mobile workflows.

### Geometry Specifications
- **Standard Cards & Surfaces:** `12px` to `16px` (`rounded-lg` / `rounded-xl`) corner radiuses, producing a unified visual contour across vertical streams.
- **Micro Chips, Tags & Telemetry Indicators:** `6px` radius to maintain structural rigidity and an industrial feel.
- **Inputs & Interactive Form Fields:** `10px` radius for focused data entry ergonomics.
- **Central Creative FAB & Round Toggles:** Full pill / circular contour (`9999px`) to immediately separate primary action triggers from structural information boxes.

## Components

### 1. Primary Bottom Navigation (5-Tab Authenticated Navigation)
The bottom dock is fixed at the viewport base with a frosted background (`#0E1524` @ 92% opacity, `backdrop-filter: blur(16px)`), bounded on top by a single `1px` border (`#1E293B`).
- **Tab Items (4 Standard):**
  - **หน้าหลัก (Home)** – Default overview of operations and feed.
  - **สินค้า (Products)** – Catalog, inventory states, SKU lookup.
  - **คอนเทนต์ (Content)** – Scheduled campaigns, video queues, creative feeds.
  - **โปรไฟล์ (Profile)** – Channel integrations, API credentials, settings.
  - *Standard State:* Icon (22px) stacked over label (`label-thai-nav`), colored `#475569`.
  - *Active State:* Cyan accent (`#06B6D4`) applied to both icon and label, accompanied by a `3px` circular cyan pip centered beneath the label.
- **Center Elevated Action (สร้าง / Create):**
  - Raised `20px` above the top boundary line of the nav bar.
  - Circular (`52 × 52px`) container filled with Rose (`#F43F5E`), displaying a solid white 24px plus-pencil icon.
  - Supported by an ambient rose halo: `0px 6px 20px rgba(244, 63, 94, 0.35)`.
  - Accompanied below by the micro-label **สร้าง** in `Noto Sans` 11px medium (`#F8FAFC`).

### 2. Buttons & Triggers
- **Primary Creative Action:** Rose solid (`#F43F5E`), text `#FFFFFF` (`Noto Sans` Medium), 48px height, rounded-lg (`12px`).
- **Secondary Telemetry Action:** Slate background (`#151F32`), outline `1px` `#1E293B`, active icon and text in Cyan (`#06B6D4`).
- **Tertiary Utility Action:** Background transparent, border none, text `#94A3B8`.

### 3. Cards & Information Modules
- **Container:** Background `#0E1524`, border `1px` `#1E293B`, padding `16px`, corner radius `14px`.
- **Card Header:** Title in `Noto Sans` 16px SemiBold (`#F8FAFC`). Optional top-right status dot: 6px Mint (`#10B981`) for ready/synced channels or Amber (`#F59E0B`) for queues requiring attention.
- **Metric Row:** Large digits displayed in `Inter` SemiBold (`label-numeric-lg`), with inline currency symbol `฿` or measurement unit set in muted secondary slate.

### 4. Input Fields
- **Container:** Height `48px`, background `#090D14`, border `1px` `#1E293B`, padding horizontal `14px`. Corner radius `10px`.
- **Focus State:** Border shifts directly to Cyan (`#06B6D4`), inner ring shadow `0 0 0 1px #06B6D4`.
- **Typography:** Thai inputs default to `Noto Sans` 14px Regular (`#F8FAFC`), placeholder `#475569`. SKU and API inputs automatically switch to `Inter` 14px Regular.

### 5. Micro Telemetry Badges
- **Constraint:** **Strictly maximum one per screen view** (typically in the top header app bar).
- **Style:** Compact pill (`padding: 2px 8px`), background `rgba(6, 182, 212, 0.08)`, border `1px solid rgba(6, 182, 212, 0.25)`.
- **Content:** Monospaced uppercase Inter (`10px`), e.g., `SYS_STATUS::READY` or `SYNC_SCOPE:ACTIVE`. Text color `#06B6D4`.

### 6. Chips & Filter Tags
- **Inactive:** `#0E1524` surface, `#1E293B` border, text `#94A3B8` (`Noto Sans` 13px).
- **Selected:** Tinted Cyan fill `rgba(6, 182, 212, 0.12)`, border `#06B6D4`, text `#06B6D4`.

### 7. Selection Controls (Checkboxes & Radios)
- **Checkboxes:** `20 × 20px`, 4px radius, `#090D14` background with `1.5px` border `#1E293B`. Checked state fills `#06B6D4` with white checkmark.
- **Radio Buttons:** `20 × 20px` circular rim `#1E293B`. Checked state reveals a centered `8px` solid mint (`#10B981`) indicator dot.