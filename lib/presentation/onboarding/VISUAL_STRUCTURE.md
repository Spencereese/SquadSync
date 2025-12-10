# 📊 OnboardingFlow - Complete Visual Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OnboardingFlow                              │
│                     (Main PageView Widget)                          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
            ┌───────▼────────┐         ┌────────▼────────┐
            │  UI Layer      │         │  State Layer    │
            │  (PageView)    │◄────────┤  (Riverpod)     │
            └───────┬────────┘         └────────┬────────┘
                    │                           │
    ┌───────────────┼───────────────┬──────────┼─────────┐
    │               │               │          │         │
┌───▼───┐    ┌─────▼─────┐    ┌───▼────┐  ┌──▼──────┐ │
│ Page 0│    │  Page 1   │    │ Page 2 │  │ Page 3  │ │
│Sign-In│    │Callsign+  │    │ Game   │  │ Prefs   │ │
│       │    │Avatar     │    │Selector│  │         │ │
└───┬───┘    └─────┬─────┘    └───┬────┘  └──┬──────┘ │
    │              │              │          │         │
    │              │              │          │    ┌────▼────────┐
    │              │              │          │    │OnboardingNot│
    │              │              │          │    │ifier        │
    │              │              │          │    │(State Mgmt) │
    │              │              │          │    └────┬────────┘
    │              │              │          │         │
    │              │              │          │    ┌────▼────────┐
    │              │              │          │    │OnboardingSt │
    │              │              │          │    │ate (Freezed)│
    │              │              │          │    └─────────────┘
    │              │              │          │
┌───▼──────────────▼──────────────▼──────────▼─────┐
│            Shared Widget Components               │
├───────────────────────────────────────────────────┤
│ • MatrixRainBackground (animated particles)       │
│ • GlassCard (glassmorphic container)              │
│ • NeonButton (glowing animated button)            │
│ • SmoothPageIndicator (neon dots)                 │
└───────────────────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
┌───────▼────────┐         ┌────────▼────────┐
│  Firebase Auth │         │  Firestore DB   │
├────────────────┤         ├─────────────────┤
│• Apple Sign-In │         │ users/{uid}     │
│• Email Sign-In │         │ ├─ callsign    │
│• Google (stub) │         │ ├─ avatarPath  │
└────────────────┘         │ ├─ pinnedGames │
                           │ ├─ preferences │
                           │ └─ onboarding  │
                           │    Complete    │
                           └─────────────────┘
```

---

## 🎯 Page Flow Diagram

```
┌────────────┐
│   START    │
└─────┬──────┘
      │
      ▼
┌────────────────────────────────────────────────────┐
│  Page 0: Sign-In                                   │
│  ┌──────────────────────────────────────────────┐  │
│  │ • Apple Sign-In Button (iOS)                 │  │
│  │ • Google Sign-In Button (placeholder)        │  │
│  │ • Email Sign-In Button                       │  │
│  └──────────────────────────────────────────────┘  │
│  Validation: User must authenticate               │
│  Auto-advance: On successful auth                 │
└─────┬──────────────────────────────────────────────┘
      │ [User authenticated]
      ▼
┌────────────────────────────────────────────────────┐
│  Page 1: Callsign & Avatar                         │
│  ┌──────────────────────────────────────────────┐  │
│  │ ┌────────────┐                               │  │
│  │ │  Avatar    │  ← Tap to select image        │  │
│  │ │  Picker    │     (ImagePicker)             │  │
│  │ └────────────┘                               │  │
│  │                                              │  │
│  │ ┌────────────────────────────────┐          │  │
│  │ │   CALLSIGN TEXT FIELD          │          │  │
│  │ │   (large, neon glow)           │          │  │
│  │ └────────────────────────────────┘          │  │
│  │                                              │  │
│  │        [CONTINUE BUTTON]                     │  │
│  └──────────────────────────────────────────────┘  │
│  Validation: Callsign must not be empty           │
│  Manual advance: Tap CONTINUE button              │
└─────┬──────────────────────────────────────────────┘
      │ [Callsign set]
      ▼
