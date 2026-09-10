import 'package:flutter/widgets.dart';

/// Height of the main tab bar chrome, not including the home-indicator inset.
///
/// Chat, groups, discovery, and lobbies used to pad with disagreeing magic
/// numbers (75 / 80 / 96 / 100). Clearance is always this + viewPadding.bottom.
const double kMainTabBarHeight = 75;

/// Bottom clearance so scrollable content / FABs sit above the main tab bar.
double mainTabClearance(double viewPaddingBottom) =>
    kMainTabBarHeight + viewPaddingBottom;

/// [mainTabClearance] using the current [MediaQuery] view padding.
double mainTabClearanceOf(BuildContext context) =>
    mainTabClearance(MediaQuery.viewPaddingOf(context).bottom);
