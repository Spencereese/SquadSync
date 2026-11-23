# Known issues

## AX5 reactions: main thread hangs in LazyVStack placement

**Status:** open. Deferred out of PR #38 to its own slice. Recorded flake: see
the latest Mac pass for `testReactionsSitUnderTheBubbleOnItsSideAtLargeText`.

**Symptom.** At the largest accessibility text size (AX5, `-uitest-largeText`),
on the iOS 26.2 simulator (iPhone 17 Pro Max), opening or closing the emoji row
under your own message sometimes hangs the main thread for minutes. In
`testReactionsSitUnderTheBubbleOnItsSideAtLargeText` it shows as a hang at
`tap-add` ("+ did not open the emoji row") or at `tap-take-back`, then
"Timed out while evaluating UI query" or, with the hang watchdog, an abort after
90 s. Roughly 1–3 clean runs in 5 standalone; it usually passes inside the full
suite. Default text size is not affected.

**It predates the Stream SDK.** The test fails the same way on e9a0941, which
has no Stream code.

**Evidence (Mac passes of 35b486f, 64b2b97, e3f3210).**
- `sample` while hung: 5864/5865 samples in one SwiftUI transaction
  (`_UIHostingView.beginTransaction` > `GraphHost.flushTransactions` >
  `AG::Graph::UpdateStack::update`), nested `StackLayout` / `_FlexFrameLayout` /
  `_PaddingLayout` / `_ZStackLayout` sizing up to 334 frames deep, plus
  `LazyStack.measureEstimates`. Almost no app frames.
- Watchdog crash reports (`SquadSync-*.ips`), Thread 0, all the same family:
  `LazyStack.place(subviews:context:cache:in:)` > `ForEachList.applyNodes` >
  `ForEachState.forEachItem` > `_LazyLayout_Subviews.applyNodes` >
  `StackPlacement.place` > `_LazyLayout_Subviews.apply(from:style:to:)`.
  Not a lock or a wait.
- DEBUG `HangProbe` counters are flat for the whole hang: no row body builds,
  no scroll-view KVO, no controller offset sets, no row geometry callbacks, no
  `ChipFlow` calls. No app code runs; SwiftUI is stuck placing the lazy list.
- Logs: `main-stall` "main thread blocked N ms so far" climbs to 150–220 s;
  polls (every 3 s on the mock backend) stop.

**Tried, in PR #38.**
1. 6b38612: the mock poll no longer rewrites unchanged state every 3 s (it
   redrew the whole thread and flashed a spot "Loading" row). Fixed the
   scroll-older stall; not this hang.
2. 64b2b97: `ChipFlow` measures each chip once per update and answers a
   zero-width probe honestly (it claimed a minimum wider than the screen).
   Correct and kept; not this hang (ChipFlow never runs during it).
3. e3f3210: emoji row moved to an overlay over the list so the message row's
   height doesn't change. Did not stop the hang (it still hung at tap-add and
   take-back) and looked wrong; reverted in the next commit.

**Diagnostics that stay (DEBUG only).**
- `MainThreadStallWatch` (category `main-stall`): off-main watchdog; logs every
  second while the main thread is blocked, with `HangProbe` counts.
- `SQ_HANG_ABORT_SECONDS` in the app's environment aborts after that long
  blocked so the simulator writes a crash report. UI tests' `launchChat` sets it
  to 90 s (`hangAbortSeconds`).
- The reactions test prints `[ui-timing] reactions-ax5 <step> <s>s` and fails if
  the app is no longer running after tap-add or take-back (a dead app made a
  "doesn't exist" wait pass once).
- Capture: `xcrun simctl spawn <UDID> log stream --level debug --predicate
  'subsystem == "com.spencereese.squadsync"'`.

**Candidate next steps.**
- At accessibility sizes, render the thread in a non-lazy `VStack` (bounded by
  the loaded page) or a `List`, so there is no lazy placement to loop.
- Disable animation on the reaction height change (`transaction.disablesAnimations`
  / `.animation(nil, value:)` on the chips and emoji row) so the lazy stack
  doesn't place through an animated height.
- Reserve the chip row's space while the emoji row opens and closes (or keep the
  row's height fixed for the transition) so no row changes height in one update.
- Reduce nesting in the message row (Spacer plus a max-width frame in one
  `HStack`, a flexible frame around a `VStack`, the outer min-height frame).
- Bisect on a minimal LazyVStack repro at AX5 and file a Feedback if it
  reproduces without app code.
