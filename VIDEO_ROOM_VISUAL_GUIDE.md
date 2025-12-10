# VideoRoomScreen Visual Hierarchy

## Screen Layout

```
┌─────────────────────────────────────────────────┐
│  ┌───────────────────────────────────────────┐  │ Top Bar
│  │ 🎮 Squad Alpha Video    👥 5  ⏱ 12:34   │  │ (Glassmorphic)
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────┬──────────┬──────────┐             │
│  │ ╔══════╗ │ ╔══════╗ │ ╔══════╗ │             │ Video Grid
│  │ ║Video ║ │ ║Video ║ │ ║Video ║ │             │ (3x3 adaptive)
│  │ ║  🔊  ║ │ ║  🔇  ║ │ ║  🔊  ║ │             │
│  │ ║Alice ║ │ ║ Bob  ║ │ ║Carol ║ │             │ Neon borders
│  │ ╚══════╝ │ ╚══════╝ │ ╚══════╝ │             │ glow when speaking
│  ├──────────┼──────────┼──────────┤             │
│  │ ╔══════╗ │ ╔══════╗ │ ╔══════╗ │             │
│  │ ║Video ║ │ ║Video ║ │ ║Video ║ │             │
│  │ ║Dave  ║ │ ║ Eve  ║ │ ║Frank ║ │             │
│  │ ╚══════╝ │ ╚══════╝ │ ╚══════╝ │             │
│  └──────────┴──────────┴──────────┘             │
│                                                  │
│  ┌─────────────────────────────────────────┐    │ Control Bar
│  │  🎤   📹   🔄   ✨   📞                  │    │ (Glass bottom)
│  │ Mute Camera Flip Effects Leave           │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘

       ┌────────┐
       │ ╔════╗ │  Floating PiP (>4 users)
       │ ║You ║ │  Draggable local video
       │ ╚════╝ │  120x160 bubble
       └────────┘
```

## Adaptive Grid Examples

### 1 Participant (Full Screen)
```
┌────────────────────┐
│                    │
│   ╔════════════╗   │
│   ║            ║   │
│   ║   Video    ║   │
│   ║    You     ║   │
│   ║            ║   │
│   ╚════════════╝   │
│                    │
└────────────────────┘
```

### 2 Participants (2x1)
```
┌────────────────────┐
│  ╔══════╗╔══════╗  │
│  ║      ║║      ║  │
│  ║ You  ║║Alice ║  │
│  ║      ║║      ║  │
│  ╚══════╝╚══════╝  │
└────────────────────┘
```

### 4 Participants (2x2)
```
┌────────────────────┐
│  ╔══════╗╔══════╗  │
│  ║ You  ║║Alice ║  │
│  ╚══════╝╚══════╝  │
│  ╔══════╗╔══════╗  │
│  ║ Bob  ║║Carol ║  │
│  ╚══════╝╚══════╝  │
└────────────────────┘
```

### 5+ Participants (3x3 + PiP)
```
┌────────────────────┐
│ ╔════╗╔════╗╔════╗ │
│ ║P1  ║║P2  ║║P3  ║ │
│ ╚════╝╚════╝╚════╝ │
│ ╔════╗╔════╗╔════╗ │
│ ║P4  ║║P5  ║║P6  ║ │   ┌──────┐
│ ╚════╝╚════╝╚════╝ │   │╔════╗│ PiP
│                    │   │║You ║│
│                    │   │╚════╝│
└────────────────────┘   └──────┘
```

## Speaking Indicator States

### Not Speaking
```
┌────────────────┐
│ ╔════════════╗ │  Normal border
│ ║            ║ │  White/gray
│ ║   Alice    ║ │  No glow
│ ║            ║ │
│ ╚════════════╝ │
└────────────────┘
```

### Speaking (Neon Pulse)
```
┌────────────────┐
│ ╔════════════╗ │  Neon border
│ ║🔊 ▁▃▅▇▅▃▁  ║ │  Cyan glow pulse
│ ║   Alice    ║ │  Waveform indicator
│ ║            ║ │  Animated ring
│ ╚════════════╝ │
└────────────────┘
   ╰─ Pulsing ─╯
```

## Component Details

