import 'package:flutter/material.dart';
import '../widgets/base_dialog.dart';
import '../widgets/dialog_variants.dart';

/// Performance optimization for frequently used dialogs
/// Provides a pool of reusable dialog instances to reduce widget rebuilds
class DialogPool {
  static final DialogPool _instance = DialogPool._internal();
  factory DialogPool() => _instance;
  DialogPool._internal();

  final Map<String, BaseDialog> _dialogCache = {};

  /// Get or create a confirmation dialog from the pool
  ConfirmationDialog getConfirmationDialog({
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    bool isDestructive = false,
    String? key,
  }) {
    final cacheKey = 'confirmation_${key ?? message.hashCode}';

    if (_dialogCache.containsKey(cacheKey)) {
      final cached = _dialogCache[cacheKey];
      if (cached is ConfirmationDialog) {
        // Update properties if needed
        return cached;
      }
    }

    final dialog = ConfirmationDialog(
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      isDestructive: isDestructive,
    );

    _dialogCache[cacheKey] = dialog;
    return dialog;
  }

  /// Get or create an input dialog from the pool
  InputDialog getInputDialog({
    required String label,
    String? hint,
    String? initialValue,
    int? maxLines,
    int? minLines,
    String? confirmText,
    String? cancelText,
    ValueChanged<String>? onConfirm,
    FormFieldValidator<String>? validator,
    String? key,
  }) {
    final cacheKey = 'input_${key ?? label.hashCode}';

    if (_dialogCache.containsKey(cacheKey)) {
      final cached = _dialogCache[cacheKey];
      if (cached is InputDialog) {
        return cached;
      }
    }

    final dialog = InputDialog(
      label: label,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      minLines: minLines,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      validator: validator,
    );

    _dialogCache[cacheKey] = dialog;
    return dialog;
  }

  /// Get or create a feedback dialog from the pool
  FeedbackDialog getFeedbackDialog({
    required String message,
    bool isSuccess = true,
    String? actionText,
    VoidCallback? onAction,
    Duration autoDismissDelay = const Duration(seconds: 2),
    String? key,
  }) {
    final cacheKey = 'feedback_${key ?? message.hashCode}_$isSuccess';

    if (_dialogCache.containsKey(cacheKey)) {
      final cached = _dialogCache[cacheKey];
      if (cached is FeedbackDialog) {
        return cached;
      }
    }

    final dialog = FeedbackDialog(
      message: message,
      isSuccess: isSuccess,
      actionText: actionText,
      onAction: onAction,
      autoDismissDelay: autoDismissDelay,
    );

    _dialogCache[cacheKey] = dialog;
    return dialog;
  }

  /// Clear all cached dialogs
  void clearCache() {
    _dialogCache.clear();
  }

  /// Remove specific dialog from cache
  void removeFromCache(String key) {
    _dialogCache.remove(key);
  }

  /// Get cache size for debugging
  int get cacheSize => _dialogCache.length;
}

/// Extension methods for easy dialog showing with pooling
extension DialogPoolExtensions on BuildContext {
  /// Show a pooled confirmation dialog
  Future<bool?> showPooledConfirmation({
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
    String? cacheKey,
  }) {
    final dialog = DialogPool().getConfirmationDialog(
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
      key: cacheKey,
    );

    return showDialog<bool>(
      context: this,
      builder: (context) => dialog,
    );
  }

  /// Show a pooled input dialog
  Future<String?> showPooledInput({
    required String label,
    String? hint,
    String? initialValue,
    int? maxLines,
    int? minLines,
    String? confirmText,
    String? cancelText,
    FormFieldValidator<String>? validator,
    String? cacheKey,
  }) {
    final dialog = DialogPool().getInputDialog(
      label: label,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      minLines: minLines,
      confirmText: confirmText,
      cancelText: cancelText,
      validator: validator,
      key: cacheKey,
    );

    return showDialog<String>(
      context: this,
      builder: (context) => dialog,
    );
  }

  /// Show a pooled feedback dialog
  Future<void> showPooledFeedback({
    required String message,
    bool isSuccess = true,
    String? actionText,
    VoidCallback? onAction,
    Duration autoDismissDelay = const Duration(seconds: 2),
    String? cacheKey,
  }) {
    final dialog = DialogPool().getFeedbackDialog(
      message: message,
      isSuccess: isSuccess,
      actionText: actionText,
      onAction: onAction,
      autoDismissDelay: autoDismissDelay,
      key: cacheKey,
    );

    return showDialog(
      context: this,
      builder: (context) => dialog,
    );
  }
}

/// Pre-configured common dialogs for frequent use
class CommonDialogs {
  static final DialogPool _pool = DialogPool();

  /// Delete confirmation dialog
  static ConfirmationDialog deleteConfirmation({
    required String itemName,
    required VoidCallback onConfirm,
  }) {
    return _pool.getConfirmationDialog(
      message:
          'Are you sure you want to delete "$itemName"? This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
      onConfirm: onConfirm,
      key: 'delete_$itemName',
    );
  }

  /// Leave squad confirmation dialog
  static ConfirmationDialog leaveSquad({
    required String squadName,
    required VoidCallback onConfirm,
  }) {
    return _pool.getConfirmationDialog(
      message:
          'Are you sure you want to leave "$squadName"? You will lose access to all squad features.',
      confirmText: 'Leave Squad',
      isDestructive: true,
      onConfirm: onConfirm,
      key: 'leave_squad',
    );
  }

  /// Success feedback for squad operations
  static FeedbackDialog squadCreated(
      {String? squadName, VoidCallback? onAction}) {
    return _pool.getFeedbackDialog(
      message: squadName != null
          ? '"$squadName" created successfully!'
          : 'Squad created successfully!',
      isSuccess: true,
      actionText: 'Invite Members',
      onAction: onAction,
      key: 'squad_created',
    );
  }

  /// Error feedback for failed operations
  static FeedbackDialog operationFailed({
    String message = 'Operation failed. Please try again.',
    VoidCallback? onAction,
  }) {
    return _pool.getFeedbackDialog(
      message: message,
      isSuccess: false,
      actionText: 'Try Again',
      onAction: onAction,
      autoDismissDelay: const Duration(seconds: 4),
      key: 'operation_failed',
    );
  }

  /// Input dialog for squad name
  static InputDialog squadNameInput({
    String? initialValue,
    required ValueChanged<String> onConfirm,
  }) {
    return _pool.getInputDialog(
      label: 'Squad Name',
      hint: 'Enter a name for your squad',
      initialValue: initialValue,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Squad name is required';
        }
        if (value.length < 3) {
          return 'Squad name must be at least 3 characters';
        }
        if (value.length > 50) {
          return 'Squad name must be less than 50 characters';
        }
        return null;
      },
      onConfirm: onConfirm,
      key: 'squad_name_input',
    );
  }
}
