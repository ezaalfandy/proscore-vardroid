# VAR UI Styling Guide – Dark Theme v1.0

> **Project:** Pencak Silat VAR (Android Camera Node + Windows Coordinator)
>
> **Goal:** Consistent, readable, tournament-ready dark UI
>
> **Primary Color:** `#0d02d9`
>
> **Principles:** clarity > aesthetics, low error rate, high contrast, fast scanning

---

## 1) Design Principles

1. **Tournament readability**
   - Large labels, clear status colors, minimal clutter.
   - Prefer *short* text + icons, avoid dense paragraphs.

2. **Consistency via tokens**
   - All colors, spacing, radii, and typography must come from shared tokens.
   - Avoid hard-coded colors per screen.

3. **State-driven UI**
   - Every action has states: idle → working → success/fail.
   - Every device has states: disconnected/connecting/paired/recording/exporting/error.

4. **Low-accident UI**
   - Critical actions (Stop / Unpair / Delete) must be guarded.
   - Make destructive actions red and require confirmation.

---

## 2) Color System

### 2.1 Base Palette (Dark)

| Token | Hex | Usage |
|---|---:|---|
| `color.primary` | `#0d02d9` | Primary buttons, active indicators, focus rings |
| `color.background` | `#0B0B10` | App background |
| `color.surface` | `#12121A` | Cards, panels |
| `color.surfaceAlt` | `#181826` | Elevated panels, tables |
| `color.border` | `#2A2A3A` | Dividers, outlines |
| `color.text` | `#EAEAF2` | Main text |
| `color.textMuted` | `#A9A9BD` | Secondary text |
| `color.iconMuted` | `#9A9AB0` | Secondary icons |

> Notes:
> - Keep surfaces subtly different (background < surface < surfaceAlt).
> - Avoid pure black (`#000`) to reduce eye strain.

### 2.2 Semantic Colors (Status)

| Token | Hex | Meaning |
|---|---:|---|
| `color.success` | `#20C997` | Connected OK, ready, completed |
| `color.warning` | `#FFC107` | Low storage/heat approaching, degraded |
| `color.danger` | `#FF4D4F` | Disconnected, recording failed, destructive |
| `color.info` | `#4DA3FF` | Informational badges |

**Status Dot Rules**
- Disconnected: `danger`
- Connecting: `warning`
- Connected but not paired: `info`
- Paired: `success`
- Recording: `primary` (with pulse)
- Exporting: `info` (with spinner)

### 2.3 Opacity & Overlays

- Backdrop overlay: `rgba(0,0,0,0.55)`
- Disabled content opacity: `0.45` (text/icons), `0.35` (buttons)
- Hover overlay (desktop): `rgba(255,255,255,0.06)`
- Pressed overlay: `rgba(255,255,255,0.10)`

---

## 3) Typography

### 3.1 Font
- Default system font (Flutter default per platform) is acceptable for MVP.
- Avoid custom fonts until UI is stable.

### 3.2 Type Scale (Recommended)

| Style | Size | Weight | Usage |
|---|---:|---:|---|
| `display` | 28 | 700 | Screen titles (Coordinator) |
| `title` | 20 | 700 | Card headers, dialogs |
| `subtitle` | 16 | 600 | Section labels |
| `body` | 14 | 400 | Normal text |
| `caption` | 12 | 500 | Metadata, helper text |
| `mono` | 12 | 500 | IP:port, tokens, debug |

### 3.3 Readability Rules
- Minimum touch UI label size: **14**.
- Status values (battery/temp/storage) should be **14–16**.
- Always use `textMuted` for less important info.

---

## 4) Spacing, Sizing, and Layout

### 4.1 Spacing Scale
Use an 8px scale:
- `space.1 = 4`
- `space.2 = 8`
- `space.3 = 12`
- `space.4 = 16`
- `space.5 = 24`
- `space.6 = 32`

### 4.2 Radius
- `radius.sm = 8`
- `radius.md = 12`
- `radius.lg = 16`

### 4.3 Elevation / Shadows
- Keep shadows subtle in dark theme.
- Prefer bordered surfaces (`border`) over heavy shadows.