┌────────────────────────────────────────────────────┐
│  Page 2: Game Selector                             │
│  ┌──────────────────────────────────────────────┐  │
│  │         [Games: 3/6 Selected]                │  │
│  │                                              │  │
│  │  ┌──────────────────────────────────┐       │  │
│  │  │  ┌────────────────────────┐      │       │  │
│  │  │  │  Card 1: Call of Duty  │      │       │  │
│  │  │  └────────────────────────┘      │       │  │
│  │  │    ┌──────────────────────┐      │       │  │
│  │  │    │ Card 2: Apex Legends │      │       │  │
│  │  │    └──────────────────────┘      │       │  │
│  │  │      ┌────────────────────┐      │       │  │
│  │  │      │ Card 3: Fortnite   │      │       │  │
│  │  │      └────────────────────┘      │       │  │
│  │  └──────────────────────────────────┘       │  │
│  │    Swiper (Tinder-style)                    │  │
│  │                                              │  │
│  │   [❌]      [SKIP BUTTON]      [❤️]         │  │
│  │   Left               Right                   │  │
│  └──────────────────────────────────────────────┘  │
│  Validation: At least 1 game selected             │
│  Auto-advance: When all cards swiped              │
│  Manual advance: Tap SKIP button                  │
└─────┬──────────────────────────────────────────────┘
      │ [Games selected]
      ▼
┌────────────────────────────────────────────────────┐
│  Page 3: Preferences                               │
│  ┌──────────────────────────────────────────────┐  │
│  │  Preference Chips (tap to toggle):           │  │
│  │  ┌────────────┐ ┌────────────┐              │  │
│  │  │🔔 Notifs ✓│ │🔊 Sound  ✓│              │  │
│  │  └────────────┘ └────────────┘              │  │
│  │  ┌────────────┐ ┌────────────┐              │  │
│  │  │📳 Haptics✓│ │➕ AutoJoin│              │  │
│  │  └────────────┘ └────────────┘              │  │
│  │  ┌────────────┐ ┌────────────┐              │  │
│  │  │🟢 Online ✓│ │🌙 Dark   ✓│              │  │
│  │  └────────────┘ └────────────┘              │  │
│  │                                              │  │
│  │     ┌──────────────────────────┐            │  │
│  │     │  ENTER THE VOID          │            │  │
│  │     │  (Neon gradient button)  │            │  │
│  │     └──────────────────────────┘            │  │
│  └──────────────────────────────────────────────┘  │
│  Validation: None (all optional)                  │
│  Final action: Saves to Firestore → Navigate     │
└─────┬──────────────────────────────────────────────┘
      │ [ENTER THE VOID pressed]
      ▼
┌────────────────────┐
│  Save to Firestore │
│  • callsign        │
│  • avatarPath      │
│  • pinnedGames     │
│  • preferences     │
│  • onboarding      │
│    Complete: true  │
└─────┬──────────────┘
      │
      ▼
┌────────────────────┐
│ Navigate('/main')  │
│  Main App Screen   │
└────────────────────┘
      │
      ▼
    [END]
```

---

## 🎨 Visual Style Guide

```
┌─────────────────────────────────────────────────────────┐
│                   COLOR PALETTE                         │
├─────────────────────────────────────────────────────────┤
│ Background:    #0B0E14 (Dark Void)                      │
│ Primary Neon:  #00E5FF (Cyan)                           │
│ Secondary:     #FF00FF (Magenta/Purple)                 │
│ Glass:         rgba(255,255,255,0.05)                   │
│ Border:        rgba(0,229,255,0.3)                      │
│ Glow:          rgba(0,229,255,0.5) + blur 20px          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  COMPONENT STYLES                       │
├─────────────────────────────────────────────────────────┤
│ GlassCard:                                              │
│ ├─ Backdrop blur: 10px                                  │
│ ├─ Background: linear-gradient(white.05, white.02)      │
│ ├─ Border: 1.5px solid white.1                          │
│ ├─ Border radius: 20px                                  │
│ └─ Shadow: cyan.1, blur 20px                            │
│                                                         │
│ NeonButton:                                             │
│ ├─ Gradient: cyan → purple                              │
│ ├─ Border: 2px solid cyan                               │
│ ├─ Glow: animated (0.5 → 1.0 opacity)                   │
│ ├─ Border radius: 30px                                  │
│ └─ Shadow: cyan.3, blur 20px, spread 5px                │
│                                                         │
│ MatrixRain:                                             │
│ ├─ Particles: 30 columns                                │
│ ├─ Colors: cyan ↔ green (animated)                      │
│ ├─ Speed: 0.3 - 1.0 (random)                            │
│ ├─ Opacity: 0.3 max (subtle)                            │
│ └─ Size: 2-4px particles                                │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 File Dependency Graph

