import 'package:flutter/material.dart';
import '../../widgets/base_dialog.dart';

/// Confirmation dialog for simple yes/no decisions
class ConfirmationDialog extends BaseDialog {
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.isDestructive = false,
  });

  @override
  BaseDialogState<ConfirmationDialog> createState() =>
      _ConfirmationDialogState();

  @override
  bool get showCloseButton => false;

  @override
  bool get dismissible => true;

  @override
  double? get maxWidth => 350;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      DialogActions.secondaryButton(
        label: cancelText ?? 'Cancel',
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(width: 8),
      DialogActions.primaryButton(
        label: confirmText ?? 'Confirm',
        onPressed: () {
          Navigator.pop(context);
          onConfirm?.call();
        },
        isDestructive: isDestructive,
      ),
    ];
  }

  @override
  Widget buildContent(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
      textAlign: TextAlign.center,
    );
  }
}

/// Input dialog for collecting user text input
class InputDialog extends BaseDialog {
  final String label;
  final String? hint;
  final String? initialValue;
  final int? maxLines;
  final int? minLines;
  final String? confirmText;
  final String? cancelText;
  final ValueChanged<String>? onConfirm;
  final FormFieldValidator<String>? validator;

  const InputDialog({
    super.key,
    required this.label,
    this.hint,
    this.initialValue,
    this.maxLines = 1,
    this.minLines,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.validator,
  });

  @override
  BaseDialogState<BaseDialog> createState() => _InputDialogState();

  @override
  String? get title => null;

  @override
  bool get showCloseButton => false;

  @override
  bool get dismissible => true;

  @override
  double? get maxWidth => 400;

  @override
  List<Widget>? buildActions(BuildContext context) {
    final state = context.findAncestorStateOfType<_InputDialogState>();
    return [
      DialogActions.secondaryButton(
        label: cancelText ?? 'Cancel',
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(width: 8),
      DialogActions.primaryButton(
        label: confirmText ?? 'OK',
        onPressed: () {
          if (state?._formKey.currentState?.validate() ?? false) {
            Navigator.pop(context);
            onConfirm?.call(state?._controller.text ?? '');
          }
        },
      ),
    ];
  }

  @override
  Widget buildContent(BuildContext context) {
    final state = context.findAncestorStateOfType<_InputDialogState>();
    return Form(
      key: state?._formKey,
      child: TextFormField(
        controller: state?._controller,
        validator: validator,
        maxLines: maxLines,
        minLines: minLines,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          filled: true,
          fillColor:
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.error,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.error,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputDialogState extends BaseDialogState<BaseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final dialog = widget as InputDialog;
    _controller = TextEditingController(text: dialog.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Selection dialog for choosing from a list of options
class SelectionDialog<T> extends BaseDialog {
  final String title;
  final List<SelectionOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T>? onSelected;
  final String? confirmText;
  final String? cancelText;

  const SelectionDialog({
    super.key,
    required this.title,
    required this.options,
    this.selectedValue,
    this.onSelected,
    this.confirmText,
    this.cancelText,
  });

  @override
  bool get showCloseButton => false;

  @override
  bool get dismissible => true;

  @override
  double? get maxWidth => 400;

  @override
  double? get maxHeight => 500;

  @override
  List<Widget>? buildActions(BuildContext context) {
    final state = context.findAncestorStateOfType<_SelectionDialogState<T>>();
    return [
      DialogActions.secondaryButton(
        label: cancelText ?? 'Cancel',
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(width: 8),
      DialogActions.primaryButton(
        label: confirmText ?? 'Select',
        onPressed: () {
          final selected = state?._selectedValue;
          if (selected != null) {
            Navigator.pop(context);
            onSelected?.call(selected);
          }
        },
      ),
    ];
  }

  @override
  Widget buildContent(BuildContext context) {
    final state = context.findAncestorStateOfType<_SelectionDialogState<T>>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = state?._selectedValue == option.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: option.icon != null
                      ? Icon(
                          option.icon,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                        )
                      : null,
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: option.description != null
                      ? Text(
                          option.description!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    context.lightImpact();
                    if (state is _SelectionDialogState<T>) {
                      state._updateSelection(option.value);
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SelectionDialogState<T> extends BaseDialogState<SelectionDialog<T>> {
  late T? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selectedValue;
  }

  void _updateSelection(T value) {
    setState(() => _selectedValue = value);
  }
}

/// Data class for selection options
class SelectionOption<T> {
  final T value;
  final String label;
  final String? description;
  final IconData? icon;

  const SelectionOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });
}

/// Success/Error dialog for showing feedback
class FeedbackDialog extends BaseDialog {
  final String message;
  final bool isSuccess;
  final String? actionText;
  final VoidCallback? onAction;
  final Duration autoDismissDelay;

  const FeedbackDialog({
    super.key,
    required this.message,
    this.isSuccess = true,
    this.actionText,
    this.onAction,
    this.autoDismissDelay = const Duration(seconds: 2),
  });

  @override
  BaseDialogState<BaseDialog> createState() => _FeedbackDialogState();

  @override
  String? get title => null;

  @override
  bool get showCloseButton => false;

  @override
  bool get dismissible => false;

  @override
  double? get maxWidth => 300;

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (actionText != null && onAction != null) {
      return [
        DialogActions.primaryButton(
          label: actionText!,
          onPressed: () {
            Navigator.pop(context);
            onAction?.call();
          },
        ),
      ];
    }
    return null;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          size: 48,
          color: isSuccess
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FeedbackDialogState extends BaseDialogState<BaseDialog> {
  @override
  void initState() {
    super.initState();
    final dialog = widget as FeedbackDialog;
    if (dialog.actionText == null) {
      // Auto-dismiss after delay if no action button
      Future.delayed(dialog.autoDismissDelay, () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }
}

class _ConfirmationDialogState extends BaseDialogState<ConfirmationDialog> {
  // No additional state needed for confirmation dialog
}
