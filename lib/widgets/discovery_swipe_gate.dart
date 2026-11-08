import 'package:flutter/material.dart';

import '../services/discovery_swipe_gate.dart';

const kDiscoverySwipeGatePanelKey = Key('discovery-swipe-gate');
const kDiscoverySwipeSurfaceKey = Key('discovery-swipe-surface');
const kDiscoverySwipeNeedFillKey = Key('discovery-swipe-need-fill');
const kDiscoverySwipeNeedVouchKey = Key('discovery-swipe-need-vouch');
const kDiscoverySwipeNeedBothKey = Key('discovery-swipe-need-both');
const kDiscoverySwipeEntryKey = Key('discovery-swipe-entry');

Key discoverySwipeReasonKey(DiscoverySwipeGateReason reason) {
  switch (reason) {
    case DiscoverySwipeGateReason.open:
      return kDiscoverySwipeSurfaceKey;
    case DiscoverySwipeGateReason.notLookingForFill:
      return kDiscoverySwipeNeedFillKey;
    case DiscoverySwipeGateReason.missingSquadVouch:
      return kDiscoverySwipeNeedVouchKey;
    case DiscoverySwipeGateReason.bothMissing:
      return kDiscoverySwipeNeedBothKey;
  }
}

/// Empty / gate copy when looking-for-fill + squad-vouch are not both true.
class DiscoverySwipeGatePanel extends StatelessWidget {
  const DiscoverySwipeGatePanel({super.key, required this.gate});

  final DiscoverySwipeGate gate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: kDiscoverySwipeGatePanelKey,
      appBar: AppBar(title: const Text('Fill swipe')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                kDiscoverySwipeGateTitle,
                key: discoverySwipeReasonKey(gate.reason),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                gate.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Squad-context entry. Opens the gated stub; does not launch public Tinder.
class DiscoverySwipeEntryButton extends StatelessWidget {
  const DiscoverySwipeEntryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: OutlinedButton(
        key: kDiscoverySwipeEntryKey,
        onPressed: onPressed,
        child: const Text('Fill swipe'),
      ),
    );
  }
}
