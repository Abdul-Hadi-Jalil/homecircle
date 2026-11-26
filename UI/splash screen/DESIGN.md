---
name: Warm Household Modern
colors:
  surface: '#f9f9ff'
  surface-dim: '#d2daf0'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f3ff'
  surface-container: '#e8edff'
  surface-container-high: '#e0e8fe'
  surface-container-highest: '#dbe2f8'
  on-surface: '#131c2b'
  on-surface-variant: '#444654'
  inverse-surface: '#283041'
  inverse-on-surface: '#edf0ff'
  outline: '#747686'
  outline-variant: '#c4c5d7'
  surface-tint: '#2c50d9'
  primary: '#2248d1'
  on-primary: '#ffffff'
  primary-container: '#4263eb'
  on-primary-container: '#f5f3ff'
  inverse-primary: '#b9c3ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#7ff6bf'
  on-secondary-container: '#00714d'
  tertiary: '#794e00'
  on-tertiary: '#ffffff'
  tertiary-container: '#9a6400'
  on-tertiary-container: '#fff2e6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dde1ff'
  primary-fixed-dim: '#b9c3ff'
  on-primary-fixed: '#001356'
  on-primary-fixed-variant: '#0035be'
  secondary-fixed: '#82f9c1'
  secondary-fixed-dim: '#64dca6'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb5'
  tertiary-fixed-dim: '#ffb956'
  on-tertiary-fixed: '#2a1800'
  on-tertiary-fixed-variant: '#633f00'
  background: '#f9f9ff'
  on-background: '#131c2b'
  surface-variant: '#dbe2f8'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
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
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  margin-tablet: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
  space-2xl: 2rem
---

## Brand & Style

This design system delivers a modern, warm, and intuitive experience tailored for busy households, parents, partners, and multi-generational family members. The interface balances structural clarity with gentle, domestic warmth—avoiding both cold enterprise utility and juvenile gamification. 

The aesthetic is grounded in a refined, modern tactile approach: generous breathing room, friendly rounded surfaces, soft diffuse elevation, and crisp typographic hierarchy. Micro-interactions feel dependable, reassuring, and immediate. The visual atmosphere reduces cognitive load during hectic daily routines, giving families confidence that chores, groceries, inventory, and coordination are effortlessly under control.

## Colors

The palette balances a confident, trustworthy primary blue with lively functional accents for stateful household operations:

- **Primary Blue (`#4263EB`) & Dark Blue (`#2948C7`):** Directs focal action, interactive controls, and active states. `#2948C7` is reserved for pressed states, active navigation indicators, and high-emphasis boundaries.
- **Light Blue Canvas (`#EDF2FF`):** Applied to selected list items, subtle badge fills, and active segmented controls.
- **Background (`#F7F9FC`) & Card Surface (`#FFFFFF`):** Establishes an airy, low-contrast backdrop that separates structural content cards cleanly without harsh borders.
- **Text & Neutral Tiers:** Deep Navy (`#1C2434`) guarantees optimal legibility across high-ambient-light scenarios (e.g., in kitchens or on the go), supported by Slate (`#718096`) for timestamps, metadata, and placeholder copy.
- **Borders (`#E6EBF2`):** Low-contrast architectural containment that remains quiet beneath soft shadows.
- **Status & Priority System:**
  - **Urgent Red (`#E85D65`):** Overdue tasks, critical supplies running out.
  - **Warning / High Orange (`#F2A93B`):** Impending deadlines, shared attention items.
  - **Success Green (`#21A675`):** Completed chores, replenished pantry items.
  - **Low Priority Gray (`#A0AEC0` fill / `#718096` label):** Non-urgent backlog items.

## Typography

Typography relies entirely on **Inter** to ensure maximum legibility at variable distances and sizes. 

- **Display & Large Headlines (`display-lg`, `headline-lg`):** Reserved for screen titles, morning briefings, and hero greeting headers. Uses tighter tracking (`-0.02em` to `-0.015em`) and strong 700 weights to establish immediate anchor points.
- **Section Headings (`headline-md`, `headline-sm`):** Defines module breaks across household dashboards, shopping lists, and assignment boards.
- **Body (`body-lg`, `body-md`):** Built with generous proportional line heights (`1.45` to `1.5`) to maximize scannability for fast reading.
- **Labels & Priority Tags (`label-md`, `label-sm`):** Slightly elevated letter-spacing coupled with semibold and bold weights ensure status pills remain crisp against light tinted backgrounds.

## Layout & Spacing

The layout is constructed on an uncompromising **8px base grid system** (with 4px half-steps for micro-alignments like badge insets and icon paddings):

