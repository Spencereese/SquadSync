import 'package:flutter/material.dart';

class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final Gradient? gradient;
  final bool compact;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.gradient,
    this.compact = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.compact ? 20 : 30),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.3 * glowAnimation.value),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.enabled ? widget.onPressed : null,
              borderRadius: BorderRadius.circular(widget.compact ? 20 : 30),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 24 : 48,
                  vertical: widget.compact ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: widget.enabled
                      ? (widget.gradient ??
                          const LinearGradient(
                            colors: [Colors.cyan, Colors.blue],
                          ))
                      : LinearGradient(
                          colors: [Colors.grey.shade800, Colors.grey.shade700],
                        ),
                  borderRadius: BorderRadius.circular(widget.compact ? 20 : 30),
                  border: Border.all(
                    color: widget.enabled
                        ? Colors.cyan.withOpacity(glowAnimation.value)
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color:
                          widget.enabled ? Colors.white : Colors.grey.shade500,
                      fontSize: widget.compact ? 14 : 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
