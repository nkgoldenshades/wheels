# Verification Documents Screen - UI Mockup & Design Guide

## Screen Layout

```
┌─────────────────────────────────────┐
│  ←    Document Verification         │  ← AppBar (centered title)
├─────────────────────────────────────┤
│                                     │
│  ╔═══════════════════════════════╗  │
│  ║  ✓ Build Trust with Documents║  │  ← Header Card (Blue gradient)
│  ║  Verify your documents to    ║  │
│  ║  unlock the verified badge   ║  │
│  ║                              ║  │
│  ║  ✓ All documents are        ║  │  ← Green checkmark (optional)
│  ║    completely optional       ║  │
│  ╚═══════════════════════════════╝  │
│                                     │
│  ╔═══════════════════════════════╗  │
│  ║ ⓘ No documents uploaded yet. ║  │  ← Status Badge (Amber)
│  ║   Add them to increase trust!║  │
│  ╚═══════════════════════════════╝  │
│                                     │
│  Upload Documents                   │  ← Section Header
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🚗  RC Book                 │☑️ │  ← Document Card
│  │     Registration Certificate│   │
│  │     - Proves ownership      │   │
│  │                             │   │
│  │ ─────────────────────────── │   │
│  │ Upload clear photos of both │   │  ← Hint text (italic gray)
│  │ pages                       │   │
│  │                             │   │
│  │ [OPTIONAL]  [Increases Trust]   │  ← Badges
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🛡️  Insurance               │☑️ │  ← Document Card
│  │     Vehicle Insurance       │   │
│  │     - Mandatory by law      │   │
│  │                             │   │
│  │ ─────────────────────────── │   │
│  │ Upload current insurance    │   │
│  │ policy                      │   │
│  │                             │   │
│  │ [OPTIONAL]  [Increases Trust]   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🪪  Driving License         │   │  ← Document Card (not uploaded)
│  │     Valid driving license   │   │
│  │     - Valid for driving     │   │
│  │                             │   │
│  │ ─────────────────────────── │   │
│  │ Upload clear photos of both │   │
│  │ sides                       │   │
│  │                             │   │
│  │ [OPTIONAL]  [Increases Trust]   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📝  National ID             │   │  ← Document Card
│  │     Identity verification   │   │
│  │                             │   │
│  │ ─────────────────────────── │   │
│  │ Upload Aadhaar or PAN card │   │
│  │                             │   │
│  │ [OPTIONAL]  [Increases Trust]   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 💼  Tax ID                  │   │  ← Document Card
│  │     Tax identification      │   │
│  │                             │   │
│  │ ─────────────────────────── │   │
│  │ Upload PAN card or GST cert│   │
│  │                             │   │
│  │ [OPTIONAL] [Business Required]  │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  [✓ Save & Continue]        │   │  ← CTA Buttons
│  ├─────────────────────────────┤   │
│  │  [Skip for Now]             │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

## Color Scheme

### Primary Colors
- **Blue** (`Colors.blue`): Optional documents, primary info
- **Green** (`Colors.green`): Uploaded/verified status, success
- **Orange** (`Colors.orange`): Driving License icon, warnings
- **Red** (`Colors.red`): National ID icon, errors
- **Purple** (`Colors.purple`): Tax ID icon

### Background Colors
- **Header**: Blue gradient (blue[50] → blue[100])
- **Status Badge**: Amber[50] background with amber[200] border
- **Document Cards**: White with gray[300] border (default) or green[50] with green[300] border (uploaded)
- **Benefit Badge**: Blue[50] background

## Header Card Design

```
┌──────────────────────────────────────┐
│ [✓]  Build Trust with Documents      │
│      Verify your documents to        │
│      unlock the verified badge       │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ✓ All documents are              │ │
│ │   completely optional             │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘

Colors:
- Background: gradient(blue[50], blue[100])
- Icon: blue[700]
- Text: black/gray[700]
- Inner box: white with 70% opacity
- Inner text: green
```

## Status Badge Design

```
┌──────────────────────────────────────┐
│ [ⓘ] No documents uploaded yet.      │
│     Add them to increase trust!      │
└──────────────────────────────────────┘

Colors:
- Background: amber[50]
- Icon: amber[700]
- Text: amber[900]
- Border: amber[200]
```

## Document Card Design (Default)

```
┌────────────────────────────────────────┐
│  [🚗]  RC Book           [☁️ Upload]   │
│        Registration Certificate        │
│                                        │
│  Upload clear photos of both pages    │
│                                        │
│  [OPTIONAL]  ↗ Get verified badge...  │
└────────────────────────────────────────┘

Colors:
- Border: gray[300] (1px)
- Icon background: blue.withOpacity(0.1)
- Icon: blue
- Status badge: blue background with 20% opacity
- Benefit badge: blue[50] background
- Benefit text: blue[700]
```

## Document Card Design (Uploaded)

```
┌────────────────────────────────────────┐
│ ✓ [🚗]  RC Book           [✓ Uploaded] │
│        Registration Certificate        │
│                                        │
│  Upload clear photos of both pages    │
│                                        │
│  [OPTIONAL]  ↗ Get verified badge...  │
└────────────────────────────────────────┘

