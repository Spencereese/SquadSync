import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/message_data.dart';

/// Unique collapsible UI for Grok AI messages
/// Shows as a compact one-liner that can be expanded to view full response
class GrokMessageBubble extends StatefulWidget {
  final MessageData messageData;
  final int index;

  const GrokMessageBubble({
    super.key,
    required this.messageData,
    required this.index,
  });

  @override
  State<GrokMessageBubble> createState() => _GrokMessageBubbleState();
}

class _GrokMessageBubbleState extends State<GrokMessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
    HapticFeedback.lightImpact();
  }

  String _getPreview() {
    final text = widget.messageData.text;
    if (text.length <= 60) return text;
    return '${text.substring(0, 60)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: GestureDetector(
        onTap: _toggleExpanded,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00D4FF).withValues(alpha: 0.15),
                const Color(0xFF0099FF).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Grok branding
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF00D4FF).withValues(alpha: 0.2),
                      const Color(0xFF0099FF).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Grok icon/badge
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF00D4FF).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Grok label
                    const Text(
                      'Grok AI',
                      style: TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    // Expand/collapse indicator
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: const Color(0xFF00D4FF).withValues(alpha: 0.8),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Content area (collapsible)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always show preview
                    if (!_isExpanded)
                      Text(
                        _getPreview(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),

                    // Full content when expanded
                    SizeTransition(
                      sizeFactor: _expandAnimation,
                      axisAlignment: -1.0,
                      child: _isExpanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.messageData.text,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Action buttons when expanded
                                Row(
                                  children: [
                                    _buildActionButton(
                                      icon: Icons.copy,
                                      label: 'Copy',
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(
                                            text: widget.messageData.text));
                                        HapticFeedback.lightImpact();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Copied to clipboard'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Tap to expand hint
                    if (!_isExpanded && widget.messageData.text.length > 60)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Tap to expand',
                          style: TextStyle(
                            color:
                                const Color(0xFF00D4FF).withValues(alpha: 0.6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(
            duration: const Duration(milliseconds: 400),
            delay: Duration(milliseconds: widget.index * 100),
          )
          .slideX(
            begin: -0.2,
            end: 0.0,
            duration: const Duration(milliseconds: 400),
            delay: Duration(milliseconds: widget.index * 100),
            curve: Curves.easeOutQuart,
          ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF00D4FF),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF00D4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
