import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Base dialog widget that provides consistent iOS-style design, animations, and interactions
/// All dialogs in the app should inherit from this base class for unified appearance and behavior
abstract class BaseDialog extends StatefulWidget {
  final String? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool showCloseButton;
  final bool useBlurBackdrop;
  final bool dismissible;
  final Duration animationDuration;
  final double? maxWidth;
  final double? maxHeight;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const BaseDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.showCloseButton = true,
    this.useBlurBackdrop = true,
    this.dismissible = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.maxWidth,
    this.maxHeight,
    this.borderRadius,
    this.padding,
    this.margin,
  });

  @override
  BaseDialogState<BaseDialog> createState() => BaseDialogState<BaseDialog>();

  /// Override this method to build the dialog content
  Widget buildContent(BuildContext context);

  /// Override this method to provide custom actions
  List<Widget>? buildActions(BuildContext context) => actions;

  /// Override this method to customize the header
  Widget? buildHeader(BuildContext context) {
    if (title == null && !showCloseButton) return null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          if (showCloseButton)
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }
}

class BaseDialogState<T extends BaseDialog> extends State<T>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    if (widget.dismissible) {
      _animateOut(() => Navigator.pop(context));
    }
  }

  void _animateOut(VoidCallback onComplete) {
    _animationController.reverse().then((_) => onComplete());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: widget.dismissible,
      onPopInvoked: (didPop) {
        if (didPop) {
          _animateOut(() {});
        }
      },
      child: GestureDetector(
        onTap: widget.dismissible ? _handleDismiss : null,
        child: Stack(
          children: [
            // Backdrop
            if (widget.useBlurBackdrop)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              )
            else
              Container(
                color: Colors.black.withOpacity(0.6),
              ),

            // Dialog content
            Center(
              child: GestureDetector(
                onTap: () {}, // Prevent tap from bubbling up
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: widget.margin ??
                        const EdgeInsets.symmetric(horizontal: 20),
                    constraints: BoxConstraints(
                      maxWidth: widget.maxWidth ??
                          MediaQuery.of(context).size.width * 0.9,
                      maxHeight: widget.maxHeight ??
                          MediaQuery.of(context).size.height * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius:
                          widget.borderRadius ?? BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          widget.borderRadius ?? BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          if (widget.buildHeader(context) != null)
                            widget.buildHeader(context)!,

                          // Content
                          Flexible(
                            child: SingleChildScrollView(
                              padding:
                                  widget.padding ?? const EdgeInsets.all(20),
                              child: widget.buildContent(context),
                            ),
                          ),

                          // Actions
                          if (widget.buildActions(context)?.isNotEmpty ?? false)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: theme.dividerColor.withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: widget.buildActions(context)!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(
                      duration: widget.animationDuration,
                      begin: 0.1,
                      end: 0.0,
                      curve: Curves.easeOutBack,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility class for common dialog actions
class DialogActions {
  static Widget primaryButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: isDestructive
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            foregroundColor: isDestructive
                ? theme.colorScheme.onError
                : theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDestructive
                        ? theme.colorScheme.onError
                        : theme.colorScheme.onPrimary,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        );
      },
    );
  }

  static Widget secondaryButton({
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            foregroundColor: isDestructive
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDestructive
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
        );
      },
    );
  }

  static Widget cancelButton({
    required BuildContext context,
    String label = 'Cancel',
  }) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }
}

/// Extension methods for haptic feedback
extension HapticFeedbackExtension on BuildContext {
  void lightImpact() => HapticFeedback.lightImpact();
  void mediumImpact() => HapticFeedback.mediumImpact();
  void heavyImpact() => HapticFeedback.heavyImpact();
  void selectionClick() => HapticFeedback.selectionClick();
}