### Video Tile Components
```
┌─────────────────────────┐
│ 🌫 Blur Indicator       │ ← Virtual background on
│                         │
│                         │
│      Video Feed         │
│    or Placeholder       │
│                         │
│  ▁▃▅▇ Waveform         │ ← Speaking indicator
│                         │
│ ┌─────────────────────┐ │
│ │ Alice         🔇    │ │ ← Name + mute status
│ └─────────────────────┘ │
└─────────────────────────┘
```

### Camera Off Placeholder
```
┌─────────────────────────┐
│                         │
│       ┌─────────┐       │
│       │    A    │       │ ← First letter avatar
│       └─────────┘       │
│                         │
│     Camera Off          │ ← Status text
│                         │
└─────────────────────────┘
```

### Control Button States

**Active (Unmuted)**
```
  ┌─────┐
  │ 🎤  │  Cyan neon glow
  └─────┘  Active border
   Mute
```

**Inactive (Muted)**
```
  ┌─────┐
  │ 🔇  │  Red border
  └─────┘  No glow
  Unmute
```

**Destructive (Leave)**
```
  ┌─────┐
  │ 📞  │  Red neon glow
  └─────┘  Red border
   Leave
```

## Color Scheme

### Primary Colors
- **Neon Cyan**: `#00F5FF` - Primary accent, speaking borders
- **Dark Void**: `#0B0E14` - Background
- **Dark Surface**: `#14181F` - Cards, modals
- **Glass White**: `rgba(255,255,255,0.08)` - Glassmorphic fills

### Status Colors
- **Active**: Cyan with neon glow
- **Inactive**: White 20% opacity
- **Muted**: Red with glow
- **Speaking**: Cyan pulsing border (0.6-1.0 opacity)

## Animation Details

### Speaking Pulse
- **Duration**: 1000ms
- **Type**: Repeat with reverse
- **Effect**: Border opacity 0.6 → 1.0 → 0.6
- **Glow**: Blur 20px → 45px → 20px

### Waveform Bars
- **Bars**: 5 animated bars
- **Height**: 4px → 16px (varies by delay)
- **Delay**: 0.2s stagger between bars
- **Color**: Cyan with neon glow

### PiP Movement
- **Type**: Pan gesture
- **Bounds**: Clamped to screen edges
- **Size**: 120x160 fixed
- **State**: Maintains all indicators

## Effects Menu Layout
```
┌───────────────────────────────┐
│                               │
│      Video Effects            │ ← Title
│                               │
│  ┌─────────────────────────┐  │
│  │ 🌫  Virtual Background  │  │ ← Option 1
│  │     Blur              ✓ │  │  (Active)
│  └─────────────────────────┘  │
│                               │
│  ┌─────────────────────────┐  │
│  │ ✨  Beauty Filter       │  │ ← Option 2
│  │                         │  │  (Inactive)
│  └─────────────────────────┘  │
│                               │
└───────────────────────────────┘
```

## Theme Integration

All colors automatically adapt to:
- **Dynamic seed color** from game cover art
- **Theme.colorScheme.primary** for neon effects
- **Glassmorphic containers** with backdrop blur
- **Neon glow extensions** for borders
- **Material 3** elevation and surfaces

## Responsive Behavior

### Portrait Mode
- Grid adapts: 1 column → 2 columns → 3 columns
- Control bar: 5 buttons horizontally
- PiP: Top-right corner default

### Landscape Mode
- Grid: Wider aspect ratios
- Control bar: Same layout
- PiP: Smaller relative size

### Small Screens
- Min tile size: 100x150
- Control buttons: 48x48 minimum
- Font scales down to 11px

## Accessibility

- **High contrast**: Neon borders on dark backgrounds
- **Clear labels**: All buttons labeled
- **Status indicators**: Visual + text (mute icons + "Camera Off")
- **Haptic feedback**: Light impact on button press
- **Readable timers**: Tabular figures for alignment

## Performance Optimizations

1. **AnimatedBuilder**: Only rebuilds animated widgets
2. **const widgets**: Immutable UI elements
3. **Clipped blur**: Only applied to glass containers
4. **Lazy grid**: GridView.builder for efficiency
5. **Conditional PiP**: Only rendered when needed (>4 users)
