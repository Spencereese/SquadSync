# 🎨 AvatarSelectionWidget - Visual Demo

```
┌─────────────────────────────────────────────────────────────────┐
│                    AVATAR SELECTION WIDGET                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                      ┌─────────────────┐                        │
│                      │  ╭─────────╮    │ ◄─ Pulsing glow ring   │
│                      │  │         │    │    (2s animation)      │
│                      │  │  AVATAR │    │                        │
│                      │  │ PREVIEW │    │                        │
│                      │  │ 180x180 │    │                        │
│                      │  │         │    │                        │
│                      │  ╰─────────╯    │                        │
│                      └─────────────────┘                        │
│                                                                 │
│                  ┌──────────────────────┐                       │
│                  │  📤 UPLOAD CUSTOM   │ ◄─ Upload button      │
│                  └──────────────────────┘    (neon border)     │
│                                                                 │
│         ─────────  OR CHOOSE PRESET  ─────────                 │
│                                                                 │
│    ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐    │
│    │ 🎭 │  │ 👤 │  │ 👻 │  │ 🤖 │  │ ⚡ │  │ 🔷 │  │ 🌟 │  ◄─ Scroll │
│    │    │  │    │  │    │  │    │  │    │  │    │  │    │    │
│    └────┘  └────┘  └────┘  └────┘  └────┘  └────┘  └────┘    │
│    Chrome  Glitch  Hood   Neon   Cyber  Circuit Void  Phantom │
│    Skull   Mask    Siloue Visor  Ghost  Face    War   ──►     │
│                    tte                          rior           │
│                                                                 │
│    ├─────────────── Horizontal scroll ──────────────────►      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

INTERACTION STATES:

┌─────────────── UNSELECTED PRESET ───────────────┐
│  ┌──────────┐                                   │
│  │          │  ◄─ Dim border (opacity 0.3)      │
│  │   Icon   │                                   │
│  │          │     No glow shadow                │
│  └──────────┘                                   │
│   Preset Name  ◄─ Grey text                     │
└──────────────────────────────────────────────────┘

┌─────────────── SELECTED PRESET ──────────────────┐
│  ┌──────────┐                                    │
│  ║          ║  ◄─ Bright border (full color)     │
│  ║   Icon   ║     + Glow shadow (20px blur)      │
│  ║          ║                                    │
│  └──────────┘                                    │
│   PRESET NAME  ◄─ Colored text (bold)            │
└───────────────────────────────────────────────────┘

┌─────────────── UPLOADED IMAGE ───────────────────┐
│  ┌──────────┐                                    │
│  │  ╭────╮  │  ◄─ Cyan border (default)          │
│  │  │PHOTO│  │     + Neon filter overlay         │
│  │  ╰────╯  │     (radial gradient)              │
│  └──────────┘                                    │
└───────────────────────────────────────────────────┘

NEON GLOW EFFECT:

Animation Timeline (2 seconds):
0.0s  ●━━━━━━━━━━━━━━━━━━━━━━━━━━ 50% opacity
      ↓
0.5s  ●━━━━━━━━━━━●━━━━━━━━━━━━━ 65% opacity
      ↓
1.0s  ●━━━━━━━━━━━━━━━━━━━━━●━━━ 100% opacity (peak)
      ↓
1.5s  ●━━━━━━━━━━━●━━━━━━━━━━━━━ 65% opacity
      ↓
2.0s  ●━━━━━━━━━━━━━━━━━━━━━━━━━━ 50% opacity (loop)

COLOR PALETTE:

Chrome Skull:      ████ #00E5FF (Cyan)
Glitch Mask:       ████ #FF00FF (Magenta)
Hooded Silhouette: ████ #00FF41 (Matrix Green)
Neon Visor:        ████ #FF3D00 (Orange-Red)
Cyber Ghost:       ████ #7C4DFF (Purple)
Circuit Face:      ████ #00E676 (Bright Green)
Void Warrior:      ████ #FFEA00 (Yellow)
Digital Phantom:   ████ #00BCD4 (Light Cyan)

NEON FILTER OVERLAY:

Center → Edge gradient:
┌────────────────────────────────────────┐
│  ●                                     │
│    ↘                                   │
│      ↘  Transparent (50% radius)       │
│        ●                               │
│          ↘                             │
│            ↘  10% opacity (80% radius) │
│              ●                         │
│                ↘                       │
│                  ↘  20% opacity (100%) │
│                    ●                   │
└────────────────────────────────────────┘

DYNAMIC ACCENT INTEGRATION:

┌──────────────────────────────────────────────┐
│  BEFORE (Default Cyan):                      │
│  ┌────────────────┐                          │
│  │   [CONTINUE]   │ ◄─ Cyan gradient         │
│  └────────────────┘                          │
│                                              │
│  Callsign text shadow: Cyan                  │
│  Upload button border: Cyan                  │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  AFTER (Selected Magenta Preset):            │
│  ┌────────────────┐                          │
│  │   [CONTINUE]   │ ◄─ Magenta gradient      │
│  └────────────────┘                          │
│                                              │
│  Callsign text shadow: Magenta               │
│  Upload button border: Magenta               │
└──────────────────────────────────────────────┘

PRESET SCROLL DEMO:

◄────────────────────────────────────────────────────►
│  [Chrome] [Glitch] [Hood] [Visor] [Ghost] [Circuit] │
│    Skull    Mask                                     │
│                                                      │
│  ← Scroll left              Scroll right →          │
└──────────────────────────────────────────────────────┘

Visible: 3-4 presets at once
Total: 8 presets
Spacing: 16px between items
Padding: 16px horizontal

UPLOAD FLOW:

┌─────────────────────────────────────────┐
│  User taps "UPLOAD CUSTOM"              │
│         ↓                               │
│  System image picker opens              │
│         ↓                               │
│  User selects photo from gallery        │
│         ↓                               │
│  Image compressed (1024x1024, 85%)      │
│         ↓                               │
│  Neon filter overlay applied            │
│         ↓                               │
│  Avatar preview updated                 │
│         ↓                               │
│  Accent color set to cyan               │
│         ↓                               │
│  onAvatarSelected callback fired        │
│         ↓                               │
│  Parent widget receives path + color    │
└─────────────────────────────────────────┘

PRESET SELECTION FLOW:

┌─────────────────────────────────────────┐
│  User taps preset avatar                │
│         ↓                               │
│  Haptic feedback (selection click)      │
│         ↓                               │
│  Preset border highlights               │
│         ↓                               │
│  Glow shadow animates in                │
│         ↓                               │
│  Center preview updates                 │
│         ↓                               │
│  Accent color changes to preset color   │
│         ↓                               │
│  onAvatarSelected callback fired        │
│         ↓                               │
│  Parent updates (button colors, etc.)   │
└─────────────────────────────────────────┘

RESPONSIVE LAYOUT:

Mobile (375px width):
┌──────────────────────────┐
│    ┌─────────────┐       │
│    │   PREVIEW   │       │
│    │   180x180   │       │
│    └─────────────┘       │
│                          │
│  [UPLOAD CUSTOM]         │
│                          │
│  ── OR CHOOSE PRESET ──  │
│                          │
│  [•] [•] [•] → scroll    │
│   3 visible presets      │
└──────────────────────────┘

Tablet/Desktop (768px+ width):
┌──────────────────────────────────────────┐
│         ┌─────────────┐                  │
│         │   PREVIEW   │                  │
│         │   180x180   │                  │
│         └─────────────┘                  │
│                                          │
│       [UPLOAD CUSTOM]                    │
│                                          │
│  ────── OR CHOOSE PRESET ──────          │
│                                          │
│  [•] [•] [•] [•] [•] [•] [•] [•]        │
│   All 8 presets visible                  │
└──────────────────────────────────────────┘

SIZE SPECIFICATIONS:

Component            Width   Height   Border   Glow
─────────────────────────────────────────────────────
Main Preview         180px   180px    3px      40px
Preset Item          80px    80px     2-3px    20px
Upload Button        auto    48px     2px      15px
Preset Name Text     80px    20px     -        -
Horizontal Scroller  100%    120px    -        -

SPACING:

Between preview and upload:      32px
Between upload and divider:      24px
Between divider and presets:     24px
Between preset items:            16px
Horizontal padding (presets):    16px
Upload button padding (H):       32px
Upload button padding (V):       14px

ANIMATION TIMINGS:

Glow pulse cycle:             2000ms (repeat)
Preset selection transition:  200ms
Border color change:          200ms
Shadow fade in/out:           200ms
Image upload transition:      instant (no anim)

```

**Legend:**
- `┌─┐` Box/container
- `║` Selected border
- `│` Normal border
- `●` Animation keyframe
- `◄─` Annotation arrow
- `→` Scroll direction
- `[•]` Preset item
- `████` Color block
