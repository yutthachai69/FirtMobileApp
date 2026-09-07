---
name: Calm Commerce Control Room
colors:
  surface: '#0c1322'
  surface-dim: '#0c1322'
  surface-bright: '#323949'
  surface-container-lowest: '#070e1d'
  surface-container-low: '#141b2b'
  surface-container: '#191f2f'
  surface-container-high: '#232a3a'
  surface-container-highest: '#2e3545'
  on-surface: '#dce2f7'
  on-surface-variant: '#bcc9cd'
  inverse-surface: '#dce2f7'
  inverse-on-surface: '#293040'
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
  background: '#0c1322'
  on-background: '#dce2f7'
  surface-variant: '#2e3545'
typography:
  headline-lg:
    fontFamily: Noto Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Noto Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 30px
  headline-sm:
    fontFamily: Noto Sans
    fontSize: 17px
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
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  metric-display:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  metric-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  code-telemetry:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-md:
    fontFamily: Noto Sans
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 19px
  label-sm:
    fontFamily: Noto Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  space-2xs: 0.125rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-base: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
  space-2xl: 2rem
  screen-margin: 1rem
  card-padding: 0.875rem
  bottom-bar-height: 4.5rem
  action-button-diameter: 3.5rem
---

## Brand & Style

The design system embodies a calm, mission-critical workspace tailored for high-volume content creators and social commerce operators. The environment rejects flashy, hyperactive gamification in favor of deep atmospheric focus, precise instrumentation, and quiet operational confidence. 

The emotional tone balances high-utility terminal clarity with consumer-grade approachability:
- **Calm Mastery:** Dark, low-glare visual surfaces prevent fatigue during marathon campaign setups and inventory tracking.
- **Precision Telemetry:** Data-dense metrics and SKU trackers feel engineered and authoritative without overwhelming the screen. Telemetry indicators are restricted to a maximum of one subtle micro-tag per screen.
- **Natural Voice:** All Thai interface copy avoids stiff, translated jargon in favor of natural, clear phrasing that resonates with everyday Thai digital entrepreneurs.
- **Anti-Clutter:** No decorative noise, vanity ribbons, or unverified partner badges. Every element serves an active monitoring, editing, or publishing purpose.

Visual movements combine **Modern Dark-Mode Corporate** utility with **Technical Minimalism**, employing micro-surfaces, subtle color temperatures, and crisp hairline separators.

## Colors

The palette establishes an ordered, low-luminance canvas accented by functional, intent-driven signals.

### Canvas & Surface Hierarchy
- **Base Canvas (`#0B0F17`):** The foundational backdrop. Anchors the viewport with deep, low-scattering navy-black.
- **Surface Level 1 (`#111827`):** Base card surfaces, navigation shells, and bottom sheets.
- **Surface Level 2 (`#1E293B`):** Nested interactive groups, input containers, active states, and table headers.
- **Surface Highlight (`#334155`):** Hairline borders, structural dividers, and inactive icon frames.

### Semantic & Accents
- **Primary / Informational (`#06B6D4` - Cyan) & Secondary Info (`#14B8A6` - Teal):** Reserved for telemetry metrics, live sync pulses, active filters, and informational status pills.
- **Action / Command (`#F43F5E` - Rose Coral):** Drives the primary CTA footprint, most notably the center bottom navigation button (สร้าง), batch activations, and urgent attention states.
- **Success / Revenue (`#10B981` - Mint Green):** Applied strictly to completed transactions, verified inventory states, positive conversion spikes, and positive margins.
- **Warning / Stalled (`#F59E0B` - Amber):** Highlights depleted stocks or scheduled posts pending platform approval.

### Text & Icon Luminescence
- **Text High-Emphasis (`#F8FAFC`):** Primary headings, numerical telemetry, and prominent field entries.
- **Text Medium-Emphasis (`#94A3B8`):** Secondary descriptions, meta attributes, timestamps, and resting state icons.
- **Text Low-Emphasis (`#475569`):** SKU keys, table gutters, and disabled states.

## Typography

The dual-type architecture solves for linguistic nuance and analytical density:

1. **Thai Script Engine (Noto Sans Thai):** Applied to all functional Thai copy across headings, titles, descriptions, navigation labels, and standard form controls. Thai script requires dedicated breathing room; hence all Thai typographical levels are strictly calibrated to a line-height ratio between **1.45 and 1.55** to eliminate glyph clipping and vowel collision.
2. **Latin & Data Engine (Inter):** Applied to tabular figures, metrics, currencies (฿, $), alphanumeric SKU tags, percentage deltas, timestamp counts, and system telemetry markers. Inter’s uniform vertical metrics provide razor-sharp tabular alignment across metric columns.
3. **Editorial Rules:** Never set mixed Thai and Latin numbers within a single continuous sentence without baseline stabilization. Natural Thai conversational phrasing must replace literal English translations (e.g., use "ยอดขายวันนี้" instead of "สรุปสถิติยอดจำหน่ายประจำวัน").

## Layout & Spacing

The layout is engineered around an exact logical viewport of **390 × 844 pt** (base iOS mobile viewport), maintaining structural density without visual suffocation.

### Grid & Boundaries
- **Layout Model:** Single-column fluid mobile stack with an internal margin of `16px` (`space-base`).
- **Vertical Rhythm:** Multiples of `4px` and `8px`. Dense telemetry groups use `4px` / `8px` gutters; card separations utilize `12px` (`space-md`) or `16px` (`space-base`).
- **Safe Area Anchors:** Bottom navigation bar maintains a `72px` base height plus device home-indicator clearance (`34px`), preserving a clean touch zone.