### 4.4 Coordinator Layout Rules (Windows)
- Primary layout: **sidebar + main + bottom timeline**
- Grid: 2×2 for cameras (future live preview)
- Keep critical controls always visible (Start/Stop/Mark).

### 4.5 Phone Layout Rules (Android)
- Runtime screen is mostly **fullscreen camera preview**.
- Controls must be at bottom with large hit targets.
- Show status panel (battery/temp/storage/connection) always.

---

## 5) Components Standards

### 5.1 Buttons

**Types**
- Primary: solid `primary`, text `#FFFFFF`
- Secondary: surface button with border
- Danger: solid `danger`
- Ghost: transparent with hover/pressed overlay

**Sizing**
- Minimum height: **44px** (phone), **36px** (desktop)
- Minimum padding: `space.3` horizontal

**Rules**
- Only **one** primary button per panel/dialog.
- Stop Recording is **Danger**.

### 5.2 Iconography
- Use a single icon set across both apps (e.g., Material Symbols).
- Status icons always paired with color + label.

### 5.3 Cards / Panels
- Background: `surface` or `surfaceAlt`
- Border: 1px `border`
- Padding: `space.4`
- Header: `subtitle` or `title`

### 5.4 Badges
- Rounded pill, padding `space.2` x `space.3`
- Use semantic colors lightly (avoid full saturated blocks everywhere).

### 5.5 Tables (Coordinator)
- Use `surfaceAlt` rows
- Row hover: white 6% overlay
- Text: body 14, muted 12 for secondary

---

## 6) States & Feedback

### 6.1 Loading
- Prefer inline spinners + label (e.g., “Connecting…”, “Exporting clip…”)
- Avoid full-screen blocking unless critical.

### 6.2 Toasts / Snackbars
- Success: `success`
- Warning: `warning`
- Error: `danger`

### 6.3 Dialogs
- Background: `surfaceAlt`
- Title: `title`
- Actions right-aligned (desktop), stacked (mobile)
- Destructive actions must require confirmation.

---

## 7) Accessibility & Contrast

- Text on `surface` should maintain high contrast.
- Avoid using only color to convey state; pair with icons/labels.
- Focus ring color: `primary` (visible on dark).
- Minimum touch target: 44×44 (Android).

---

## 8) Branding Rules

### 8.1 Primary Usage
- `#0d02d9` is reserved for:
  - primary CTAs
  - recording indicator animation
  - active navigation
  - selected list item

Avoid using `primary` as a large background to prevent eye fatigue.

### 8.2 Logo / Header
- Coordinator: simple top-left logo + app name.
- Phone: minimal branding; prioritize camera preview.

---

## 9) Flutter Best Practices for UI Consistency

This section defines **how to implement** the styling guide in Flutter so both apps remain consistent.

### 9.1 Single Source of Truth (Design Tokens)

**Rule:** never scatter colors, spacing, radii, and text styles across widgets.

Create a shared package/module (recommended for both apps):
- `packages/var_ui/` (or a shared `lib/ui/` folder copied into both apps)

Suggested structure:
- `app_colors.dart` → all color constants
- `app_spacing.dart` → spacing scale
- `app_radius.dart` → corner radii
- `app_typography.dart` → text styles
- `app_theme.dart` → ThemeData / ColorScheme
- `components/` → reusable widgets

### 9.2 Use ThemeData + ColorScheme (don’t hardcode)

**Best practice:** use Material 3 and define a `ColorScheme` from your tokens.

- Use `Theme.of(context).colorScheme` in widgets
- Use `Theme.of(context).textTheme` for typography

Avoid:
- `Color(0xFF0D02D9)` repeated in widgets
- random `TextStyle(...)` scattered everywhere

### 9.3 Constants vs Theme

Use **constants/tokens** to build the theme, then consume via **Theme**:

- ✅ Tokens (constants): `AppColors.primary`, `AppColors.surface`
- ✅ Theme usage in widgets: `colorScheme.primary`, `colorScheme.surface`

**Rule:** widgets should *prefer* theme lookups unless you’re building the theme itself.

