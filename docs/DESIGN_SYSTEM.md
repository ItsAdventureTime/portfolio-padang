# DESIGN_SYSTEM.md — Padang ERP Lite

## Brand Identity

**Client:** Padang Construction and Supplies Corporation
**Tagline:** Design | Construct | Supply
**Accreditation:** AAA Accredited Contractor (PCAB)

The visual identity is derived directly from the company logo:
a shield-shaped monogram ("PC") in deep black with rich gold/champagne tones,
a gold ribbon banner, and clean bold typography.

---

## Design Philosophy

**Dark-first. Premium. Data-dense but breathable.**

- Glassmorphic navigation chrome (sidebar, top bar) — creates layered depth
- Opaque card surfaces for all data tables and financial figures — ensures legibility
- Gold accents signal authority, trustworthiness, and the brand's AAA status
- Micro-animations enhance perceived responsiveness; never distract from data
- WCAG 2.2 AA minimum contrast on all text

---

## Color Tokens

### Brand Colors (Gold)

| Token | HSL | Hex | Usage |
|---|---|---|---|
| `--color-gold-300` | hsl(44, 65%, 72%) | `#E8C97A` | Subtle highlights |
| `--color-gold-400` | hsl(44, 62%, 55%) | `#D4A843` | Primary CTA, active state indicator |
| `--color-gold-500` | hsl(44, 58%, 48%) | `#C8A84B` | Primary brand gold |
| `--color-gold-600` | hsl(40, 68%, 38%) | `#A8841E` | Hover state |
| `--color-gold-700` | hsl(38, 72%, 30%) | `#8B6914` | Dark gold, badge backgrounds |
| `--color-gold-800` | hsl(36, 70%, 22%) | `#6B4E0F` | Deep gold, pressed state |

### Surface Colors (Dark)

| Token | HSL | Hex | Usage |
|---|---|---|---|
| `--color-surface-950` | hsl(0, 0%, 5%) | `#0D0D0D` | App background |
| `--color-surface-900` | hsl(0, 0%, 10%) | `#1A1A1A` | Sidebar, primary navigation |
| `--color-surface-800` | hsl(0, 0%, 14%) | `#242424` | Card backgrounds, panels |
| `--color-surface-750` | hsl(0, 0%, 17%) | `#2B2B2B` | Elevated cards |
| `--color-surface-700` | hsl(0, 0%, 18%) | `#2E2E2E` | Borders, dividers |
| `--color-surface-600` | hsl(0, 0%, 24%) | `#3D3D3D` | Input backgrounds |
| `--color-surface-500` | hsl(0, 0%, 32%) | `#525252` | Disabled backgrounds |

### Text Colors

| Token | Hex | Usage |
|---|---|---|
| `--color-text-primary` | `#F5F5F5` | Body text, headings |
| `--color-text-secondary` | `#A0A0A0` | Labels, metadata, timestamps |
| `--color-text-tertiary` | `#6B6B6B` | Placeholder text, disabled |
| `--color-text-inverse` | `#0D0D0D` | Text on gold backgrounds |

### Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `--color-success-400` | `#4ADE80` | Completed, paid, on-budget |
| `--color-success-500` | `#22C55E` | Success badges |
| `--color-success-900` | `#14532D` | Success badge background |
| `--color-warning-400` | `#FBBF24` | Pending approval, at-risk |
| `--color-warning-500` | `#F59E0B` | Warning badges |
| `--color-warning-900` | `#451A03` | Warning badge background |
| `--color-error-400` | `#F87171` | Overdue, rejected, over-budget |
| `--color-error-500` | `#EF4444` | Error badges, alerts |
| `--color-error-900` | `#450A0A` | Error badge background |
| `--color-info-400` | `#60A5FA` | Informational, in-progress |
| `--color-info-500` | `#3B82F6` | Info badges |
| `--color-info-900` | `#1E3A5F` | Info badge background |

