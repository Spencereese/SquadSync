import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/squad_notifier.dart';

class BanDialog {
  static void show(BuildContext context, WidgetRef ref) {
    String? selectedPlayer;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ban a Member'),
        content: Row(
          children: [
            Image.asset('assets/images/sword.png',
                width: 24, height: 24, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Member'),
                items: ref
                    .read(squadNotifierProvider.notifier)
                    .getFilteredMembers
                    .map((player) =>
                        DropdownMenuItem(value: player, child: Text(player)))
                    .toList(),
                onChanged: (value) => selectedPlayer = value,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (selectedPlayer != null) {
                ref.read(squadNotifierProvider.notifier).addBan(
                    selectedPlayer!,
                    ref
                            .read(squadNotifierProvider)
                            .value
                            ?.memberDisplayNames
                            .values
                            .first ??
                        'Unknown');
                Navigator.pop(context);
              }
            },
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }
}
