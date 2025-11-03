import 'package:flutter/material.dart';

/// Base class for squad-related dialogs with common styling and patterns
abstract class BaseSquadDialog extends StatelessWidget {
  const BaseSquadDialog({super.key});

  /// Common dialog shape used across all squad dialogs
  static RoundedRectangleBorder get dialogShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      );

  /// Common cancel button style
  static TextButton cancelButton(BuildContext context,
      {String text = 'Cancel'}) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(text),
    );
  }

  /// Common submit button style
  static TextButton submitButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      child: Text(text),
    );
  }

  /// Common dialog actions row
  static List<Widget> dialogActions({
    required BuildContext context,
    required List<Widget> actions,
  }) {
    return actions;
  }

  @override
  Widget build(BuildContext context);
}