---

## Typography

### Fonts (Google Fonts)

| Role | Family | Weights | Usage |
|---|---|---|---|
| **Display** | Outfit | 600, 700, 800 | Hero headings, module titles, stat cards |
| **Body / UI** | Inter | 400, 500, 600 | All body text, labels, buttons, navigation |
| **Monospace / Numbers** | JetBrains Mono | 400, 500 | Financial figures, reference numbers, codes |

Import in CSS:
```css
@import url('https://fonts.googleapis.com/css2?family=Outfit:wght@600;700;800&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap');
```

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

## Elevation & Glassmorphism

### Navigation Surfaces (Glassmorphic)

Applied to: sidebar, top navigation bar, modal overlays, dropdown menus.

```css
.glass-surface {
  background: rgba(26, 26, 26, 0.72);
  backdrop-filter: blur(12px) saturate(1.4);
  -webkit-backdrop-filter: blur(12px) saturate(1.4);
  border: 1px solid rgba(200, 168, 75, 0.12);
}
```

### Card Surfaces (Opaque — data-dense content)

Applied to: data tables, financial summaries, form panels, stat cards with detailed data.

```css
.card-surface {
  background: var(--color-surface-800);
  border: 1px solid var(--color-surface-700);
  border-radius: 12px;
}
```

### Stat Cards (Elevated)

Applied to: KPI summary cards on dashboard.

```css
.stat-card {
  background: var(--color-surface-750);
  border: 1px solid var(--color-surface-700);
  border-radius: 12px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.4);
}

.stat-card:hover {
  border-color: rgba(200, 168, 75, 0.35);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.4), 0 0 16px rgba(200, 168, 75, 0.12);
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

- Width: 256px (expanded), 64px (collapsed — icon-only mode)
- Glass surface treatment
- Logo at top (shield mark + wordmark)
- Nav items: icon + label; gold left-border indicator on active item
- Collapse toggle at bottom
- Role badge chip at bottom (user's current role)

### Top Bar (Header)

- Height: 56px
- Glass surface treatment
- Breadcrumb navigation (left)
- Page title (center or left of breadcrumb)
- Demo: role switcher dropdown (right)
- Production: user menu (avatar + name + role) + notifications bell (right)

### Role Switcher (Demo only)

- Prominent in top bar
- Chip-style dropdown: current role in gold, list of all roles
- Switching role reloads current page with role-filtered data

### Status Badges

| Status | Background | Text | Border |
|---|---|---|---|
| Draft | `surface-700` | `text-secondary` | `surface-600` |
| Pending / Submitted | `warning-900` | `warning-400` | `warning-700` |
| GM Approval | `warning-900` | `warning-400` | `warning-700` |
| Approved | `info-900` | `info-400` | `info-700` |
| Issued / Active | `info-900` | `info-400` | `info-700` |
| DCS for Payment | `gold-800` | `gold-400` | `gold-700` |
| Completed / Paid | `success-900` | `success-400` | `success-700` |
| Rejected / Cancelled | `error-900` | `error-400` | `error-700` |
| On Hold | `surface-700` | `text-secondary` | `surface-500` |

### Data Tables

- Full-width, server-side paginated
- Alternating row subtle shading (`surface-800` / `surface-750`)
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
Skeleton color: `surface-700` with shimmer animation (`linear-gradient` sweep).

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
- Focus rings: gold outline (`outline: 2px solid var(--color-gold-400); outline-offset: 2px`)
- Contrast: minimum 4.5:1 for body text; 3:1 for large text and UI components
- All icons have `aria-label` or adjacent visible label
- Tables have proper `<thead>`, `scope` attributes on `<th>`
- Forms have associated `<label>` elements (not placeholder-only)
- Status badges use both color and text (not color alone)
- Modal dialogs trap focus; return focus on close
- Approval confirmation dialogs are `role="alertdialog"`