- **Mobile Viewport Structure:** The primary mobile canvas adheres to a 4-column fluid layout with an outer canvas margin of `16px` (`margin`) and `16px` gutters (`gutter`). On tablet devices and shared household displays, margins expand to `24px` (`margin-tablet`) across an 8-column layout.
- **Touch Target Integrity:** Every interactive zone maintains a mandatory minimum hit area of `48px × 48px`, even when visual icons or chips are smaller, avoiding accidental taps by children or elders.
- **Rhythm & Nesting:** Internal card paddings strictly apply `16px` (`space-md`) or `20px` (`space-lg`), separating header zones from task body lists with `12px` to `16px` gaps. Vertical stacking between unrelated card modules utilizes `16px` or `24px` (`space-2xl`).

## Elevation & Depth

Elevation conveys soft, organic physical presence without heavy, dirty shadows. The depth model blends translucent ambient shadows with low-contrast structural borders:

- **Level 0 (Flat / Canvas):** Applied to the base canvas background (`#F7F9FC`). Zero shadow, zero elevation.
- **Level 1 (Card Default):** Applied to cards, list groups, and input fields.
  - Shadow: `0px 2px 8px -1px rgba(28, 36, 52, 0.04), 0px 1px 3px 0px rgba(28, 36, 52, 0.02)`
  - Border: `1px solid #E6EBF2`
- **Level 2 (Floating Modules & Modals):** Applied to raised task detail sheets, bottom action drawers, and hover/active cards.
  - Shadow: `0px 8px 24px -4px rgba(41, 72, 199, 0.08), 0px 4px 12px -2px rgba(28, 36, 52, 0.04)`
  - Border: `1px solid #E6EBF2`
- **Level 3 (Fixed Bottom Navigation & Overlays):** Fixed bottom navigation bar and floating contextual action triggers.
  - Shadow: `0px -4px 20px 0px rgba(28, 36, 52, 0.05)`
  - Top Border: `1px solid #E6EBF2`

## Shapes

The interface embraces a gentle, highly approachable radius scale that softens household management:

- **Primary Cards & Containers:** Standardized at `16px` to `20px` corner radii (`rounded-xl` equivalent). This rounds the silhouette sufficiently to feel warm and tactile without squandering internal layout space.
- **Buttons & Form Fields:** Standardized at `12px` to `14px` radii for balanced ergonomics.
- **Badges, Priority Tags & Avatars:** Fully rounded pill (`9999px`) shapes for tags and circular avatars for family profiles, providing clear shape contrast against structural square-based cards.

## Components

### Buttons
- **Primary:** Background `#4263EB`, text `#FFFFFF`, border none, height `48px`, border-radius `12px`. Pressed state shifts to `#2948C7`.
- **Secondary / Soft:** Background `#EDF2FF`, text `#4263EB`, border none, height `48px`, border-radius `12px`.
- **Tertiary / Outlined:** Background `transparent`, text `#1C2434`, border `1.5px solid #E6EBF2`, height `48px`, border-radius `12px`.

### Priority Badges
- **Urgent:** Background `#FDE8E9`, text `#E85D65`, font `label-sm`, border-radius `9999px`, padding `4px 10px`.
- **High:** Background `#FEF6EB`, text `#E08A18`, font `label-sm`, border-radius `9999px`, padding `4px 10px`.
- **Normal:** Background `#EDF2FF`, text `#4263EB`, font `label-sm`, border-radius `9999px`, padding `4px 10px`.
- **Low:** Background `#EDF2F7`, text `#718096`, font `label-sm`, border-radius `9999px`, padding `4px 10px`.

### Cards & Household Lists
- **Standard Card:** Background `#FFFFFF`, border-radius `18px`, border `1px solid #E6EBF2`, padding `16px`, Level 1 ambient shadow.
- **Interactive Task Item:** Background `#FFFFFF`, min-height `56px`, horizontal padding `16px`, flex layout with trailing assignee avatar, title, and priority pill. Completed items strike through title and shift text to `#718096`.

### Checkboxes & Form Controls
- **Checkboxes:** Minimum target `48px × 48px`, visual box `22px × 22px`, border-radius `6px`. Unchecked: border `2px solid #CBD5E0`. Checked: background `#21A675`, border `2px solid #21A675`, white check icon.
- **Input Fields:** Height `50px`, background `#FFFFFF`, border `1.5px solid #E6EBF2`, border-radius `12px`, padding `0 16px`, text `body-lg`. Focus state: border `#4263EB` with `0 0 0 3px rgba(66, 99, 235, 0.15)`.

### Fixed 5-Tab Bottom Navigation
- Fixed height `68px` plus safe-area-inset-bottom.
- Background `#FFFFFF` with Level 3 elevation shadow and top border `1px solid #E6EBF2`.
- Five slots: **Home**, **Inventory**, **Tasks**, **Chat**, **Profile**.
- Equal division distribution. Active tab displays `#4263EB` with bold label (`label-sm`) and filled line icon; inactive tabs display `#718096` with regular line icon.

### Household Member Avatar Stack
- Size: `32px × 32px` circular avatars overlapping by `-8px`, with a `2px solid #FFFFFF` separating border ring.