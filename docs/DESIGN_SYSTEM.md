# DESIGN_SYSTEM.md — Padang ERP Lite

## Brand Identity

**Client:** Padang Construction and Supplies Corporation
**Tagline:** Design | Construct | Supply
**Accreditation:** AAA Accredited Contractor (PCAB)

The visual identity is derived directly from the company logo:
a full charcoal-and-warm-metallic-gold crest with the PADANG wordmark,
DESIGN | CONSTRUCT | SUPPLY, and AAA ACCREDITED CONTRACTOR.

### Logo source of truth

- Authoritative source: `/photo_2026-08-03_00-36-49.jpg` (the original user-provided 834 × 721 JPG).
- Bundled web derivative: `frontend/public/assets/padang-logo.jpg`, a byte-identical copy of the source retained for static asset delivery. The original JPG remains the source of truth and must not be deleted or replaced.
- The legacy `frontend/public/assets/padang-logo.svg` may remain for historical compatibility, but it is not the active brand mark and must not be used in new UI.
- The source JPG must be visibly used in the desktop sidebar, tablet/sidebar
  treatment, compact mobile header, mobile drawer, login screen, production
  session gate, and metadata/icon treatment. Do not substitute a generic
  monogram or wordmark.

---

## Design Philosophy

**Light-first Enterprise Corporate. Crisp, Professional, Data-dense.**

- Clean white and warm ivory surfaces with a charcoal navigation rail — professional corporate aesthetic
- Crisp, high-contrast table surfaces for financial data legibility
- Warm metallic gold accents (`#C9A24D`, `#E5C778`) derived from the crest and ribbon
- Micro-animations enhance perceived responsiveness; never distract from data
- WCAG 2.2 AA-conscious contrast, visible keyboard focus, and reduced-motion support

### Luna audit interaction pattern (2026-08-14)