### 9.4 Reusable Components (Composition)

Build the UI using **small reusable components** and composition.

Recommended shared components:
- `StatusDot(status)`
- `VarButton.primary/secondary/danger(...)`
- `VarCard(...)`
- `VarBadge(type, label)`
- `WarningBanner(type, text, action)`
- `DeviceStatusRow(icon, label, value)`
- `ConfirmDialog(title, body, dangerAction)`

**Rule:** Screens should only compose components, not implement styling from scratch.

### 9.5 Widget Style Extensions

To reduce repetition and enforce consistency, use extensions:
- `context.colors` → typed access to colors
- `context.text` → typed access to text styles
- `context.spacing` → common gaps

Example (conceptual):
- `context.colors.primary`
- `context.text.title`

### 9.6 Responsive Layout Best Practices

**Coordinator (Windows):**
- Use `LayoutBuilder` and constraints-based layout
- Keep sidebar width fixed and content flexible
- Avoid hardcoded pixel positions

**Android:**
- Use safe areas and large touch targets
- Keep primary controls in bottom bar
- Ensure UI works in both portrait/landscape if you allow rotation

### 9.7 State-driven UI (Clean Architecture)

Use a clear state model so UI reflects reality:
- Device states: disconnected/connecting/paired/recording/exporting/error
- Clip states: queued/downloading/ready/failed

Recommended patterns:
- `ChangeNotifier` / `ValueNotifier` for MVP
- Riverpod/Bloc later if complexity grows

**Rule:** never let UI infer state from scattered booleans—use a single enum/state object.

### 9.8 Theming for Components

Use these global theme customizations to enforce consistency:
- `InputDecorationTheme`
- `ElevatedButtonThemeData`
- `OutlinedButtonThemeData`
- `CardTheme`
- `DialogTheme`
- `SnackBarThemeData`

### 9.9 UI Performance Best Practices

- Prefer `const` widgets where possible
- Avoid rebuilding video previews unnecessarily
- Use `RepaintBoundary` around heavy areas (e.g., preview)
- Split large screens into smaller widgets

### 9.10 Linting & Review Rules

- Add a lint rule: **no direct Color(...) in UI layer** (except in theme files)
- PR checklist must include:
  - no hard-coded styles
  - uses shared components
  - uses spacing scale

---

## 10) Flutter Theme Tokens (Reference)

> Use these as the single source of truth. Do not hardcode hex values in widgets.

### 10.1 Token Map

- `primary`: `#0d02d9`
- `background`: `#0B0B10`
- `surface`: `#12121A`
- `surfaceAlt`: `#181826`
- `border`: `#2A2A3A`
- `text`: `#EAEAF2`
- `textMuted`: `#A9A9BD`
- `success`: `#20C997`
- `warning`: `#FFC107`
- `danger`: `#FF4D4F`
- `info`: `#4DA3FF`

### 10.2 Theme Implementation Notes
- Prefer Material 3 with consistent `ColorScheme`.
- Define a shared `AppTheme` library used by both apps.
- Centralize:
  - typography
  - component shapes
  - button styles
  - input decoration theme

---

## 11) UI Consistency Checklist

Use this checklist during PR review:

- [ ] No hard-coded colors in widgets (use tokens/theme)
- [ ] Spacing uses the 8px scale
- [ ] Buttons follow type hierarchy (primary/secondary/danger)
- [ ] Status colors follow semantic rules
- [ ] Destructive actions are guarded
- [ ] Text styles use defined type scale
- [ ] Same icon set across apps
- [ ] Recording state is visually unmistakable

---

## 11) Screen-Specific Styling Notes

### 11.1 Coordinator (Windows)
- Device cards show:
  - connection dot + label
  - battery/temp/storage
  - recording indicator
- Mark timeline is always readable and clickable.
- Clip list uses consistent file naming and metadata display.

### 11.2 Camera Node (Android)
- Fullscreen preview with minimal overlays.
- Bottom controls are large, spaced, and lockable.
- Warning banners must be full-width and persistent until resolved.

---

**End of Document – VAR UI Styling Guide – Dark Theme v1.0**