```
onboarding_flow.dart
├─ imports
│  ├─ onboarding_notifier.dart
│  │  └─ onboarding_notifier.freezed.dart (generated)
│  ├─ widgets/matrix_rain_background.dart
│  ├─ widgets/glass_card.dart
│  ├─ widgets/neon_button.dart
│  ├─ smooth_page_indicator (package)
│  ├─ flutter_card_swiper (package)
│  ├─ firebase_auth (package)
│  ├─ sign_in_with_apple (package)
│  └─ image_picker (package)
└─ exports
   └─ OnboardingFlow widget

onboarding_notifier.dart
├─ imports
│  ├─ flutter_riverpod
│  ├─ freezed_annotation
│  ├─ firebase_auth
│  └─ cloud_firestore
└─ exports
   ├─ OnboardingNotifier
   ├─ OnboardingState (freezed)
   └─ onboardingProvider
```

---

## 🚀 Animation Timeline

```
Time     │ Animation
─────────┼───────────────────────────────────────────────────
0s       │ MatrixRain: Start particle animation
         │ PageIndicator: Show dot 0 active
         │
0-2s     │ SignIn Buttons: Pulse border (1.0x → 1.2x)
         │ MatrixRain: Continuous scroll
         │
User taps│ Haptic feedback
Sign-In  │ Auth flow starts
         │
Auth     │ Auto-advance to page 1
Success  │ PageIndicator: Animate dot 0 → 1
         │
Page 1   │ Avatar circle: Neon glow pulsing
         │ TextField: Show cursor
         │
User     │ Continue button: Glow intensifies
enters   │ Enabled state visual feedback
callsign │
         │
Page 2   │ Cards: Stack with offset
advance  │ Top card: Full opacity
         │ Cards 2-3: Reduced opacity
         │
User     │ Card rotation animation
swipes   │ "ADD"/"SKIP" overlay fade in
right/   │ Next card moves to front (300ms)
left     │ Haptic feedback (medium impact)
         │
Page 3   │ Chips: Initial state shown
advance  │ Final button: Gradient glow cycle
         │
User     │ Chip: Scale animation (1.0 → 1.1 → 1.0)
taps     │ Border color transition
chip     │ Glow effect on selected
         │ Haptic feedback (selection click)
         │
ENTER    │ Heavy haptic feedback
THE      │ Button press animation
VOID     │ Loading indicator appears
         │ Firestore save → Navigate
         │
Complete │ Fade out entire screen
         │ Navigate to main app
```

---

## 💾 State Flow Diagram

```
                    ┌─────────────────┐
                    │ OnboardingState │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼────────┐  ┌───────▼────────┐  ┌───────▼────────┐
│  currentPage   │  │   callsign     │  │ selectedGames  │
│  (0-3)         │  │   (String?)    │  │ (List<String>) │
└────────────────┘  └────────────────┘  └────────────────┘
        │                    │                    │
        │           ┌────────▼────────┐           │
        │           │   avatarPath    │           │
        │           │   (String?)     │           │
        │           └─────────────────┘           │
        │                                         │
┌───────▼────────┐         ┌────────────────┐    │
│  isLoading     │         │  preferences   │◄───┘
│  (bool)        │         │  (Map<String,  │
└────────────────┘         │   bool>)       │
        │                  └────────────────┘
        │                           │
        └───────────┬───────────────┘
                    │
              ┌─────▼──────┐
              │   error    │
              │ (String?)  │
              └────────────┘
```

---

**Legend:**
- `└─` Tree structure
- `┌─┐` Container/box
- `│` Vertical connector
- `▼` Flow direction
- `◄─` Reference/dependency
- `✓` Selected/enabled state