### The 5-Point Bottom Navigation Architecture
The bottom navigation bar conforms to strict spatial intervals to accommodate natural thumb reach:
1. **หน้าหลัก (Home):** Col 1 (20% slot). Standard tab item.
2. **สินค้า (Products):** Col 2 (20% slot). Standard tab item.
3. **สร้าง (Create):** Col 3 (Center 20% slot). Hosts an elevated, out-of-flow action element measuring `56px × 56px` vertically shifted by `-18px` relative to the bar baseline.
4. **คอนเทนต์ (Content):** Col 4 (20% slot). Standard tab item.
5. **โปรไฟล์ (Profile):** Col 5 (20% slot). Standard tab item.

## Elevation & Depth

Visual hierarchy within this dark terminal aesthetic avoids heavy, fuzzy drop shadows that produce muddy, dirty edges on high-density OLED screens. Depth is created via **Tonal Stacking** and **Precise Micro-Borders**.

### Layer Stacking Model
- **Level 0 (Backdrop):** `#0B0F17`. Inert visual ground.
- **Level 1 (Card & Module Shells):** `#111827` overlaid with a `1px` inner structural border of `#1E293B`.
- **Level 2 (Active Items & Modals):** `#1E293B` bounded by `#334155` border tint.
- **Level 3 (Elevated Center CTA & Floating Toasts):** `#F43F5E` base on the action button with a tight directional glow: `0px 8px 20px rgba(244, 63, 94, 0.35)`.

### Border Discipline
Every elevated module and list card uses low-contrast outlines: `1px solid rgba(255, 255, 255, 0.06)`. This maintains structural geometry even under low ambient room lighting.

## Shapes

The design system employs a **Rounded** (Level 2) geometry to reconcile professional data density with modern mobile usability:

- **Surface Containers & Cards:** `16px` (`rounded-lg`) corner radii for comfortable visual grouping.
- **Input Fields & Secondary Buttons:** `10px` to `12px` corner radii, providing balanced thumb targets.
- **Elevated Center Create Button:** Pure circular form (`50%` / pill-shaped) to declare its role as the dominant focal point.
- **Micro-Tags & Badges:** `6px` radius for tight, telemetry-style metadata containment.

## Components

### 1. Navigation Bar (5-Point)
- **Bar Container:** Fixed to viewport bottom. Background `#111827` with 94% opacity and `backdrop-filter: blur(16px)`. Border top `1px solid #1E293B`.
- **Standard Tabs (หน้าหลัก, สินค้า, คอนเทนต์, โปรไฟล์):** `24px` outline icon seated above `11px` Thai typography (`Noto Sans`, line-height `16px`). Resting state `#94A3B8`, active state `#06B6D4` with a `3px` cyan active indicator dot below the label.
- **Center "สร้าง" Button:** `56px` diameter circle. Background `#F43F5E` (Rose Coral). Features a crisp white centered `+` icon (`24px`). Rises `-18px` above the top edge of the navigation container. Pressed state shrinks to scale `0.94` with immediate haptic response.

### 2. Micro-Tag / Telemetry Micro-Detail
- Restricted to a maximum of **one** instance per screen to preserve dashboard calmness.
- **Styling:** Height `20px`, horizontal padding `6px`, border-radius `4px`. Background: `rgba(6, 182, 212, 0.08)`, border `1px solid rgba(6, 182, 212, 0.25)`.
- **Content:** Monospaced Latin via Inter (`code-telemetry`, `11px`, `#06B6D4`), displaying real-time metrics such as `SYNC: LIVE` or `SKU: 1,420 ACTIVE`.

### 3. Data Cards & SKU Rows
- **Container:** `#111827` background, `12px` internal padding, `1px solid #1E293B` perimeter.
- **Header:** Product or campaign title in Thai (`Noto Sans`, `14px`, Medium), right-aligned metric values in Inter (`14px`, SemiBold, `#F8FAFC`).
- **Sub-info:** Muted gray SKU code (`#475569`) paired with a live inventory indicator dot (`#10B981` if in stock, `#F59E0B` if running low).

### 4. Input Fields
- **Container:** `#1E293B` background, height `48px`, horizontal padding `12px`. Border `1px solid #334155`.
- **States:** Focus replaces border with `#06B6D4` and adds a subtle glow (`0 0 0 1px #06B6D4`).
- **Thai Input:** Text renders in `Noto Sans` (`14px`), while currency and numeric values render automatically in `Inter`.

### 5. Buttons
- **Primary / Global Action:** Solid `#F43F5E`, white text, height `48px`, font `Noto Sans` (`14px`, SemiBold).
- **Secondary / Telemetry Action:** Background `rgba(6, 182, 212, 0.1)`, border `1px solid #06B6D4`, text `#06B6D4`.
- **Ghost / Neutral:** Background transparent, text `#94A3B8`, hover/pressed `#1E293B`.

### 6. Chips & Filtering
- Height `32px`, horizontal padding `12px`, border-radius `8px`.
- Inactive: `#111827` background, border `1px solid #1E293B`, text `#94A3B8`.
- Active: Background `rgba(6, 182, 212, 0.12)`, border `1px solid #06B6D4`, text `#F8FAFC`. No decorative checkmarks; color and weight communicate selection.