Colors:
- Border: green[300] (2px - thicker)
- Background: green[50]
- Icon: green
- Checkmark: green
```

## Typography

```
AppBar Title:
  - Font: Default (Material)
  - Size: 20px
  - Weight: 500
  - Color: black

Header Title:
  - Font: Default
  - Size: 16px
  - Weight: bold
  - Color: black

Document Title:
  - Font: Default
  - Size: 15px
  - Weight: bold
  - Color: black

Subtitle:
  - Font: Default
  - Size: 12px
  - Color: gray[600]

Hint Text:
  - Font: Default
  - Size: 11px
  - Style: italic
  - Color: gray[500]

Status Badge:
  - Font: Default
  - Size: 10px
  - Weight: bold
  - Color: matching status

Benefit Text:
  - Font: Default
  - Size: 11px
  - Weight: 500
  - Color: blue[700]
```

## Spacing & Dimensions

```
Screen Padding:              16px all sides
Section Spacing:             24px vertical
Card Spacing:                12px between cards
Padding within Card:         16px all sides
Icon Size:                   24px
Upload Status Icon:          20px
Small Icon (trending):       12px

Card Border Radius:          12px
Badge Border Radius:         8px
Inner Box Radius:            4px

Button Height:               48px
Button Border Radius:        depends on style
```

## States & Interactions

### Document Card States

**Default (Not Uploaded)**
```
- Border: gray[300] (1px)
- Background: white
- Opacity: 1.0
- Hover: slight elevation shadow
```

**Uploaded**
```
- Border: green[300] (2px)
- Background: green[50]
- Checkmark: visible
- Opacity: 1.0
```

**Loading**
```
- Border: blue[300]
- Spinner: visible on upload button
- Opacity: 0.9
```

**Error**
```
- Border: red[300]
- Background: red[50]
- Error icon: visible
- Opacity: 1.0
```

## Buttons

### Primary Button (Save & Continue)
```
Style:     FilledButton
Background: Colors.green
Text:      'Save & Continue'
Width:     Full width
Height:    48px
Icon:      None
```

### Secondary Button (Skip for Now)
```
Style:     OutlinedButton
Border:    gray[400]
Text:      'Skip for Now'
Width:     Full width
Height:    48px
Icon:      None
```

### Upload Button (on card)
```
Style:     InkWell
Icon:      cloud_upload_outlined or check_circle
Size:      20px
Background: gray[200] or green.withOpacity(0.2)
```

## Icons Used

```
Document Icons:
- RC Book:         icons.directions_car (blue)
- Insurance:       icons.shield_outlined (green)
- Driving License: icons.credit_card (orange)
- National ID:     icons.assignment (red)
- Tax ID:          icons.receipt (purple)

Status Icons:
- Upload:          icons.cloud_upload_outlined
- Uploaded:        icons.check_circle (green)
- Info:            icons.info
- Verified:        icons.verified_user
- Trending Up:     icons.trending_up (for benefits)
```

## Responsive Design

### Mobile (< 600px)
```
- Full width cards
- 16px padding
- Touch-friendly spacing (min 48px buttons)
- Icons scale normally
```

### Tablet (600px - 900px)
```
- Full width cards (respects max width if needed)
- 20px padding
- Same spacing
```

### Web (> 900px)
```
- Optional: constrain max width to 800px
- Center horizontally
- Same padding
```

## Animations

### Card Tap
```
Duration:   200ms
Effect:     Slight scale (0.98)
Effect:     Elevation increase
Color:      Ripple on InkWell
```

### Status Change
```
Duration:   300ms
Effect:     Border color transition
Effect:     Background color transition
```

### Upload Progress
```
Duration:   Continuous
Effect:     Spinner animation
Effect:     opacity pulse on uploading card
```

## Dark Mode (Optional Future)

```
Background:       Colors.grey[900]
Cards:           Colors.grey[800]
Text:            Colors.white
Borders:         Colors.grey[700]
Header:          gradient(blue[900], blue[800])
Status Badge:    Colors.amber[900] bg
```

## Accessibility

### Touch Targets
- All buttons: minimum 48px × 48px
- All cards: minimum 56px height

### Color Contrast
- All text meets WCAG AA standards
- Status colors used with text + icons (not color alone)

### Semantic Labels
- Document cards use clear titles
- Benefits clearly explained
- Status clearly indicated

## Design Tokens Summary

```dart
// Spacing
const primaryPadding = 16.0;
const cardMargin = 12.0;
const sectionGap = 24.0;

// Border Radius
const cardRadius = 12.0;
const badgeRadius = 8.0;

// Icon Sizes
const documentIconSize = 24.0;
const statusIconSize = 20.0;

// Colors
final blue = Colors.blue;
final green = Colors.green;
final orange = Colors.orange;
final red = Colors.red;
final purple = Colors.purple;
```

---

**Screen Size**: Optimized for 375px - 1440px width
**Safe Area**: Respects system navigation/status bars
**Orientation**: Portrait primary (landscape supported)
**Status Bar**: Light icons on dark app bar