The frontend uses a small local adaptation of the responsive, typed, accessible
interaction intent documented by [SmoothUI](https://github.com/educlopez/smoothui):
drawer entry, restrained content stagger, button hover/pressed feedback, table
hover feedback, and loading skeletons use transform/opacity/local CSS motion only
when `prefers-reduced-motion: no-preference` is active. Layouts use a capped
content measure and `100dvh`-safe shell/session heights. No SmoothUI package,
runtime registry, CLI fetch, Motion dependency, or network requirement is used.
Production data states are intentionally quiet: loading, live, error, and empty
states communicate through text and `aria-live`, not decorative effects.

The accessibility baseline is [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/):
semantic labels and status text remain primary, the existing drawer focus trap
and restoration are preserved, and the double-context focus treatment uses a
dark gold ring on light surfaces and a light gold ring on the charcoal rail.

The shared `formatPHP`, `formatDate`, `formatStatus`, and `StatusBadge` helpers
are the canonical register formatting path. Status badges use green for
complete/active states, amber for in-progress/approval states, blue for
informational states, slate for unset states, and red for failure/overdue
states.

---

## Color Tokens

### Brand Colors (warm metallic gold)

| Token | HSL | Hex | Usage |
|---|---|---|---|
| `--color-gold-100` | warm tint | `#FFF7E3` | Demo banner, permission and info surfaces |
| `--color-gold-300` | restrained highlight | `#E5C778` | Focus on charcoal, active indicators, chart highlight |
| `--color-gold-500` | warm metallic | `#C9A24D` | Brand mark, avatar, progress accents |
| `--color-gold-700` | accessible deep gold | `#7D5A16` | Text and links on light surfaces |

### Surface Colors (Light Corporate)

| Token | HSL | Hex | Usage |
|---|---|---|---|
| `--color-surface-50` | warm ivory | `#FBFAF7` | Main app background |
| `--color-surface-100` | warm neutral | `#F3F0EA` | Empty states and soft surfaces |
| `--color-surface-0` | hsl(0, 0%, 100%) | `#FFFFFF` | Card backgrounds, table rows |
| `--color-surface-200` | warm line | `#E7E1D6` | Subtitle/card borders |
| `--color-surface-300` | warm border | `#CFC6B6` | Input and secondary-button borders |
| `--color-surface-400` | warm muted | `#827B70` | Placeholder and tertiary text |

### Charcoal navigation colors

| Token | Hex | Usage |
|---|---|---|
| `--color-charcoal-950` | `#1F1E1B` | Desktop sidebar and mobile drawer |
| `--color-charcoal-900` | `#292724` | Primary buttons and drawer controls |
| `--color-charcoal-800` | `#393631` | Hover/raised charcoal surfaces |
| `--color-charcoal-line` | `#47423A` | Navigation dividers and borders |
| `--color-charcoal-text` | `#F5F0E7` | Navigation text on charcoal |

### Text Colors

| Token | Hex | Usage |
|---|---|---|
| `--color-text-primary` | `#262321` | Primary body text, headings |
| `--color-text-secondary` | `#5C5851` | Subheaders, table headers, labels |
| `--color-text-tertiary` | `#827B70` | Placeholders, secondary metadata |
| `--color-text-inverse` | `#FFFFFF` | Text on dark/gold buttons |

### Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `--color-success-50` | `#F0FDF4` | Success badge background |
| `--color-success-600` | `#16A34A` | Completed, paid, on-budget text |
| `--color-success-700` | `#15803D` | Success badge border/text |
| `--color-warning-50` | `#FFFBEB` | Warning badge background |
| `--color-warning-600` | `#D97706` | Pending approval, at-risk text |
| `--color-warning-700` | `#B45309` | Warning badge border/text |
| `--color-error-50` | `#FEF2F2` | Error badge background |
| `--color-error-600` | `#DC2626` | Overdue, rejected text |
| `--color-error-700` | `#B91C1C` | Error badge border/text |
| `--color-info-50` | `#EFF6FF` | Info badge background |
| `--color-info-600` | `#2563EB` | In-progress, issued text |
| `--color-info-700` | `#1D4ED8` | Info badge border/text |

---

## Typography

### Fonts (Self-Hosted and Build-Offline)

| Role | Family | Weights | Usage |
|---|---|---|---|
| **Display** | Outfit | 600, 700, 800 | Hero headings, module titles, stat cards |
| **Body / UI** | Inter | 400, 500, 600 | All body text, labels, buttons, navigation |
| **Monospace / Numbers** | JetBrains Mono | 400, 500 | Financial figures, reference numbers, codes |

Load the fonts from the Fontsource variable packages listed in
`frontend/package.json`: `@fontsource-variable/outfit`,
`@fontsource-variable/inter`, and `@fontsource-variable/jetbrains-mono`.
The root layout imports their package CSS, and `globals.css` maps the existing
`--font-outfit`, `--font-inter`, and `--font-mono` variables to the packaged
families. The variable `@font-face` declarations provide the full weight
ranges used by the UI.

Font files are therefore supplied by `npm ci` and bundled from local
dependencies during `next build`. The build must not import `next/font/google`
or use a runtime CSS `@import` from Google; browsers make no request to Google
and the CSP can remain same-origin. The local Docker Sandbox build still needs
npm registry access (or an equivalent populated npm cache) to install
dependencies, but the VPS artifact deployment does not run npm and the
Next.js build itself does not need `fonts.googleapis.com` or
`fonts.gstatic.com`.

### Type Scale

| Token | Size | Line Height | Weight | Usage |
|---|---|---|---|---|
| `text-display-xl` | 36px / 2.25rem | 1.2 | 800 | Page hero (Outfit) |
| `text-display-lg` | 28px / 1.75rem | 1.25 | 700 | Section titles (Outfit) |
| `text-display-md` | 22px / 1.375rem | 1.3 | 600 | Module headings (Outfit) |
| `text-heading-lg` | 18px / 1.125rem | 1.4 | 600 | Card titles (Inter) |
| `text-heading-md` | 16px / 1rem | 1.4 | 600 | Sub-headings (Inter) |
| `text-body-lg` | 15px / 0.9375rem | 1.6 | 400 | Body text (Inter) |
| `text-body-md` | 14px / 0.875rem | 1.6 | 400 | Default body (Inter) |
| `text-body-sm` | 13px / 0.8125rem | 1.5 | 400 | Labels, metadata (Inter) |
| `text-body-xs` | 12px / 0.75rem | 1.5 | 400 | Timestamps, footnotes (Inter) |
| `text-mono-md` | 14px / 0.875rem | 1.4 | 400 | Financial figures (JetBrains Mono) |
| `text-mono-sm` | 13px / 0.8125rem | 1.4 | 400 | Reference numbers, codes (JetBrains Mono) |

---

## Spacing Scale

Based on 4px base unit:

| Token | Value |
|---|---|
| `space-1` | 4px |
| `space-2` | 8px |
| `space-3` | 12px |
| `space-4` | 16px |
| `space-5` | 20px |
| `space-6` | 24px |
| `space-8` | 32px |
| `space-10` | 40px |
| `space-12` | 48px |
| `space-16` | 64px |

---

## Elevation and Surfaces

The launch theme is light-first: content, cards, tables, forms, and stat cards
use opaque light surfaces, while the sidebar and mobile drawer use the crest's
charcoal as navigation chrome. This is not a user-selectable dark mode, and no
glassmorphism is part of the product contract.

```css
.navigation-surface {
  background: var(--color-charcoal-950);
  border: 1px solid var(--color-charcoal-line);
}

.card-surface {
  background: var(--color-surface-0);
  border: 1px solid var(--color-surface-200);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.06);
}

.stat-card:hover {
  border-color: var(--color-gold-300);
  box-shadow: 0 4px 14px rgba(15, 23, 42, 0.10);
  transition: border-color 200ms ease, box-shadow 200ms ease;
}
```

---

## Border Radius

| Token | Value | Usage |
|---|---|---|
| `radius-sm` | 6px | Inputs, small badges |
| `radius-md` | 8px | Buttons, table rows |
| `radius-lg` | 12px | Cards, panels |
| `radius-xl` | 16px | Modals, drawers |
| `radius-full` | 9999px | Pills, avatars |

---

## Component Patterns

### Navigation Sidebar

- Width: 256px (expanded), 72px (collapsed — icon-only mode)
- Opaque charcoal navigation surface with subtle warm border
- Official JPG crest at top (shield, PADANG wordmark, tagline, AAA line)
- Nav items: icon + label; gold left-border indicator on active item
- Collapse toggle at bottom
- Role badge chip at bottom (user's current role)

### Top Bar (Header)

- Minimum height: 72px on desktop; compact header controls below 768px
- Opaque light navigation surface with subtle border
- Breadcrumb navigation (left)
- Page title (center or left of breadcrumb)
- Demo: role switcher dropdown (right)
- Production: user menu (avatar + name + role) + notifications bell (right)
- Mobile: menu trigger and compact crest mark remain visible; the breadcrumb
  moves into the drawer context

### Role Switcher (Demo only)

- Prominent in top bar
- Chip-style dropdown: current role in gold, list of all roles
- Switching role reloads current page with role-filtered data

### Status Badges

| Status | Background | Text | Border |
|---|---|---|---|
| Draft | `surface-100` | `text-secondary` | `surface-300` |
| Pending / Submitted | `warning-50` | `warning-700` | `warning-600` |
| GM Approval | `warning-50` | `warning-700` | `warning-600` |
| Approved | `info-50` | `info-700` | `info-600` |
| Issued / Active | `info-50` | `info-700` | `info-600` |
| DCS for Payment | `gold-100` | `gold-700` | `gold-400` |
| Completed / Paid | `success-50` | `success-700` | `success-600` |
| Rejected / Cancelled | `error-50` | `error-700` | `error-600` |
| On Hold | `surface-100` | `text-secondary` | `surface-300` |

### Data Tables

- Full-width, server-side paginated
- Alternating row subtle shading (`surface-0` / `surface-50`)
- Column sort indicators (gold chevrons on active column)
- Row hover: gold left-border flash + subtle background lift
- Selection checkbox: gold accent
- Pagination: previous/next + page numbers; "X of Y records" count
- No horizontal scroll; responsive column hiding at smaller breakpoints
- Bulk actions toolbar appears on selection (sticky above table)

### Forms

- Label above input (never floating label for financial data — too ambiguous)
- Required fields marked with gold asterisk
- Validation errors: `error-400` text below field; `error-500` border
- Multi-step forms: stepper at top (gold filled circle = current step)
- Monetary input: PHP symbol prefix; JetBrains Mono font; comma-formatted

### Approval Action Buttons

- **Approve:** `success-500` background, white text
- **Reject:** `error-500` background, white text
- Reject requires a "Reason" text area (required field)
- Both actions require confirmation dialog

---

## Animations & Transitions

### Page Transitions

Use the **View Transitions API** (`document.startViewTransition`) for route changes.
Fallback: instant if not supported.

```css
::view-transition-old(root) {
  animation: 180ms ease-out fade-out;
}
::view-transition-new(root) {
  animation: 220ms ease-in fade-in;
}
```

### Loading States

Skeleton loaders (not spinners) for all async content.
Skeleton color: `surface-200` with shimmer animation (`linear-gradient` sweep).

### Micro-animations

| Element | Animation | Duration |
|---|---|---|
| Sidebar nav active state | Gold border slides in from left | 150ms ease |
| Stat card hover | Border glow + subtle lift (translateY -2px) | 200ms ease |
| Table row hover | Gold left-border + background | 120ms ease |
| Badge status change | Crossfade | 200ms ease |
| Dropdown open | Scale-in from 95% + fade | 150ms ease-out |
| Modal open | Scale-in from 96% + fade | 200ms ease-out |
| Toast notification | Slide-in from top-right + fade | 250ms ease-out |
| Stats counter on dashboard load | Count-up animation | 800ms ease-out |

### Scroll-Driven Animations

Use CSS `animation-timeline: scroll()` for:
- Dashboard stat cards: subtle fade-up on first scroll into viewport
- Report sections: staggered reveal

---

## PHP Currency Formatting

All monetary values use:
- Symbol: `₱` (U+20B1)
- Thousand separators: comma (`,`)
- Decimal: period (`.`); always 2 decimal places for display
- Negative: parentheses, e.g., `(₱12,345.00)` for accounting display
- Font: JetBrains Mono for tabular alignment

Utility function:
```typescript
formatPHP(amount: number, { negative?: 'parentheses' | 'minus' } = {}): string
```

---

## Icons

Use **Lucide React** (consistent with shadcn/ui default).
Custom construction-specific icons (if needed) as SVG components in `/components/icons/`.

---

## Responsive Breakpoints

| Breakpoint | Min-width | Behavior |
|---|---|---|
| `sm` | 640px | — |
| `md` | 768px | Sidebar collapses to icon-only; table columns reduce |
| `lg` | 1024px | Full sidebar; standard layout |
| `xl` | 1280px | Comfortable reading width |
| `2xl` | 1536px | Max dashboard grid width capped at 1440px |

Mobile (< 640px): sidebar hidden, accessible via hamburger menu (drawer).
Critical financial workflows remain usable at 375px (iPhone SE).

---

## Accessibility (WCAG 2.2 AA)

- All interactive elements keyboard-navigable
- Focus rings: accessible deep-gold outline on light surfaces and restrained gold outline on charcoal (`outline: 3px solid var(--focus-ring); outline-offset: 3px`)
- Contrast: minimum 4.5:1 for body text; 3:1 for large text and UI components
- All icons have `aria-label` or adjacent visible label
- Tables have proper `<thead>`, `scope` attributes on `<th>`
- Forms have associated `<label>` elements (not placeholder-only)
- Status badges use both color and text (not color alone)
- Modal dialogs trap focus; return focus on close
- Approval confirmation dialogs are `role="alertdialog"`
- Motion is optional polish only; drawer/skeleton transitions stop for
  `prefers-reduced-motion: reduce`
