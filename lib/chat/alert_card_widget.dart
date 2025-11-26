import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../presentation/notifiers/user_notifier.dart';

class AlertCardWidget extends ConsumerWidget {
  const AlertCardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStateAsync = ref.watch(userNotifierProvider);

    return userStateAsync.when(
      data: (userState) =>
          _buildAlertsList(context, ref, userState?.alerts ?? []),
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => SizedBox.shrink(),
    );
  }

  Widget _buildAlertsList(
      BuildContext context, WidgetRef ref, List<String> alerts) {
    if (alerts.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            ...alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.notifications, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(alert),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(userNotifierProvider.notifier)
                              .removeAlert(alert);
                        },
                        tooltip: 'Dismiss alert',
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
